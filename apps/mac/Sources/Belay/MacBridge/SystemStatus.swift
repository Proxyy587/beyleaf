import AppKit
import CoreWLAN
import Foundation
import IOKit.ps
import Network

/// Wi-Fi, battery, volume and clock for the notch's status row.
@MainActor
final class SystemStatus: ObservableObject {
    struct Battery: Equatable { var percent: Int; var charging: Bool; var onAC: Bool }

    @Published private(set) var battery: Battery?
    @Published private(set) var wifiOn = false
    /// 0...3 bars from RSSI. The network name needs Location permission on macOS 14+, so it is shown only if available.
    @Published private(set) var wifiBars = 0
    @Published private(set) var wifiName: String?
    @Published private(set) var online = true
    @Published var volume: Double = 0.5
    @Published private(set) var now = Date()

    private let path = NWPathMonitor()
    private var timer: Timer?

    init() {
        path.pathUpdateHandler = { [weak self] p in
            let ok = p.status == .satisfied
            Task { @MainActor in self?.online = ok }
        }
        path.start(queue: .global(qos: .utility))
        refresh()
        readVolume()
    }

    /// Refresh quickly while the notch is open, slowly while it's closed (battery budget, docs/tech-stack.md §4).
    func setActive(_ active: Bool) {
        timer?.invalidate()
        let t = Timer(timeInterval: active ? 1 : 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        if active { refresh(); readVolume() }
    }

    func refresh() {
        now = Date()
        battery = Self.readBattery()
        if let wifi = CWWiFiClient.shared().interface() {
            wifiOn = wifi.powerOn()
            let rssi = wifi.rssiValue()
            wifiBars = !wifiOn || rssi == 0 ? 0 : rssi > -55 ? 3 : rssi > -70 ? 2 : 1
            wifiName = wifi.ssid()
        } else {
            wifiOn = false; wifiBars = 0; wifiName = nil
        }
    }

    func setVolume(_ value: Double) {
        volume = value
        let level = Int((value * 100).rounded())
        Task.detached {
            var error: NSDictionary?
            NSAppleScript(source: "set volume output volume \(level)")?.executeAndReturnError(&error)
        }
    }

    private func readVolume() {
        Task.detached {
            var error: NSDictionary?
            let out = NSAppleScript(source: "output volume of (get volume settings)")?.executeAndReturnError(&error)
            let value = out.map { Double($0.int32Value) / 100 }
            await MainActor.run { if let value { self.volume = value } }
        }
    }

    private static func readBattery() -> Battery? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for source in list {
            guard let d = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  let cur = d[kIOPSCurrentCapacityKey] as? Int, let max = d[kIOPSMaxCapacityKey] as? Int, max > 0 else { continue }
            let charging = d[kIOPSIsChargingKey] as? Bool ?? false
            let onAC = (d[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
            return Battery(percent: Int((Double(cur) / Double(max) * 100).rounded()), charging: charging, onAC: onAC)
        }
        return nil
    }
}

import AppKit
import CoreWLAN
import Foundation
import IOKit.ps
import Network

/// Wi-Fi, battery, volume and clock for the notch's status row.
@MainActor
final class SystemStatus: ObservableObject {
    struct Battery: Equatable { var percent: Int; var charging: Bool; var onAC: Bool; var minutesToEmpty: Int? }

    @Published private(set) var battery: Battery?
    @Published private(set) var wifiOn = false
    /// 0...3 bars from RSSI. The network name needs Location permission on macOS 14+, so it is shown only if available.
    @Published private(set) var wifiBars = 0
    @Published private(set) var wifiName: String?
    @Published private(set) var online = true
    @Published var volume: Double = 0.5
    @Published private(set) var now = Date()

    /// "3h 12m" while on battery, when macOS has an estimate.
    var timeLeft: String? {
        guard let m = battery?.minutesToEmpty, m > 0, battery?.onAC == false else { return nil }
        return m >= 60 ? "\(m / 60)h \(m % 60)m" : "\(m)m"
    }

    private let path = NWPathMonitor()
    private var timer: Timer?

    init() {
        path.pathUpdateHandler = { [weak self] p in
            let ok = p.status == .satisfied
            Task { @MainActor in if self?.online != ok { self?.online = ok } }
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

    /// Publishes only values that actually changed, and the clock only when the minute changes: an unchanged
    /// @Published assignment still redraws the whole notch (measured: 10-25% CPU spikes at 1 Hz).
    func refresh() {
        let minute = Calendar.current.dateInterval(of: .minute, for: Date())?.start ?? Date()
        if minute != now { now = minute }
        let b = Self.readBattery()
        if b != battery { battery = b }
        var on = false, bars = 0, name: String? = nil
        if let wifi = CWWiFiClient.shared().interface() {
            on = wifi.powerOn()
            let rssi = wifi.rssiValue()
            bars = !on || rssi == 0 ? 0 : rssi > -55 ? 3 : rssi > -70 ? 2 : 1
            name = wifi.ssid()
        }
        if on != wifiOn { wifiOn = on }
        if bars != wifiBars { wifiBars = bars }
        if name != wifiName { wifiName = name }
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
            let tte = d[kIOPSTimeToEmptyKey] as? Int
            return Battery(percent: Int((Double(cur) / Double(max) * 100).rounded()), charging: charging, onAC: onAC,
                           minutesToEmpty: (tte ?? -1) > 0 ? tte : nil)
        }
        return nil
    }
}

import AppKit
import Foundation
import IOKit.ps
import Network

/// Battery level and internet reachability, for the low-battery and internet live activities.
/// (The Wi-Fi, battery and volume rows were cut in the purpose audit, docs/ui-inventory.md §5.)
@MainActor
final class SystemStatus: ObservableObject {
    struct Battery: Equatable { var percent: Int; var charging: Bool; var onAC: Bool; var minutesToEmpty: Int? }

    @Published private(set) var battery: Battery?
    @Published private(set) var online = true

    private let path = NWPathMonitor()
    private var powerSource: CFRunLoopSource?

    init() {
        path.pathUpdateHandler = { [weak self] p in
            let ok = p.status == .satisfied
            Task { @MainActor in if self?.online != ok { self?.online = ok } }
        }
        path.start(queue: .global(qos: .utility))
        refresh()
        // macOS tells us when the power source changes (level, plugged in, unplugged): no polling. Macs without a
        // battery never get a call, so they cost nothing.
        guard battery != nil else { return }
        let context = Unmanaged.passUnretained(self).toOpaque()
        if let src = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            let me = Unmanaged<SystemStatus>.fromOpaque(ctx).takeUnretainedValue()
            MainActor.assumeIsolated { me.refresh() }
        }, context)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
            powerSource = src
        }
    }

    /// Publishes only when the value changed: an unchanged @Published assignment still redraws the notch.
    func refresh() {
        let b = Self.readBattery()
        if b != battery { battery = b }
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

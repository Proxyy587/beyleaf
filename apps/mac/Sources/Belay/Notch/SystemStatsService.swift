import Darwin
import Foundation
import IOKit.ps

/// Samples the Mac's own counters for the System widget (docs/widget-hub.md §3.9). Public APIs only, no permission:
/// `host_processor_info`, `host_statistics64`, `sysctl`, `getifaddrs`, IOKit power sources, and URL resource values.
///
/// It samples only between `start()` and `stop()`, which the card calls from its appearance and its `ticking` flag, so
/// nothing runs while the page isn't on screen. One sample every 2 s costs a few tens of microseconds (one Mach call
/// per source); the slow-changing ones (disk, battery) are read every 10 s.
@MainActor
final class SystemStats: ObservableObject {
    static let shared = SystemStats()

    struct Snapshot: Equatable {
        var cpu: Double?
        var cores: [Double] = []
        var memUsed: UInt64 = 0
        var memTotal: UInt64 = 0
        var pressure = MemoryPressure.normal
        var diskFree: UInt64?
        var diskTotal: UInt64?
        var down: Double = 0
        var up: Double = 0
        var battery: BatteryInfo?
    }

    @Published private(set) var snapshot = Snapshot()
    /// "Apple M2 · 8 cores · 16 GB", read once.
    let about: String = {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var buf = [UInt8](repeating: 0, count: max(size, 1))
        sysctlbyname("machdep.cpu.brand_string", &buf, &size, nil, 0)
        let chip = String(decoding: buf.prefix { $0 != 0 }, as: UTF8.self)
        return SystemLogic.about(chip: chip, cores: ProcessInfo.processInfo.processorCount, memoryBytes: ProcessInfo.processInfo.physicalMemory)
    }()

    static let interval: TimeInterval = 2
    private var timer: Timer?
    private var tick = 0
    private var lastTicks: [CPUTicks] = []
    private var lastNet: (rx: UInt32, tx: UInt32, at: Date)?

    private init() {}

    func start() {
        guard timer == nil else { return }
        tick = 0
        sample()
        let t = Timer(timeInterval: Self.interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sample() }
        }
        t.tolerance = 0.5   // lets the system coalesce our wake-up with others
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate(); timer = nil
        lastTicks = []; lastNet = nil   // a later start must not diff against a stale sample
    }

    private func sample(now: Date = Date()) {
        var s = snapshot
        let ticks = Self.readCPU()
        if let u = SystemLogic.cpuUsage(prev: lastTicks, cur: ticks) { s.cpu = u.overall; s.cores = u.perCore }
        lastTicks = ticks

        let (used, total, pressure) = Self.readMemory()
        s.memUsed = used; s.memTotal = total; s.pressure = pressure

        if let net = Self.readNetwork() {
            if let p = lastNet {
                let dt = now.timeIntervalSince(p.at)
                s.down = SystemLogic.rate(prev: p.rx, cur: net.rx, seconds: dt)
                s.up = SystemLogic.rate(prev: p.tx, cur: net.tx, seconds: dt)
            }
            lastNet = (net.rx, net.tx, now)
        }

        if tick % 5 == 0 {   // disk and battery barely move: every 10 s
            let d = Self.readDisk()
            s.diskFree = d.free; s.diskTotal = d.total
            s.battery = Self.readBattery()
        }
        tick += 1
        if s != snapshot { snapshot = s }   // publish only a real change
    }

    // MARK: Readers

    private static func readCPU() -> [CPUTicks] {
        var count: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &count, &info, &infoCount) == KERN_SUCCESS, let info else { return [] }
        defer { vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: info)), vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride)) }
        let stride = Int(CPU_STATE_MAX)
        return (0..<Int(count)).map { i in
            func tick(_ s: Int32) -> UInt32 { UInt32(bitPattern: info[i * stride + Int(s)]) }
            return CPUTicks(user: tick(CPU_STATE_USER), system: tick(CPU_STATE_SYSTEM), idle: tick(CPU_STATE_IDLE), nice: tick(CPU_STATE_NICE))
        }
    }

    private static func readMemory() -> (used: UInt64, total: UInt64, pressure: MemoryPressure) {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let ok = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count) }
        } == KERN_SUCCESS
        let total = ProcessInfo.processInfo.physicalMemory
        var level: Int32 = 1
        var size = MemoryLayout<Int32>.size
        sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0)
        guard ok else { return (0, total, SystemLogic.pressure(fromSysctl: Int(level))) }
        let pages = MemoryPages(internalPages: UInt64(stats.internal_page_count), purgeable: UInt64(stats.purgeable_count),
                                wired: UInt64(stats.wire_count), compressed: UInt64(stats.compressor_page_count),
                                pageSize: UInt64(getpagesize()))
        return (min(SystemLogic.memoryUsed(pages), total), total, SystemLogic.pressure(fromSysctl: Int(level)))
    }

    /// Summed 32-bit byte counters of the physical interfaces (`en*`: Wi-Fi, Ethernet, Thunderbolt). Tunnels and
    /// loopback are skipped so traffic isn't counted twice.
    private static func readNetwork() -> (rx: UInt32, tx: UInt32)? {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return nil }
        defer { freeifaddrs(head) }
        var rx: UInt32 = 0, tx: UInt32 = 0
        for p in sequence(first: first, next: { $0.pointee.ifa_next }) {
            guard let addr = p.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_LINK), let data = p.pointee.ifa_data else { continue }
            guard String(cString: p.pointee.ifa_name).hasPrefix("en") else { continue }
            let d = data.assumingMemoryBound(to: if_data.self).pointee
            rx = rx &+ d.ifi_ibytes; tx = tx &+ d.ifi_obytes
        }
        return (rx, tx)
    }

    private static func readDisk() -> (free: UInt64?, total: UInt64?) {
        let keys: Set<URLResourceKey> = [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey]
        guard let v = try? URL(fileURLWithPath: "/").resourceValues(forKeys: keys) else { return (nil, nil) }
        return (v.volumeAvailableCapacityForImportantUsage.map { UInt64(max(0, $0)) }, v.volumeTotalCapacity.map { UInt64(max(0, $0)) })
    }

    private static func readBattery() -> BatteryInfo? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for ps in list {
            guard let d = IOPSGetPowerSourceDescription(blob, ps)?.takeUnretainedValue() as? [String: Any],
                  d["Type"] as? String == "InternalBattery",
                  let cur = d["Current Capacity"] as? Int, let max = d["Max Capacity"] as? Int, max > 0 else { continue }
            let charging = d["Is Charging"] as? Bool ?? false
            let plugged = (d["Power Source State"] as? String) == "AC Power"
            let m = (charging ? d["Time to Full Charge"] : d["Time to Empty"]) as? Int
            return BatteryInfo(percent: Int((Double(cur) / Double(max) * 100).rounded()), charging: charging, pluggedIn: plugged,
                               minutes: m.flatMap { $0 > 0 ? $0 : nil })
        }
        return nil   // a desktop Mac: no battery row at all
    }
}

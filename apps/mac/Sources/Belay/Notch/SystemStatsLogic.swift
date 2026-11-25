import Foundation

// System widget logic (docs/widget-hub.md §3.9): counters in, percentages and text out. Foundation only, so the
// self-test compiles it with swiftc. The Mach and IOKit calls that produce the counters live in SystemStatsService.swift.

/// One core's cumulative scheduler ticks (`host_processor_info`, PROCESSOR_CPU_LOAD_INFO). The counters are 32-bit and wrap.
struct CPUTicks: Equatable, Sendable {
    var user: UInt32, system: UInt32, idle: UInt32, nice: UInt32
}

/// Memory as the Mach VM statistics report it, in pages.
struct MemoryPages: Equatable, Sendable {
    var internalPages: UInt64   // anonymous memory (app memory + purgeable)
    var purgeable: UInt64
    var wired: UInt64
    var compressed: UInt64
    var pageSize: UInt64
}

enum MemoryPressure: Int, Sendable { case normal = 1, warning = 2, critical = 4 }

struct BatteryInfo: Equatable, Sendable {
    var percent: Int
    var charging: Bool
    var pluggedIn: Bool
    /// Minutes to empty (on battery) or to full (charging); nil while macOS is still working it out.
    var minutes: Int?
}

enum SystemLogic {
    // MARK: CPU

    /// Wrap-safe difference of two 32-bit counters.
    static func delta32(_ prev: UInt32, _ cur: UInt32) -> UInt64 { UInt64(cur &- prev) }

    /// Busy fraction (0...1) of one core between two samples. Nice counts as busy. No elapsed ticks reads as 0.
    static func coreUsage(_ prev: CPUTicks, _ cur: CPUTicks) -> Double {
        let busy = delta32(prev.user, cur.user) + delta32(prev.system, cur.system) + delta32(prev.nice, cur.nice)
        let idle = delta32(prev.idle, cur.idle)
        let total = busy + idle
        return total == 0 ? 0 : Double(busy) / Double(total)
    }

    /// Per-core usage and the overall figure (the mean of the cores, weighted by their ticks). Empty or mismatched
    /// samples give nil.
    static func cpuUsage(prev: [CPUTicks], cur: [CPUTicks]) -> (overall: Double, perCore: [Double])? {
        guard !prev.isEmpty, prev.count == cur.count else { return nil }
        var busy: UInt64 = 0, total: UInt64 = 0
        var per: [Double] = []
        for (p, c) in zip(prev, cur) {
            let b = delta32(p.user, c.user) + delta32(p.system, c.system) + delta32(p.nice, c.nice)
            let i = delta32(p.idle, c.idle)
            busy += b; total += b + i
            per.append(b + i == 0 ? 0 : Double(b) / Double(b + i))
        }
        return (total == 0 ? 0 : Double(busy) / Double(total), per)
    }

    // MARK: Memory

    /// Bytes in use, the way Activity Monitor's "Memory Used" adds up: app memory (anonymous minus purgeable) + wired + compressed.
    static func memoryUsed(_ m: MemoryPages) -> UInt64 {
        let app = m.internalPages >= m.purgeable ? m.internalPages - m.purgeable : 0
        return (app + m.wired + m.compressed) * m.pageSize
    }

    static func pressure(fromSysctl level: Int) -> MemoryPressure { MemoryPressure(rawValue: level) ?? .normal }

    // MARK: Network

    /// Bytes a second between two counter samples `seconds` apart. 32-bit counters (`getifaddrs`), wrap-safe.
    static func rate(prev: UInt32, cur: UInt32, seconds: Double) -> Double {
        seconds <= 0 ? 0 : Double(delta32(prev, cur)) / seconds
    }

    // MARK: Text

    /// Decimal units, as macOS shows storage and as networks count: "0 B", "512 B", "1.2 KB", "12 MB", "1.2 GB".
    /// One decimal under 10, none from 10 up.
    static func bytes(_ n: Double) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var v = max(0, n), i = 0
        while v >= 1000, i < units.count - 1 { v /= 1000; i += 1 }
        if i == 0 { return "\(Int(v)) B" }
        let rounded = v < 10 ? (v * 10).rounded() / 10 : v.rounded()
        // 999.9 KB rounds to 1000: carry into the next unit instead of printing "1000 KB".
        if rounded >= 1000, i < units.count - 1 { return "1.0 \(units[i + 1])" }
        return (rounded < 10 ? String(format: "%.1f", rounded) : String(format: "%.0f", rounded)) + " \(units[i])"
    }

    static func rateText(_ bytesPerSecond: Double) -> String { bytes(bytesPerSecond) + "/s" }

    static func percent(_ f: Double) -> String { "\(Int((min(1, max(0, f)) * 100).rounded()))%" }

    /// "3 h 4 min", "45 min", "1 h".
    static func duration(minutes: Int) -> String {
        let m = max(0, minutes)
        if m < 60 { return "\(m) min" }
        return m % 60 == 0 ? "\(m / 60) h" : "\(m / 60) h \(m % 60) min"
    }

    /// The battery line: "CHARGING · 1 H 20 MIN TO FULL" style text in plain case (the status line uppercases it).
    static func batteryStatus(_ b: BatteryInfo) -> String {
        if b.charging {
            return b.minutes.map { "Charging · \(duration(minutes: $0)) to full" } ?? "Charging"
        }
        if b.pluggedIn { return b.percent >= 100 ? "Charged" : "Plugged in" }
        return b.minutes.map { "\(duration(minutes: $0)) left" } ?? "On battery"
    }

    /// "Apple M2 · 8 cores · 16 GB".
    static func about(chip: String, cores: Int, memoryBytes: UInt64) -> String {
        var parts: [String] = []
        if !chip.isEmpty { parts.append(chip) }
        if cores > 0 { parts.append("\(cores) cores") }
        if memoryBytes > 0 { parts.append("\(Int((Double(memoryBytes) / 1_073_741_824).rounded())) GB") }
        return parts.joined(separator: " · ")
    }

    /// VoiceOver text for the whole card.
    static func spoken(cpu: Double?, memUsed: UInt64, memTotal: UInt64, pressure: MemoryPressure, diskFree: UInt64?,
                       down: Double, up: Double, battery: BatteryInfo?) -> String {
        var s: [String] = []
        if let cpu { s.append("CPU \(percent(cpu))") }
        if memTotal > 0 { s.append("Memory \(bytes(Double(memUsed))) of \(bytes(Double(memTotal))), pressure \(pressure == .normal ? "normal" : pressure == .warning ? "high" : "critical")") }
        if let diskFree { s.append("Disk \(bytes(Double(diskFree))) free") }
        s.append("Network down \(rateText(down)), up \(rateText(up))")
        if let battery { s.append("Battery \(battery.percent) percent, \(batteryStatus(battery))") }
        return s.joined(separator: ". ") + "."
    }
}

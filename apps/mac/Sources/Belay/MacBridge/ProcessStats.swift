import Darwin
import Foundation

/// Belay's own CPU and memory, for the live readout in Settings → General → Performance.
/// Read only while that section is on screen; nothing is sampled in the background.
enum ProcessStats {
    struct Sample { let cpuSeconds: Double; let at: Date }

    /// Total user + system CPU time this process has used so far.
    static func sample() -> Sample {
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)
        func seconds(_ t: timeval) -> Double { Double(t.tv_sec) + Double(t.tv_usec) / 1_000_000 }
        return Sample(cpuSeconds: seconds(usage.ru_utime) + seconds(usage.ru_stime), at: Date())
    }

    /// CPU use between two samples, as a percentage of one core (the same scale Activity Monitor uses).
    static func cpuPercent(from a: Sample, to b: Sample) -> Double {
        let wall = b.at.timeIntervalSince(a.at)
        return wall > 0 ? max(0, (b.cpuSeconds - a.cpuSeconds) / wall * 100) : 0
    }

    /// Memory as Activity Monitor's "Memory" column reports it (physical footprint), in bytes.
    static func memoryFootprint() -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) { p in
            p.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count) }
        }
        return kr == KERN_SUCCESS ? info.phys_footprint : 0
    }
}

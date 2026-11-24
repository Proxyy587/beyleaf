// Self-test for BeatAnalyzer on synthetic signals (no audio device, nothing played).
// Run: apps/mac/scripts/beat-selftest.sh
import Foundation

let sr = 48_000.0
var failures = 0
@MainActor func check(_ ok: Bool, _ what: String) { print(ok ? "ok    \(what)" : "FAIL  \(what)"); if !ok { failures += 1 } }
@MainActor func run(_ seconds: Double, _ sample: (Int) -> Float) -> BeatAnalyzer {
    let a = BeatAnalyzer(sampleRate: sr)
    let n = Int(seconds * sr)
    var chunk = [Float](repeating: 0, count: 512)   // IOProc-sized chunks
    var i = 0
    while i < n {
        let c = min(512, n - i)
        for k in 0..<c { chunk[k] = sample(i + k) }
        chunk.withUnsafeBufferPointer { a.process(UnsafeBufferPointer(rebasing: $0[0..<c])) }
        i += c
    }
    return a
}
func fmt(_ l: [Float]) -> String { l.map { String(format: "%.2f", $0) }.joined(separator: " ") }

// 1. Silence: bars rest at zero, no beats.
let silent = run(2) { _ in 0 }
print("silence      levels \(fmt(silent.levels)) beats \(silent.beatCount)")
check(silent.levels.allSatisfy { $0 < 0.01 } && silent.beatCount == 0, "silence: no movement, no beats")

// 2. Steady 1 kHz sine: the mids band (600–2500 Hz) leads; a steady tone is not a beat.
let sine = run(3) { i in 0.5 * sin(2 * .pi * 1000 * Float(i) / Float(sr)) }
print("1 kHz sine   levels \(fmt(sine.levels)) beats \(sine.beatCount)")
check(sine.levels[2] > 0.6 && sine.levels[2] > sine.levels[0] && sine.levels[2] > sine.levels[3], "sine: 1 kHz lands in the mids band")
check(sine.beatCount == 0, "sine: steady tone gives no beats")

// 3. Kick drum at 120 BPM (60 Hz decaying bursts every 0.5 s) over a quiet hi-hat noise bed, 8 s.
var seed: UInt64 = 42
@MainActor func noise() -> Float { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Float(Int64(bitPattern: seed >> 11) % 1000) / 1000 }
let period = Int(0.5 * sr)
let kick = run(8) { i in
    let t = Float(i % period) / Float(sr)
    return 0.8 * exp(-t * 18) * sin(2 * .pi * 60 * t) + 0.02 * noise()
}
print("kick 120 BPM levels \(fmt(kick.levels)) beats \(kick.beatCount) (expect ~16)")
check((14...17).contains(kick.beatCount), "kick: one beat per kick (14–17 in 8 s)")

// 4. Kick every 0.1 s (faster than the 250 ms refractory gap): beats are rate-limited, not doubled.
let fast = run(4) { i in let t = Float(i % Int(0.1 * sr)) / Float(sr); return 0.8 * exp(-t * 40) * sin(2 * .pi * 60 * t) }
print("kick 600 BPM beats \(fast.beatCount) (max 16)")
check(fast.beatCount <= 16, "fast kicks: at most one beat per 250 ms")

// 5. Cost: analysing 60 s of audio must be far faster than real time.
let t0 = Date()
_ = run(60) { i in 0.3 * sin(2 * .pi * 220 * Float(i) / Float(sr)) }
let ms = Date().timeIntervalSince(t0) * 1000
print(String(format: "cost         60 s of audio analysed in %.0f ms (%.3f%% of real time)", ms, ms / 600))
check(ms < 600, "cost: under 1% of real time")

print(failures == 0 ? "beat-selftest: PASS" : "beat-selftest: FAIL (\(failures))")
exit(failures == 0 ? 0 : 1)

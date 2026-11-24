import Accelerate

/// Turns mono audio into a few log-spaced band levels (0…1) and beat onsets, for the notch's music bars.
///
/// Pure DSP, no I/O: samples in, numbers out. Nothing is stored beyond one FFT window, so no audio is kept.
/// Not thread-safe: call it from one queue (the tap's IOProc queue).
///
/// - Bands: Hann-windowed 1024-point FFT every 512 samples (~94 analyses/s at 48 kHz); power summed per band, in dB,
///   normalised against a slowly decaying peak (automatic gain), so quiet and loud tracks both move. Each band follows
///   its own peak, but never more than 18 dB above the loudest band's, so spectral leakage from a loud band stays low.
/// - Smoothing: fast attack, slower release, so bars jump on hits and fall gently.
/// - Beats: low-band energy against its own ~0.5 s average (classic energy onset), at most one per 250 ms.
///   The kick band must be within 24 dB of the loudest band, and the history full. A beat sets `pulse` to 1; it decays
///   in about 120 ms.
final class BeatAnalyzer {
    static let fftSize = 1024
    static let hop = 512
    /// Band edges in Hz: kick, bass and low mids, mids, highs.
    static let edges: [Double] = [40, 150, 600, 2500, 10_000]

    let sampleRate: Double
    var bandCount: Int { Self.edges.count - 1 }

    private(set) var levels: [Float]
    private(set) var pulse: Float = 0
    private(set) var beatCount = 0
    /// Analysis frames processed (for tests and silence detection).
    private(set) var frames = 0

    private let fft: vDSP.FFT<DSPSplitComplex>
    private let window: [Float]
    private var buffer = [Float](repeating: 0, count: BeatAnalyzer.fftSize)
    private var filled = 0
    private var windowed = [Float](repeating: 0, count: BeatAnalyzer.fftSize)
    private var real = [Float](repeating: 0, count: BeatAnalyzer.fftSize / 2)
    private var imag = [Float](repeating: 0, count: BeatAnalyzer.fftSize / 2)
    private var power = [Float](repeating: 0, count: BeatAnalyzer.fftSize / 2)
    private let bins: [Range<Int>]
    private var peakDb: [Float]
    private var bassHistory = [Float](repeating: 0, count: 48)
    private var historyIndex = 0
    private var framesSinceBeat = 1_000

    private static let attack: Float = 0.6
    private static let release: Float = 0.12
    private static let window_dB: Float = 30          // levels span the 30 dB under the running peak
    private static let peakDecay_dB: Float = 0.05      // per frame, ~4.7 dB/s
    private static let bandBoost_dB: Float = 18         // most a quiet band is lifted relative to the loudest
    private static let beatFloor_dB: Float = 24         // kick band must be this close to the loudest band
    private static let silenceRMS: Float = 1e-4        // -80 dBFS
    private static let beatRatio: Float = 1.5
    private static let pulseDecay: Float = 0.82

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
        fft = vDSP.FFT(log2n: vDSP_Length(log2(Double(Self.fftSize))), radix: .radix2, ofType: DSPSplitComplex.self)!
        window = vDSP.window(ofType: Float.self, usingSequence: .hanningDenormalized, count: Self.fftSize, isHalfWindow: false)
        let binHz = sampleRate / Double(Self.fftSize)
        let nyquistBin = Self.fftSize / 2
        bins = zip(Self.edges, Self.edges.dropFirst()).map { lo, hi in
            let a = max(1, Int((lo / binHz).rounded()))
            let b = min(nyquistBin, max(a + 1, Int((hi / binHz).rounded())))
            return a..<b
        }
        levels = Array(repeating: 0, count: Self.edges.count - 1)
        peakDb = Array(repeating: -60, count: Self.edges.count - 1)
    }

    /// Feed mono samples (any count). Runs an analysis for every completed hop.
    func process(_ samples: UnsafeBufferPointer<Float>) {
        var i = 0
        while i < samples.count {
            let n = min(Self.fftSize - filled, samples.count - i)
            buffer.withUnsafeMutableBufferPointer { b in
                for k in 0..<n { b[filled + k] = samples[i + k] }
            }
            filled += n; i += n
            if filled == Self.fftSize {
                analyse()
                // Keep the second half for 50% overlap.
                buffer.withUnsafeMutableBufferPointer { b in
                    for k in 0..<Self.hop { b[k] = b[k + Self.hop] }
                }
                filled = Self.fftSize - Self.hop
            }
        }
    }

    private func analyse() {
        frames += 1
        framesSinceBeat += 1
        pulse *= Self.pulseDecay

        let rms = vDSP.rootMeanSquare(buffer)
        if rms < Self.silenceRMS {
            for b in levels.indices { levels[b] *= (1 - Self.release) }
            return
        }

        vDSP.multiply(buffer, window, result: &windowed)
        let half = Self.fftSize / 2
        real.withUnsafeMutableBufferPointer { rp in
            imag.withUnsafeMutableBufferPointer { ip in
                var split = DSPSplitComplex(realp: rp.baseAddress!, imagp: ip.baseAddress!)
                windowed.withUnsafeBytes { raw in
                    vDSP_ctoz(raw.bindMemory(to: DSPComplex.self).baseAddress!, 2, &split, 1, vDSP_Length(half))
                }
                fft.forward(input: split, output: &split)
                power.withUnsafeMutableBufferPointer { pp in
                    vDSP_zvmags(&split, 1, pp.baseAddress!, 1, vDSP_Length(half))
                }
            }
        }

        var energies = [Float](repeating: 0, count: bins.count)
        var dbs = [Float](repeating: 0, count: bins.count)
        for (b, range) in bins.enumerated() {
            var sum: Float = 0
            power.withUnsafeBufferPointer { p in
                vDSP_sve(p.baseAddress! + range.lowerBound, 1, &sum, vDSP_Length(range.count))
            }
            energies[b] = sum / Float(range.count)
            dbs[b] = 10 * log10(energies[b] + 1e-12)
            peakDb[b] = max(dbs[b], peakDb[b] - Self.peakDecay_dB)
        }
        let loudestPeak = peakDb.max() ?? 0
        for b in bins.indices {
            let reference = max(peakDb[b], loudestPeak - Self.bandBoost_dB)
            let target = min(1, max(0, (dbs[b] - (reference - Self.window_dB)) / Self.window_dB))
            let k = target > levels[b] ? Self.attack : Self.release
            levels[b] += (target - levels[b]) * k
        }
        let bassEnergy = energies[0]
        let bassCounts = dbs[0] > (dbs.max() ?? 0) - Self.beatFloor_dB

        // Onset: kick-band energy well above its recent average, at most one beat per 250 ms.
        let average = vDSP.mean(bassHistory)
        let minGap = Int((0.25 * sampleRate / Double(Self.hop)).rounded())
        if frames > bassHistory.count, bassCounts, bassEnergy > average * Self.beatRatio, framesSinceBeat >= minGap {
            beatCount += 1
            framesSinceBeat = 0
            pulse = 1
        }
        bassHistory[historyIndex] = bassEnergy
        historyIndex = (historyIndex + 1) % bassHistory.count
    }
}

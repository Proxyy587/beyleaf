import AppKit
import os
import QuartzCore
import SwiftUI

/// The latest band levels and beat pulse, shared between the audio queue (writer) and the bars' display link (reader).
/// A lock instead of `@Published`: 30 SwiftUI updates a second re-laid-out the whole notch window and cost 11–20% CPU
/// (measured 2026-11-25 with `--beat-demo`). Reading here costs nothing when nobody draws.
final class BeatLevels: @unchecked Sendable {
    private var lock = os_unfair_lock()
    private var levels: [Float]
    private var pulse: Float = 0
    /// Bumped on every write, so the reader can tell new data from a quiet stream.
    private var version: UInt64 = 0
    /// Set by the reader when it stops its display link; the next write wakes it once, on the main queue.
    private var parked = false
    private var onUnpark: (@Sendable () -> Void)?

    init(bands: Int) { levels = Array(repeating: 0, count: bands) }

    func write(_ levels: [Float], pulse: Float) {
        os_unfair_lock_lock(&lock)
        self.levels = levels; self.pulse = pulse; version &+= 1
        let wake = parked ? onUnpark : nil
        parked = false
        os_unfair_lock_unlock(&lock)
        if let wake { DispatchQueue.main.async(execute: wake) }
    }

    /// The reader parks itself; `wake` runs on the main queue after the next write.
    func park(wake: @escaping @Sendable () -> Void) {
        os_unfair_lock_lock(&lock); defer { os_unfair_lock_unlock(&lock) }
        parked = true; onUnpark = wake
    }

    func reset() { write(Array(repeating: 0, count: levels.count), pulse: 0) }

    func read() -> (levels: [Float], pulse: Float, version: UInt64) {
        os_unfair_lock_lock(&lock); defer { os_unfair_lock_unlock(&lock) }
        return (levels, pulse, version)
    }
}

/// Music bars drawn with Core Animation layers, outside SwiftUI's update cycle.
///
/// A display link (synced to the screen, capped by Settings → Performance) eases each bar toward the latest level, so
/// motion is smooth at 60/120 Hz even though the analyser publishes 30 times a second. Only layer transforms change:
/// the GPU composites them, and nothing is laid out. The link stops itself once the bars have settled with no new data,
/// and whenever the view leaves the window.
final class BeatBarsNSView: NSView {
    var source: BeatLevels? { didSet { wake() } }
    var ink: NSColor = .white { didSet { bars.forEach { $0.backgroundColor = ink.cgColor } } }
    var maxFPS: Float = 60 { didSet { configureLink() } }

    private var bars: [CALayer] = []
    private var shown: [CGFloat] = []
    private var lift: CGFloat = 0
    private var lastVersion: UInt64 = .max
    private var link: CADisplayLink?
    private var quietFrames = 0

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = false
    }
    required init?(coder: NSCoder) { fatalError("not used") }

    override var isFlipped: Bool { true }

    override func layout() {
        super.layout()
        rebuildIfNeeded()
        apply()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { link?.invalidate(); link = nil } else { wake() }
    }

    override func viewDidHide() { super.viewDidHide(); link?.isPaused = true }
    override func viewDidUnhide() { super.viewDidUnhide(); wake() }

    /// Start (or resume) the link: new data may be waiting.
    func wake() {
        guard window != nil, !isHiddenOrHasHiddenAncestor else { return }
        if link == nil { configureLink() }
        quietFrames = 0
        link?.isPaused = false
    }

    private func configureLink() {
        link?.invalidate()
        guard window != nil else { link = nil; return }
        let l = displayLink(target: self, selector: #selector(tick))
        l.preferredFrameRateRange = CAFrameRateRange(minimum: min(30, maxFPS), maximum: maxFPS, preferred: maxFPS)
        l.add(to: .main, forMode: .common)
        link = l
    }

    private func rebuildIfNeeded() {
        let count = source?.read().levels.count ?? 0
        guard bars.count != count else { return }
        bars.forEach { $0.removeFromSuperlayer() }
        bars = (0..<count).map { _ in
            let b = CALayer()
            b.backgroundColor = ink.cgColor
            b.anchorPoint = CGPoint(x: 0.5, y: 1)   // grow from the bottom
            layer?.addSublayer(b)
            return b
        }
        shown = Array(repeating: 0, count: count)
    }

    @objc private func tick(_ link: CADisplayLink) {
        guard let source else { link.isPaused = true; return }
        let now = source.read()
        rebuildIfNeeded()
        let fresh = now.version != lastVersion
        lastVersion = now.version
        // Ease toward the target: quick up, gentle down (frame-rate independent).
        let dt = CGFloat(max(1.0 / 120, min(1.0 / 20, link.targetTimestamp - link.timestamp)))
        var moving = false
        for i in shown.indices where i < now.levels.count {
            let target = CGFloat(0.2 + 0.8 * now.levels[i])
            let rate: CGFloat = target > shown[i] ? 28 : 10
            let next = shown[i] + (target - shown[i]) * min(1, rate * dt)
            if abs(next - shown[i]) > 0.002 { moving = true }
            shown[i] = next
        }
        let targetLift = CGFloat(now.pulse)
        let nextLift = lift + (targetLift - lift) * min(1, 24 * dt)
        if abs(nextLift - lift) > 0.002 { moving = true }
        lift = nextLift
        apply()
        // Settled and no new data for half a second: stop until the next write wakes us (via `wake()` from SwiftUI).
        quietFrames = (moving || fresh) ? 0 : quietFrames + 1
        if quietFrames > 30 {
            link.isPaused = true
            source.park { [weak self] in MainActor.assumeIsolated { self?.wake() } }
        }
    }

    private func apply() {
        guard !bars.isEmpty else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let gap: CGFloat = 2
        let w = (bounds.width - gap * CGFloat(bars.count - 1)) / CGFloat(bars.count)
        let scale = 1 + 0.12 * lift
        for (i, b) in bars.enumerated() {
            let h = bounds.height * min(1, shown[i] * scale)
            b.cornerRadius = w / 2
            b.bounds = CGRect(x: 0, y: 0, width: w, height: max(w, h))
            b.position = CGPoint(x: CGFloat(i) * (w + gap) + w / 2, y: bounds.height)
        }
        CATransaction.commit()
    }
}

/// SwiftUI wrapper. SwiftUI only creates it and passes colour and frame-rate changes; per-frame work never touches it.
struct BeatBarsLayer: NSViewRepresentable {
    let source: BeatLevels
    let ink: Color
    let maxFPS: Float
    func makeNSView(context: Context) -> BeatBarsNSView {
        let v = BeatBarsNSView(frame: .zero)
        v.source = source
        return v
    }
    func updateNSView(_ v: BeatBarsNSView, context: Context) {
        v.ink = NSColor(ink)
        if v.maxFPS != maxFPS { v.maxFPS = maxFPS }
        v.wake()
    }
}

import SwiftUI

/// One of Belay's 15 buddies (`brand/buddies/`). Each comes in two styles; the eyes are separate so they can move.
enum BuddyID: String, CaseIterable, Identifiable, Sendable {
    case beepo, sprout, willo, pip, gloop
    case barnaby, fig, poko, crush, fizz
    case otto, bram, breeze, ziggy, toby

    var id: String { rawValue }
}

enum BuddyStyle: String, CaseIterable, Sendable {
    case smooth, pixel
}

/// What the buddy is doing. Eyes blink by scaling Y and look by moving the eye group; the body only ever translates.
enum BuddyMood: String, CaseIterable, Sendable {
    case idle, blink, lookLeft, lookRight, hover, sleep, happy

    var eyesClosed: Bool { self == .blink || self == .sleep }
    var look: CGFloat {
        switch self {
        case .lookLeft: -1
        case .lookRight: 1
        default: 0
        }
    }
}

// MARK: - Art data

/// The traced art, as written by `scripts/gen-buddies.swift` into `BuddyArtwork.swift`.
enum BuddyArtwork {
    struct EyeRect: Sendable { let x, y, w, h: CGFloat }
    struct SmoothLayer: Sendable { let part: String; let fill: UInt32; let clipped: Bool; let path: String }
    struct SmoothSpec: Sendable {
        let width, height: CGFloat
        let eyeFill: UInt32
        let eyes: [EyeRect]
        let layers: [SmoothLayer]
    }
    /// Cells are base-36 characters: `rows` holds one palette index per cell ("." is empty); the eye and mouth lists
    /// are x, y, palette-index triples.
    struct PixelSpec: Sendable {
        let width, height: Int
        let palette: [UInt32]
        let rows: String
        let eyesOpen, eyesClosed, eyesHappy, mouth: String
    }
}

extension Color {
    init(rgb: UInt32) {
        self.init(.sRGB, red: Double((rgb >> 16) & 0xFF) / 255, green: Double((rgb >> 8) & 0xFF) / 255,
                  blue: Double(rgb & 0xFF) / 255, opacity: 1)
    }
}

/// Parsed, ready-to-draw art. Parsed once per buddy, on first use, from the generated strings.
@MainActor
enum BuddyArt {
    struct Smooth {
        let size: CGSize
        let layers: [(path: Path, color: Color, clipped: Bool)]
        let silhouette: Path
        let eyes: Path
        let happyEyes: Path
        let eyeColor: Color
        let eyeWidth: CGFloat
        let eyeCenterY: CGFloat
    }

    struct Cell { let x: Int, y: Int, color: Int }

    struct Pixel {
        let width: Int, height: Int
        let palette: [CGColor]
        let body: [Cell]
        let eyesOpen: [Cell], eyesClosed: [Cell], eyesHappy: [Cell], mouth: [Cell]
    }

    private static var smoothCache: [BuddyID: Smooth] = [:]
    private static var pixelCache: [BuddyID: Pixel] = [:]

    static func smooth(_ id: BuddyID) -> Smooth {
        if let s = smoothCache[id] { return s }
        let spec = BuddyArtwork.smoothSpec(id)
        let layers = spec.layers.map { (path: svgPath($0.path), color: Color(rgb: $0.fill), clipped: $0.clipped) }
        var eyes = Path(), happy = Path()
        for e in spec.eyes {
            eyes.addRoundedRect(in: CGRect(x: e.x, y: e.y, width: e.w, height: e.h),
                                cornerSize: CGSize(width: e.w / 2, height: e.w / 2), style: .circular)
            // The happy eye: an upturned arc as wide as two eyes, stroked in the eye colour (^ ^).
            let cx = e.x + e.w / 2, cy = e.y + e.h / 2, a = e.w * 0.95, up = e.h * 0.42, dn = e.h * 0.12
            happy.move(to: CGPoint(x: cx - a, y: cy + dn))
            happy.addQuadCurve(to: CGPoint(x: cx + a, y: cy + dn), control: CGPoint(x: cx, y: cy - up - dn))
        }
        let first = spec.eyes.first ?? .init(x: 0, y: 0, w: 1, h: 1)
        let s = Smooth(size: CGSize(width: spec.width, height: spec.height), layers: layers,
                       silhouette: layers.first?.path ?? Path(), eyes: eyes, happyEyes: happy,
                       eyeColor: Color(rgb: spec.eyeFill), eyeWidth: first.w,
                       eyeCenterY: spec.eyes.map { $0.y + $0.h / 2 }.reduce(0, +) / CGFloat(max(1, spec.eyes.count)))
        smoothCache[id] = s
        return s
    }

    static func pixel(_ id: BuddyID) -> Pixel {
        if let p = pixelCache[id] { return p }
        let spec = BuddyArtwork.pixelSpec(id)
        var body: [Cell] = []
        for (i, ch) in spec.rows.enumerated() where ch != "." {
            body.append(Cell(x: i % spec.width, y: i / spec.width, color: b36(ch)))
        }
        let palette = spec.palette.map { rgb in
            CGColor(srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255, green: CGFloat((rgb >> 8) & 0xFF) / 255,
                    blue: CGFloat(rgb & 0xFF) / 255, alpha: 1)
        }
        let p = Pixel(width: spec.width, height: spec.height, palette: palette, body: body,
                      eyesOpen: cells(spec.eyesOpen), eyesClosed: cells(spec.eyesClosed),
                      eyesHappy: cells(spec.eyesHappy), mouth: cells(spec.mouth))
        pixelCache[id] = p
        return p
    }

    private static func b36(_ c: Character) -> Int { Int(String(c), radix: 36) ?? 0 }

    private static func cells(_ s: String) -> [Cell] {
        let a = Array(s)
        return stride(from: 0, to: a.count - 2, by: 3).map { Cell(x: b36(a[$0]), y: b36(a[$0 + 1]), color: b36(a[$0 + 2])) }
    }

    /// The generated paths use absolute M, L, C and Z only.
    static func svgPath(_ d: String) -> Path {
        var path = Path()
        var nums: [CGFloat] = [], cmd: Character = " ", token = ""
        func flushNumber() { if !token.isEmpty, let v = Double(token) { nums.append(CGFloat(v)) }; token = "" }
        func run() {
            switch cmd {
            case "M": if nums.count >= 2 { path.move(to: CGPoint(x: nums[0], y: nums[1])) }
            case "L": if nums.count >= 2 { path.addLine(to: CGPoint(x: nums[0], y: nums[1])) }
            case "C":
                var i = 0
                while i + 5 < nums.count {
                    path.addCurve(to: CGPoint(x: nums[i + 4], y: nums[i + 5]),
                                  control1: CGPoint(x: nums[i], y: nums[i + 1]),
                                  control2: CGPoint(x: nums[i + 2], y: nums[i + 3]))
                    i += 6
                }
            case "Z": path.closeSubpath()
            default: break
            }
            nums.removeAll(keepingCapacity: true)
        }
        for ch in d {
            if ch.isLetter && ch != "e" {
                flushNumber(); run(); cmd = ch
            } else if ch == " " || ch == "," {
                flushNumber()
            } else if ch == "-" && !token.isEmpty && token.last != "e" {
                flushNumber(); token = "-"
            } else {
                token.append(ch)
            }
        }
        flushNumber(); run()
        return path
    }
}

// MARK: - Driving the moods

/// Plays short, self-ending motions (a blink, a happy hop) on a buddy. Nothing runs at rest: each motion is one
/// short task that ends itself.
@MainActor @Observable
final class BuddyAnimator {
    private(set) var mood: BuddyMood = .idle
    /// Bumped to play one hop.
    private(set) var hop = 0
    private var resting: BuddyMood = .idle
    private var task: Task<Void, Never>?

    /// Hover, look and sleep hold until changed.
    func set(_ mood: BuddyMood) {
        task?.cancel()
        resting = mood
        self.mood = mood
    }

    /// Close the eyes for 120 ms, then go back to what the buddy was doing.
    func blink() {
        guard resting != .sleep else { return }
        task?.cancel()
        mood = .blink
        task = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled, let self else { return }
            self.mood = self.resting
        }
    }

    /// ^ ^ eyes and one hop, then back.
    func cheer() {
        task?.cancel()
        if resting == .sleep { resting = .idle }
        mood = .happy
        hop += 1
        task = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled, let self else { return }
            self.mood = self.resting
        }
    }
}

import Foundation

// Moon widget logic (docs/widget-hub.md §3.11). Date math only: the mean synodic month from a known new moon. Accurate to
// about half a day, which is plenty for "waxing gibbous, 63% lit". Foundation only, so the self-test compiles it alone.

enum MoonPhase: Int, CaseIterable, Sendable {
    case new, waxingCrescent, firstQuarter, waxingGibbous, full, waningGibbous, lastQuarter, waningCrescent

    var name: String {
        switch self {
        case .new: "New moon"
        case .waxingCrescent: "Waxing crescent"
        case .firstQuarter: "First quarter"
        case .waxingGibbous: "Waxing gibbous"
        case .full: "Full moon"
        case .waningGibbous: "Waning gibbous"
        case .lastQuarter: "Last quarter"
        case .waningCrescent: "Waning crescent"
        }
    }
}

enum MoonLogic {
    /// Days from one new moon to the next, on average.
    static let synodic = 29.530588853
    /// A known new moon: 2000-01-06 18:14 UTC.
    static let reference = Date(timeIntervalSince1970: 947_182_440)

    /// Days since the last new moon, in 0..<synodic.
    static func age(_ date: Date) -> Double {
        let days = date.timeIntervalSince(reference) / 86_400
        let a = days.truncatingRemainder(dividingBy: synodic)
        return a < 0 ? a + synodic : a
    }

    /// 0 at new moon, 0.5 at full, back to 1.
    static func cycle(_ date: Date) -> Double { age(date) / synodic }

    /// The lit fraction of the disc, 0...1.
    static func illumination(_ date: Date) -> Double { (1 - cos(2 * .pi * cycle(date))) / 2 }

    /// One of the eight named phases; each name covers an eighth of the month centred on its moment.
    static func phase(_ date: Date) -> MoonPhase {
        MoonPhase(rawValue: Int((cycle(date) * 8).rounded()) % 8) ?? .new
    }


    /// The next moment (after `date`) when the cycle reaches `target` (0 = new, 0.5 = full).
    static func next(cycle target: Double, after date: Date) -> Date {
        var wait = (target - cycle(date)) * synodic
        if wait <= 0 { wait += synodic }
        return date.addingTimeInterval(wait * 86_400)
    }

    /// "Full moon in 4 days", "Full moon tomorrow", "Full moon today", whichever of the two is next.
    static func nextLine(_ date: Date, zone: TimeZone = .current) -> String {
        let full = next(cycle: 0.5, after: date), new = next(cycle: 0, after: date)
        let isFull = full <= new
        let target = isFull ? full : new
        var cal = Calendar(identifier: .gregorian); cal.timeZone = zone
        let d = cal.dateComponents([.day], from: cal.startOfDay(for: date), to: cal.startOfDay(for: target)).day ?? 0
        let when = d <= 0 ? "today" : d == 1 ? "tomorrow" : "in \(d) days"
        return "\(isFull ? "Full" : "New") moon \(when)"
    }

    /// "63% lit".
    static func litText(_ date: Date) -> String { "\(Int((illumination(date) * 100).rounded()))% lit" }

    static func spoken(_ date: Date, zone: TimeZone = .current) -> String {
        "Moon, \(phase(date).name.lowercased()), \(litText(date)). \(nextLine(date, zone: zone))."
    }

    /// The lit part of the disc as polygon points in a unit circle (x right, y down), seen from the northern
    /// hemisphere: waxing is lit on the right, waning on the left. Two arcs: the limb, then the terminator.
    static func litOutline(cycle f: Double, steps: Int = 32) -> [(x: Double, y: Double)] {
        let waxing = f < 0.5
        let g = waxing ? f : 1 - f              // 0...0.5 in both halves
        let k = cos(2 * .pi * g)                // 1 at new, 0 at the quarter, -1 at full
        let sign = waxing ? 1.0 : -1.0
        var pts: [(Double, Double)] = []
        for i in 0...steps {                    // limb, top to bottom
            let y = -1 + 2 * Double(i) / Double(steps)
            pts.append((sign * (1 - y * y).squareRoot(), y))
        }
        for i in 0...steps {                    // terminator, bottom to top
            let y = 1 - 2 * Double(i) / Double(steps)
            pts.append((sign * k * (1 - y * y).squareRoot(), y))
        }
        return pts
    }
}

import Foundation

// Weather widget logic (docs/widget-hub.md §3.7). Foundation only: URLs, parsing, the rain hint, units and freshness.
// Data: Open-Meteo (CC BY 4.0), city only, no Location permission.

struct WeatherCity: Codable, Equatable, Sendable {
    var name: String
    var admin1: String?
    var country: String?
    var latitude: Double
    var longitude: Double

    /// "London, England, United Kingdom"
    var label: String { [name, admin1, country].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ") }
}

struct WeatherForecast: Codable, Equatable, Sendable {
    var temperature: Double          // °C, as fetched
    var code: Int                    // WMO weather code
    var high: Double
    var low: Double
    var hourly: [Hour]               // from midnight today, hourly
    var utcOffset: Int               // seconds, the city's
    var fetched: Date

    struct Hour: Codable, Equatable, Sendable { var time: Date; var rainChance: Int }
}

enum WeatherUnits: String, CaseIterable, Identifiable, Sendable {
    case auto, celsius, fahrenheit
    var id: String { rawValue }
    var name: String { switch self { case .auto: "Automatic"; case .celsius: "°C"; case .fahrenheit: "°F" } }
    /// Automatic follows the system's measurement system.
    func isFahrenheit(locale: Locale = .current) -> Bool {
        switch self { case .celsius: false; case .fahrenheit: true; case .auto: locale.measurementSystem == .us }
    }
}

enum WeatherLogic {
    static let refreshAfter: TimeInterval = 30 * 60
    static let staleAfter: TimeInterval = 3 * 3600

    // MARK: URLs

    static func searchURL(_ query: String) -> URL? {
        var c = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")
        c?.queryItems = [.init(name: "name", value: query), .init(name: "count", value: "5"), .init(name: "language", value: "en"), .init(name: "format", value: "json")]
        return c?.url
    }

    /// Always fetched in °C; units are applied when showing, so a units change needs no request.
    static func forecastURL(_ city: WeatherCity) -> URL? {
        var c = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        c?.queryItems = [
            .init(name: "latitude", value: String(city.latitude)), .init(name: "longitude", value: String(city.longitude)),
            .init(name: "current", value: "temperature_2m,weather_code"),
            .init(name: "daily", value: "temperature_2m_max,temperature_2m_min"),
            .init(name: "hourly", value: "precipitation_probability"),
            .init(name: "forecast_days", value: "2"), .init(name: "timezone", value: "auto"),
            .init(name: "timeformat", value: "unixtime"), .init(name: "temperature_unit", value: "celsius"),
        ]
        return c?.url
    }

    // MARK: Parsing

    static func parseCities(_ data: Data) -> [WeatherCity] {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let results = root["results"] as? [[String: Any]] else { return [] }
        return results.prefix(5).compactMap { r in
            guard let name = r["name"] as? String, let lat = r["latitude"] as? Double, let lon = r["longitude"] as? Double else { return nil }
            return WeatherCity(name: name, admin1: r["admin1"] as? String, country: r["country"] as? String, latitude: lat, longitude: lon)
        }
    }

    static func parseForecast(_ data: Data, fetched: Date) -> WeatherForecast? {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let cur = root["current"] as? [String: Any], let temp = (cur["temperature_2m"] as? NSNumber)?.doubleValue,
              let code = (cur["weather_code"] as? NSNumber)?.intValue,
              let daily = root["daily"] as? [String: Any],
              let hi = (daily["temperature_2m_max"] as? [NSNumber])?.first?.doubleValue,
              let lo = (daily["temperature_2m_min"] as? [NSNumber])?.first?.doubleValue,
              let hourly = root["hourly"] as? [String: Any],
              let times = hourly["time"] as? [NSNumber], let chances = hourly["precipitation_probability"] as? [Any]
        else { return nil }
        let hours = zip(times, chances).compactMap { t, c -> WeatherForecast.Hour? in
            (c as? NSNumber).map { WeatherForecast.Hour(time: Date(timeIntervalSince1970: t.doubleValue), rainChance: $0.intValue) }
        }
        return WeatherForecast(temperature: temp, code: code, high: hi, low: lo, hourly: hours,
                               utcOffset: (root["utc_offset_seconds"] as? NSNumber)?.intValue ?? 0, fetched: fetched)
    }

    // MARK: Showing

    /// "6°" in the chosen unit, rounded.
    static func degrees(_ celsius: Double, fahrenheit: Bool) -> String {
        let v = fahrenheit ? celsius * 9 / 5 + 32 : celsius
        let r = Int(v.rounded())
        return "\(r == 0 ? 0 : r)°"      // never "-0°"
    }

    /// "LONDON · H 8 L 3", with "· OFFLINE" when the last fetch failed and this forecast is a kept one.
    static func status(city: WeatherCity, _ f: WeatherForecast, fahrenheit: Bool, offline: Bool) -> String {
        let h = degrees(f.high, fahrenheit: fahrenheit).dropLast(), l = degrees(f.low, fahrenheit: fahrenheit).dropLast()
        return "\(city.name.uppercased()) · H \(h) L \(l)" + (offline ? " · OFFLINE" : "")
    }

    private static func clock(_ date: Date, offset: Int) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_GB"); f.timeZone = TimeZone(secondsFromGMT: offset); f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    /// "Rain from 15:00" (the first hour in the next 12 with ≥ 50% chance) or "Dry until 02:00" (the window's end).
    static func rainHint(_ f: WeatherForecast, now: Date) -> String {
        let hour = floor(now.timeIntervalSince1970 / 3600) * 3600
        let start = Date(timeIntervalSince1970: hour), end = Date(timeIntervalSince1970: hour + 12 * 3600)
        if let wet = f.hourly.first(where: { $0.time >= start && $0.time < end && $0.rainChance >= 50 }) {
            return wet.time == start ? "Rain now" : "Rain from \(clock(wet.time, offset: f.utcOffset))"
        }
        return "Dry until \(clock(end, offset: f.utcOffset))"
    }

    /// (SF Symbol, words) for a WMO weather code.
    static func condition(_ code: Int) -> (symbol: String, words: String) {
        switch code {
        case 0: ("sun.max", "clear")
        case 1: ("sun.max", "mostly clear")
        case 2: ("cloud.sun", "partly cloudy")
        case 3: ("cloud", "overcast")
        case 45, 48: ("cloud.fog", "foggy")
        case 51...57: ("cloud.drizzle", "drizzle")
        case 61...65: ("cloud.rain", "rain")
        case 66, 67: ("cloud.sleet", "freezing rain")
        case 71...77, 85, 86: ("cloud.snow", "snow")
        case 80...82: ("cloud.heavyrain", "showers")
        case 95...99: ("cloud.bolt.rain", "thunderstorms")
        default: ("cloud", "cloudy")
        }
    }

    /// "Weather in London: 6 degrees, partly cloudy, high 8, low 3. Rain from 15:00."
    static func spoken(city: WeatherCity, _ f: WeatherForecast, fahrenheit: Bool, now: Date) -> String {
        func n(_ c: Double) -> String { String(degrees(c, fahrenheit: fahrenheit).dropLast()) }
        return "Weather in \(city.name): \(n(f.temperature)) degrees, \(condition(f.code).words), high \(n(f.high)), low \(n(f.low)). \(rainHint(f, now: now))."
    }

    // MARK: Freshness

    /// Fetch only when there is no forecast or it is older than 30 minutes.
    static func needsFetch(_ f: WeatherForecast?, now: Date) -> Bool {
        guard let f else { return true }
        return now.timeIntervalSince(f.fetched) >= refreshAfter
    }

    /// Older than 3 hours: too stale to show when offline.
    static func isTooStale(_ f: WeatherForecast, now: Date) -> Bool { now.timeIntervalSince(f.fetched) > staleAfter }
}

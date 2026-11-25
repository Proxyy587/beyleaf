import Foundation

/// Fetches Open-Meteo for the Weather widget (docs/widget-hub.md §3.7). One request, only while the Day page is visible
/// and the forecast is older than 30 minutes. Ephemeral session (no cookies or cache on disk), 10 s timeout.
@MainActor
final class WeatherService: ObservableObject {
    static let shared = WeatherService()

    @Published private(set) var forecast: WeatherForecast?
    /// The last fetch failed. With a kept forecast the card says OFFLINE; without one it offers Retry.
    @Published private(set) var failed = false
    @Published private(set) var loading = false

    private var forecastCity: WeatherCity?
    private let session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 10; c.timeoutIntervalForResource = 10; c.waitsForConnectivity = false
        return URLSession(configuration: c)
    }()

    private init() {
        // A kept forecast survives relaunch, so the card has something to show offline.
        if let d = UserDefaults.standard.data(forKey: "weatherForecast"),
           let kept = try? JSONDecoder().decode(Kept.self, from: d) { forecast = kept.forecast; forecastCity = kept.city }
    }
    private struct Kept: Codable { var city: WeatherCity; var forecast: WeatherForecast }

    /// Fetches when this city has no forecast or it is older than 30 minutes. A forecast for another city is dropped.
    func refreshIfNeeded(for city: WeatherCity, now: Date = Date()) async {
        if forecastCity != city { forecast = nil; forecastCity = nil }
        guard !loading, WeatherLogic.needsFetch(forecast, now: now) else { return }
        await fetch(city)
    }

    func retry(for city: WeatherCity) async { guard !loading else { return }; await fetch(city) }

    private func fetch(_ city: WeatherCity) async {
        guard let url = WeatherLogic.forecastURL(city) else { return }
        loading = true; defer { loading = false }
        do {
            let (data, response) = try await session.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200, let f = WeatherLogic.parseForecast(data, fetched: Date()) else { throw URLError(.badServerResponse) }
            forecast = f; forecastCity = city; failed = false
            if let d = try? JSONEncoder().encode(Kept(city: city, forecast: f)), AppSettings.shared.persistsWeather { UserDefaults.standard.set(d, forKey: "weatherForecast") }
        } catch { failed = true }
    }

    /// Up to 5 places for what's typed (Settings, debounced by the caller). Nil when the request failed.
    func search(_ query: String) async -> [WeatherCity]? {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2, let url = WeatherLogic.searchURL(q) else { return [] }
        guard let (data, response) = try? await session.data(from: url), (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return WeatherLogic.parseCities(data)
    }
}

import Foundation
import SwiftUI
import Observation

@Observable
class SettingsViewModel {
    // ── Connection ──────────────────────────────────────────────────────────
    var hostURL          = ""
    var apiKey           = ""
    var connectionStatus = ConnectionStatus.untested

    enum ConnectionStatus: Equatable {
        case untested, testing, success, failure(String)
        var label: String {
            switch self {
            case .untested:        return "Not tested"
            case .testing:         return "Testing…"
            case .success:         return "Connected"
            case .failure(let e):  return "Failed: \(e)"
            }
        }
    }

    // ── Polling ─────────────────────────────────────────────────────────────
    var refreshInterval = 30   // seconds

    static let refreshOptions: [(label: String, seconds: Int)] = [
        ("5 s",   5),
        ("15 s",  15),
        ("30 s",  30),
        ("1 min", 60),
        ("2 min", 120),
        ("5 min", 300),
        ("Never", 0),
    ]

    // ── Appearance ──────────────────────────────────────────────────────────
    enum AccentColorOption: String, CaseIterable, Identifiable {
        case blue, indigo, purple, pink, red, orange, yellow, green, teal, mint
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        var color: Color {
            switch self {
            case .blue:   return .blue
            case .indigo: return .indigo
            case .purple: return .purple
            case .pink:   return .pink
            case .red:    return .red
            case .orange: return .orange
            case .yellow: return .yellow
            case .green:  return .green
            case .teal:   return .teal
            case .mint:   return .mint
            }
        }
    }

    var accentColorOption: AccentColorOption = .blue
    var accentColor: Color { accentColorOption.color }

    // ── Units ───────────────────────────────────────────────────────────────
    enum TemperatureUnit: String, CaseIterable, Identifiable {
        case celsius, fahrenheit
        var id: String { rawValue }
        var label: String { self == .celsius ? "Celsius (°C)" : "Fahrenheit (°F)" }
        var symbol: String { self == .celsius ? "°C" : "°F" }

        func format(_ celsius: Double) -> String {
            let value = self == .celsius ? celsius : celsius * 9 / 5 + 32
            return String(format: "%.0f\(symbol)", value)
        }
    }

    var temperatureUnit: TemperatureUnit = .celsius

    // ── Dashboard card visibility ────────────────────────────────────────────
    var showPoolHealthCard    = true
    var showTemperatureCard   = true
    var showNetworkCard       = true
    var showAlertBanner       = true

    // ── Private ─────────────────────────────────────────────────────────────
    private let network   = TrueNASNetworkManager.shared
    private let defaults  = UserDefaults.standard

    // MARK: - Init
    init() {
        hostURL = KeychainManager.load(key: KeychainManager.hostURLKey) ?? ""
        apiKey  = KeychainManager.load(key: KeychainManager.apiKeyKey)  ?? ""

        // Polling
        refreshInterval = defaults.object(forKey: "refreshInterval") as? Int ?? 30

        // Appearance
        accentColorOption = AccentColorOption(
            rawValue: defaults.string(forKey: "accentColorOption") ?? "") ?? .blue

        // Units
        temperatureUnit = TemperatureUnit(
            rawValue: defaults.string(forKey: "temperatureUnit") ?? "") ?? .celsius

        // Dashboard cards
        showPoolHealthCard  = defaults.object(forKey: "showPoolHealthCard")  as? Bool ?? true
        showTemperatureCard = defaults.object(forKey: "showTemperatureCard") as? Bool ?? true
        showNetworkCard     = defaults.object(forKey: "showNetworkCard")     as? Bool ?? true
        showAlertBanner     = defaults.object(forKey: "showAlertBanner")     as? Bool ?? true

        network.configure(host: hostURL, apiKey: apiKey)
        if !hostURL.isEmpty && !apiKey.isEmpty {
            network.preconnect()
        }
    }

    // MARK: - Save
    func save() {
        KeychainManager.save(hostURL, for: KeychainManager.hostURLKey)
        KeychainManager.save(apiKey,  for: KeychainManager.apiKeyKey)

        defaults.set(refreshInterval,           forKey: "refreshInterval")
        defaults.set(accentColorOption.rawValue, forKey: "accentColorOption")
        defaults.set(temperatureUnit.rawValue,   forKey: "temperatureUnit")
        defaults.set(showPoolHealthCard,         forKey: "showPoolHealthCard")
        defaults.set(showTemperatureCard,        forKey: "showTemperatureCard")
        defaults.set(showNetworkCard,            forKey: "showNetworkCard")
        defaults.set(showAlertBanner,            forKey: "showAlertBanner")

        network.configure(host: hostURL, apiKey: apiKey)
    }

    // MARK: - Connection test
    func testConnection() async {
        save()
        connectionStatus = .testing
        do {
            try await network.testConnection()
            connectionStatus = .success
        } catch {
            connectionStatus = .failure(error.localizedDescription)
        }
    }
}

import Foundation
import Observation

@Observable
class SettingsViewModel {
    var hostURL          = ""
    var apiKey           = ""
    var refreshInterval  = 30   // seconds
    var connectionStatus = ConnectionStatus.untested

    enum ConnectionStatus {
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

    private let network = TrueNASNetworkManager.shared

    init() {
        hostURL = KeychainManager.load(key: KeychainManager.hostURLKey) ?? ""
        apiKey  = KeychainManager.load(key: KeychainManager.apiKeyKey)  ?? ""
        network.configure(host: hostURL, apiKey: apiKey)
    }

    func save() {
        KeychainManager.save(hostURL, for: KeychainManager.hostURLKey)
        KeychainManager.save(apiKey,  for: KeychainManager.apiKeyKey)
        network.configure(host: hostURL, apiKey: apiKey)
    }

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

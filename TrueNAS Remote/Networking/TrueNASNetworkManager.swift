import Foundation

// MARK: - Errors
enum NetworkError: Error, LocalizedError {
    case notConfigured
    case invalidURL
    case httpError(Int)
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:        return "Host URL and API key not configured. Go to Settings."
        case .invalidURL:           return "Invalid host URL."
        case .httpError(let c):     return "HTTP \(c)"
        case .decodingError(let m): return "Decode error: \(m)"
        }
    }
}

// MARK: - Core Manager
class TrueNASNetworkManager {
    static let shared = TrueNASNetworkManager()

    var hostURL  = ""
    var apiKey   = ""

    let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest  = 20
        cfg.timeoutIntervalForResource = 60
        return URLSession(configuration: cfg)
    }()

    func configure(host: String, apiKey: String) {
        var h = host.trimmingCharacters(in: .whitespacesAndNewlines)
        while h.hasSuffix("/") { h.removeLast() }
        self.hostURL = h
        self.apiKey  = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Core request
    func request(path: String, method: String = "GET", body: Data? = nil) async throws -> Data {
        guard !hostURL.isEmpty, !apiKey.isEmpty else { throw NetworkError.notConfigured }
        guard let url = URL(string: hostURL + path) else { throw NetworkError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse,
           !(200..<300).contains(http.statusCode) {
            throw NetworkError.httpError(http.statusCode)
        }
        return data
    }

    // MARK: - Typed GET helper
    func get<T: Decodable>(_ path: String, as type: T.Type = T.self) async throws -> T {
        let data = try await request(path: path)
        do {
            return try JSONDecoder.truenas.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingError(error.localizedDescription)
        }
    }

    // MARK: - POST helper (returns Data for flexibility)
    @discardableResult
    func post(_ path: String, body: Encodable? = nil) async throws -> Data {
        var bodyData: Data?
        if let b = body {
            bodyData = try JSONEncoder().encode(b)
        }
        return try await request(path: path, method: "POST", body: bodyData)
    }

    func testConnection() async throws {
        _ = try await request(path: "/api/v2.0/system/info")
    }
}

// MARK: - JSONDecoder with snake_case + date strategy
extension JSONDecoder {
    static let truenas: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }()
}

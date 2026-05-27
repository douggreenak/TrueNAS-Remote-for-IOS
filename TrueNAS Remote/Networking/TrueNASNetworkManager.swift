import Foundation

// MARK: - Errors
enum NetworkError: Error, LocalizedError {
    case notConfigured
    case connectionFailed(String)
    case authFailed
    case rpcError(Int, String)
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:           return "Host URL and API key not configured. Go to Settings."
        case .connectionFailed(let m): return "Connection failed: \(m)"
        case .authFailed:              return "Authentication failed. Check your API key in Settings."
        case .rpcError(let c, let m):  return "Server error \(c): \(m)"
        case .decodingError(let m):    return "Decode error: \(m)"
        }
    }
}

// MARK: - TLS delegate (accepts self-signed certificates for local TrueNAS servers)
/// TrueNAS ships with a self-signed certificate. We accept it unconditionally
/// because we're connecting to a user-specified host on a trusted local network.
private final class InsecureTLSDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}

// MARK: - Core Manager
///
/// JSON-RPC 2.0 over WSS (encrypted WebSocket) — connects to `wss://<host>/api/current`.
/// Plain `ws://` (HTTP) is rejected by TrueNAS as insecure — all connections are upgraded.
/// One persistent connection is maintained and reused across all calls.
/// Authentication is performed once per connection using `auth.login_with_api_key`.
///
actor TrueNASNetworkManager {
    static let shared = TrueNASNetworkManager()

    private var hostURL = ""
    private var apiKey  = ""

    private var ws:           URLSessionWebSocketTask?
    private var pending:      [String: CheckedContinuation<Data, Error>] = [:]
    private var authenticated = false
    private var connecting:   Task<Void, Error>?

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest  = 30
        cfg.timeoutIntervalForResource = 300
        // InsecureTLSDelegate accepts TrueNAS's self-signed certificate.
        return URLSession(configuration: cfg,
                          delegate: InsecureTLSDelegate(),
                          delegateQueue: nil)
    }()

    // MARK: - Configuration

    /// Updates credentials and drops the active connection so the next call reconnects.
    /// Declared `nonisolated` so callers do not need `await`.
    nonisolated func configure(host: String, apiKey: String) {
        var h = host.trimmingCharacters(in: .whitespacesAndNewlines)
        while h.hasSuffix("/") { h.removeLast() }
        let cleanHost = h
        let cleanKey  = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        Task { await self._apply(host: cleanHost, apiKey: cleanKey) }
    }

    private func _apply(host: String, apiKey: String) {
        hostURL      = host
        self.apiKey  = apiKey
        _drop(reason: "credentials changed")
    }

    // MARK: - Public API

    func testConnection() async throws {
        try await _ensureConnected()
    }

    /// Raw JSON-RPC call. `params` is a pre-serialised JSON array (e.g. `Data("[42]")`).
    /// Pass `nil` for methods that take no parameters — an empty array `[]` is sent.
    @discardableResult
    func call(method: String, params: Data? = nil) async throws -> Data {
        try await _ensureConnected()

        let id = UUID().uuidString
        var obj: [String: Any] = ["jsonrpc": "2.0", "id": id, "method": method]
        if let p = params,
           let arr = try? JSONSerialization.jsonObject(with: p) {
            obj["params"] = arr
        } else {
            obj["params"] = [] as [Any]
        }
        guard let msgData = try? JSONSerialization.data(withJSONObject: obj),
              let msgStr  = String(data: msgData, encoding: .utf8) else {
            throw NetworkError.connectionFailed("Failed to encode RPC message")
        }
        guard let ws else { throw NetworkError.connectionFailed("Not connected") }

        return try await withCheckedThrowingContinuation { cont in
            pending[id] = cont
            ws.send(.string(msgStr)) { error in
                guard let error else { return }
                Task { await self._fail(id: id, err: .connectionFailed(error.localizedDescription)) }
            }
        }
    }

    /// Typed JSON-RPC call — decodes the `result` field directly to `T`.
    func call<T: Decodable>(method: String, params: Data? = nil, as type: T.Type = T.self) async throws -> T {
        let data = try await call(method: method, params: params)
        do {
            return try JSONDecoder.truenas.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingError(error.localizedDescription)
        }
    }

    // MARK: - Connection lifecycle

    private func _ensureConnected() async throws {
        guard !hostURL.isEmpty, !apiKey.isEmpty else { throw NetworkError.notConfigured }
        if ws != nil && authenticated { return }

        // Serialise concurrent first-call connection attempts
        if let existing = connecting {
            try await existing.value
            return
        }

        let task = Task<Void, Error> { try await self._connect() }
        connecting = task
        defer { connecting = nil }
        try await task.value
    }

    private func _connect() async throws {
        // Always use WSS — TrueNAS revokes API keys used over plain (unencrypted) ws://.
        // Strip any existing scheme and re-prefix with wss://.
        var stripped = hostURL
        for prefix in ["wss://", "ws://", "https://", "http://"] {
            if stripped.lowercased().hasPrefix(prefix) {
                stripped = String(stripped.dropFirst(prefix.count))
                break
            }
        }
        let base = "wss://" + stripped
        guard let url = URL(string: base + "/api/current") else {
            throw NetworkError.connectionFailed("Invalid server URL: \(base)/api/current")
        }

        let task = session.webSocketTask(with: url)
        ws = task
        task.resume()

        // Start background receive loop (unstructured — runs independently)
        Task { await self._receiveLoop(task: task) }

        // Authenticate — stored in pending dict like any other call
        // result is Data("true") on success; rpcError is thrown on failure
        do {
            let authResult = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Data, Error>) in
                pending["__auth__"] = cont
                let obj: [String: Any] = [
                    "jsonrpc": "2.0",
                    "id":      "__auth__",
                    "method":  "auth.login_with_api_key",
                    "params":  [apiKey]
                ]
                guard let d = try? JSONSerialization.data(withJSONObject: obj),
                      let s = String(data: d, encoding: .utf8) else {
                    pending.removeValue(forKey: "__auth__")?.resume(throwing: NetworkError.authFailed)
                    return
                }
                task.send(.string(s)) { error in
                    guard let error else { return }
                    Task { await self._fail(id: "__auth__", err: .connectionFailed(error.localizedDescription)) }
                }
            }
            guard String(data: authResult, encoding: .utf8) == "true" else {
                _drop(reason: "authentication rejected")
                throw NetworkError.authFailed
            }
        } catch {
            // Clean up socket on any auth failure so the next call reconnects fresh.
            // Guard against calling _drop() twice if it was already called inside the continuation.
            if ws === task { _drop(reason: "auth failed: \(error.localizedDescription)") }
            throw error
        }
        authenticated = true
    }

    // MARK: - Receive loop

    private func _receiveLoop(task: URLSessionWebSocketTask) async {
        while true {
            do {
                let message = try await task.receive()
                // If this socket was replaced while we were awaiting, exit silently.
                guard task === ws else { return }
                var rawStr: String?
                switch message {
                case .string(let s): rawStr = s
                case .data(let d):   rawStr = String(data: d, encoding: .utf8)
                @unknown default:    break
                }
                guard let s = rawStr,
                      let d = s.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: d) as? [String: Any]
                else { continue }

                let msgId = json["id"] as? String ?? ""
                guard let cont = pending.removeValue(forKey: msgId) else { continue }

                // Auth response
                if msgId == "__auth__" {
                    if json["error"] == nil,
                       let ok = json["result"] as? Bool, ok {
                        cont.resume(returning: Data("true".utf8))
                    } else {
                        cont.resume(throwing: NetworkError.authFailed)
                    }
                    continue
                }

                // Regular call response
                if let err = json["error"] as? [String: Any] {
                    let code = err["code"]    as? Int    ?? -32000
                    let msg  = err["message"] as? String ?? "RPC error"
                    cont.resume(throwing: NetworkError.rpcError(code, msg))
                } else if let result = json["result"] {
                    if result is NSNull {
                        cont.resume(returning: Data("null".utf8))
                    } else if JSONSerialization.isValidJSONObject(result),
                              let rd = try? JSONSerialization.data(withJSONObject: result) {
                        cont.resume(returning: rd)
                    } else {
                        // Primitive (Bool, Int) — encode as JSON literal string
                        cont.resume(returning: Data(String(describing: result).utf8))
                    }
                } else {
                    cont.resume(returning: Data("null".utf8))
                }

            } catch {
                // Only call _drop if this is still the active socket.
                // A stale loop (replaced by a reconnect) must exit silently.
                if task === ws { _drop(reason: error.localizedDescription) }
                return
            }
        }
    }

    // MARK: - Helpers

    private func _drop(reason: String) {
        ws?.cancel(with: .normalClosure, reason: nil)
        ws = nil
        authenticated = false
        let err = NetworkError.connectionFailed(reason)
        let p = pending
        pending = [:]
        p.values.forEach { $0.resume(throwing: err) }
    }

    private func _fail(id: String, err: NetworkError) {
        pending.removeValue(forKey: id)?.resume(throwing: err)
    }
}

// MARK: - JSONDecoder with snake_case + date strategy
extension JSONDecoder {
    static let truenas: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy  = .convertFromSnakeCase
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }()
}

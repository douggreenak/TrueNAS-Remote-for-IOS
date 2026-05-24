import Foundation

// Custom CodingKey for keys beginning with $ (e.g. TrueNAS BSON dates: {"$date": ms})
private struct BSONDateKey: CodingKey {
    var stringValue: String
    init?(stringValue: String) { self.stringValue = stringValue }
    var intValue: Int? { nil }
    init?(intValue: Int) { nil }
    static let date = BSONDateKey(stringValue: "$date")!
}

/// Decodes either a {"$date": ms} BSON wrapper or a plain Double epoch
private func decodeBSONDate(from decoder: Decoder) throws -> Date? {
    // Try dict form first
    if let c = try? decoder.container(keyedBy: BSONDateKey.self),
       let ms = try? c.decode(Double.self, forKey: .date) {
        return Date(timeIntervalSince1970: ms / 1000)
    }
    // Try plain epoch double
    if let svc = try? decoder.singleValueContainer(),
       let ts = try? svc.decode(Double.self) {
        return Date(timeIntervalSince1970: ts)
    }
    return nil
}

extension TrueNASNetworkManager {

    // MARK: - System Info
    func fetchSystemInfo() async throws -> SystemInfo {
        struct Raw: Decodable {
            let version: String
            let hostname: String
            let uptimeSeconds: Double
            let physmem: Int64?
            let platform: String?
            let systemSerial: String?
            let loadavg: [Double]?
        }
        let raw = try await get("/api/v2.0/system/info", as: Raw.self)
        return SystemInfo(
            version:       raw.version,
            hostname:      raw.hostname,
            uptimeSeconds: raw.uptimeSeconds,
            memoryTotal:   raw.physmem ?? 0,
            loadAvg1:      raw.loadavg?[safe: 0] ?? 0,
            loadAvg5:      raw.loadavg?[safe: 1] ?? 0,
            loadAvg15:     raw.loadavg?[safe: 2] ?? 0,
            platform:      raw.platform ?? "Generic",
            serialNumber:  raw.systemSerial ?? "—"
        )
    }

    // MARK: - Alerts
    func fetchAlerts() async throws -> [TrueNASAlert] {
        struct DateBox: Decodable {
            let dateMs: Double?
            init(from decoder: Decoder) throws {
                dateMs = (try? decodeBSONDate(from: decoder))
                    .map { $0.timeIntervalSince1970 * 1000 }
            }
        }
        struct Raw: Decodable {
            let uuid: String
            let level: String
            let formatted: String
            let source: String
            let datetime: DateBox
            let dismissed: Bool
        }
        let raws = try await get("/api/v2.0/alert/list", as: [Raw].self)
        return raws.map { r in
            TrueNASAlert(
                id:        r.uuid,
                level:     AlertLevel(rawValue: r.level) ?? .info,
                message:   r.formatted,
                source:    r.source,
                timestamp: r.datetime.dateMs.map { Date(timeIntervalSince1970: $0 / 1000) } ?? Date(),
                dismissed: r.dismissed
            )
        }
    }

    func dismissAlert(uuid: String) async throws {
        try await post("/api/v2.0/alert/dismiss", body: uuid)
    }

    // MARK: - Boot Environments
    func fetchBootEnvironments() async throws -> [BootEnvironment] {
        struct DateBox: Decodable {
            let date: Date?
            init(from decoder: Decoder) throws { date = try? decodeBSONDate(from: decoder) }
        }
        struct Raw: Decodable {
            let id: String
            let name: String
            let created: DateBox
            let size: Int64?
            let activated: Bool
            let keep: Bool?
        }
        let raws = try await get("/api/v2.0/bootenv", as: [Raw].self)
        return raws.map { r in
            BootEnvironment(
                id:          r.id,
                name:        r.name,
                created:     r.created.date ?? Date(),
                size:        r.size ?? 0,
                active:      r.activated,
                keepForever: r.keep ?? false
            )
        }
    }

    func activateBootEnvironment(id: String) async throws {
        try await post("/api/v2.0/bootenv/id/\(id)/activate")
    }

    // MARK: - Users
    func fetchUsers() async throws -> [TrueNASUser] {
        struct Raw: Decodable {
            let uid: Int
            let username: String
            let fullName: String
            let email: String?
            let shell: String
            let homeDirectory: String
            let locked: Bool
            let sudo: Bool?
            let groups: [Int]
            let builtin: Bool
        }
        return try await get("/api/v2.0/user", as: [Raw].self).map {
            TrueNASUser(id: $0.uid, username: $0.username, fullName: $0.fullName,
                        email: $0.email ?? "", shell: $0.shell, homeDir: $0.homeDirectory,
                        locked: $0.locked, sudoEnabled: $0.sudo ?? false,
                        groups: $0.groups, builtIn: $0.builtin)
        }
    }

    // MARK: - Groups
    func fetchGroups() async throws -> [TrueNASGroup] {
        struct Raw: Decodable {
            let gid: Int
            let group: String
            let users: [Int]
            let builtin: Bool
            let sudo: Bool?
        }
        return try await get("/api/v2.0/group", as: [Raw].self).map {
            TrueNASGroup(id: $0.gid, name: $0.group, users: $0.users.map { "\($0)" },
                         builtIn: $0.builtin, sudoEnabled: $0.sudo ?? false)
        }
    }

    // MARK: - Certificates
    func fetchCertificates() async throws -> [Certificate] {
        struct Raw: Decodable {
            let id: Int; let name: String; let commonName: String?
            let issuer: String?; let san: [String]?
            let from: String?; let until: String?
            let keyType: String?; let keyLength: Int?
        }
        let df = DateFormatter(); df.dateFormat = "EEE MMM  d HH:mm:ss yyyy"
        return try await get("/api/v2.0/certificate", as: [Raw].self).map { r in
            Certificate(id: r.id, name: r.name,
                        commonName: r.commonName ?? r.name,
                        issuer: r.issuer ?? "—",
                        san: r.san ?? [],
                        from:  df.date(from: r.from  ?? "") ?? Date(),
                        until: df.date(from: r.until ?? "") ?? Date(),
                        keyType: r.keyType ?? "RSA",
                        keyLength: r.keyLength ?? 2048)
        }
    }

    // MARK: - Audit Log
    func fetchAuditLog(limit: Int = 100) async throws -> [AuditEntry] {
        struct Raw: Decodable {
            let auditId: String
            let timestamp: Double?
            let username: String?
            let service: String?
            let event: String?
            let success: Bool?
            let address: String?
        }
        let path = "/api/v2.0/audit?limit=\(limit)&offset=0&order_by=-timestamp"
        return try await get(path, as: [Raw].self).map { r in
            AuditEntry(
                id:        r.auditId,
                timestamp: r.timestamp.map { Date(timeIntervalSince1970: $0) } ?? Date(),
                username:  r.username ?? "—",
                service:   r.service  ?? "—",
                event:     r.event    ?? "—",
                success:   r.success  ?? true,
                address:   r.address  ?? "—",
                detail:    [:]
            )
        }
    }
}

// Safe array subscript
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

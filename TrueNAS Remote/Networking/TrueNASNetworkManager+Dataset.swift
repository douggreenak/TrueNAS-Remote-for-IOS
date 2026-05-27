import Foundation

extension TrueNASNetworkManager {

    // MARK: - Datasets
    func fetchDatasets(pool: String? = nil) async throws -> [Dataset] {
        struct ZFSInt:   Decodable { let parsed: Int64? }
        struct ZFSCount: Decodable { let parsed: Int? }
        struct ZFSString: Decodable { let value: String? }
        struct ZFSDouble: Decodable {
            let asDouble: Double?
            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                if let s = try? c.decode(String.self, forKey: .parsed) {
                    asDouble = Double(s)
                } else {
                    asDouble = try? c.decode(Double.self, forKey: .parsed)
                }
            }
            enum CodingKeys: String, CodingKey { case parsed }
        }
        struct Raw: Decodable {
            let id: String; let name: String; let pool: String
            let type: String?
            let encrypted: Bool?; let locked: Bool?
            let children: [Raw]?
            let used:         ZFSInt?
            let available:    ZFSInt?
            let referenced:   ZFSInt?
            let compressratio: ZFSDouble?
            let dedupratio:   ZFSDouble?
            let snapshotCount: ZFSCount?
            let comments:     ZFSString?
            enum CodingKeys: String, CodingKey {
                case id, name, pool, type, encrypted, locked, children
                case used, available, referenced, compressratio, dedupratio, comments
                case snapshotCount = "snapshot_count"
            }
        }

        // Build filter: [filters, options]
        let filterArray: [Any]
        if let pool {
            filterArray = [[["pool", "=", pool]]] as [Any]
        } else {
            filterArray = [[]] as [Any]
        }
        let params = try JSONSerialization.data(withJSONObject: filterArray)

        let raws = try await call(method: "pool.dataset.query", params: params, as: [Raw].self)

        func convert(_ r: Raw) -> Dataset {
            let enc: EncryptionStatus = {
                guard r.encrypted == true else { return .unencrypted }
                return .encrypted(locked: r.locked ?? false)
            }()
            return Dataset(
                id:                 r.id,
                name:               r.name.components(separatedBy: "/").last ?? r.name,
                pool:               r.pool,
                type:               DatasetType(rawValue: r.type ?? "FILESYSTEM") ?? .filesystem,
                usedBytes:          r.used?.parsed        ?? 0,
                availableBytes:     r.available?.parsed   ?? 0,
                referencedBytes:    r.referenced?.parsed  ?? 0,
                compressionRatio:   r.compressratio?.asDouble ?? 1.0,
                deduplicationRatio: r.dedupratio?.asDouble  ?? 1.0,
                encryption:         enc,
                snapshotCount:      r.snapshotCount?.parsed ?? 0,
                children:           (r.children ?? []).map { convert($0) },
                comments:           r.comments?.value ?? ""
            )
        }
        return raws.map { convert($0) }
    }

    // MARK: - Snapshots
    func fetchSnapshots(dataset: String) async throws -> [Snapshot] {
        struct BytesProp:    Decodable { let parsed: Int64? }
        struct CreationProp: Decodable { let rawvalue: String? }
        struct Props: Decodable {
            let creation:   CreationProp?
            let referenced: BytesProp?
            let used:       BytesProp?
        }
        struct Raw: Decodable {
            let id:           String
            let dataset:      String
            let snapshotName: String
            let properties:   Props?
            let holds:        [String: Bool]?
        }

        // params: [filters, options]
        let params = try JSONSerialization.data(withJSONObject: [
            [["dataset", "=", dataset]],
            ["limit": 200] as [String: Any]
        ] as [Any])
        let raws = try await call(method: "pool.snapshot.query", params: params, as: [Raw].self)

        return raws.map { r in
            let created: Date = {
                guard let raw  = r.properties?.creation?.rawvalue,
                      let secs = TimeInterval(raw) else { return Date() }
                return Date(timeIntervalSince1970: secs)
            }()
            return Snapshot(
                id:              r.id,
                dataset:         r.dataset,
                name:            r.snapshotName,
                created:         created,
                referencedBytes: r.properties?.referenced?.parsed ?? 0,
                usedBytes:       r.properties?.used?.parsed       ?? 0,
                holdCount:       r.holds?.count ?? 0
            )
        }
    }

    func createSnapshot(dataset: String, name: String, recursive: Bool = false) async throws {
        let params = try JSONSerialization.data(withJSONObject: [
            ["dataset": dataset, "name": name, "recursive": recursive] as [String: Any]
        ])
        try await call(method: "pool.snapshot.create", params: params)
    }

    func deleteSnapshot(id: String) async throws {
        let params = try JSONSerialization.data(withJSONObject: [id])
        try await call(method: "pool.snapshot.delete", params: params)
    }

    func rollbackSnapshot(id: String) async throws {
        let params = try JSONSerialization.data(withJSONObject: [id])
        try await call(method: "pool.snapshot.rollback", params: params)
    }
}

// MARK: - Generic Codable value wrapper (used by DataProtection scrub task pool field)
struct AnyCodable: Codable {
    let value: Any?
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let i = try? c.decode(Int.self)    { value = i; return }
        if let d = try? c.decode(Double.self) { value = d; return }
        if let s = try? c.decode(String.self) { value = s; return }
        if let b = try? c.decode(Bool.self)   { value = b; return }
        value = nil
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case let i as Int:    try c.encode(i)
        case let d as Double: try c.encode(d)
        case let s as String: try c.encode(s)
        case let b as Bool:   try c.encode(b)
        default:              try c.encodeNil()
        }
    }
}

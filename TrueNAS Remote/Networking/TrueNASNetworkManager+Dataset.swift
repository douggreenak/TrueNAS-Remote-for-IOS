import Foundation

extension TrueNASNetworkManager {

    // MARK: - Datasets
    func fetchDatasets(pool: String? = nil) async throws -> [Dataset] {
        struct Raw: Decodable {
            let id: String
            let name: String
            let pool: String
            let type: String?
            let encrypted: Bool?
            let locked: Bool?
            let children: [Raw]?
            // Nested value containers use "parsed" key
            enum CodingKeys: String, CodingKey {
                case id, name, pool, type = "type", encrypted, locked, children
            }
        }
        let path = pool != nil
            ? "/api/v2.0/pool/dataset?pool=\(pool!)"
            : "/api/v2.0/pool/dataset"
        let raws = try await get(path, as: [Raw].self)

        func convert(_ r: Raw) -> Dataset {
            let enc: EncryptionStatus = {
                guard r.encrypted == true else { return .unencrypted }
                return .encrypted(locked: r.locked ?? false)
            }()
            var ds = Dataset(
                id: r.id, name: r.name.components(separatedBy: "/").last ?? r.name,
                pool: r.pool,
                type: DatasetType(rawValue: r.type ?? "FILESYSTEM") ?? .filesystem,
                usedBytes: 0, availableBytes: 0, referencedBytes: 0,
                compressionRatio: 1.0, deduplicationRatio: 1.0,
                encryption: enc, snapshotCount: 0,
                children: (r.children ?? []).map { convert($0) },
                comments: ""
            )
            return ds
        }
        return raws.map { convert($0) }
    }

    // MARK: - Snapshots
    func fetchSnapshots(dataset: String) async throws -> [Snapshot] {
        let enc = dataset.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? dataset
        let path = "/api/v2.0/pool/snapshot?dataset=\(enc)&limit=200"
        struct Raw: Decodable {
            let id: String
            let dataset: String
            let snapshotName: String
        }
        let raws = try await get(path, as: [Raw].self)
        return raws.map { r in
            Snapshot(id: r.id, dataset: r.dataset, name: r.snapshotName,
                     created: Date(), referencedBytes: 0, usedBytes: 0, holdCount: 0)
        }
    }

    func createSnapshot(dataset: String, name: String, recursive: Bool = false) async throws {
        struct Body: Encodable { let dataset: String; let name: String; let recursive: Bool }
        try await post("/api/v2.0/pool/snapshot",
                       body: Body(dataset: dataset, name: name, recursive: recursive))
    }

    func deleteSnapshot(id: String) async throws {
        let enc = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        _ = try await request(path: "/api/v2.0/pool/snapshot/id/\(enc)", method: "DELETE")
    }

    func rollbackSnapshot(id: String) async throws {
        let enc = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        try await post("/api/v2.0/pool/snapshot/id/\(enc)/rollback")
    }
}

// Generic Codable value wrapper
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

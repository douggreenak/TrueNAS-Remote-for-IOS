import Foundation

extension TrueNASNetworkManager {

    // MARK: - Pools
    func fetchPools() async throws -> [StoragePool] {
        struct DiskNode: Decodable {
            let disk: String?
            let name: String?
            let status: String?
            let stats: Stats?
            struct Stats: Decodable {
                let readErrors: Int?
                let writeErrors: Int?
                let checksumErrors: Int?
            }
        }
        struct VDEVNode: Decodable {
            let name: String?
            let type: String?
            let status: String?
            let children: [DiskNode]?
        }
        struct Topology: Decodable {
            let data: [VDEVNode]?
            let cache: [VDEVNode]?
            let log: [VDEVNode]?
            let spare: [VDEVNode]?
            let special: [VDEVNode]?
            let dedup: [VDEVNode]?
        }
        struct Scan: Decodable {
            let state: String?
            let endTime: AnyCodable?   // {"$date": ms} or null
        }
        struct Raw: Decodable {
            let id: Int; let name: String; let status: String
            let size: Int64?; let allocated: Int64?; let free: Int64?
            let scan: Scan?; let topology: Topology?
        }

        let raws = try await get("/api/v2.0/pool", as: [Raw].self)
        return raws.map { r in
            var allVdevs: [VDEV] = []
            var allDisks: [Disk] = []

            func toDisks(_ nodes: [DiskNode]?) -> [Disk] {
                (nodes ?? []).compactMap { n in
                    guard let d = n.disk ?? n.name else { return nil }
                    return Disk(id: d, serial: "—", model: "—", size: 0,
                                temperature: nil, powerOnHours: nil, poolName: r.name,
                                smartStatus: .unknown,
                                readErrors:    n.stats?.readErrors    ?? 0,
                                writeErrors:   n.stats?.writeErrors   ?? 0,
                                checksumErrors: n.stats?.checksumErrors ?? 0,
                                smartResults: [])
                }
            }

            func processVDEVs(_ nodes: [VDEVNode]?, type: VDEVType) {
                for (i, v) in (nodes ?? []).enumerated() {
                    let disks = toDisks(v.children)
                    let vdev  = VDEV(id: "\(r.id)-\(type.rawValue)-\(i)",
                                     type: type,
                                     status: PoolStatus(rawValue: v.status ?? "ONLINE") ?? .online,
                                     disks: disks)
                    allVdevs.append(vdev)
                    allDisks.append(contentsOf: disks)
                }
            }

            processVDEVs(r.topology?.data,    type: .data)
            processVDEVs(r.topology?.cache,   type: .cache)
            processVDEVs(r.topology?.log,     type: .log)
            processVDEVs(r.topology?.spare,   type: .spare)
            processVDEVs(r.topology?.special, type: .special)
            processVDEVs(r.topology?.dedup,   type: .dedup)

            return StoragePool(
                id: r.id, name: r.name,
                status: PoolStatus(rawValue: r.status) ?? .unknown,
                usedBytes:  r.allocated ?? 0,
                totalBytes: r.size ?? 0,
                freeBytes:  r.free ?? 0,
                vdevs:  allVdevs,
                disks:  allDisks,
                readErrors:     allDisks.reduce(0) { $0 + $1.readErrors },
                writeErrors:    allDisks.reduce(0) { $0 + $1.writeErrors },
                checksumErrors: allDisks.reduce(0) { $0 + $1.checksumErrors },
                lastScrub:      nil,
                lastScrubStatus: r.scan?.state
            )
        }
    }

    func scrubPool(id: Int) async throws {
        struct Body: Encodable { let action: String }
        try await post("/api/v2.0/pool/id/\(id)/scrub", body: Body(action: "START"))
    }

    // MARK: - Disks
    func fetchDisks() async throws -> [Disk] {
        struct Raw: Decodable {
            let name: String; let serial: String?; let model: String?
            let size: Int64?; let pool: String?
        }
        return try await get("/api/v2.0/disk", as: [Raw].self).map { r in
            Disk(id: r.name, serial: r.serial ?? "—", model: r.model ?? "—",
                 size: r.size ?? 0, temperature: nil, powerOnHours: nil,
                 poolName: r.pool, smartStatus: .unknown,
                 readErrors: 0, writeErrors: 0, checksumErrors: 0, smartResults: [])
        }
    }

    func runSmartTest(diskName: String, testType: SmartTestType) async throws {
        struct Body: Encodable { let type: String }
        try await post("/api/v2.0/disk/id/\(diskName)/smart_test",
                       body: Body(type: testType.rawValue))
    }
}

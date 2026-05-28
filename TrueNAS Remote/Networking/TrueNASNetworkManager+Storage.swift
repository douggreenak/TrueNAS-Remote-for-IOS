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
            // For DISK-type VDEVs (single disk), these fields live on the VDEV node itself
            let disk: String?
            let stats: DiskNode.Stats?
        }
        struct Topology: Decodable {
            let data: [VDEVNode]?
            let cache: [VDEVNode]?
            let log: [VDEVNode]?
            let spare: [VDEVNode]?
            let special: [VDEVNode]?
            let dedup: [VDEVNode]?
        }
        struct BSONDate: Decodable {
            let date: Date?
            private enum CodingKeys: String, CodingKey { case dollarDate = "$date" }
            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                if let ms = try c.decodeIfPresent(Int64.self, forKey: .dollarDate) {
                    date = Date(timeIntervalSince1970: Double(ms) / 1000.0)
                } else { date = nil }
            }
        }
        struct Scan: Decodable {
            let state: String?
            let endTime: BSONDate?
        }
        struct Raw: Decodable {
            let id: Int; let name: String; let status: String
            let size: Int64?; let allocated: Int64?; let free: Int64?
            let scan: Scan?; let topology: Topology?
        }

        let raws = try await call(method: "pool.query", as: [Raw].self)
        return raws.map { r in
            var allVdevs: [VDEV] = []
            var allDisks: [Disk] = []

            func toDisks(_ nodes: [DiskNode]?) -> [Disk] {
                (nodes ?? []).compactMap { n in
                    guard let d = n.disk ?? n.name else { return nil }
                    return Disk(id: d, serial: "—", model: "—", size: 0,
                                temperature: nil, powerOnHours: nil, poolName: r.name,
                                smartStatus: .unknown,
                                readErrors:     n.stats?.readErrors     ?? 0,
                                writeErrors:    n.stats?.writeErrors    ?? 0,
                                checksumErrors: n.stats?.checksumErrors ?? 0,
                                smartResults: [])
                }
            }

            func processVDEVs(_ nodes: [VDEVNode]?, type: VDEVType) {
                for (i, v) in (nodes ?? []).enumerated() {
                    let disks: [Disk]
                    if let children = v.children, !children.isEmpty {
                        // Multi-disk VDEV (MIRROR, RAIDZ, etc.) — disks are in children
                        disks = toDisks(children)
                    } else if let diskName = v.disk ?? v.name {
                        // Single-disk VDEV — the VDEV node itself carries disk + stats
                        disks = [Disk(id: diskName, serial: "—", model: "—", size: 0,
                                      temperature: nil, powerOnHours: nil, poolName: r.name,
                                      smartStatus: .unknown,
                                      readErrors:     v.stats?.readErrors     ?? 0,
                                      writeErrors:    v.stats?.writeErrors    ?? 0,
                                      checksumErrors: v.stats?.checksumErrors ?? 0,
                                      smartResults: [])]
                    } else {
                        disks = []
                    }
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
                lastScrub:       r.scan?.endTime?.date,
                lastScrubStatus: r.scan?.state
            )
        }
    }

    func scrubPool(id: Int) async throws {
        // params: [pool_id, {action}]
        let params = try JSONSerialization.data(withJSONObject: [id, ["action": "START"]] as [Any])
        try await call(method: "pool.scrub", params: params)
    }

    // MARK: - Disks
    func fetchDisks() async throws -> [Disk] {
        struct Raw: Decodable {
            let name: String; let serial: String?; let model: String?
            let size: Int64?
            // NOTE: disk.query in TrueNAS SCALE 25.x always returns pool=null;
            // pool membership is derived from pool topology in the ViewModel.
        }
        return try await call(method: "disk.query", as: [Raw].self).map { r in
            Disk(id: r.name, serial: r.serial ?? "—", model: r.model ?? "—",
                 size: r.size ?? 0, temperature: nil, powerOnHours: nil,
                 poolName: nil, smartStatus: .unknown,
                 readErrors: 0, writeErrors: 0, checksumErrors: 0, smartResults: [])
        }
    }

    /// Returns a map of device name → temperature (°C) for all disks.
    /// Pass an empty array to get all disks; disk.temperatures expects [[name...]] params.
    func fetchDiskTemperatures() async throws -> [String: Double] {
        // Correct format: params = [[]] — outer array is the params array,
        // inner [] is the (empty) list of disk names meaning "all disks".
        let params = try JSONSerialization.data(withJSONObject: [[]] as [[String]])
        return try await call(method: "disk.temperatures", params: params,
                              as: [String: Double].self)
    }

    /// Returns a map of device name → pool name using disk.details.
    /// This is the ONLY reliable way to get pool membership in SCALE 25.x,
    /// because disk.query always returns pool=null and the boot-pool disks
    /// don't appear in pool.query at all.
    func fetchDiskPoolMap() async throws -> [String: String] {
        struct DiskDetail: Decodable {
            let name: String
            let importedZpool: String?
            let exportedZpool: String?
        }
        struct Details: Decodable {
            let used: [DiskDetail]?
            let unused: [DiskDetail]?
        }
        let params = try JSONSerialization.data(withJSONObject:
            [["type": "BOTH", "join_partitions": false] as [String: Any]])
        let details = try await call(method: "disk.details", params: params, as: Details.self)
        var map = [String: String]()
        let all = (details.used ?? []) + (details.unused ?? [])
        for d in all {
            if let pool = d.importedZpool { map[d.name] = pool }
            else if let pool = d.exportedZpool { map[d.name] = pool + " (exported)" }
        }
        return map
    }

    /// Run a S.M.A.R.T. self-test on a disk.
    /// In SCALE 25.x the method is disk.smart_test with positional args [names, type].
    func runSmartTest(diskName: String, testType: SmartTestType) async throws {
        let params = try JSONSerialization.data(withJSONObject: [[diskName], testType.rawValue] as [Any])
        try await call(method: "disk.smart_test", params: params)
    }
}

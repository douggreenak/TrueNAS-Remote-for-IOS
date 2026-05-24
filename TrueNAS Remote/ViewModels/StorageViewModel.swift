import Foundation
import Observation

@Observable
class StorageViewModel {
    var pools        : [StoragePool] = []
    var disks        : [Disk]        = []
    var datasets     : [Dataset]     = []
    var snapshots    : [Snapshot]    = []
    var selectedPool : StoragePool?
    var isLoading    = false
    var errorMessage : String?

    private let network = TrueNASNetworkManager.shared

    init() { loadMockData() }

    func refresh() async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            async let p = network.fetchPools()
            async let d = network.fetchDisks()
            pools = try await p
            disks = try await d
        } catch { errorMessage = error.localizedDescription }
    }

    func refreshDatasets(pool: String? = nil) async {
        do { datasets = try await network.fetchDatasets(pool: pool) }
        catch { errorMessage = error.localizedDescription }
    }

    func refreshSnapshots(dataset: String) async {
        do { snapshots = try await network.fetchSnapshots(dataset: dataset) }
        catch { errorMessage = error.localizedDescription }
    }

    func scrub(pool: StoragePool) async {
        do { try await network.scrubPool(id: pool.id) }
        catch { errorMessage = error.localizedDescription }
    }

    func createSnapshot(dataset: String, name: String) async {
        do {
            try await network.createSnapshot(dataset: dataset, name: name)
            await refreshSnapshots(dataset: dataset)
        } catch { errorMessage = error.localizedDescription }
    }

    func deleteSnapshot(_ snap: Snapshot) async {
        do {
            try await network.deleteSnapshot(id: snap.id)
            snapshots.removeAll { $0.id == snap.id }
        } catch { errorMessage = error.localizedDescription }
    }

    func rollbackSnapshot(_ snap: Snapshot) async {
        do { try await network.rollbackSnapshot(id: snap.id) }
        catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Mock Data
    private func loadMockData() {
        let tb: Int64 = 1_099_511_627_776

        func makeDisk(_ id: String, serial: String, model: String, pool: String, temp: Int?) -> Disk {
            Disk(id: id, serial: serial, model: model, size: 8 * tb / 8,
                 temperature: temp, powerOnHours: Int.random(in: 5000...30000),
                 poolName: pool, smartStatus: .passed,
                 readErrors: 0, writeErrors: 0, checksumErrors: 0, smartResults: [])
        }

        let tankDisks = [
            makeDisk("sda", serial: "WD-WXB1A34TPZ8F", model: "WDC WD80EAZZ-00BKLB0", pool: "tank", temp: 38),
            makeDisk("sdb", serial: "WD-WXB1A34TRK9G", model: "WDC WD80EAZZ-00BKLB0", pool: "tank", temp: 37),
            makeDisk("sdc", serial: "WD-WXB1A34TQJ2H", model: "WDC WD80EAZZ-00BKLB0", pool: "tank", temp: 39)
        ]
        let backupDisks = [
            makeDisk("sdd", serial: "ST8000DM004-2CX188", model: "Seagate ST8000DM004", pool: "backup", temp: 34),
            makeDisk("sde", serial: "ST8000DM004-2CX189", model: "Seagate ST8000DM004", pool: "backup", temp: 35)
        ]
        let vmDisks = [
            makeDisk("sdf", serial: "SAMSUNG_MZ7LH960HAJR", model: "Samsung 860 EVO", pool: "vm-storage", temp: 31),
            Disk(id: "sdg", serial: "SAMSUNG_MZ7LH961HAJR", model: "Samsung 860 EVO",
                 size: Int64(1.8 * Double(tb) / 8), temperature: nil, powerOnHours: 12000,
                 poolName: "vm-storage", smartStatus: .unknown,
                 readErrors: 1, writeErrors: 0, checksumErrors: 2, smartResults: [])
        ]

        let tankVDEV = VDEV(id: "tank-data-0", type: .data, status: .online, disks: tankDisks)
        let backupVDEV = VDEV(id: "backup-data-0", type: .data, status: .online, disks: backupDisks)
        let vmVDEV = VDEV(id: "vm-data-0", type: .data, status: .degraded, disks: vmDisks)

        pools = [
            StoragePool(id: 1, name: "tank", status: .online,
                        usedBytes: Int64(3.2 * Double(tb)),
                        totalBytes: Int64(7.2 * Double(tb)),
                        freeBytes: Int64(4.0 * Double(tb)),
                        vdevs: [tankVDEV], disks: tankDisks,
                        readErrors: 0, writeErrors: 0, checksumErrors: 0,
                        lastScrub: Date().addingTimeInterval(-86400 * 3),
                        lastScrubStatus: "FINISHED"),
            StoragePool(id: 2, name: "backup", status: .online,
                        usedBytes: Int64(1.1 * Double(tb)),
                        totalBytes: Int64(3.6 * Double(tb)),
                        freeBytes: Int64(2.5 * Double(tb)),
                        vdevs: [backupVDEV], disks: backupDisks,
                        readErrors: 0, writeErrors: 0, checksumErrors: 0,
                        lastScrub: Date().addingTimeInterval(-86400 * 7),
                        lastScrubStatus: "FINISHED"),
            StoragePool(id: 3, name: "vm-storage", status: .degraded,
                        usedBytes: Int64(0.8 * Double(tb)),
                        totalBytes: Int64(1.8 * Double(tb)),
                        freeBytes: Int64(1.0 * Double(tb)),
                        vdevs: [vmVDEV], disks: vmDisks,
                        readErrors: 1, writeErrors: 0, checksumErrors: 2,
                        lastScrub: nil, lastScrubStatus: nil)
        ]
        disks = tankDisks + backupDisks + vmDisks

        datasets = [
            Dataset(id: "tank", name: "tank", pool: "tank", type: .filesystem,
                    usedBytes: Int64(3.2 * Double(tb)), availableBytes: Int64(4.0 * Double(tb)),
                    referencedBytes: 0, compressionRatio: 1.43, deduplicationRatio: 1.0,
                    encryption: .unencrypted, snapshotCount: 12, children: [
                        Dataset(id: "tank/media", name: "media", pool: "tank", type: .filesystem,
                                usedBytes: Int64(2.1 * Double(tb)), availableBytes: Int64(4.0 * Double(tb)),
                                referencedBytes: 0, compressionRatio: 1.2, deduplicationRatio: 1.0,
                                encryption: .unencrypted, snapshotCount: 4, children: [], comments: ""),
                        Dataset(id: "tank/documents", name: "documents", pool: "tank", type: .filesystem,
                                usedBytes: Int64(0.3 * Double(tb)), availableBytes: Int64(4.0 * Double(tb)),
                                referencedBytes: 0, compressionRatio: 2.1, deduplicationRatio: 1.0,
                                encryption: .encrypted(locked: false), snapshotCount: 8, children: [], comments: "Encrypted personal data"),
                        Dataset(id: "tank/vm-data", name: "vm-data", pool: "tank", type: .volume,
                                usedBytes: Int64(0.5 * Double(tb)), availableBytes: Int64(4.0 * Double(tb)),
                                referencedBytes: 0, compressionRatio: 1.0, deduplicationRatio: 1.0,
                                encryption: .unencrypted, snapshotCount: 2, children: [], comments: "")
                    ], comments: "")
        ]

        let gb: Int64 = 1_073_741_824
        snapshots = [
            Snapshot(id: "tank/media@auto-2026-05-20", dataset: "tank/media",
                     name: "auto-2026-05-20", created: Date().addingTimeInterval(-86400 * 3),
                     referencedBytes: Int64(2.1 * Double(tb)), usedBytes: 2 * gb, holdCount: 0),
            Snapshot(id: "tank/media@auto-2026-05-21", dataset: "tank/media",
                     name: "auto-2026-05-21", created: Date().addingTimeInterval(-86400 * 2),
                     referencedBytes: Int64(2.12 * Double(tb)), usedBytes: Int64(1.5 * Double(gb)), holdCount: 0),
            Snapshot(id: "tank/media@manual-backup", dataset: "tank/media",
                     name: "manual-backup", created: Date().addingTimeInterval(-86400 * 7),
                     referencedBytes: Int64(2.0 * Double(tb)), usedBytes: 3 * gb, holdCount: 1),
            Snapshot(id: "tank/documents@auto-2026-05-22", dataset: "tank/documents",
                     name: "auto-2026-05-22", created: Date().addingTimeInterval(-86400),
                     referencedBytes: Int64(0.3 * Double(tb)), usedBytes: 512 * 1024 * 1024, holdCount: 0),
            Snapshot(id: "tank/documents@pre-edit", dataset: "tank/documents",
                     name: "pre-edit", created: Date().addingTimeInterval(-86400 * 14),
                     referencedBytes: Int64(0.28 * Double(tb)), usedBytes: 768 * 1024 * 1024, holdCount: 0)
        ]
    }
}

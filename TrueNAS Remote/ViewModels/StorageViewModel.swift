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

    func refresh() async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            async let p = network.fetchPools()
            async let d = network.fetchDisks()
            async let t = network.fetchDiskTemperatures()

            var fetchedPools = try await p
            let fetchedDisks = try await d
            // Temperatures are best-effort — never fail the whole refresh if unavailable.
            let temperatures = (try? await t) ?? [:]

            // Enrich each pool's disk stubs with real metadata from disk.query + temperatures.
            let diskMap = Dictionary(uniqueKeysWithValues: fetchedDisks.map { ($0.id, $0) })

            for i in fetchedPools.indices {
                fetchedPools[i].disks = fetchedPools[i].disks.map { stub in
                    enrich(stub, from: diskMap, temperatures: temperatures)
                }
                fetchedPools[i].vdevs = fetchedPools[i].vdevs.map { vdev in
                    VDEV(id: vdev.id, type: vdev.type, status: vdev.status,
                         disks: vdev.disks.map { enrich($0, from: diskMap, temperatures: temperatures) })
                }
            }

            // Derive pool membership from pool topology
            // (disk.query returns pool=null in TrueNAS SCALE 25.x)
            var poolByDisk = [String: String]()
            for pool in fetchedPools {
                for disk in pool.disks { poolByDisk[disk.id] = pool.name }
            }

            pools = fetchedPools

            // Build the full disk list with pool names and temperatures applied.
            disks = fetchedDisks.map { disk in
                let poolName = poolByDisk[disk.id]
                let temp     = temperatures[disk.id].map { Int($0) }
                return Disk(id: disk.id, serial: disk.serial, model: disk.model,
                            size: disk.size, temperature: temp,
                            powerOnHours: disk.powerOnHours, poolName: poolName,
                            smartStatus: disk.smartStatus,
                            readErrors: disk.readErrors, writeErrors: disk.writeErrors,
                            checksumErrors: disk.checksumErrors, smartResults: disk.smartResults)
            }
        } catch { errorMessage = error.localizedDescription }
    }

    /// Merge real disk metadata into a topology stub, preserving ZFS error counts.
    private func enrich(_ stub: Disk, from map: [String: Disk],
                        temperatures: [String: Double] = [:]) -> Disk {
        guard let real = map[stub.id] else { return stub }
        let temp = temperatures[stub.id].map { Int($0) } ?? real.temperature ?? stub.temperature
        return Disk(
            id:             stub.id,
            serial:         real.serial,
            model:          real.model,
            size:           real.size > 0 ? real.size : stub.size,
            temperature:    temp,
            powerOnHours:   real.powerOnHours,
            poolName:       stub.poolName ?? real.poolName,
            smartStatus:    real.smartStatus,
            readErrors:     stub.readErrors,    // keep ZFS topology error counts
            writeErrors:    stub.writeErrors,
            checksumErrors: stub.checksumErrors,
            smartResults:   real.smartResults
        )
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

}

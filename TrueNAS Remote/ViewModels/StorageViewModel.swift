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
        guard !isLoading else { return }
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            // Fetch pools, raw disk list, temperatures, and pool map in parallel.
            // disk.details gives the authoritative pool-per-disk mapping including
            // the boot-pool (sda/sdf) and single-disk VDEVs that pool.query misses.
            async let p    = network.fetchPools()
            async let d    = network.fetchDisks()
            async let t    = network.fetchDiskTemperatures()
            async let pmap = network.fetchDiskPoolMap()

            var fetchedPools = try await p
            let fetchedDisks = try await d
            let temperatures = (try? await t)    ?? [:]
            let poolByDisk   = (try? await pmap) ?? [:]

            // Enrich each pool's disk stubs with real metadata + temperatures.
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

            pools = fetchedPools

            // Build full disk list using disk.details pool map (authoritative).
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

    /// Lightweight refresh — fetches only pools (skips disks/temperatures).
    /// Used by the Dashboard pool-health section so it can show pool status
    /// without triggering the full disk + temperature fetch.
    func refreshPoolsOnly() async {
        guard pools.isEmpty else { return }  // already have data, skip
        do { pools = try await network.fetchPools() }
        catch { /* silent — dashboard shows "Loading" until full refresh */ }
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

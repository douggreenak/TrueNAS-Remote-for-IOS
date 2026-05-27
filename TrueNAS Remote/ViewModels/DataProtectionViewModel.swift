import Foundation
import Observation

@Observable
class DataProtectionViewModel {
    var snapshotTasks  : [SnapshotTask]   = []
    var replication    : [ReplicationTask] = []
    var cloudSync      : [CloudSyncTask]  = []
    var rsyncTasks     : [RsyncTask]      = []
    var scrubTasks     : [ScrubTask]      = []
    var isLoading      = false
    var errorMessage   : String?

    private let network = TrueNASNetworkManager.shared

    func refresh() async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            async let sn = network.fetchSnapshotTasks()
            async let rp = network.fetchReplicationTasks()
            async let cs = network.fetchCloudSyncTasks()
            async let rs = network.fetchRsyncTasks()
            async let sc = network.fetchScrubTasks()
            snapshotTasks = try await sn
            replication   = try await rp
            cloudSync     = try await cs
            rsyncTasks    = try await rs
            scrubTasks    = try await sc
        } catch { errorMessage = error.localizedDescription }
    }

    func runSnapshotTask(_ task: SnapshotTask) async {
        do { try await network.runSnapshotTask(id: task.id) }
        catch { errorMessage = error.localizedDescription }
    }

    func runReplication(_ task: ReplicationTask) async {
        do { try await network.runReplicationTask(id: task.id) }
        catch { errorMessage = error.localizedDescription }
    }

    func runCloudSync(_ task: CloudSyncTask) async {
        do { try await network.runCloudSyncTask(id: task.id) }
        catch { errorMessage = error.localizedDescription }
    }

    func runRsync(_ task: RsyncTask) async {
        do { try await network.runRsyncTask(id: task.id) }
        catch { errorMessage = error.localizedDescription }
    }

}

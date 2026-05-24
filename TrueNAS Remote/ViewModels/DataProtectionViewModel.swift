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

    init() { loadMockData() }

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

    private func loadMockData() {
        snapshotTasks = [
            SnapshotTask(id: 1, dataset: "tank/media",     recursive: false, lifetime: "2 WEEKS",
                         schedule: "Daily at 2:00 AM",    enabled: true,  lastRunStatus: .success, lastRun: Date().addingTimeInterval(-86400)),
            SnapshotTask(id: 2, dataset: "tank/documents", recursive: true,  lifetime: "1 MONTH",
                         schedule: "Daily at 3:00 AM",    enabled: true,  lastRunStatus: .success, lastRun: Date().addingTimeInterval(-86400 * 2)),
            SnapshotTask(id: 3, dataset: "tank",           recursive: true,  lifetime: "1 WEEK",
                         schedule: "Every hour at :00",   enabled: false, lastRunStatus: .unknown, lastRun: nil)
        ]
        replication = [
            ReplicationTask(id: 1, name: "tank → backup offsite", sourcePath: "tank/media",
                            targetPath: "backup/media-mirror", direction: "PUSH", transport: "SSH",
                            schedule: "Daily at 4:00 AM", enabled: true,
                            lastRunStatus: .success, lastRun: Date().addingTimeInterval(-86400)),
            ReplicationTask(id: 2, name: "documents backup", sourcePath: "tank/documents",
                            targetPath: "backup/docs", direction: "PUSH", transport: "SSH",
                            schedule: "Daily at 5:00 AM", enabled: true,
                            lastRunStatus: .failed, lastRun: Date().addingTimeInterval(-3600 * 6))
        ]
        cloudSync = [
            CloudSyncTask(id: 1, description: "Photos → Backblaze B2", direction: "PUSH",
                          path: "/mnt/tank/photos", provider: "Backblaze B2",
                          schedule: "Daily at 1:00 AM", enabled: true,
                          lastRunStatus: .success, lastRun: Date().addingTimeInterval(-86400),
                          bytesTransferred: 2_147_483_648),
            CloudSyncTask(id: 2, description: "Documents → S3 Glacier", direction: "PUSH",
                          path: "/mnt/tank/documents", provider: "Amazon S3",
                          schedule: "Daily at 2:00 AM", enabled: false,
                          lastRunStatus: .unknown, lastRun: nil, bytesTransferred: nil)
        ]
        rsyncTasks = [
            RsyncTask(id: 1, path: "/mnt/tank/media", remoteHost: "nas2.local",
                      remotePort: 22, remotePath: "/backup/media", direction: "PUSH",
                      schedule: "Daily at 6:00 AM", enabled: true,
                      lastRunStatus: .success, lastRun: Date().addingTimeInterval(-86400 * 2))
        ]
        scrubTasks = [
            ScrubTask(id: 1, poolName: "tank",       schedule: "Daily at 12:00 AM",
                      enabled: true,  threshold: 35, lastRun: Date().addingTimeInterval(-86400 * 3),
                      lastRunDuration: 3720, lastRunStatus: .success, isRunning: false, progress: nil),
            ScrubTask(id: 2, poolName: "backup",     schedule: "Daily at 12:00 AM",
                      enabled: true,  threshold: 35, lastRun: Date().addingTimeInterval(-86400 * 7),
                      lastRunDuration: 1800, lastRunStatus: .success, isRunning: false, progress: nil),
            ScrubTask(id: 3, poolName: "vm-storage", schedule: "Daily at 12:00 AM",
                      enabled: false, threshold: 35, lastRun: nil, lastRunDuration: nil,
                      lastRunStatus: .unknown, isRunning: false, progress: nil)
        ]
    }
}

import Foundation

extension TrueNASNetworkManager {

    // MARK: - Snapshot Tasks
    func fetchSnapshotTasks() async throws -> [SnapshotTask] {
        struct Raw: Decodable {
            let id: Int; let dataset: String; let recursive: Bool?
            let lifetime_value: Int?; let lifetime_unit: String?
            let enabled: Bool?
            let schedule: ScheduleRaw?
            struct ScheduleRaw: Decodable { let minute: String?; let hour: String?; let dom: String?; let month: String?; let dow: String? }
        }
        let raws = try await get("/api/v2.0/pool/snapshottask", as: [Raw].self)
        return raws.map { r in
            let life = "\(r.lifetime_value ?? 2) \(r.lifetime_unit ?? "WEEKS")"
            return SnapshotTask(id: r.id, dataset: r.dataset,
                                recursive: r.recursive ?? false,
                                lifetime: life,
                                schedule: scheduleString(r.schedule?.hour, r.schedule?.minute),
                                enabled: r.enabled ?? true,
                                lastRunStatus: .unknown, lastRun: nil)
        }
    }

    func runSnapshotTask(id: Int) async throws {
        try await post("/api/v2.0/pool/snapshottask/id/\(id)/run")
    }

    // MARK: - Replication Tasks
    func fetchReplicationTasks() async throws -> [ReplicationTask] {
        struct Raw: Decodable {
            let id: Int; let name: String
            let sourceDatasetsRaw: [String]?; let targetDataset: String?
            let direction: String?; let transport: String?
            let schedule: ScheduleRaw?; let enabled: Bool?
            let state: StateRaw?
            struct ScheduleRaw: Decodable { let hour: String?; let minute: String? }
            struct StateRaw: Decodable { let state: String?; let datetime: Double? }
        }
        let raws = try await get("/api/v2.0/replication", as: [Raw].self)
        return raws.map { r in
            ReplicationTask(
                id: r.id, name: r.name,
                sourcePath: r.sourceDatasetsRaw?.first ?? "—",
                targetPath: r.targetDataset ?? "—",
                direction: r.direction ?? "PUSH",
                transport: r.transport ?? "SSH",
                schedule: scheduleString(r.schedule?.hour, r.schedule?.minute),
                enabled: r.enabled ?? true,
                lastRunStatus: TaskRunStatus(rawValue: r.state?.state ?? "") ?? .unknown,
                lastRun: r.state?.datetime.map { Date(timeIntervalSince1970: $0) }
            )
        }
    }

    func runReplicationTask(id: Int) async throws {
        try await post("/api/v2.0/replication/id/\(id)/run")
    }

    // MARK: - Cloud Sync Tasks
    func fetchCloudSyncTasks() async throws -> [CloudSyncTask] {
        struct Raw: Decodable {
            let id: Int; let description: String?; let direction: String?
            let path: String?; let credentials: CredsRaw?
            let schedule: ScheduleRaw?; let enabled: Bool?
            let job: JobRaw?
            struct CredsRaw: Decodable { let name: String?; let provider: String? }
            struct ScheduleRaw: Decodable { let hour: String?; let minute: String? }
            struct JobRaw: Decodable { let state: String?; let timeStarted: Double? }
        }
        return try await get("/api/v2.0/cloudsync", as: [Raw].self).map { r in
            CloudSyncTask(
                id: r.id, description: r.description ?? "Cloud Sync \(r.id)",
                direction: r.direction ?? "PUSH", path: r.path ?? "—",
                provider: r.credentials?.name ?? "—",
                schedule: scheduleString(r.schedule?.hour, r.schedule?.minute),
                enabled: r.enabled ?? true,
                lastRunStatus: TaskRunStatus(rawValue: r.job?.state ?? "") ?? .unknown,
                lastRun: r.job?.timeStarted.map { Date(timeIntervalSince1970: $0) },
                bytesTransferred: nil
            )
        }
    }

    func runCloudSyncTask(id: Int) async throws {
        try await post("/api/v2.0/cloudsync/id/\(id)/run")
    }

    // MARK: - Rsync Tasks
    func fetchRsyncTasks() async throws -> [RsyncTask] {
        struct Raw: Decodable {
            let id: Int; let path: String?; let remotehost: String?
            let remoteport: Int?; let remotepath: String?; let direction: String?
            let schedule: ScheduleRaw?; let enabled: Bool?; let job: JobRaw?
            struct ScheduleRaw: Decodable { let hour: String?; let minute: String? }
            struct JobRaw: Decodable { let state: String?; let timeStarted: Double? }
        }
        return try await get("/api/v2.0/rsynctask", as: [Raw].self).map { r in
            RsyncTask(id: r.id, path: r.path ?? "—", remoteHost: r.remotehost ?? "—",
                      remotePort: r.remoteport ?? 22, remotePath: r.remotepath ?? "—",
                      direction: r.direction ?? "PUSH",
                      schedule: scheduleString(r.schedule?.hour, r.schedule?.minute),
                      enabled: r.enabled ?? true,
                      lastRunStatus: TaskRunStatus(rawValue: r.job?.state ?? "") ?? .unknown,
                      lastRun: r.job?.timeStarted.map { Date(timeIntervalSince1970: $0) })
        }
    }

    func runRsyncTask(id: Int) async throws {
        try await post("/api/v2.0/rsynctask/id/\(id)/run")
    }

    // MARK: - Scrub Tasks
    func fetchScrubTasks() async throws -> [ScrubTask] {
        struct Raw: Decodable {
            let id: Int; let pool: String?; let enabled: Bool?
            let threshold: Int?; let schedule: ScheduleRaw?
            struct ScheduleRaw: Decodable { let hour: String?; let minute: String? }
        }
        return try await get("/api/v2.0/pool/scrub", as: [Raw].self).map { r in
            ScrubTask(id: r.id, poolName: r.pool ?? "—",
                      schedule: scheduleString(r.schedule?.hour, r.schedule?.minute),
                      enabled: r.enabled ?? true, threshold: r.threshold ?? 35,
                      lastRun: nil, lastRunDuration: nil,
                      lastRunStatus: .unknown, isRunning: false, progress: nil)
        }
    }

    // MARK: - Schedule helper
    private func scheduleString(_ hour: String?, _ minute: String?) -> String {
        guard let h = hour, let m = minute else { return "—" }
        if h == "*" && m == "*"    { return "Every minute" }
        if h == "*"                { return "Every hour at :\(m)" }
        let hInt = Int(h) ?? 0
        let mPad = m.count == 1 ? "0\(m)" : m
        let ampm = hInt >= 12 ? "PM" : "AM"
        let h12  = hInt == 0 ? 12 : (hInt > 12 ? hInt - 12 : hInt)
        return "Daily at \(h12):\(mPad) \(ampm)"
    }
}

import Foundation

extension TrueNASNetworkManager {

    // MARK: - BSON Date helper
    /// Decodes {"$date": ms} BSON wrapper used by TrueNAS task state timestamps.
    private struct TaskBSONDate: Decodable {
        let date: Date?
        private enum CodingKeys: String, CodingKey { case ms = "$date" }
        init(from decoder: Decoder) throws {
            if let c = try? decoder.container(keyedBy: CodingKeys.self),
               let ms = (try? c.decode(Double.self, forKey: .ms))
                     ?? (try? c.decode(Int64.self, forKey: .ms)).map(Double.init) {
                date = Date(timeIntervalSince1970: ms / 1000)
                return
            }
            if let svc = try? decoder.singleValueContainer(),
               let ts  = try? svc.decode(Double.self) {
                date = Date(timeIntervalSince1970: ts)
                return
            }
            date = nil
        }
    }

    // MARK: - Snapshot Tasks
    func fetchSnapshotTasks() async throws -> [SnapshotTask] {
        struct Raw: Decodable {
            let id: Int; let dataset: String; let recursive: Bool?
            let lifetime_value: Int?; let lifetime_unit: String?
            let enabled: Bool?
            let schedule: ScheduleRaw?
            struct ScheduleRaw: Decodable {
                let minute: String?; let hour: String?
                let dom: String?; let month: String?; let dow: String?
            }
        }
        let raws = try await call(method: "pool.snapshottask.query", as: [Raw].self)
        return raws.map { r in
            let lifetimeValue = r.lifetime_value ?? 2
            let lifetimeUnit  = (r.lifetime_unit ?? "WEEKS").lowercased()
            let life = "\(lifetimeValue) \(lifetimeUnit)"
            return SnapshotTask(
                id: r.id, dataset: r.dataset,
                recursive: r.recursive ?? false,
                lifetime: life,
                schedule: scheduleString(r.schedule?.hour, r.schedule?.minute,
                                         dow: r.schedule?.dow, dom: r.schedule?.dom),
                enabled: r.enabled ?? true,
                lastRunStatus: .unknown, lastRun: nil)
        }
    }

    func runSnapshotTask(id: Int) async throws {
        let params = try JSONSerialization.data(withJSONObject: [id])
        try await call(method: "pool.snapshottask.run", params: params)
    }

    // MARK: - Replication Tasks
    func fetchReplicationTasks() async throws -> [ReplicationTask] {
        struct Raw: Decodable {
            let id: Int; let name: String
            let sourceDatasetsRaw: [String]?; let targetDataset: String?
            let direction: String?; let transport: String?
            let schedule: ScheduleRaw?; let enabled: Bool?
            let state: StateRaw?
            struct ScheduleRaw: Decodable {
                let hour: String?; let minute: String?
                let dow: String?; let dom: String?
            }
            struct StateRaw: Decodable { let state: String?; let datetime: TaskBSONDate? }
        }
        let raws = try await call(method: "replication.query", as: [Raw].self)
        return raws.map { r in
            ReplicationTask(
                id: r.id, name: r.name,
                sourcePath: r.sourceDatasetsRaw?.first ?? "—",
                targetPath: r.targetDataset ?? "—",
                direction: r.direction ?? "PUSH",
                transport: r.transport ?? "SSH",
                schedule: scheduleString(r.schedule?.hour, r.schedule?.minute,
                                         dow: r.schedule?.dow, dom: r.schedule?.dom),
                enabled: r.enabled ?? true,
                lastRunStatus: TaskRunStatus(rawValue: r.state?.state ?? "") ?? .unknown,
                lastRun: r.state?.datetime?.date
            )
        }
    }

    func runReplicationTask(id: Int) async throws {
        let params = try JSONSerialization.data(withJSONObject: [id])
        try await call(method: "replication.run", params: params)
    }

    // MARK: - Cloud Sync Tasks
    func fetchCloudSyncTasks() async throws -> [CloudSyncTask] {
        struct Raw: Decodable {
            let id: Int; let description: String?; let direction: String?
            let path: String?; let credentials: CredsRaw?
            let schedule: ScheduleRaw?; let enabled: Bool?
            let job: JobRaw?
            struct CredsRaw: Decodable { let name: String? }
            struct ScheduleRaw: Decodable {
                let hour: String?; let minute: String?
                let dow: String?; let dom: String?
            }
            struct JobRaw: Decodable { let state: String?; let timeStarted: TaskBSONDate? }
        }
        return try await call(method: "cloudsync.query", as: [Raw].self).map { r in
            CloudSyncTask(
                id: r.id, description: r.description ?? "Cloud Sync \(r.id)",
                direction: r.direction ?? "PUSH", path: r.path ?? "—",
                provider: r.credentials?.name ?? "—",
                schedule: scheduleString(r.schedule?.hour, r.schedule?.minute,
                                         dow: r.schedule?.dow, dom: r.schedule?.dom),
                enabled: r.enabled ?? true,
                lastRunStatus: TaskRunStatus(rawValue: r.job?.state ?? "") ?? .unknown,
                lastRun: r.job?.timeStarted?.date,
                bytesTransferred: nil
            )
        }
    }

    func runCloudSyncTask(id: Int) async throws {
        let params = try JSONSerialization.data(withJSONObject: [id])
        try await call(method: "cloudsync.run", params: params)
    }

    // MARK: - Rsync Tasks
    func fetchRsyncTasks() async throws -> [RsyncTask] {
        struct Raw: Decodable {
            let id: Int; let path: String?; let remotehost: String?
            let remoteport: Int?; let remotepath: String?; let direction: String?
            let schedule: ScheduleRaw?; let enabled: Bool?; let job: JobRaw?
            struct ScheduleRaw: Decodable {
                let hour: String?; let minute: String?
                let dow: String?; let dom: String?
            }
            struct JobRaw: Decodable { let state: String?; let timeStarted: TaskBSONDate? }
        }
        return try await call(method: "rsynctask.query", as: [Raw].self).map { r in
            RsyncTask(id: r.id, path: r.path ?? "—", remoteHost: r.remotehost ?? "—",
                      remotePort: r.remoteport ?? 22, remotePath: r.remotepath ?? "—",
                      direction: r.direction ?? "PUSH",
                      schedule: scheduleString(r.schedule?.hour, r.schedule?.minute,
                                               dow: r.schedule?.dow, dom: r.schedule?.dom),
                      enabled: r.enabled ?? true,
                      lastRunStatus: TaskRunStatus(rawValue: r.job?.state ?? "") ?? .unknown,
                      lastRun: r.job?.timeStarted?.date)
        }
    }

    func runRsyncTask(id: Int) async throws {
        let params = try JSONSerialization.data(withJSONObject: [id])
        try await call(method: "rsynctask.run", params: params)
    }

    // MARK: - Scrub Tasks
    func fetchScrubTasks() async throws -> [ScrubTask] {
        struct Raw: Decodable {
            let id: Int
            let pool: AnyCodable?       // Int in 25.x, String in older versions
            let poolName: String?
            let enabled: Bool?
            let threshold: Int?; let schedule: ScheduleRaw?
            struct ScheduleRaw: Decodable { let hour: String?; let minute: String? }
        }
        return try await call(method: "pool.scrub.query", as: [Raw].self).map { r in
            let name: String = {
                if let s = r.poolName, !s.isEmpty { return s }
                switch r.pool?.value {
                case let i as Int:    return "Pool \(i)"
                case let s as String: return s
                default:              return "—"
                }
            }()
            return ScrubTask(id: r.id, poolName: name,
                      schedule: scheduleString(r.schedule?.hour, r.schedule?.minute),
                      enabled: r.enabled ?? true, threshold: r.threshold ?? 35,
                      lastRun: nil, lastRunDuration: nil,
                      lastRunStatus: .unknown, isRunning: false, progress: nil)
        }
    }

    // MARK: - Schedule helper
    private func scheduleString(
        _ hour: String?, _ minute: String?,
        dow: String? = nil, dom: String? = nil
    ) -> String {
        guard let h = hour, let m = minute, !h.isEmpty, !m.isEmpty else { return "—" }

        // Every-minute / every-hour shortcuts
        if h == "*" && m == "*" { return "Every minute" }
        if h == "*" {
            let mInt = Int(m) ?? 0
            return "Every hour at :\(String(format: "%02d", mInt))"
        }

        // Build time string (12-hour)
        let hInt = Int(h) ?? 0
        let mInt = Int(m) ?? 0
        let ampm = hInt >= 12 ? "PM" : "AM"
        let h12  = hInt == 0 ? 12 : (hInt > 12 ? hInt - 12 : hInt)
        let timeStr = "\(h12):\(String(format: "%02d", mInt)) \(ampm)"

        // Day-of-week names
        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

        // Named dow (e.g. "1", "1,3,5", "1-5")
        if let d = dow, d != "*", d != "?" {
            let days = d.split(separator: ",").compactMap { part -> String? in
                let s = part.trimmingCharacters(in: .whitespaces)
                if let idx = Int(s), idx < 7 { return dayNames[idx] }
                // Handle ranges like "1-5"
                if s.contains("-") {
                    let bounds = s.split(separator: "-").compactMap { Int($0) }
                    if bounds.count == 2 {
                        if bounds[0] == 1 && bounds[1] == 5 { return "Weekdays" }
                        if bounds[0] == 0 && bounds[1] == 6 { return "Daily" }
                    }
                }
                return nil
            }
            if !days.isEmpty {
                let dayLabel = days.count == 1 ? days[0] : days.joined(separator: "/")
                return "\(dayLabel) at \(timeStr)"
            }
        }

        // Day-of-month (e.g. "1" = 1st of month)
        if let dm = dom, dm != "*", dm != "?", let day = Int(dm) {
            let suffix: String
            switch day % 10 {
            case 1 where day != 11: suffix = "st"
            case 2 where day != 12: suffix = "nd"
            case 3 where day != 13: suffix = "rd"
            default: suffix = "th"
            }
            return "Monthly on the \(day)\(suffix) at \(timeStr)"
        }

        return "Daily at \(timeStr)"
    }
}

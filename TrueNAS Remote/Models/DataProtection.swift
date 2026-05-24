import Foundation
import SwiftUI

// MARK: - Shared run status
enum TaskRunStatus: String {
    case success    = "SUCCESS"
    case failed     = "FAILED"
    case running    = "RUNNING"
    case pending    = "PENDING"
    case hold       = "HOLD"
    case unknown    = "UNKNOWN"

    var color: Color {
        switch self {
        case .success:  return .green
        case .failed:   return .red
        case .running:  return .blue
        case .pending:  return .orange
        case .hold:     return .secondary
        case .unknown:  return .secondary
        }
    }

    var icon: String {
        switch self {
        case .success:  return "checkmark.circle.fill"
        case .failed:   return "xmark.circle.fill"
        case .running:  return "arrow.clockwise.circle.fill"
        case .pending:  return "clock.fill"
        default:        return "questionmark.circle"
        }
    }

    var label: String { rawValue.capitalized }
}

// MARK: - Snapshot Task
struct SnapshotTask: Identifiable {
    let id: Int
    let dataset: String
    let recursive: Bool
    let lifetime: String         // e.g. "2 WEEKS"
    let schedule: String         // human-readable cron
    var enabled: Bool
    var lastRunStatus: TaskRunStatus
    var lastRun: Date?
}

// MARK: - Replication Task
struct ReplicationTask: Identifiable {
    let id: Int
    let name: String
    let sourcePath: String
    let targetPath: String
    let direction: String        // PUSH or PULL
    let transport: String        // SSH, LOCAL, NETCAT
    let schedule: String
    var enabled: Bool
    var lastRunStatus: TaskRunStatus
    var lastRun: Date?
    var progress: Double?        // 0-1 when running
    var jobId: Int?
}

// MARK: - Cloud Provider
enum CloudProvider: String {
    case s3        = "S3"
    case backblaze = "B2"
    case gcs       = "GOOGLE_CLOUD_STORAGE"
    case azure     = "AZUREBLOB"
    case dropbox   = "DROPBOX"
    case onedrive  = "ONEDRIVE"
    case other     = "OTHER"

    var label: String {
        switch self {
        case .s3:        return "Amazon S3"
        case .backblaze: return "Backblaze B2"
        case .gcs:       return "Google Cloud"
        case .azure:     return "Azure Blob"
        case .dropbox:   return "Dropbox"
        case .onedrive:  return "OneDrive"
        case .other:     return "Cloud"
        }
    }

    var icon: String { "cloud.fill" }
}

// MARK: - Cloud Sync Task
struct CloudSyncTask: Identifiable {
    let id: Int
    let description: String
    let direction: String        // PUSH or PULL
    let path: String
    let provider: String
    let schedule: String
    var enabled: Bool
    var lastRunStatus: TaskRunStatus
    var lastRun: Date?
    var bytesTransferred: Int64?

    var directionLabel: String { direction == "PUSH" ? "↑ Push" : "↓ Pull" }
    var directionIcon:  String { direction == "PUSH" ? "icloud.and.arrow.up.fill" : "icloud.and.arrow.down.fill" }
}

// MARK: - Rsync Task
struct RsyncTask: Identifiable {
    let id: Int
    let path: String
    let remoteHost: String
    let remotePort: Int
    let remotePath: String
    let direction: String
    let schedule: String
    var enabled: Bool
    var lastRunStatus: TaskRunStatus
    var lastRun: Date?
}

// MARK: - Scrub Task
struct ScrubTask: Identifiable {
    let id: Int
    let poolName: String
    let schedule: String
    var enabled: Bool
    var threshold: Int           // days since last scrub to skip
    var lastRun: Date?
    var lastRunDuration: TimeInterval?
    var lastRunStatus: TaskRunStatus
    var isRunning: Bool
    var progress: Double?        // 0-1 when running
}

// MARK: - S.M.A.R.T. Scheduled Test
struct SmartScheduledTest: Identifiable {
    let id: Int
    let diskName: String
    let diskSerial: String
    let testType: SmartTestType
    let schedule: String
}

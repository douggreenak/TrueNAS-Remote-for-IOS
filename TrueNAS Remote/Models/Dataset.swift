import Foundation
import SwiftUI

// MARK: - Dataset Type
enum DatasetType: String, Decodable {
    case filesystem = "FILESYSTEM"
    case volume     = "VOLUME"

    var label: String { self == .filesystem ? "Dataset" : "Zvol" }
    var icon: String  { self == .filesystem ? "folder.fill" : "cylinder.fill" }
}

// MARK: - Encryption Status
enum EncryptionStatus {
    case unencrypted
    case encrypted(locked: Bool)

    var isEncrypted: Bool {
        if case .encrypted = self { return true }
        return false
    }

    var isLocked: Bool {
        if case .encrypted(let locked) = self { return locked }
        return false
    }

    var label: String {
        switch self {
        case .unencrypted:            return "Unencrypted"
        case .encrypted(let locked):  return locked ? "Locked" : "Encrypted"
        }
    }

    var icon: String {
        switch self {
        case .unencrypted:            return "lock.open"
        case .encrypted(let locked):  return locked ? "lock.fill" : "lock.open.fill"
        }
    }

    var color: Color {
        switch self {
        case .unencrypted:            return .secondary
        case .encrypted(let locked):  return locked ? .red : .green
        }
    }
}

// MARK: - Dataset
struct Dataset: Identifiable {
    let id: String              // full path e.g. "tank/media/movies"
    let name: String            // leaf name e.g. "movies"
    let pool: String
    let type: DatasetType
    let usedBytes: Int64
    let availableBytes: Int64
    let referencedBytes: Int64
    let compressionRatio: Double
    let deduplicationRatio: Double
    let encryption: EncryptionStatus
    var snapshotCount: Int
    var children: [Dataset]
    var comments: String

    var formattedUsed:      String { fmt(usedBytes) }
    var formattedAvailable: String { fmt(availableBytes) }

    private func fmt(_ b: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: b, countStyle: .binary)
    }

    var depth: Int { id.components(separatedBy: "/").count - 1 }
}

// MARK: - Snapshot
struct Snapshot: Identifiable {
    let id: String          // full snapshot name e.g. "tank/media@auto-2024-01-01"
    let dataset: String     // dataset path
    let name: String        // snapshot name part e.g. "auto-2024-01-01"
    let created: Date
    let referencedBytes: Int64
    let usedBytes: Int64
    var holdCount: Int

    var formattedReferenced: String {
        ByteCountFormatter.string(fromByteCount: referencedBytes, countStyle: .binary)
    }

    var formattedUsed: String {
        ByteCountFormatter.string(fromByteCount: usedBytes, countStyle: .binary)
    }
}

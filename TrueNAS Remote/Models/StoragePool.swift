import Foundation
import SwiftUI

// MARK: - Pool Status
enum PoolStatus: String, Decodable {
    case online   = "ONLINE"
    case degraded = "DEGRADED"
    case faulted  = "FAULTED"
    case offline  = "OFFLINE"
    case removed  = "REMOVED"
    case unknown  = "UNKNOWN"

    var isHealthy: Bool { self == .online }

    var color: Color {
        switch self {
        case .online:             return .green
        case .degraded:           return .orange
        case .faulted, .removed:  return .red
        case .offline, .unknown:  return .secondary
        }
    }

    var label: String { rawValue.capitalized }

    var icon: String {
        switch self {
        case .online:   return "checkmark.circle.fill"
        case .degraded: return "exclamationmark.triangle.fill"
        case .faulted:  return "xmark.octagon.fill"
        default:        return "questionmark.circle.fill"
        }
    }
}

// MARK: - VDEV
enum VDEVType: String, Decodable {
    case data      = "data"
    case cache     = "cache"
    case log       = "log"
    case dedup     = "dedup"
    case special   = "special"
    case spare     = "spare"
    case root      = "root"

    var label: String {
        switch self {
        case .data:    return "Data"
        case .cache:   return "Cache (L2ARC)"
        case .log:     return "Log (SLOG)"
        case .dedup:   return "Dedup"
        case .special: return "Special"
        case .spare:   return "Hot Spare"
        case .root:    return "Root"
        }
    }

    var icon: String {
        switch self {
        case .data:    return "cylinder.split.1x2.fill"
        case .cache:   return "memorychip.fill"
        case .log:     return "pencil.and.list.clipboard"
        case .spare:   return "lifepreserver.fill"
        default:       return "cylinder.fill"
        }
    }
}

struct VDEV: Identifiable {
    let id: String
    let type: VDEVType
    let status: PoolStatus
    let disks: [Disk]
    var name: String { type.label }
}

// MARK: - Pool
struct StoragePool: Identifiable {
    let id: Int
    let name: String
    let status: PoolStatus
    let usedBytes: Int64
    let totalBytes: Int64
    let freeBytes: Int64
    var vdevs: [VDEV]
    var disks: [Disk]
    var readErrors: Int
    var writeErrors: Int
    var checksumErrors: Int
    var lastScrub: Date?
    var lastScrubStatus: String?

    var usedFraction: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes)
    }

    var formattedUsed:  String { Self.fmt(usedBytes) }
    var formattedFree:  String { Self.fmt(freeBytes) }
    var formattedTotal: String { Self.fmt(totalBytes) }

    private static func fmt(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .binary)
    }

    var totalErrors: Int { readErrors + writeErrors + checksumErrors }
}

import Foundation
import SwiftUI

// MARK: - App Status
enum AppStatus: String, Decodable {
    case running    = "RUNNING"
    case stopped    = "STOPPED"
    case deploying  = "DEPLOYING"
    case error      = "ERROR"
    case unknown    = "UNKNOWN"

    var color: Color {
        switch self {
        case .running:   return .green
        case .stopped:   return .secondary
        case .deploying: return .blue
        case .error:     return .red
        case .unknown:   return .secondary
        }
    }

    var label: String {
        switch self {
        case .running:   return "Running"
        case .stopped:   return "Stopped"
        case .deploying: return "Deploying"
        case .error:     return "Error"
        case .unknown:   return "Unknown"
        }
    }

    var icon: String {
        switch self {
        case .running:   return "play.circle.fill"
        case .stopped:   return "stop.circle.fill"
        case .deploying: return "arrow.clockwise.circle.fill"
        case .error:     return "exclamationmark.circle.fill"
        case .unknown:   return "questionmark.circle.fill"
        }
    }
}

// MARK: - Installed App
struct InstalledApp: Identifiable {
    let id: String           // app name slug
    let name: String
    let version: String
    var status: AppStatus
    var updateAvailable: Bool
    var latestVersion: String?
    let description: String
    let catalog: String      // e.g. "TRUENAS" or "CUSTOM"
    var iconURL: String?     // from metadata.icon
    var metadata: AppMetadata?
}

struct AppMetadata {
    var cpuUsage: Double?
    var memoryUsageMB: Double?
    var networkInBytes: Int64?
    var networkOutBytes: Int64?
}

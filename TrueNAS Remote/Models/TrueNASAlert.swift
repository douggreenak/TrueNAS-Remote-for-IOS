import Foundation
import SwiftUI

// MARK: - Alert Level
enum AlertLevel: String, Decodable, CaseIterable {
    case critical  = "CRITICAL"
    case warning   = "WARNING"
    case notice    = "NOTICE"
    case info      = "INFO"
    case error     = "ERROR"

    var color: Color {
        switch self {
        case .critical, .error: return .red
        case .warning:          return .orange
        case .notice:           return .yellow
        case .info:             return .blue
        }
    }

    var icon: String {
        switch self {
        case .critical, .error: return "exclamationmark.octagon.fill"
        case .warning:          return "exclamationmark.triangle.fill"
        case .notice:           return "bell.fill"
        case .info:             return "info.circle.fill"
        }
    }

    var label: String { rawValue.capitalized }

    var sortPriority: Int {
        switch self {
        case .critical: return 0
        case .error:    return 1
        case .warning:  return 2
        case .notice:   return 3
        case .info:     return 4
        }
    }
}

// MARK: - Alert
struct TrueNASAlert: Identifiable {
    let id: String
    let level: AlertLevel
    let message: String
    let source: String
    let timestamp: Date
    var dismissed: Bool

    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

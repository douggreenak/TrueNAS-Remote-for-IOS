import Foundation
import SwiftUI

struct AuditEntry: Identifiable {
    let id: String           // UUID from server
    let timestamp: Date
    let username: String
    let service: String      // e.g. "SMB", "MIDDLEWARE", "SUDO"
    let event: String        // e.g. "AUTHENTICATION", "CONNECT"
    let success: Bool
    let address: String      // remote IP
    var detail: [String: String]   // extra key/value pairs

    var statusColor: Color { success ? .green : .red }
    var statusIcon:  String { success ? "checkmark.circle.fill" : "xmark.circle.fill" }

    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

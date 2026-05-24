import Foundation
import SwiftUI

// MARK: - State
enum ServiceState: String, Decodable {
    case running = "RUNNING"
    case stopped = "STOPPED"
    case unknown = "UNKNOWN"

    var isRunning: Bool { self == .running }

    var color: Color { isRunning ? .green : .red }

    var label: String { rawValue.capitalized }

    var icon: String { isRunning ? "circle.fill" : "circle" }
}

// MARK: - System Service
struct SystemService: Identifiable {
    let id: Int
    let name: String            // internal name e.g. "cifs"
    let displayName: String     // human name e.g. "SMB"
    var state: ServiceState
    var startOnBoot: Bool

    static let wellKnown: [String: String] = [
        "cifs":        "SMB",
        "nfs":         "NFS",
        "ssh":         "SSH",
        "ftp":         "FTP",
        "iscsitarget": "iSCSI",
        "smart":       "S.M.A.R.T.",
        "snmp":        "SNMP",
        "ups":         "UPS",
        "rsyncd":      "Rsyncd",
        "ntp":         "NTP",
        "s3":          "MinIO",
        "lldp":        "LLDP",
        "webdav":      "WebDAV",
        "netdata":     "Netdata"
    ]
}

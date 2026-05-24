import Foundation
import SwiftUI

// MARK: - VM State
enum VMState: String, Decodable {
    case running  = "RUNNING"
    case stopped  = "STOPPED"
    case error    = "ERROR"
    case unknown  = "UNKNOWN"

    var isRunning: Bool { self == .running }

    var color: Color {
        switch self {
        case .running:  return .green
        case .stopped:  return .secondary
        case .error:    return .red
        case .unknown:  return .secondary
        }
    }

    var label: String { rawValue.capitalized }

    var icon: String {
        switch self {
        case .running:  return "play.circle.fill"
        case .stopped:  return "stop.circle.fill"
        case .error:    return "exclamationmark.circle.fill"
        case .unknown:  return "questionmark.circle.fill"
        }
    }
}

// MARK: - Virtual Machine
struct VirtualMachine: Identifiable {
    let id: Int
    let name: String
    var status: VMState
    let cpuCount: Int
    let memoryMB: Int          // megabytes
    let description: String
    var uptime: TimeInterval?  // seconds, nil when stopped
    var pid: Int?              // process ID when running

    var formattedMemory: String {
        if memoryMB >= 1024 { return "\(memoryMB / 1024) GiB" }
        return "\(memoryMB) MiB"
    }

    var formattedUptime: String {
        guard let u = uptime else { return "—" }
        let h = Int(u) / 3600
        let m = (Int(u) % 3600) / 60
        let s = Int(u) % 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m \(s)s" }
        return "\(s)s"
    }
}

import Foundation
import SwiftUI

// MARK: - S.M.A.R.T.
enum SmartStatus: String {
    case passed  = "PASSED"
    case failed  = "FAILED"
    case unknown = "UNKNOWN"

    var color: Color {
        switch self {
        case .passed:  return .green
        case .failed:  return .red
        case .unknown: return .secondary
        }
    }

    var icon: String {
        switch self {
        case .passed:  return "checkmark.seal.fill"
        case .failed:  return "xmark.seal.fill"
        case .unknown: return "questionmark.circle"
        }
    }
}

enum SmartTestType: String, CaseIterable {
    case short      = "SHORT"
    case long       = "LONG"
    case conveyance = "CONVEYANCE"
    case offline    = "OFFLINE"

    var label: String {
        switch self {
        case .short:      return "Short"
        case .long:       return "Long"
        case .conveyance: return "Conveyance"
        case .offline:    return "Offline"
        }
    }
}

struct SmartTestResult: Identifiable {
    let id: String
    let testType: SmartTestType
    let status: SmartStatus
    let remaining: Int    // percentage remaining when stopped
    let lifetime: Int     // power-on hours at time of test
    let description: String
    let date: Date?
}

// MARK: - Disk
struct Disk: Identifiable {
    let id: String              // device name, e.g. "sda"
    let serial: String
    let model: String
    let size: Int64             // bytes
    let temperature: Int?       // celsius
    let powerOnHours: Int?
    let poolName: String?       // which pool it belongs to (nil = unused)
    let smartStatus: SmartStatus
    let readErrors: Int
    let writeErrors: Int
    let checksumErrors: Int
    var smartResults: [SmartTestResult]

    var temperatureDisplay: String {
        guard let t = temperature else { return "N/A" }
        return "\(t)°C"
    }

    var temperatureColor: Color {
        guard let t = temperature else { return .secondary }
        if t >= 55 { return .red }
        if t >= 45 { return .orange }
        return .primary
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .decimal)
    }

    var totalErrors: Int { readErrors + writeErrors + checksumErrors }
}

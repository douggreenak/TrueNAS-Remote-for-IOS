import Foundation

// MARK: - System Info
struct SystemInfo {
    var version: String       = "—"
    var hostname: String      = "—"
    var uptimeSeconds: TimeInterval = 0
    var cpuUsage: Double      = 0      // 0–100
    var memoryUsed: Int64     = 0      // bytes
    var memoryTotal: Int64    = 0      // bytes
    var memoryZFSCache: Int64 = 0      // bytes
    var memoryServices: Int64 = 0      // bytes
    var loadAvg1:  Double     = 0
    var loadAvg5:  Double     = 0
    var loadAvg15: Double     = 0
    var platform: String      = "Generic"
    var serialNumber: String  = "—"
    var updateAvailable: Bool = false
    var updateVersion: String?

    var memoryUsedFraction: Double {
        guard memoryTotal > 0 else { return 0 }
        return Double(memoryUsed) / Double(memoryTotal)
    }
    var memoryUsedPercent: Double { memoryUsedFraction * 100 }

    var formattedUptime: String {
        let total = Int(uptimeSeconds)
        let d = total / 86400
        let h = (total % 86400) / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if d > 0 { return "\(d)d \(h)h \(m)m" }
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m \(s)s" }
        return "\(s)s"
    }

    var formattedMemory: String {
        "\(fmt(memoryUsed)) / \(fmt(memoryTotal))"
    }

    private func fmt(_ b: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: b, countStyle: .binary)
    }
}

// MARK: - Reporting chart point
struct ReportingPoint: Identifiable {
    let id  = UUID()
    let time: Date
    let value: Double
    var label: String = ""
}

// MARK: - Named series (multiple lines on one chart)
struct ReportingSeries: Identifiable {
    let id = UUID()
    let name: String
    var points: [ReportingPoint]
    var color: String = ""
}

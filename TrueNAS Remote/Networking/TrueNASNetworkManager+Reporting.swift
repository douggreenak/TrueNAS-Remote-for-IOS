import Foundation

extension TrueNASNetworkManager {

    enum ReportingGraph: String {
        case cpu        = "cpu"
        case memory     = "memory"
        case load       = "load"
        case interface  = "interface"
        case disk       = "disk"          // was "diskio" — requires identifier (full disk string from reporting.graphs)
        case arcsize    = "arcsize"
        case arcresult  = "arcresult"    // ARC hit/miss rate — valid in 25.x but may return error if no ARC data
        case cputemp    = "cputemp"
        case uptime     = "uptime"

        var title: String {
            switch self {
            case .cpu:       return "CPU Usage"
            case .memory:    return "Memory"
            case .load:      return "System Load"
            case .interface: return "Network I/O"
            case .disk:      return "Disk I/O"
            case .arcsize:   return "ZFS ARC Size"
            case .arcresult: return "ZFS ARC Hit Rate"
            case .cputemp:   return "CPU Temperature"
            case .uptime:    return "Uptime"
            }
        }
    }

    /// Returns [ReportingSeries] — one per named graph line.
    ///
    /// JSON-RPC method: reporting.get_data
    /// Params: [[{"name": "cpu"}]]  — params[0] is the array of graph descriptors.
    ///   The old {"graphs":[…]} wrapper is INVALID in TrueNAS 25.x; use [[…]] instead.
    /// Response rows: [[timestamp, val0, val1, …]] — row[0] is Unix timestamp,
    /// legend[0] is always "time" and is skipped.
    func fetchReporting(
        graph: ReportingGraph,
        identifier: String? = nil,
        unit: String = "HOURLY"   // retained for call-site compatibility; unused by API
    ) async throws -> [ReportingSeries] {

        // ── Response ──────────────────────────────────────────────────────
        struct Response: Decodable {
            let name: String
            let data: [[Double?]]?
            let legend: [String]?
        }

        // Build params: [[{"name": "cpu"}]] or [[{"name": "interface", "identifier": "em0"}]]
        // Omit "identifier" key entirely when nil (don't send "identifier": null)
        var graphItem: [String: Any] = ["name": graph.rawValue]
        if let id = identifier { graphItem["identifier"] = id }
        // params[0] = array of graph descriptors (NOT wrapped in {"graphs":…})
        let params = try JSONSerialization.data(withJSONObject: [[graphItem]])

        let raw = try await call(method: "reporting.get_data", params: params)
        let results = try JSONDecoder.truenas.decode([Response].self, from: raw)

        guard let first = results.first,
              let rows  = first.data,
              !rows.isEmpty else { return [] }

        // Legend[0] is always "time" — skip it; remaining entries are series names
        let names = Array((first.legend ?? ["time", "value"]).dropFirst())
        var series: [ReportingSeries] = names.map { ReportingSeries(name: $0, points: []) }

        for row in rows {
            // row[0] = Unix timestamp, row[1…] = per-series values
            guard row.count > 1, let ts = row.first, let timestamp = ts else { continue }
            let t = Date(timeIntervalSince1970: timestamp)
            for (i, val) in row.dropFirst().enumerated() {
                if i < series.count, let v = val {
                    series[i].points.append(ReportingPoint(time: t, value: v))
                }
            }
        }
        return series
    }
}

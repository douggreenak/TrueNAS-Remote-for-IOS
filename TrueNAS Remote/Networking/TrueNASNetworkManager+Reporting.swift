import Foundation

extension TrueNASNetworkManager {

    enum ReportingGraph: String {
        case cpu        = "cpu"
        case memory     = "memory"
        case load       = "load"
        case interface  = "interface"
        case diskio     = "diskio"
        case arcsize    = "arcsize"
        case arcresult  = "arcresult"
        case cputemp    = "cputemp"
        case uptime     = "uptime"

        var title: String {
            switch self {
            case .cpu:       return "CPU Usage"
            case .memory:    return "Memory"
            case .load:      return "System Load"
            case .interface: return "Network I/O"
            case .diskio:    return "Disk I/O"
            case .arcsize:   return "ZFS ARC Size"
            case .arcresult: return "ZFS ARC Hit Rate"
            case .cputemp:   return "CPU Temperature"
            case .uptime:    return "Uptime"
            }
        }
    }

    struct ReportingQuery: Encodable {
        var graphs: [GraphQuery]
        var reporting_query: QueryParams

        struct GraphQuery: Encodable {
            let name: String
            var identifier: String?
        }
        struct QueryParams: Encodable {
            var start: String = "now-1h"
            var end: String   = "now"
            var step: Int     = 10
            var unit: String  = "HOURLY"
            var page: Int     = 1
        }
    }

    /// Returns [ReportingSeries] — one series per named graph line
    func fetchReporting(
        graph: ReportingGraph,
        identifier: String? = nil,
        unit: String = "HOURLY"
    ) async throws -> [ReportingSeries] {
        struct Response: Decodable {
            let name: String
            let identifier: String?
            let data: [[Double?]]?
            let start: Int?
            let end: Int?
            let step: Int?
            let legend: [String]?
        }

        var q = ReportingQuery(
            graphs: [.init(name: graph.rawValue, identifier: identifier)],
            reporting_query: .init(unit: unit)
        )
        q.reporting_query.unit = unit

        let body = try JSONEncoder().encode(q)
        let data = try await request(path: "/api/v2.0/reporting/get_data", method: "POST", body: body)
        let results = try JSONDecoder.truenas.decode([Response].self, from: data)

        guard let first = results.first,
              let rows  = first.data,
              let start = first.start,
              let step  = first.step else { return [] }

        let legends = first.legend ?? ["value"]
        var series: [ReportingSeries] = legends.map { ReportingSeries(name: $0, points: []) }

        for (rowIdx, row) in rows.enumerated() {
            let t = Date(timeIntervalSince1970: Double(start + rowIdx * step))
            for (colIdx, val) in row.enumerated() {
                if colIdx < series.count, let v = val {
                    series[colIdx].points.append(ReportingPoint(time: t, value: v))
                }
            }
        }
        return series
    }
}

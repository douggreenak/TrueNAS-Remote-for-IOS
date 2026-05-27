import Foundation
import Observation

@Observable
class ReportingViewModel {
    enum TimeRange: String, CaseIterable {
        case hour  = "HOURLY"
        case day   = "DAILY"
        case week  = "WEEKLY"
        var label: String {
            switch self { case .hour: return "1h"; case .day: return "24h"; case .week: return "7d" }
        }
    }

    var selectedRange     = TimeRange.hour
    var cpuSeries         : [ReportingSeries] = []
    var memorySeries      : [ReportingSeries] = []
    var networkSeries     : [ReportingSeries] = []
    var diskSeries        : [ReportingSeries] = []
    var arcSeries         : [ReportingSeries] = []
    var tempSeries        : [ReportingSeries] = []
    var loadSeries        : [ReportingSeries] = []
    var isLoading         = false
    var errorMessage      : String?
    // Populated on first refresh from the server's interface list
    var selectedInterface = ""

    private let network = TrueNASNetworkManager.shared

    func refresh() async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }

        // ── Core graphs (always present) ──────────────────────────────────
        do {
            let unit = selectedRange.rawValue
            async let cpu  = network.fetchReporting(graph: .cpu,     unit: unit)
            async let mem  = network.fetchReporting(graph: .memory,  unit: unit)
            async let arc  = network.fetchReporting(graph: .arcsize, unit: unit)
            async let temp = network.fetchReporting(graph: .cputemp, unit: unit)
            async let load = network.fetchReporting(graph: .load,    unit: unit)
            cpuSeries    = try await cpu
            memorySeries = try await mem
            arcSeries    = try await arc
            tempSeries   = try await temp
            loadSeries   = try await load
        } catch {
            errorMessage = error.localizedDescription
        }

        // ── Network graph — discover interface if not yet set ─────────────
        do {
            if selectedInterface.isEmpty {
                let ifaces = try await network.fetchInterfaces()
                selectedInterface = ifaces.first(where: { $0.linkState })?.name
                                 ?? ifaces.first?.name ?? ""
            }
            if !selectedInterface.isEmpty {
                networkSeries = try await network.fetchReporting(
                    graph: .interface, identifier: selectedInterface,
                    unit: selectedRange.rawValue
                )
            }
        } catch {
            networkSeries = []
        }
    }
}

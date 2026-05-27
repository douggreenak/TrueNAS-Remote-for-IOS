import Foundation
import Observation

@Observable
class DashboardViewModel {
    var systemInfo    = SystemInfo()
    var temperatures  : [ReportingPoint] = []
    var cpuHistory    : [ReportingPoint] = []
    var networkSeries : [ReportingSeries] = []
    var isLoading     = false
    var errorMessage  : String?

    private let network = TrueNASNetworkManager.shared

    func refresh() async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            // Fetch system info and reporting graphs in parallel
            async let infoFetch = network.fetchSystemInfo()
            async let cpuFetch  = network.fetchReporting(graph: .cpu,     unit: "HOURLY")
            async let memFetch  = network.fetchReporting(graph: .memory,  unit: "HOURLY")
            async let tempFetch = network.fetchReporting(graph: .cputemp, unit: "HOURLY")

            var info     = try await infoFetch
            let cpuData  = (try? await cpuFetch)  ?? []
            let memData  = (try? await memFetch)  ?? []
            let tempData = (try? await tempFetch) ?? []

            // CPU: aggregate series is named "cpu" (first in legend after "time")
            if let cpuSeries = cpuData.first(where: { $0.name == "cpu" }) ?? cpuData.first {
                cpuHistory    = cpuSeries.points
                info.cpuUsage = cpuSeries.points.last?.value ?? 0
            }

            // Memory: API returns only 'available' bytes; used = total − available
            if let availSeries = memData.first(where: { $0.name.lowercased() == "available" })
                               ?? memData.first {
                let availBytes    = Int64(max(0, availSeries.points.last?.value ?? 0))
                info.memoryUsed   = max(0, info.memoryTotal - availBytes)
            }

            // Temperature: prefer aggregate 'cpu' series; fall back to first core
            temperatures = (tempData.first(where: { $0.name == "cpu" }) ?? tempData.first)?.points ?? []

            systemInfo = info
        } catch {
            errorMessage = error.localizedDescription
        }

        // Best-effort network sparkline: discover the primary interface then fetch reporting
        do {
            let ifaces  = try await network.fetchInterfaces()
            let primary = ifaces.first(where: { $0.linkState }) ?? ifaces.first
            if let name = primary?.name {
                networkSeries = try await network.fetchReporting(
                    graph: .interface, identifier: name, unit: "HOURLY"
                )
            } else {
                networkSeries = []
            }
        } catch {
            networkSeries = []
        }
    }
}

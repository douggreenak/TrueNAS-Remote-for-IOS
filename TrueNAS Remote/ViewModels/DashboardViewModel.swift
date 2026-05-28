import Foundation
import Observation

@Observable
class DashboardViewModel {
    var systemInfo      = SystemInfo()
    var temperatures    : [ReportingPoint] = []
    var cpuHistory      : [ReportingPoint] = []
    var memoryHistory   : [ReportingPoint] = []   // "used" bytes over time
    var arcHistory      : [ReportingPoint] = []   // ZFS ARC size over time
    var networkSeries   : [ReportingSeries] = []
    var isLoading       = false
    var isLoadingCharts = false   // true while background reporting fetch is running
    var errorMessage    : String?

    private let network = TrueNASNetworkManager.shared

    // MARK: - Fast path

    /// Fetches `system.info` and returns quickly so rings, hostname, uptime
    /// and load averages appear in the UI within ~0.5 s.
    /// Chart data is then loaded in a separate background Task so it does not
    /// block `isLoading` — the spinner stops as soon as basic info is ready.
    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            systemInfo = try await network.fetchSystemInfo()
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        // Kick off chart loading in the background; does NOT hold up isLoading.
        if !isLoadingCharts {
            Task { await self.refreshCharts() }
        }
    }

    // MARK: - Slow path (reporting charts)

    /// Fetches all reporting series (CPU, memory, temperature, ARC, network)
    /// and updates chart arrays + ring values when data arrives.
    /// Called automatically from refresh() and safe to call directly for a
    /// chart-only refresh (e.g. pull-to-refresh from the detail views).
    func refreshCharts() async {
        guard !isLoadingCharts else { return }
        isLoadingCharts = true
        defer { isLoadingCharts = false }

        // Snapshot total memory so the Task body doesn't race with a concurrent refresh()
        let memTotal = systemInfo.memoryTotal

        async let cpuFetch   = network.fetchReporting(graph: .cpu,     unit: "HOURLY")
        async let memFetch   = network.fetchReporting(graph: .memory,  unit: "HOURLY")
        async let tempFetch  = network.fetchReporting(graph: .cputemp, unit: "HOURLY")
        async let arcFetch   = network.fetchReporting(graph: .arcsize, unit: "HOURLY")

        let cpuData  = (try? await cpuFetch)  ?? []
        let memData  = (try? await memFetch)  ?? []
        let tempData = (try? await tempFetch) ?? []
        let arcData  = (try? await arcFetch)  ?? []

        // CPU: aggregate series named "cpu" (first in legend after "time")
        if let cpuSeries = cpuData.first(where: { $0.name == "cpu" }) ?? cpuData.first {
            cpuHistory = cpuSeries.points
            systemInfo.cpuUsage = cpuSeries.points.last?.value ?? systemInfo.cpuUsage
        }

        // Memory: API returns only 'available' bytes; used = total − available.
        if let availSeries = memData.first(where: { $0.name.lowercased() == "available" })
                           ?? memData.first {
            let total = Double(memTotal)
            memoryHistory = availSeries.points.map {
                ReportingPoint(time: $0.time, value: max(0, total - $0.value))
            }
            let availBytes  = Int64(max(0, availSeries.points.last?.value ?? 0))
            systemInfo.memoryUsed = max(0, memTotal - availBytes)
        }

        // ZFS ARC: store history and populate current cache size
        if let arcSeries = arcData.first(where: { $0.name.lowercased().contains("arc") })
                         ?? arcData.first {
            arcHistory             = arcSeries.points
            systemInfo.memoryZFSCache = Int64(max(0, arcSeries.points.last?.value ?? 0))
        }

        // Temperature: prefer aggregate 'cpu' series; fall back to first core
        temperatures = (tempData.first(where: { $0.name == "cpu" }) ?? tempData.first)?.points ?? []

        // Network sparkline: discover primary active interface then fetch its reporting.
        // Sequential by necessity (need the interface name before fetching data).
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

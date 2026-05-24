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

    var selectedRange  = TimeRange.hour
    var cpuSeries      : [ReportingSeries] = []
    var memorySeries   : [ReportingSeries] = []
    var networkSeries  : [ReportingSeries] = []
    var diskSeries     : [ReportingSeries] = []
    var arcSeries      : [ReportingSeries] = []
    var tempSeries     : [ReportingSeries] = []
    var loadSeries     : [ReportingSeries] = []
    var isLoading      = false
    var errorMessage   : String?
    var selectedInterface = "eno1"

    private let network = TrueNASNetworkManager.shared

    init() { loadMockData() }

    func refresh() async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            let unit = selectedRange.rawValue
            async let cpu  = network.fetchReporting(graph: .cpu,      unit: unit)
            async let mem  = network.fetchReporting(graph: .memory,   unit: unit)
            async let net  = network.fetchReporting(graph: .interface, identifier: selectedInterface, unit: unit)
            async let arc  = network.fetchReporting(graph: .arcsize,  unit: unit)
            async let temp = network.fetchReporting(graph: .cputemp,  unit: unit)
            async let load = network.fetchReporting(graph: .load,     unit: unit)
            cpuSeries     = try await cpu
            memorySeries  = try await mem
            networkSeries = try await net
            arcSeries     = try await arc
            tempSeries    = try await temp
            loadSeries    = try await load
        } catch { errorMessage = error.localizedDescription }
    }

    private func mockSeries(_ name: String, points n: Int = 60,
                             base: Double, range: Double,
                             stepSeconds: Double = 60) -> ReportingSeries {
        let now = Date()
        var pts: [ReportingPoint] = []
        var v = base
        for i in 0..<n {
            v = max(0, min(base + range, v + Double.random(in: -range * 0.15...range * 0.15)))
            pts.append(ReportingPoint(time: now.addingTimeInterval(Double(i - n) * stepSeconds), value: v))
        }
        return ReportingSeries(name: name, points: pts)
    }

    private func loadMockData() {
        cpuSeries     = [mockSeries("CPU",      base: 42, range: 30)]
        memorySeries  = [mockSeries("Used",     base: 13.0e9, range: 2e9),
                         mockSeries("ZFS Cache",base: 8.5e9,  range: 1e9),
                         mockSeries("Free",     base: 9.5e9,  range: 1.5e9)]
        networkSeries = [mockSeries("In",  base: 12e6, range: 10e6),
                         mockSeries("Out", base: 3e6,  range: 2e6)]
        diskSeries    = [mockSeries("sda Read",  base: 50e6, range: 100e6),
                         mockSeries("sda Write", base: 20e6, range: 50e6)]
        arcSeries     = [mockSeries("ARC Size",  base: 8.5e9, range: 500e6),
                         mockSeries("Hit Rate",  base: 94, range: 5)]
        tempSeries    = [mockSeries("CPU Temp",  base: 71, range: 8)]
        loadSeries    = [mockSeries("1m",  base: 1.45, range: 1.0),
                         mockSeries("5m",  base: 1.32, range: 0.8),
                         mockSeries("15m", base: 1.20, range: 0.6)]
    }
}

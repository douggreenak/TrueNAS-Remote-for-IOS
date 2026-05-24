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

    init() { loadMockData() }

    func refresh() async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            var info = try await network.fetchSystemInfo()
            // Retain previous mock CPU/mem until reporting is live
            info.cpuUsage    = systemInfo.cpuUsage
            info.memoryUsed  = systemInfo.memoryUsed
            systemInfo = info
        } catch { errorMessage = error.localizedDescription }
    }

    private func loadMockData() {
        systemInfo = SystemInfo(
            version:          "TrueNAS-SCALE-24.10.2",
            hostname:         "truenas.local",
            uptimeSeconds:    1_315_800,
            cpuUsage:         42.5,
            memoryUsed:       13_210_701_824,
            memoryTotal:      34_359_738_368,
            memoryZFSCache:   8_589_934_592,
            memoryServices:   1_073_741_824,
            loadAvg1:         1.45,
            loadAvg5:         1.32,
            loadAvg15:        1.20,
            platform:         "Generic",
            serialNumber:     "SN-2024-DEMO",
            updateAvailable:  true,
            updateVersion:    "TrueNAS-SCALE-24.10.3"
        )

        let now = Date()
        let rawTemps: [Double] = [68, 71, 69, 73, 70, 72, 68, 71, 74, 70, 69, 72, 71, 73, 70]
        temperatures = rawTemps.enumerated().map { i, t in
            ReportingPoint(time: now.addingTimeInterval(Double(i - rawTemps.count) * 300), value: t)
        }

        let rawCPU: [Double] = [38, 42, 45, 40, 52, 47, 43, 42, 55, 48, 44, 42, 41, 43, 42]
        cpuHistory = rawCPU.enumerated().map { i, v in
            ReportingPoint(time: now.addingTimeInterval(Double(i - rawCPU.count) * 60), value: v)
        }

        let rawIn:  [Double] = [11.2, 12.5, 10.8, 14.3, 13.1, 11.9, 12.7, 10.5, 13.8, 12.1, 11.4, 12.9, 11.7, 13.3, 12.4]
        let rawOut: [Double] = [2.8,  3.1,  2.6,  3.5,  3.3,  2.9,  3.0,  2.7,  3.4,  3.1,  2.8,  3.2,  2.9,  3.3,  3.0]
        networkSeries = [
            ReportingSeries(name: "In",
                            points: rawIn.enumerated().map { i, v in
                                ReportingPoint(time: now.addingTimeInterval(Double(i - rawIn.count) * 60),
                                               value: v * 1_000_000)
                            }),
            ReportingSeries(name: "Out",
                            points: rawOut.enumerated().map { i, v in
                                ReportingPoint(time: now.addingTimeInterval(Double(i - rawOut.count) * 60),
                                               value: v * 1_000_000)
                            })
        ]
    }
}

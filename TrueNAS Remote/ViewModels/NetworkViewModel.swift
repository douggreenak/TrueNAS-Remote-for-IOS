import Foundation
import Observation

@Observable
class NetworkViewModel {
    var interfaces   : [NetworkInterface] = []
    var networkConfig = NetworkConfig(hostname: "—", domain: "—", ipv4Gateway: "—",
                                      ipv6Gateway: "—", nameservers: [], httpProxy: "",
                                      outboundInterface: "—")
    var staticRoutes : [StaticRoute] = []
    var isLoading    = false
    var errorMessage : String?

    private let network = TrueNASNetworkManager.shared

    func refresh() async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            async let i = network.fetchInterfaces()
            async let c = network.fetchNetworkConfig()
            async let r = network.fetchStaticRoutes()
            interfaces   = try await i
            networkConfig = try await c
            staticRoutes = try await r
        } catch { errorMessage = error.localizedDescription }
    }

}

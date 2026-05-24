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

    init() { loadMockData() }

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

    private func loadMockData() {
        let now = Date()
        func traffic(_ bps: Double) -> [TrafficSample] {
            (0..<12).map { i in
                TrafficSample(time: now.addingTimeInterval(Double(i - 12) * 30),
                              inBytes: bps * Double.random(in: 0.8...1.2),
                              outBytes: bps * 0.3 * Double.random(in: 0.8...1.2))
            }
        }

        interfaces = [
            NetworkInterface(id: "eno1", name: "eno1", type: .physical, linkState: true,
                             ipv4Addresses: ["192.168.1.100"], ipv6Addresses: [],
                             macAddress: "AA:BB:CC:DD:EE:01", mtu: 1500, speed: 1000,
                             dhcp: false,
                             inBytes: 1_234_567_890, outBytes: 234_567_890,
                             inBytesPerSec: 12_500_000, outBytesPerSec: 3_125_000,
                             trafficHistory: traffic(12_500_000)),
            NetworkInterface(id: "eno2", name: "eno2", type: .physical, linkState: true,
                             ipv4Addresses: ["10.0.0.1"], ipv6Addresses: [],
                             macAddress: "AA:BB:CC:DD:EE:02", mtu: 1500, speed: 10000,
                             dhcp: false,
                             inBytes: 56_789_012_345, outBytes: 12_345_678_901,
                             inBytesPerSec: 125_000_000, outBytesPerSec: 62_500_000,
                             trafficHistory: traffic(125_000_000)),
            NetworkInterface(id: "eno3", name: "eno3", type: .physical, linkState: false,
                             ipv4Addresses: [], ipv6Addresses: [],
                             macAddress: "AA:BB:CC:DD:EE:03", mtu: 1500, speed: nil,
                             dhcp: false,
                             inBytes: 0, outBytes: 0,
                             inBytesPerSec: 0, outBytesPerSec: 0, trafficHistory: []),
            NetworkInterface(id: "bond0", name: "bond0", type: .lag, linkState: true,
                             ipv4Addresses: ["192.168.1.101"], ipv6Addresses: [],
                             macAddress: "AA:BB:CC:DD:EE:04", mtu: 9000, speed: 2000,
                             dhcp: false,
                             inBytes: 9_876_543_210, outBytes: 1_234_567_890,
                             inBytesPerSec: 25_000_000, outBytesPerSec: 6_250_000,
                             trafficHistory: traffic(25_000_000))
        ]

        networkConfig = NetworkConfig(
            hostname: "truenas",
            domain: "local",
            ipv4Gateway: "192.168.1.1",
            ipv6Gateway: "",
            nameservers: ["8.8.8.8", "1.1.1.1"],
            httpProxy: "",
            outboundInterface: "eno1"
        )

        staticRoutes = [
            StaticRoute(id: 1, destination: "10.10.0.0/24", gateway: "192.168.1.254", description: "Corp VPN"),
            StaticRoute(id: 2, destination: "172.16.0.0/16", gateway: "192.168.1.253", description: "Lab network")
        ]
    }
}

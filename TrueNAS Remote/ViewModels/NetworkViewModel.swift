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

    // Track previous fetch to compute per-second rates
    private var previousInterfaceBytes: [String: (rx: Int64, tx: Int64)] = [:]
    private var lastFetchTime: Date?

    private let network = TrueNASNetworkManager.shared

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            async let i = network.fetchInterfaces()
            async let c = network.fetchNetworkConfig()
            async let r = network.fetchStaticRoutes()
            let rawIfaces = try await i
            networkConfig = try await c
            staticRoutes  = try await r

            let now = Date()
            let dt  = lastFetchTime.map { now.timeIntervalSince($0) } ?? 0

            // Enrich each interface with computed per-second rates + rolling history
            interfaces = rawIfaces.map { iface in
                let prev = previousInterfaceBytes[iface.id]
                var inRate  : Double = 0
                var outRate : Double = 0

                if let p = prev, dt > 0.5 {
                    // Guard against counter wrap-around (reboot / overflow)
                    let inDelta  = max(0, iface.inBytes  - p.rx)
                    let outDelta = max(0, iface.outBytes - p.tx)
                    // If delta > 1 GB in one interval something wrapped; skip that sample
                    if inDelta  < 1_000_000_000 { inRate  = Double(inDelta)  / dt }
                    if outDelta < 1_000_000_000 { outRate = Double(outDelta) / dt }
                }

                // Rolling 60-sample history (one per refresh)
                let prevHistory = interfaces.first(where: { $0.id == iface.id })?.trafficHistory ?? []
                let newSample   = TrafficSample(time: now, inBytes: inRate, outBytes: outRate)
                let history     = Array((prevHistory + [newSample]).suffix(60))

                return NetworkInterface(
                    id:             iface.id,
                    name:           iface.name,
                    type:           iface.type,
                    linkState:      iface.linkState,
                    ipv4Addresses:  iface.ipv4Addresses,
                    ipv6Addresses:  iface.ipv6Addresses,
                    macAddress:     iface.macAddress,
                    mtu:            iface.mtu,
                    speed:          iface.speed,
                    dhcp:           iface.dhcp,
                    inBytes:        iface.inBytes,
                    outBytes:       iface.outBytes,
                    inBytesPerSec:  inRate,
                    outBytesPerSec: outRate,
                    trafficHistory: history
                )
            }

            // Store current bytes for next delta
            previousInterfaceBytes = Dictionary(uniqueKeysWithValues:
                rawIfaces.map { ($0.id, (rx: $0.inBytes, tx: $0.outBytes)) }
            )
            lastFetchTime = now

        } catch { errorMessage = error.localizedDescription }
    }

}

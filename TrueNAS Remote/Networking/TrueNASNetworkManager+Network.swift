import Foundation

extension TrueNASNetworkManager {

    // MARK: - Interfaces
    func fetchInterfaces() async throws -> [NetworkInterface] {
        struct AliasRaw: Decodable {
            let type: String?
            let address: String?
            let netmask: Int?
        }
        struct StateRaw: Decodable {
            // convertFromSnakeCase is active — use camelCase to match JSON snake_case keys
            let linkState: String?           // link_state
            let rxBytes: Int64?              // rx_bytes
            let txBytes: Int64?              // tx_bytes
            let speed: Int?
            let linkAddress: String?         // link_address (MAC) — hwaddr is absent in SCALE 25.x
            let mtu: Int?
            let mediaSubtype: String?        // media_subtype, e.g. "1000Mb/s Twisted Pair"
            let aliases: [AliasRaw]?         // IPs are in state.aliases
        }
        struct Raw: Decodable {
            let id: String
            let name: String
            let type: String?
            let state: StateRaw?
            let description: String?
            let ipv4Dhcp: Bool?              // ipv4_dhcp at top level
        }

        let raws = try await call(method: "interface.query", as: [Raw].self)
        return raws.map { r in
            let stateAliases = r.state?.aliases ?? []
            let ipv4 = stateAliases.filter { $0.type == "INET"  }.compactMap(\.address)
            let ipv6 = stateAliases.filter { $0.type == "INET6" }.compactMap(\.address)
            let linkUp = r.state?.linkState.map { $0.contains("UP") } ?? false
            // Parse speed from mediaSubtype ("1000Mb/s Twisted Pair") if numeric speed field absent
            let speed: Int? = r.state?.speed ?? {
                guard let sub = r.state?.mediaSubtype,
                      let match = sub.range(of: #"(\d+)Mb/s"#, options: .regularExpression) else { return nil }
                return Int(sub[match].prefix(while: { $0.isNumber }))
            }()
            return NetworkInterface(
                id:            r.id,
                name:          r.name,
                type:          InterfaceType(rawValue: r.type ?? "PHYSICAL") ?? .physical,
                linkState:     linkUp,
                ipv4Addresses: ipv4,
                ipv6Addresses: ipv6,
                macAddress:    r.state?.linkAddress ?? "—",
                mtu:           r.state?.mtu ?? 1500,
                speed:         speed,
                dhcp:          r.ipv4Dhcp ?? false,
                inBytes:       r.state?.rxBytes ?? 0,
                outBytes:      r.state?.txBytes ?? 0,
                inBytesPerSec:  0,
                outBytesPerSec: 0,
                trafficHistory: []
            )
        }
    }

    // MARK: - Global Config
    func fetchNetworkConfig() async throws -> NetworkConfig {
        struct Raw: Decodable {
            let hostname: String?
            let domain: String?
            let ipv4gateway: String?
            let ipv6gateway: String?
            let nameserver1: String?
            let nameserver2: String?
            let nameserver3: String?
            let httpproxy: String?
            let outboundInterface: String?
        }
        // Method renamed to network.configuration.config in TrueNAS 25.x
        let r = try await call(method: "network.configuration.config", as: Raw.self)
        var ns: [String] = []
        if let s = r.nameserver1, !s.isEmpty { ns.append(s) }
        if let s = r.nameserver2, !s.isEmpty { ns.append(s) }
        if let s = r.nameserver3, !s.isEmpty { ns.append(s) }
        return NetworkConfig(
            hostname:          r.hostname ?? "—",
            domain:            r.domain   ?? "—",
            ipv4Gateway:       r.ipv4gateway ?? "—",
            ipv6Gateway:       r.ipv6gateway ?? "—",
            nameservers:       ns,
            httpProxy:         r.httpproxy ?? "",
            outboundInterface: r.outboundInterface ?? "—"
        )
    }

    // MARK: - Static Routes
    func fetchStaticRoutes() async throws -> [StaticRoute] {
        struct Raw: Decodable {
            let id: Int; let destination: String; let gateway: String; let description: String
        }
        return try await call(method: "staticroute.query", as: [Raw].self)
            .map { StaticRoute(id: $0.id, destination: $0.destination,
                               gateway: $0.gateway, description: $0.description) }
    }
}

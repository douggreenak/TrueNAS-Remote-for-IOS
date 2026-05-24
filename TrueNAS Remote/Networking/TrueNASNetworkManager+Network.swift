import Foundation

extension TrueNASNetworkManager {

    // MARK: - Interfaces
    func fetchInterfaces() async throws -> [NetworkInterface] {
        struct Raw: Decodable {
            let id: String
            let name: String
            let type: String?
            let state: StateRaw?
            let aliases: [AliasRaw]?
            let description: String?

            struct StateRaw: Decodable {
                let link_state: String?
                let rx_bytes: Int64?
                let tx_bytes: Int64?
                let speed: Int?
                let hwaddr: String?
                let mtu: Int?
            }
            struct AliasRaw: Decodable {
                let type: String?
                let address: String?
                let netmask: Int?
            }
        }
        let raws = try await get("/api/v2.0/interface", as: [Raw].self)
        return raws.map { r in
            let ipv4 = (r.aliases ?? []).filter { $0.type == "INET" }.compactMap(\.address)
            let ipv6 = (r.aliases ?? []).filter { $0.type == "INET6" }.compactMap(\.address)
            return NetworkInterface(
                id:          r.id,
                name:        r.name,
                type:        InterfaceType(rawValue: r.type ?? "PHYSICAL") ?? .physical,
                linkState:   r.state?.link_state == "LINK_STATE_UP",
                ipv4Addresses: ipv4,
                ipv6Addresses: ipv6,
                macAddress:  r.state?.hwaddr ?? "—",
                mtu:         r.state?.mtu ?? 1500,
                speed:       r.state?.speed,
                dhcp:        false,
                inBytes:     r.state?.rx_bytes ?? 0,
                outBytes:    r.state?.tx_bytes ?? 0,
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
        let r = try await get("/api/v2.0/network/configuration", as: Raw.self)
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
        struct Raw: Decodable { let id: Int; let destination: String; let gateway: String; let description: String }
        return try await get("/api/v2.0/staticroute", as: [Raw].self)
            .map { StaticRoute(id: $0.id, destination: $0.destination, gateway: $0.gateway, description: $0.description) }
    }
}

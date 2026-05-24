import Foundation
import SwiftUI

// MARK: - Interface Type
enum InterfaceType: String, Decodable {
    case physical = "PHYSICAL"
    case vlan     = "VLAN"
    case bridge   = "BRIDGE"
    case lag      = "LINK_AGGREGATION"
    case unknown  = "UNKNOWN"

    var label: String {
        switch self {
        case .physical: return "Physical"
        case .vlan:     return "VLAN"
        case .bridge:   return "Bridge"
        case .lag:      return "LAG"
        case .unknown:  return "Unknown"
        }
    }

    var icon: String {
        switch self {
        case .physical: return "cable.connector"
        case .vlan:     return "tag.fill"
        case .bridge:   return "arrow.triangle.branch"
        case .lag:      return "link"
        case .unknown:  return "questionmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .physical: return .blue
        case .vlan:     return .purple
        case .bridge:   return .orange
        case .lag:      return .teal
        case .unknown:  return .secondary
        }
    }
}

// MARK: - Traffic Sample (for sparkline)
struct TrafficSample: Identifiable {
    let id = UUID()
    let time: Date
    let inBytes: Double    // bytes/sec
    let outBytes: Double   // bytes/sec
}

// MARK: - Network Interface
struct NetworkInterface: Identifiable {
    let id: String           // e.g. "eno1"
    let name: String
    let type: InterfaceType
    var linkState: Bool      // true = up
    var ipv4Addresses: [String]
    var ipv6Addresses: [String]
    var macAddress: String
    var mtu: Int
    var speed: Int?          // Mbps
    var dhcp: Bool
    var inBytes: Int64       // total bytes received
    var outBytes: Int64      // total bytes sent
    var inBytesPerSec: Double
    var outBytesPerSec: Double
    var trafficHistory: [TrafficSample]

    var primaryIP: String { ipv4Addresses.first ?? ipv6Addresses.first ?? "—" }
    var speedLabel: String { speed.map { "\($0) Mbps" } ?? "—" }

    var inMbps:  Double { inBytesPerSec  * 8 / 1_000_000 }
    var outMbps: Double { outBytesPerSec * 8 / 1_000_000 }
}

// MARK: - Network Global Config
struct NetworkConfig {
    var hostname: String
    var domain: String
    var ipv4Gateway: String
    var ipv6Gateway: String
    var nameservers: [String]
    var httpProxy: String
    var outboundInterface: String
}

// MARK: - Static Route
struct StaticRoute: Identifiable {
    let id: Int
    let destination: String
    let gateway: String
    let description: String
}

import Foundation
import SwiftUI

// MARK: - SMB Share
struct SMBShare: Identifiable {
    let id: Int
    let name: String
    let path: String
    var enabled: Bool
    var comment: String
    var readOnly: Bool
    var browsable: Bool
    var guestOk: Bool
}

// MARK: - NFS Share
struct NFSShare: Identifiable {
    let id: Int
    let path: String
    var enabled: Bool
    var comment: String
    var networks: [String]   // e.g. ["192.168.1.0/24"]
    var hosts: [String]
    var mapallUser: String
    var mapallGroup: String
    var readOnly: Bool
    var alldirs: Bool

    var networksDisplay: String {
        networks.isEmpty ? (hosts.isEmpty ? "Everyone" : hosts.joined(separator: ", "))
                         : networks.joined(separator: ", ")
    }
}

// MARK: - iSCSI Target
struct ISCSITarget: Identifiable {
    let id: Int
    let name: String
    let iqn: String          // e.g. "iqn.2005-10.org.freenas.ctl:target1"
    let alias: String
    var mode: String         // iSCSI, FC, or Both
    var groups: [ISCSITargetGroup]
}

struct ISCSITargetGroup: Identifiable {
    let id: Int
    let portal: Int
    let initiator: Int?
    let authType: String     // None, CHAP, Mutual CHAP
}

// MARK: - iSCSI Extent
struct ISCSIExtent: Identifiable {
    let id: Int
    let name: String
    let type: String         // DISK or FILE
    let path: String
    let size: Int64
    var enabled: Bool

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .binary)
    }
}

// MARK: - iSCSI Initiator
struct ISCSIInitiator: Identifiable {
    let id: Int
    let comment: String
    var initiators: [String]
    var authorizedNetworks: [String]
}

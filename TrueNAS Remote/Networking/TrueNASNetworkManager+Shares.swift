import Foundation

extension TrueNASNetworkManager {

    // MARK: - SMB
    func fetchSMBShares() async throws -> [SMBShare] {
        struct Raw: Decodable {
            let id: Int; let name: String; let path: String
            let enabled: Bool?; let comment: String?
            let ro: Bool?; let browsable: Bool?
            let options: Options?
            let guestok: Bool?          // fallback for older API versions
            struct Options: Decodable { let guestok: Bool? }
        }
        return try await call(method: "sharing.smb.query", as: [Raw].self).map {
            SMBShare(id: $0.id, name: $0.name, path: $0.path,
                     enabled: $0.enabled ?? true, comment: $0.comment ?? "",
                     readOnly: $0.ro ?? false, browsable: $0.browsable ?? true,
                     guestOk: $0.options?.guestok ?? $0.guestok ?? false)
        }
    }

    func toggleSMBShare(id: Int, enabled: Bool) async throws {
        // params: [id, update_dict]
        let params = try JSONSerialization.data(withJSONObject: [id, ["enabled": enabled]] as [Any])
        try await call(method: "sharing.smb.update", params: params)
    }

    // MARK: - NFS
    func fetchNFSShares() async throws -> [NFSShare] {
        struct Raw: Decodable {
            let id: Int; let path: String; let enabled: Bool?; let comment: String?
            let networks: [String]?; let hosts: [String]?
            let mapallUser: String?; let mapallGroup: String?
            let ro: Bool?; let alldirs: Bool?
        }
        return try await call(method: "sharing.nfs.query", as: [Raw].self).map {
            NFSShare(id: $0.id, path: $0.path, enabled: $0.enabled ?? true,
                     comment: $0.comment ?? "", networks: $0.networks ?? [],
                     hosts: $0.hosts ?? [], mapallUser: $0.mapallUser ?? "",
                     mapallGroup: $0.mapallGroup ?? "", readOnly: $0.ro ?? false,
                     alldirs: $0.alldirs ?? false)
        }
    }

    // MARK: - iSCSI
    func fetchISCSITargets() async throws -> [ISCSITarget] {
        struct Raw: Decodable {
            let id: Int; let name: String; let alias: String?; let mode: String?
        }
        return try await call(method: "iscsi.target.query", as: [Raw].self).map {
            ISCSITarget(id: $0.id, name: $0.name,
                        iqn: "iqn.2005-10.org.freenas.ctl:\($0.name)",
                        alias: $0.alias ?? "",
                        mode: $0.mode ?? "ISCSI", groups: [])
        }
    }

    func fetchISCSIExtents() async throws -> [ISCSIExtent] {
        struct Raw: Decodable {
            let id: Int; let name: String; let type: String?
            let path: String?; let filesize: Int64?; let enabled: Bool?
        }
        return try await call(method: "iscsi.extent.query", as: [Raw].self).map {
            ISCSIExtent(id: $0.id, name: $0.name, type: $0.type ?? "DISK",
                        path: $0.path ?? "", size: $0.filesize ?? 0,
                        enabled: $0.enabled ?? true)
        }
    }
}

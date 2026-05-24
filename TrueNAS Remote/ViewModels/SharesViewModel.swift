import Foundation
import Observation

@Observable
class SharesViewModel {
    var smbShares    : [SMBShare]     = []
    var nfsShares    : [NFSShare]     = []
    var iscsiTargets : [ISCSITarget]  = []
    var iscsiExtents : [ISCSIExtent]  = []
    var isLoading    = false
    var errorMessage : String?

    private let network = TrueNASNetworkManager.shared

    init() { loadMockData() }

    func refresh() async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            async let s = network.fetchSMBShares()
            async let n = network.fetchNFSShares()
            async let t = network.fetchISCSITargets()
            async let e = network.fetchISCSIExtents()
            smbShares    = try await s
            nfsShares    = try await n
            iscsiTargets = try await t
            iscsiExtents = try await e
        } catch { errorMessage = error.localizedDescription }
    }

    func toggleSMB(share: SMBShare) async {
        do {
            try await network.toggleSMBShare(id: share.id, enabled: !share.enabled)
            if let i = smbShares.firstIndex(where: { $0.id == share.id }) {
                smbShares[i] = SMBShare(id: share.id, name: share.name, path: share.path,
                                        enabled: !share.enabled, comment: share.comment,
                                        readOnly: share.readOnly, browsable: share.browsable,
                                        guestOk: share.guestOk)
            }
        } catch { errorMessage = error.localizedDescription }
    }

    private func loadMockData() {
        smbShares = [
            SMBShare(id: 1, name: "Media",     path: "/mnt/tank/media",     enabled: true,  comment: "Plex media library", readOnly: false, browsable: true,  guestOk: false),
            SMBShare(id: 2, name: "Documents", path: "/mnt/tank/documents", enabled: true,  comment: "Encrypted docs",     readOnly: false, browsable: false, guestOk: false),
            SMBShare(id: 3, name: "Public",    path: "/mnt/tank/public",    enabled: false, comment: "Guest share",        readOnly: false, browsable: true,  guestOk: true),
            SMBShare(id: 4, name: "Backups",   path: "/mnt/backup",         enabled: true,  comment: "Machine backups",    readOnly: false, browsable: false, guestOk: false)
        ]
        nfsShares = [
            NFSShare(id: 1, path: "/mnt/tank/media", enabled: true, comment: "Media NFS",
                     networks: ["192.168.1.0/24"], hosts: [], mapallUser: "", mapallGroup: "", readOnly: true, alldirs: false),
            NFSShare(id: 2, path: "/mnt/tank/vm-data", enabled: true, comment: "VM data",
                     networks: ["10.0.0.0/24"], hosts: [], mapallUser: "root", mapallGroup: "wheel", readOnly: false, alldirs: true)
        ]
        iscsiTargets = [
            ISCSITarget(id: 1, name: "vmware-target", iqn: "iqn.2005-10.org.freenas.ctl:vmware-target",
                        alias: "VMware LUN", mode: "ISCSI", groups: [])
        ]
        iscsiExtents = [
            ISCSIExtent(id: 1, name: "vmware-lun0", type: "DISK", path: "/mnt/tank/vm-data",
                        size: 500 * 1024 * 1024 * 1024, enabled: true)
        ]
    }
}

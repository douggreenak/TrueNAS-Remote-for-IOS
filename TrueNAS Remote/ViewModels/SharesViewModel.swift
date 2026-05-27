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

}

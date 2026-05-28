import Foundation
import Observation

@Observable
class SystemViewModel {
    var alerts          : [TrueNASAlert]     = []
    var bootEnvironments: [BootEnvironment]  = []
    var users           : [TrueNASUser]      = []
    var groups          : [TrueNASGroup]     = []
    var certificates    : [Certificate]      = []
    var auditLog        : [AuditEntry]       = []
    var isLoading       = false
    var errorMessage    : String?

    var activeAlerts: [TrueNASAlert] { alerts.filter { !$0.dismissed }.sorted { $0.level.sortPriority < $1.level.sortPriority } }
    var criticalCount: Int { activeAlerts.filter { $0.level == .critical || $0.level == .error }.count }

    private let network = TrueNASNetworkManager.shared

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true; errorMessage = nil
        defer { isLoading = false }

        // Core data — failure shows an error banner
        do {
            async let a = network.fetchAlerts()
            async let u = network.fetchUsers()
            async let g = network.fetchGroups()
            async let c = network.fetchCertificates()
            alerts        = try await a
            users         = try await u
            groups        = try await g
            certificates  = try await c
        } catch { errorMessage = error.localizedDescription }

        // Best-effort — silently empty on failure (bootenv 404 on 25.x; audit may vary)
        bootEnvironments = (try? await network.fetchBootEnvironments()) ?? []
        auditLog         = (try? await network.fetchAuditLog())         ?? []
    }

    func dismissAlert(_ alert: TrueNASAlert) async {
        do {
            try await network.dismissAlert(uuid: alert.id)
            if let i = alerts.firstIndex(where: { $0.id == alert.id }) {
                alerts[i] = TrueNASAlert(id: alert.id, level: alert.level, message: alert.message,
                                          source: alert.source, timestamp: alert.timestamp, dismissed: true)
            }
        } catch { errorMessage = error.localizedDescription }
    }

    func activateBootEnv(_ env: BootEnvironment) async {
        do {
            try await network.activateBootEnvironment(id: env.id)
            for i in bootEnvironments.indices {
                let e = bootEnvironments[i]
                bootEnvironments[i] = BootEnvironment(id: e.id, name: e.name, created: e.created,
                                                       size: e.size, active: e.id == env.id,
                                                       keepForever: e.keepForever)
            }
        } catch { errorMessage = error.localizedDescription }
    }

}

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

    init() { loadMockData() }

    func refresh() async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            async let a = network.fetchAlerts()
            async let b = network.fetchBootEnvironments()
            async let u = network.fetchUsers()
            async let g = network.fetchGroups()
            async let c = network.fetchCertificates()
            async let l = network.fetchAuditLog()
            alerts           = try await a
            bootEnvironments = try await b
            users            = try await u
            groups           = try await g
            certificates     = try await c
            auditLog         = try await l
        } catch { errorMessage = error.localizedDescription }
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

    private func loadMockData() {
        alerts = [
            TrueNASAlert(id: "a1", level: .critical, message: "Pool vm-storage is DEGRADED. Investigate immediately.",
                          source: "STORAGE", timestamp: Date().addingTimeInterval(-3600), dismissed: false),
            TrueNASAlert(id: "a2", level: .warning, message: "Disk sdg has 2 checksum errors. Run a scrub.",
                          source: "STORAGE", timestamp: Date().addingTimeInterval(-7200), dismissed: false),
            TrueNASAlert(id: "a3", level: .warning, message: "Certificate 'truenas-cert' expires in 28 days.",
                          source: "CERTIFICATES", timestamp: Date().addingTimeInterval(-86400), dismissed: false),
            TrueNASAlert(id: "a4", level: .info, message: "Replication task 'documents backup' failed.",
                          source: "REPLICATION", timestamp: Date().addingTimeInterval(-21600), dismissed: false),
            TrueNASAlert(id: "a5", level: .info, message: "Update TrueNAS-SCALE-24.10.3 is available.",
                          source: "UPDATE", timestamp: Date().addingTimeInterval(-43200), dismissed: true)
        ]

        bootEnvironments = [
            BootEnvironment(id: "default",  name: "Initial-Install",  created: Date().addingTimeInterval(-86400 * 180), size: 4_294_967_296, active: false, keepForever: true),
            BootEnvironment(id: "24.10.1",  name: "24.10.1-upgrade",  created: Date().addingTimeInterval(-86400 * 30),  size: 4_831_838_208, active: false, keepForever: false),
            BootEnvironment(id: "24.10.2",  name: "24.10.2-current",  created: Date().addingTimeInterval(-86400 * 7),   size: 4_925_820_928, active: true,  keepForever: false)
        ]

        users = [
            TrueNASUser(id: 0,    username: "root",   fullName: "Root",       email: "admin@truenas.local", shell: "/usr/bin/zsh", homeDir: "/root",      locked: false, sudoEnabled: true,  groups: [0],   builtIn: true),
            TrueNASUser(id: 1000, username: "doug",   fullName: "Doug Green", email: "doug@example.com",    shell: "/bin/bash",    homeDir: "/home/doug", locked: false, sudoEnabled: true,  groups: [1000, 1001], builtIn: false),
            TrueNASUser(id: 1001, username: "media",  fullName: "Media User", email: "",                    shell: "/usr/sbin/nologin", homeDir: "/nonexistent", locked: true, sudoEnabled: false, groups: [1002], builtIn: false)
        ]

        groups = [
            TrueNASGroup(id: 0,    name: "wheel",     users: ["root", "doug"], builtIn: true,  sudoEnabled: true),
            TrueNASGroup(id: 1000, name: "doug",      users: ["doug"],          builtIn: false, sudoEnabled: false),
            TrueNASGroup(id: 1001, name: "admin",     users: ["doug"],          builtIn: false, sudoEnabled: false),
            TrueNASGroup(id: 1002, name: "media",     users: ["media"],         builtIn: false, sudoEnabled: false)
        ]

        let now = Date()
        certificates = [
            Certificate(id: 1, name: "truenas-cert", commonName: "truenas.local",
                        issuer: "self-signed", san: ["truenas.local", "192.168.1.100"],
                        from: now.addingTimeInterval(-86400 * 337), until: now.addingTimeInterval(86400 * 28),
                        keyType: "RSA", keyLength: 4096),
            Certificate(id: 2, name: "plex-cert", commonName: "plex.example.com",
                        issuer: "Let's Encrypt", san: ["plex.example.com"],
                        from: now.addingTimeInterval(-86400 * 60), until: now.addingTimeInterval(86400 * 30),
                        keyType: "EC", keyLength: 256)
        ]

        auditLog = (0..<20).map { i in
            let events = [("AUTHENTICATION", true), ("CONNECT", true), ("AUTHENTICATION", false), ("DISCONNECT", true), ("CREATE", true)]
            let services = ["MIDDLEWARE", "SMB", "NFS", "SSH", "SUDO"]
            let users = ["root", "doug", "media"]
            let (event, success) = events[i % events.count]
            return AuditEntry(
                id:        "audit-\(i)",
                timestamp: now.addingTimeInterval(-Double(i) * 1800),
                username:  users[i % users.count],
                service:   services[i % services.count],
                event:     event,
                success:   success,
                address:   "192.168.1.\(100 + (i % 50))",
                detail:    [:]
            )
        }
    }
}

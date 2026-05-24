import Foundation
import Observation

@Observable
class ServicesViewModel {
    var services    : [SystemService]  = []
    var vms         : [VirtualMachine] = []
    var apps        : [InstalledApp]   = []
    var isLoading   = false
    var errorMessage: String?
    var actionError : String?

    private let network = TrueNASNetworkManager.shared

    init() { loadMockData() }

    func refresh() async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            async let s = network.fetchServices()
            async let v = network.fetchVMs()
            async let a = network.fetchApps()
            services = try await s
            vms      = try await v
            apps     = try await a
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Service Control
    func controlService(_ service: SystemService, action: String) async {
        actionError = nil
        do {
            try await network.controlService(name: service.name, action: action)
            let newState: ServiceState = action == "stop" ? .stopped : .running
            if let i = services.firstIndex(where: { $0.id == service.id }) {
                services[i] = SystemService(id: service.id, name: service.name,
                                            displayName: service.displayName,
                                            state: newState, startOnBoot: service.startOnBoot)
            }
        } catch { actionError = error.localizedDescription }
    }

    func controlVM(_ vm: VirtualMachine, action: String) async {
        actionError = nil
        do {
            try await network.controlVM(id: vm.id, action: action)
            let newState: VMState = action == "stop" ? .stopped : .running
            if let i = vms.firstIndex(where: { $0.id == vm.id }) {
                vms[i] = VirtualMachine(id: vm.id, name: vm.name, status: newState,
                                        cpuCount: vm.cpuCount, memoryMB: vm.memoryMB,
                                        description: vm.description, uptime: nil, pid: nil)
            }
        } catch { actionError = error.localizedDescription }
    }

    func controlApp(_ app: InstalledApp, action: String) async {
        actionError = nil
        do {
            try await network.controlApp(id: app.id, action: action)
            let newStatus: AppStatus = action == "stop" ? .stopped : .running
            if let i = apps.firstIndex(where: { $0.id == app.id }) {
                apps[i] = InstalledApp(id: app.id, name: app.name, version: app.version,
                                       status: newStatus, updateAvailable: app.updateAvailable,
                                       latestVersion: app.latestVersion, description: app.description,
                                       catalog: app.catalog, metadata: nil)
            }
        } catch { actionError = error.localizedDescription }
    }

    // MARK: - Mock Data
    private func loadMockData() {
        services = [
            SystemService(id: 1,  name: "cifs",        displayName: "SMB",       state: .running, startOnBoot: true),
            SystemService(id: 2,  name: "nfs",         displayName: "NFS",       state: .stopped, startOnBoot: false),
            SystemService(id: 3,  name: "ssh",         displayName: "SSH",       state: .running, startOnBoot: true),
            SystemService(id: 4,  name: "ftp",         displayName: "FTP",       state: .stopped, startOnBoot: false),
            SystemService(id: 5,  name: "iscsitarget", displayName: "iSCSI",     state: .running, startOnBoot: true),
            SystemService(id: 6,  name: "smart",       displayName: "S.M.A.R.T.",state: .running, startOnBoot: true),
            SystemService(id: 7,  name: "snmp",        displayName: "SNMP",      state: .stopped, startOnBoot: false),
            SystemService(id: 8,  name: "ups",         displayName: "UPS",       state: .stopped, startOnBoot: false),
            SystemService(id: 9,  name: "rsyncd",      displayName: "Rsyncd",    state: .stopped, startOnBoot: false),
            SystemService(id: 10, name: "lldp",        displayName: "LLDP",      state: .running, startOnBoot: true)
        ]
        vms = [
            VirtualMachine(id: 1, name: "Ubuntu 22.04 LTS", status: .stopped, cpuCount: 4, memoryMB: 4096, description: "Dev environment", uptime: nil, pid: nil),
            VirtualMachine(id: 2, name: "Windows 11 Pro",   status: .running, cpuCount: 8, memoryMB: 16384, description: "Gaming VM", uptime: 3600 * 5 + 300, pid: 12345),
            VirtualMachine(id: 3, name: "pfSense 2.7",      status: .running, cpuCount: 2, memoryMB: 1024,  description: "Router/Firewall", uptime: 86400 * 30, pid: 12346)
        ]
        apps = [
            InstalledApp(id: "plex",       name: "Plex Media Server", version: "1.32.8", status: .running,  updateAvailable: false, latestVersion: nil, description: "Media server", catalog: "TRUENAS", metadata: nil),
            InstalledApp(id: "nextcloud",  name: "Nextcloud",         version: "27.1.0", status: .stopped,  updateAvailable: true,  latestVersion: "28.0.0", description: "Cloud storage", catalog: "TRUENAS", metadata: nil),
            InstalledApp(id: "jellyfin",   name: "Jellyfin",          version: "10.8.13",status: .running,  updateAvailable: false, latestVersion: nil, description: "Open-source media", catalog: "TRUENAS", metadata: nil),
            InstalledApp(id: "portainer",  name: "Portainer CE",      version: "2.19.4", status: .deploying,updateAvailable: false, latestVersion: nil, description: "Container management", catalog: "TRUENAS", metadata: nil),
            InstalledApp(id: "homeassist", name: "Home Assistant",    version: "2024.1",  status: .running,  updateAvailable: true,  latestVersion: "2024.3", description: "Home automation", catalog: "TRUENAS", metadata: nil)
        ]
    }
}

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

}

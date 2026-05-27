import Foundation

extension TrueNASNetworkManager {

    // MARK: - System Services
    func fetchServices() async throws -> [SystemService] {
        struct Raw: Decodable {
            let id: Int; let service: String; let state: String; let enable: Bool
        }
        return try await call(method: "service.query", as: [Raw].self).map {
            SystemService(id: $0.id,
                          name: $0.service,
                          displayName: SystemService.wellKnown[$0.service]
                              ?? $0.service.replacingOccurrences(of: "_", with: " ").capitalized,
                          state: ServiceState(rawValue: $0.state) ?? .unknown,
                          startOnBoot: $0.enable)
        }
    }

    func controlService(name: String, action: String) async throws {
        // params: [service_name]
        let params = try JSONSerialization.data(withJSONObject: [name])
        try await call(method: "service.\(action)", params: params)
    }

    // MARK: - Virtual Machines
    func fetchVMs() async throws -> [VirtualMachine] {
        struct Raw: Decodable {
            let id: Int; let name: String; let description: String?
            let vcpus: Int?; let memory: Int?   // memory is already in MB from the API
            let status: StatusRaw
            struct StatusRaw: Decodable { let state: String; let pid: Int? }
        }
        return try await call(method: "vm.query", as: [Raw].self).map {
            VirtualMachine(id: $0.id, name: $0.name,
                           status: VMState(rawValue: $0.status.state) ?? .unknown,
                           cpuCount: $0.vcpus ?? 1,
                           memoryMB: $0.memory ?? 512,   // already MB — do NOT divide
                           description: $0.description ?? "",
                           uptime: nil, pid: $0.status.pid)
        }
    }

    func controlVM(id: Int, action: String) async throws {
        // params: [vm_id]
        let params = try JSONSerialization.data(withJSONObject: [id])
        try await call(method: "vm.\(action)", params: params)
    }

    // MARK: - Apps
    func fetchApps() async throws -> [InstalledApp] {
        struct Raw: Decodable {
            let id: String; let name: String; let state: String?
            let humanVersion: String?; let upgradeAvailable: Bool?
            let metadata: MetaRaw?
            struct MetaRaw: Decodable {
                let description: String?
                let train: String?
                let icon: String?   // URL to app icon, e.g. https://media.sys.truenas.net/apps/…
            }
        }
        let raws = try await call(method: "app.query", as: [Raw].self)
        return raws.map { r in
            InstalledApp(id: r.id, name: r.name,
                         version: r.humanVersion ?? "—",
                         status: AppStatus(rawValue: r.state ?? "UNKNOWN") ?? .unknown,
                         updateAvailable: r.upgradeAvailable ?? false,
                         latestVersion: nil,
                         description: r.metadata?.description ?? "",
                         catalog: r.metadata?.train ?? "TRUENAS",
                         iconURL: r.metadata?.icon,
                         metadata: nil)
        }
    }

    func controlApp(id: String, action: String) async throws {
        // params: [app_id]
        let params = try JSONSerialization.data(withJSONObject: [id])
        try await call(method: "app.\(action)", params: params)
    }
}

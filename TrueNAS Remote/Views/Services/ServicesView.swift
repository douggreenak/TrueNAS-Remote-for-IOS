import SwiftUI

struct ServicesView: View {
    @Environment(ServicesViewModel.self)  private var vm
    @Environment(SettingsViewModel.self)  private var settings
    @State private var segment = 0   // 0=Services 1=VMs 2=Apps
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            Picker("Category", selection: $segment) {
                Text("Services").tag(0)
                Text("VMs").tag(1)
                Text("Apps").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal).padding(.vertical, 8)

            Group {
                switch segment {
                case 0: servicesList
                case 1: vmList
                default: appsList
                }
            }
        }
        .navigationTitle("Services")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if vm.isLoading { ProgressView().controlSize(.small) }
            }
        }
        .task(id: settings.refreshInterval) {
            await vm.refresh()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(settings.refreshInterval))
                await vm.refresh()
            }
        }
        .alert("Error", isPresented: .constant(vm.actionError != nil)) {
            Button("OK") { vm.actionError = nil }
        } message: { Text(vm.actionError ?? "") }
    }

    // MARK: - Services List
    private var filteredServices: [SystemService] {
        searchText.isEmpty ? vm.services :
        vm.services.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) ||
                              $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var servicesList: some View {
        List {
            let running = filteredServices.filter { $0.state == .running }
            let stopped = filteredServices.filter { $0.state != .running }
            if !running.isEmpty {
                Section("Running (\(running.count))") {
                    ForEach(running) { svc in
                        ServiceRow(service: svc) { action in
                            Task { await vm.controlService(svc, action: action) }
                        }
                    }
                }
            }
            if !stopped.isEmpty {
                Section("Stopped (\(stopped.count))") {
                    ForEach(stopped) { svc in
                        ServiceRow(service: svc) { action in
                            Task { await vm.controlService(svc, action: action) }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await vm.refresh() }
        .searchable(text: $searchText, prompt: "Search services…")
    }

    // MARK: - VMs List
    private var vmList: some View {
        Group {
            if vm.isLoading && vm.vms.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.vms.isEmpty {
                ContentUnavailableView("No Virtual Machines",
                    systemImage: "desktopcomputer",
                    description: Text("No VMs configured."))
            } else {
                List(vm.vms) { vm_ in
                    VMRow(vm: vm_) { action in
                        Task { await vm.controlVM(vm_, action: action) }
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable { await vm.refresh() }
            }
        }
    }

    // MARK: - Apps List
    private var appsList: some View {
        Group {
            if vm.isLoading && vm.apps.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.apps.isEmpty {
                ContentUnavailableView("No Apps",
                    systemImage: "square.grid.2x2",
                    description: Text("No apps installed."))
            } else {
                List(vm.apps) { app in
                    AppRow(app: app) { action in
                        Task { await vm.controlApp(app, action: action) }
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable { await vm.refresh() }
            }
        }
    }
}

// MARK: - Service Row
private struct ServiceRow: View {
    let service: SystemService
    let action: (String) -> Void

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(service.state.color)
                .frame(width: 8, height: 8)
                .shadow(color: service.state.color.opacity(0.6), radius: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(service.displayName).font(.body.weight(.medium))
                HStack(spacing: 6) {
                    Text(service.state.label)
                        .font(.caption)
                        .foregroundStyle(service.state == .running ? Color.green : Color.secondary)
                    if service.startOnBoot {
                        Label("Auto-start", systemImage: "bolt.fill")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            controlMenu
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if service.state != .running {
                Button { action("start") } label: { Label("Start", systemImage: "play.fill") }
                    .tint(.green)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if service.state == .running {
                Button(role: .destructive) { action("stop") } label: { Label("Stop", systemImage: "stop.fill") }
                    .tint(.red)
            }
        }
    }

    private var controlMenu: some View {
        Menu {
            if service.state != .running {
                Button { action("start") } label: { Label("Start", systemImage: "play.fill") }
            }
            if service.state == .running {
                Button { action("stop") } label: { Label("Stop", systemImage: "stop.fill") }
                Button { action("restart") } label: { Label("Restart", systemImage: "arrow.clockwise") }
            }
        } label: {
            Image(systemName: "ellipsis.circle").font(.title3).foregroundStyle(.secondary)
        }
    }
}

// MARK: - VM Row
private struct VMRow: View {
    let vm: VirtualMachine
    let action: (String) -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(vm.status.color.opacity(0.12))
                    .frame(width: 34, height: 34)
                Image(systemName: vm.status.icon)
                    .foregroundStyle(vm.status.color)
                    .font(.system(size: 16))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(vm.name).font(.body.weight(.medium))
                HStack(spacing: 8) {
                    Label("\(vm.cpuCount) vCPU", systemImage: "cpu")
                        .font(.caption).foregroundStyle(.secondary)
                    Label(vm.formattedMemory, systemImage: "memorychip")
                        .font(.caption).foregroundStyle(.secondary)
                    if vm.status.isRunning {
                        Text(vm.formattedUptime)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.green)
                    }
                }
            }
            Spacer()
            controlMenu
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .leading) {
            Button { action("start") } label: { Label("Start", systemImage: "play.fill") }.tint(.green)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { action("stop") } label: { Label("Stop", systemImage: "stop.fill") }.tint(.red)
        }
    }

    private var controlMenu: some View {
        Menu {
            if !vm.status.isRunning {
                Button { action("start") } label: { Label("Start", systemImage: "play.fill") }
            }
            if vm.status.isRunning {
                Button { action("stop")    } label: { Label("Stop",    systemImage: "stop.fill") }
                Button { action("restart") } label: { Label("Restart", systemImage: "arrow.clockwise") }
            }
        } label: {
            Image(systemName: "ellipsis.circle").font(.title3).foregroundStyle(.secondary)
        }
    }
}

// MARK: - App Row
private struct AppRow: View {
    let app: InstalledApp
    let action: (String) -> Void

    var body: some View {
        HStack(spacing: 14) {
            appIcon
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(app.name).font(.body.weight(.medium))
                    if app.updateAvailable {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundStyle(.blue).font(.caption)
                    }
                }
                HStack(spacing: 8) {
                    Text("v\(app.version)").font(.caption).foregroundStyle(.secondary)
                    Circle().fill(app.status.color).frame(width: 6, height: 6)
                    Text(app.status.label).font(.caption).foregroundStyle(app.status.color)
                }
            }
            Spacer()
            controlMenu
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var appIcon: some View {
        if let urlString = app.iconURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit()
                        .frame(width: 38, height: 38)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                case .failure, .empty:
                    fallbackIcon
                @unknown default:
                    fallbackIcon
                }
            }
        } else {
            fallbackIcon
        }
    }

    private var fallbackIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.15))
            Image(systemName: "app.fill").foregroundStyle(Color.accentColor)
        }
        .frame(width: 38, height: 38)
    }

    private var controlMenu: some View {
        Menu {
            Button { action("start") } label: { Label("Start", systemImage: "play.fill") }
                .disabled(app.status == .running)
            Button { action("stop")  } label: { Label("Stop",  systemImage: "stop.fill") }
                .disabled(app.status == .stopped)
            if app.updateAvailable {
                Button { action("upgrade") } label: { Label("Upgrade", systemImage: "arrow.up.circle") }
            }
        } label: {
            Image(systemName: "ellipsis.circle").font(.title3).foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ServicesView()
        .environment(ServicesViewModel())
        .environment(SettingsViewModel())
}

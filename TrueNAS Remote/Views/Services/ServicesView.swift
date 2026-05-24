import SwiftUI

struct ServicesView: View {
    @Environment(ServicesViewModel.self)  private var vm
    @Environment(SettingsViewModel.self)  private var settings
    @State private var segment = 0   // 0=Services 1=VMs 2=Apps

    var body: some View {
        NavigationStack {
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
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if vm.isLoading { ProgressView() }
                    else { Button("", systemImage: "arrow.clockwise") { Task { await vm.refresh() } } }
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
    }

    // MARK: - Services List
    private var servicesList: some View {
        List(vm.services) { svc in
            ServiceRow(service: svc) { action in
                Task { await vm.controlService(svc, action: action) }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await vm.refresh() }
    }

    // MARK: - VMs List
    private var vmList: some View {
        List(vm.vms) { vm_ in
            VMRow(vm: vm_) { action in
                Task { await vm.controlVM(vm_, action: action) }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Apps List
    private var appsList: some View {
        List(vm.apps) { app in
            AppRow(app: app) { action in
                Task { await vm.controlApp(app, action: action) }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Service Row
private struct ServiceRow: View {
    let service: SystemService
    let action: (String) -> Void

    var body: some View {
        HStack(spacing: 14) {
            Circle().fill(service.state.color).frame(width: 10, height: 10)
                .shadow(color: service.state.color.opacity(0.5), radius: 3)
            VStack(alignment: .leading, spacing: 2) {
                Text(service.displayName).font(.body.weight(.medium))
                HStack(spacing: 6) {
                    Text(service.state.label).font(.caption).foregroundStyle(.secondary)
                    if service.startOnBoot {
                        Label("Boot", systemImage: "bolt.fill")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            controlMenu
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button { action("start") } label: { Label("Start", systemImage: "play.fill") }
                .tint(.green).disabled(service.state == .running)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { action("stop") } label: { Label("Stop", systemImage: "stop.fill") }
                .tint(.red).disabled(service.state == .stopped)
        }
    }

    private var controlMenu: some View {
        Menu {
            Button { action("start")   } label: { Label("Start",   systemImage: "play.fill") }
                .disabled(service.state == .running)
            Button { action("stop")    } label: { Label("Stop",    systemImage: "stop.fill") }
                .disabled(service.state == .stopped)
            Button { action("restart") } label: { Label("Restart", systemImage: "arrow.clockwise") }
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
            Image(systemName: vm.status.icon).foregroundStyle(vm.status.color)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(vm.name).font(.body.weight(.medium))
                HStack(spacing: 8) {
                    Label("\(vm.cpuCount) vCPU", systemImage: "cpu")
                        .font(.caption).foregroundStyle(.secondary)
                    Label(vm.formattedMemory, systemImage: "memorychip")
                        .font(.caption).foregroundStyle(.secondary)
                    if vm.status.isRunning {
                        Text(vm.formattedUptime).font(.caption).foregroundStyle(.green)
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
            Button { action("start")   } label: { Label("Start",   systemImage: "play.fill") }
                .disabled(vm.status.isRunning)
            Button { action("stop")    } label: { Label("Stop",    systemImage: "stop.fill") }
                .disabled(!vm.status.isRunning)
            Button { action("restart") } label: { Label("Restart", systemImage: "arrow.clockwise") }
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
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.15))
                Image(systemName: "app.fill").foregroundStyle(Color.accentColor)
            }
            .frame(width: 38, height: 38)
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

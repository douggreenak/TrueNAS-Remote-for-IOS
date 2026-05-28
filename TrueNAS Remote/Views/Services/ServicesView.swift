import SwiftUI

struct ServicesView: View {
    @Environment(ServicesViewModel.self)  private var vm
    @Environment(SettingsViewModel.self)  private var settings
    @State private var segment = 0   // 0=Apps 1=Services 2=VMs
    @State private var searchText = ""

    // Apps tab is first (most commonly used feature in TrueNAS)
    private let tabs: [(label: String, icon: String)] = [
        ("Apps",     "square.grid.2x2.fill"),
        ("Services", "gearshape.fill"),
        ("VMs",      "desktopcomputer"),
    ]
    @Namespace private var tabNS

    var body: some View {
        tabContent
            .animation(.none, value: segment)   // instant content switch – no flicker
            .pageLoading(vm.isLoading && vm.services.isEmpty && vm.vms.isEmpty && vm.apps.isEmpty)
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    tabBar
                    // Search bar only visible on the Services tab
                    if segment == 1 {
                        ServicesSearchBar(text: $searchText)
                    }
                    Divider()
                }
            }
            .navigationTitle("Services")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if vm.isLoading { ProgressView().controlSize(.small) }
                }
            }
            .task { await vm.refresh() }
            .alert("Error", isPresented: .constant(vm.actionError != nil)) {
                Button("OK") { vm.actionError = nil }
            } message: { Text(vm.actionError ?? "") }
            .onChange(of: segment) { _, _ in searchText = "" }
    }

    @ViewBuilder private var tabContent: some View {
        switch segment {
        case 0: appsList
        case 1: servicesList
        default: vmList
        }
    }

    // MARK: - Tab Bar
    private var tabBar: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(tabs.indices, id: \.self) { i in
                        Button { segment = i } label: {
                            VStack(spacing: 4) {
                                HStack(spacing: 5) {
                                    Image(systemName: tabs[i].icon).font(.caption2)
                                    Text(tabs[i].label)
                                        .font(.subheadline.weight(segment == i ? .semibold : .regular))
                                }
                                .foregroundStyle(segment == i ? .primary : .secondary)
                                .padding(.horizontal, 14).padding(.vertical, 8)

                                if segment == i {
                                    RoundedRectangle(cornerRadius: 2).fill(Color.accentColor)
                                        .frame(height: 3)
                                        .matchedGeometryEffect(id: "svcTab", in: tabNS)
                                } else {
                                    RoundedRectangle(cornerRadius: 2).fill(Color.clear).frame(height: 3)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .id(i)
                    }
                }
                .padding(.horizontal, 12)
                .animation(.spring(response: 0.3, dampingFraction: 0.75), value: segment)
            }
            .onChange(of: segment) { _, new in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    proxy.scrollTo(new, anchor: .center)
                }
            }
        }
        .padding(.vertical, 2)
        .background(.bar)
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
                    NavigationLink(destination: AppDetailView(app: app, vm: vm)) {
                        AppListRow(app: app)
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable { await vm.refresh() }
            }
        }
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
}

// MARK: - Search Bar Component
private struct ServicesSearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary).font(.subheadline)
            TextField("Search services…", text: $text)
                .autocorrectionDisabled().textInputAutocapitalization(.never)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(Color(.systemFill), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(.bar)
    }
}

// MARK: - App Icon helper (shared by list row and detail view)
struct AppIconView: View {
    let app: InstalledApp
    let cornerRadius: CGFloat

    var body: some View {
        if let urlString = app.iconURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                default:
                    fallback
                }
            }
        } else {
            fallback
        }
    }

    private var fallback: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius).fill(Color.accentColor.opacity(0.15))
            Image(systemName: "app.fill").foregroundStyle(Color.accentColor)
        }
    }
}

// MARK: - App List Row (compact)
struct AppListRow: View {
    let app: InstalledApp

    var body: some View {
        HStack(spacing: 14) {
            AppIconView(app: app, cornerRadius: 10)
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
        }
        .padding(.vertical, 2)
    }
}

// MARK: - App Detail View
struct AppDetailView: View {
    let app: InstalledApp
    let vm: ServicesViewModel
    @State private var pendingAction: String?
    @State private var showConfirm = false

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    AppIconView(app: app, cornerRadius: 14)
                        .frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(app.name).font(.title2.bold())
                        HStack(spacing: 6) {
                            Circle().fill(app.status.color).frame(width: 8, height: 8)
                            Text(app.status.label)
                                .font(.subheadline).foregroundStyle(app.status.color)
                        }
                        Text("Version \(app.version)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Controls") {
                if app.status != .running {
                    Button {
                        Task { await vm.controlApp(app, action: "start") }
                    } label: {
                        Label("Start App", systemImage: "play.fill")
                            .foregroundStyle(.green)
                    }
                }
                if app.status == .running {
                    Button {
                        pendingAction = "stop"; showConfirm = true
                    } label: {
                        Label("Stop App", systemImage: "stop.fill")
                            .foregroundStyle(.red)
                    }
                    Button {
                        pendingAction = "restart"; showConfirm = true
                    } label: {
                        Label("Restart App", systemImage: "arrow.clockwise")
                            .foregroundStyle(.orange)
                    }
                }
                if app.updateAvailable {
                    Button {
                        Task { await vm.controlApp(app, action: "upgrade") }
                    } label: {
                        Label("Upgrade Available", systemImage: "arrow.up.circle.fill")
                            .foregroundStyle(.blue)
                    }
                }
            }

            Section("Information") {
                LabeledContent("App ID", value: app.id)
                LabeledContent("Version", value: app.version)
                LabeledContent("Status", value: app.status.label)
                if app.updateAvailable {
                    HStack {
                        Text("Update")
                        Spacer()
                        Label("Available", systemImage: "arrow.up.circle.fill")
                            .foregroundStyle(.blue).font(.subheadline)
                    }
                }
            }
        }
        .navigationTitle(app.name)
        .toolbarTitleDisplayMode(.inline)
        .listStyle(.insetGrouped)
        .listSectionSpacing(.compact)
        .confirmationDialog(
            pendingAction == "stop" ? "Stop \(app.name)?" : "Restart \(app.name)?",
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            if let a = pendingAction {
                Button(a == "stop" ? "Stop App" : "Restart App",
                       role: a == "stop" ? .destructive : .none) {
                    Task { await vm.controlApp(app, action: a) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(pendingAction == "stop"
                 ? "Stopping \(app.name) will make its services unavailable."
                 : "Restarting \(app.name) will briefly interrupt its services.")
        }
    }
}

// MARK: - Service Row
private struct ServiceRow: View {
    let service: SystemService
    let action: (String) -> Void
    @State private var pendingAction: String?
    @State private var showConfirm = false

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
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if service.state == .running {
                Button(role: .destructive) {
                    pendingAction = "stop"; showConfirm = true
                } label: { Label("Stop", systemImage: "stop.fill") }
                Button {
                    pendingAction = "restart"; showConfirm = true
                } label: { Label("Restart", systemImage: "arrow.clockwise") }
                .tint(.orange)
            }
        }
        .confirmationDialog(
            pendingAction == "stop"
                ? "Stop \(service.displayName)?"
                : "Restart \(service.displayName)?",
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            if let a = pendingAction {
                Button(a == "stop" ? "Stop Service" : "Restart Service",
                       role: a == "stop" ? .destructive : .none) { action(a) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(pendingAction == "stop"
                 ? "Stopping \(service.displayName) may interrupt active connections."
                 : "Restarting \(service.displayName) will briefly interrupt active connections.")
        }
    }

    private var controlMenu: some View {
        Menu {
            if service.state != .running {
                Button { action("start") } label: { Label("Start", systemImage: "play.fill") }
            }
            if service.state == .running {
                Button { pendingAction = "stop"; showConfirm = true } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                Button { pendingAction = "restart"; showConfirm = true } label: {
                    Label("Restart", systemImage: "arrow.clockwise")
                }
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
    @State private var pendingAction: String?
    @State private var showConfirm = false

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
            Button(role: .destructive) {
                pendingAction = "stop"; showConfirm = true
            } label: { Label("Stop", systemImage: "stop.fill") }
        }
        .confirmationDialog(
            pendingAction == "stop" ? "Stop \(vm.name)?" : "Restart \(vm.name)?",
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            if let a = pendingAction {
                Button(a == "stop" ? "Stop VM" : "Restart VM",
                       role: a == "stop" ? .destructive : .none) { action(a) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var controlMenu: some View {
        Menu {
            if !vm.status.isRunning {
                Button { action("start") } label: { Label("Start", systemImage: "play.fill") }
            }
            if vm.status.isRunning {
                Button { pendingAction = "stop"; showConfirm = true } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                Button { pendingAction = "restart"; showConfirm = true } label: {
                    Label("Restart", systemImage: "arrow.clockwise")
                }
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

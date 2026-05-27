import SwiftUI

struct SystemView: View {
    @Environment(SystemViewModel.self)     private var vm
    @Environment(DashboardViewModel.self)  private var dashboard
    @Environment(SettingsViewModel.self)   private var settings
    @State private var segment = 0  // 0=Alerts 1=Boot 2=Users 3=Certs 4=Audit 5=Update

    private let tabs = ["Alerts", "Boot Envs", "Users", "Certs", "Audit", "Update"]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(tabs.indices, id: \.self) { i in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { segment = i }
                        } label: {
                            HStack(spacing: 4) {
                                Text(tabs[i])
                                    .font(.subheadline.weight(segment == i ? .semibold : .regular))
                                    .foregroundStyle(segment == i ? .primary : .secondary)
                                if i == 0 && vm.criticalCount > 0 {
                                    Text("\(vm.criticalCount)")
                                        .font(.caption2.bold())
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 5).padding(.vertical, 2)
                                        .background(Color.red, in: Capsule())
                                }
                                if i == 5 && dashboard.systemInfo.updateAvailable {
                                    Circle().fill(Color.blue).frame(width: 7, height: 7)
                                }
                            }
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(segment == i ? Color.accentColor.opacity(0.12) : Color.clear,
                                        in: Capsule())
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 4)

            Divider()

            Group {
                switch segment {
                case 0: alertsView
                case 1: bootEnvsView
                case 2: usersView
                case 3: certsView
                case 4: auditView
                default: updateView
                }
            }
        }
        .navigationTitle("System")
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
    }

    // MARK: - Alerts
    private var alertsView: some View {
        Group {
            if vm.isLoading && vm.alerts.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.alerts.isEmpty {
                ContentUnavailableView("No Alerts",
                    systemImage: "checkmark.circle.fill",
                    description: Text("System is healthy."))
            } else {
                List {
                    let active = vm.activeAlerts
                    if !active.isEmpty {
                        Section("Active (\(active.count))") {
                            ForEach(active) { alert in
                                AlertRow(alert: alert) {
                                    Task { await vm.dismissAlert(alert) }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button {
                                        Task { await vm.dismissAlert(alert) }
                                    } label: {
                                        Label("Dismiss", systemImage: "checkmark.circle")
                                    }
                                    .tint(.blue)
                                }
                            }
                        }
                    }
                    let dismissed = vm.alerts.filter { $0.dismissed }
                    if !dismissed.isEmpty {
                        Section("Dismissed") {
                            ForEach(dismissed) { alert in
                                AlertRow(alert: alert, onDismiss: nil)
                                    .opacity(0.5)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable { await vm.refresh() }
            }
        }
    }

    // MARK: - Boot Environments
    private var bootEnvsView: some View {
        Group {
            if vm.bootEnvironments.isEmpty {
                ContentUnavailableView("No Boot Environments",
                    systemImage: "externaldrive.badge.timemachine",
                    description: Text("No boot environments found."))
            } else {
                List(vm.bootEnvironments) { env in
                    BootEnvRow(env: env) {
                        Task { await vm.activateBootEnv(env) }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    // MARK: - Users & Groups
    private var usersView: some View {
        List {
            let regularUsers = vm.users.filter { !$0.builtIn }
            let builtinUsers = vm.users.filter { $0.builtIn }
            if !regularUsers.isEmpty {
                Section("Users (\(regularUsers.count))") {
                    ForEach(regularUsers) { user in
                        UserRow(user: user)
                    }
                }
            }
            if !builtinUsers.isEmpty {
                Section("Built-in Users (\(builtinUsers.count))") {
                    ForEach(builtinUsers) { user in
                        UserRow(user: user)
                    }
                }
            }
            let regularGroups = vm.groups.filter { !$0.builtIn }
            let builtinGroups = vm.groups.filter { $0.builtIn }
            if !regularGroups.isEmpty {
                Section("Groups (\(regularGroups.count))") {
                    ForEach(regularGroups) { group in
                        GroupRow(group: group)
                    }
                }
            }
            if !builtinGroups.isEmpty {
                Section("Built-in Groups (\(builtinGroups.count))") {
                    ForEach(builtinGroups) { group in
                        GroupRow(group: group)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Certificates
    private var certsView: some View {
        Group {
            if vm.certificates.isEmpty {
                ContentUnavailableView("No Certificates",
                    systemImage: "lock.shield",
                    description: Text("No certificates installed."))
            } else {
                List(vm.certificates) { cert in
                    CertRow(cert: cert)
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    // MARK: - Audit Log
    private var auditView: some View {
        AuditLogView(entries: vm.auditLog)
    }

    // MARK: - Update
    private var updateView: some View {
        List {
            Section("Current Installation") {
                LabeledContent("Version", value: dashboard.systemInfo.version)
                LabeledContent("Hostname", value: dashboard.systemInfo.hostname)
                LabeledContent("Platform", value: dashboard.systemInfo.platform)
                LabeledContent("Serial", value: dashboard.systemInfo.serialNumber)
            }

            Section("Update Status") {
                if dashboard.systemInfo.updateAvailable {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundStyle(.blue).font(.title2)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Update Available").font(.headline)
                            if let v = dashboard.systemInfo.updateVersion {
                                Text(v).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    Button {
                        // Update requires TrueNAS web UI interaction
                    } label: {
                        Label("Download & Install", systemImage: "arrow.down.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(true)
                    Text("Updates must be applied from the TrueNAS web interface.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green).font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Up to date").font(.headline)
                            Text("No updates available").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("Release Notes") {
                Text("Visit the TrueNAS documentation for full release notes and upgrade instructions.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Alert Row
private struct AlertRow: View {
    let alert: TrueNASAlert
    let onDismiss: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: alert.level.icon)
                .foregroundStyle(alert.level.color)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.message).font(.subheadline).lineLimit(3)
                HStack(spacing: 8) {
                    Text(alert.source).font(.caption2).foregroundStyle(.secondary)
                    Text(alert.relativeTime).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Boot Env Row
private struct BootEnvRow: View {
    let env: BootEnvironment
    let onActivate: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: env.active ? "star.fill" : "star")
                .foregroundStyle(env.active ? .yellow : .secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(env.name).font(.body.weight(.medium))
                    if env.active {
                        Text("Active").font(.caption2.bold())
                            .foregroundStyle(.green)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.green.opacity(0.12), in: Capsule())
                    }
                    if env.keepForever {
                        Image(systemName: "lock.fill").font(.caption2).foregroundStyle(.orange)
                    }
                }
                HStack(spacing: 10) {
                    Label(env.formattedDate, systemImage: "calendar")
                        .font(.caption).foregroundStyle(.secondary)
                    Label(env.formattedSize, systemImage: "internaldrive")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if !env.active {
                Button("Activate") { onActivate() }
                    .font(.caption.bold())
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - User Row
private struct UserRow: View {
    let user: TrueNASUser

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(user.builtIn ? Color.blue.opacity(0.15) : Color.purple.opacity(0.15))
                    .frame(width: 32, height: 32)
                Text(String(user.username.prefix(1)).uppercased())
                    .font(.subheadline.bold())
                    .foregroundStyle(user.builtIn ? .blue : .purple)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(user.username).font(.body.weight(.medium))
                    if user.locked {
                        Image(systemName: "lock.fill").font(.caption2).foregroundStyle(.orange)
                    }
                    if user.sudoEnabled {
                        Text("sudo").font(.caption2.bold()).foregroundStyle(.red)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Color.red.opacity(0.12), in: Capsule())
                    }
                }
                Text(user.fullName.isEmpty ? user.shell : user.fullName)
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("UID \(user.id)").font(.caption2.monospaced()).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Group Row
private struct GroupRow: View {
    let group: TrueNASGroup

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.3.fill").foregroundStyle(.teal).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(group.name).font(.body.weight(.medium))
                    if group.sudoEnabled {
                        Text("sudo").font(.caption2.bold()).foregroundStyle(.red)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Color.red.opacity(0.12), in: Capsule())
                    }
                }
                Text("\(group.users.count) member\(group.users.count == 1 ? "" : "s")")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("GID \(group.id)").font(.caption2.monospaced()).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Certificate Row
private struct CertRow: View {
    let cert: Certificate

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield.fill").foregroundStyle(cert.expiryColor).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(cert.name).font(.body.weight(.medium))
                Text(cert.commonName).font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Text(cert.keyType + " \(cert.keyLength)-bit")
                        .font(.caption2).foregroundStyle(.secondary)
                    if !cert.issuer.isEmpty && cert.issuer != "—" {
                        Text(cert.issuer).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(cert.expiryLabel)
                    .font(.caption.bold())
                    .foregroundStyle(cert.expiryColor)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(cert.expiryColor.opacity(0.1), in: Capsule())
                Text(cert.until, format: .dateTime.month(.abbreviated).day().year())
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Audit Row
private struct AuditRow: View {
    let entry: AuditEntry

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: entry.statusIcon)
                .foregroundStyle(entry.statusColor)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.event).font(.subheadline.weight(.medium))
                    Text(entry.service).font(.caption2.bold())
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12), in: Capsule())
                }
                HStack(spacing: 8) {
                    Text(entry.username).font(.caption).foregroundStyle(.secondary)
                    // Only apply monospace for real IP addresses, not placeholder "—"
                    if entry.address == "—" {
                        Text(entry.address).font(.caption).foregroundStyle(.tertiary)
                    } else {
                        Text(entry.address).font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            Text(entry.relativeTime).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Searchable Audit Log View
private struct AuditLogView: View {
    let entries: [AuditEntry]
    @State private var searchText = ""
    @State private var filterService = "All"

    private var services: [String] {
        ["All"] + Array(Set(entries.map(\.service))).sorted()
    }

    private var filtered: [AuditEntry] {
        entries.filter { entry in
            let matchesSearch = searchText.isEmpty ||
                entry.username.localizedCaseInsensitiveContains(searchText) ||
                entry.event.localizedCaseInsensitiveContains(searchText) ||
                entry.address.localizedCaseInsensitiveContains(searchText)
            let matchesService = filterService == "All" || entry.service == filterService
            return matchesSearch && matchesService
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Service filter chips — above the list, no Section wrapper
            if services.count > 2 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(services, id: \.self) { svc in
                            Button {
                                filterService = svc
                            } label: {
                                Text(svc)
                                    .font(.caption.weight(filterService == svc ? .semibold : .regular))
                                    .foregroundStyle(filterService == svc ? .white : .primary)
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(filterService == svc ? Color.accentColor : Color.secondary.opacity(0.15),
                                                in: Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                Divider()
            }

            List {
                Section(filtered.count == entries.count
                        ? "\(filtered.count) events"
                        : "\(filtered.count) of \(entries.count) events") {
                    if filtered.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    } else {
                        ForEach(filtered) { entry in
                            AuditRow(entry: entry)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
        .searchable(text: $searchText, prompt: "Search by user, event, address…")
    }
}

#Preview {
    SystemView()
        .environment(SystemViewModel())
        .environment(DashboardViewModel())
        .environment(SettingsViewModel())
}

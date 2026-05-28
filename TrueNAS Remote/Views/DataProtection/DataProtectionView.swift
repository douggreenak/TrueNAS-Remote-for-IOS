import SwiftUI

struct DataProtectionView: View {
    @Environment(DataProtectionViewModel.self) private var vm
    @Environment(SettingsViewModel.self)       private var settings
    @State private var segment = 0  // 0=Snapshots 1=Replication 2=Cloud 3=Rsync 4=Scrub
    @Namespace private var tabNS

    private let tabs: [(label: String, icon: String)] = [
        ("Snapshots",   "camera.badge.clock"),
        ("Replication", "arrow.triangle.2.circlepath"),
        ("Cloud Sync",  "cloud.fill"),
        ("Rsync",       "arrow.left.arrow.right"),
        ("Scrub",       "sparkles"),
    ]

    var body: some View {
        tabContent
            .animation(.none, value: segment)   // instant switch, no flicker
            .pageLoading(vm.isLoading && allEmpty)
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    tabBar
                    Divider()
                }
            }
            .navigationTitle("Data Protection")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if vm.isLoading { ProgressView().controlSize(.small) }
                }
            }
            .task { await vm.refresh() }
            .alert("Error", isPresented: .constant(vm.errorMessage != nil)) {
                Button("OK") { vm.errorMessage = nil }
            } message: { Text(vm.errorMessage ?? "") }
    }

    private var allEmpty: Bool {
        vm.snapshotTasks.isEmpty && vm.replication.isEmpty &&
        vm.cloudSync.isEmpty    && vm.rsyncTasks.isEmpty  &&
        vm.scrubTasks.isEmpty
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
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.accentColor)
                                        .frame(height: 3)
                                        .matchedGeometryEffect(id: "dpTab", in: tabNS)
                                } else {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.clear).frame(height: 3)
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

    // MARK: - Content switcher
    @ViewBuilder
    private var tabContent: some View {
        switch segment {
        case 0: snapshotsList
        case 1: replicationList
        case 2: cloudSyncList
        case 3: rsyncList
        default: scrubList
        }
    }

    // MARK: - Snapshot Tasks
    private var snapshotsList: some View {
        Group {
            if vm.snapshotTasks.isEmpty {
                ContentUnavailableView("No Snapshot Tasks",
                    systemImage: "camera.badge.clock",
                    description: Text("No periodic snapshot tasks configured."))
            } else {
                List(vm.snapshotTasks) { task in
                    SnapshotTaskRow(task: task) {
                        Task { await vm.runSnapshotTask(task) }
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable { await vm.refresh() }
            }
        }
    }

    // MARK: - Replication (tappable for detail)
    private var replicationList: some View {
        Group {
            if vm.replication.isEmpty {
                ContentUnavailableView("No Replication Tasks",
                    systemImage: "arrow.triangle.2.circlepath",
                    description: Text("No replication tasks configured."))
            } else {
                List(vm.replication) { task in
                    NavigationLink(destination: ReplicationDetailView(task: task) {
                        Task { await vm.runReplication(task) }
                    }) {
                        ReplicationRow(task: task) {
                            Task { await vm.runReplication(task) }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable { await vm.refresh() }
            }
        }
    }

    // MARK: - Cloud Sync (tappable for detail)
    private var cloudSyncList: some View {
        Group {
            if vm.cloudSync.isEmpty {
                ContentUnavailableView("No Cloud Sync Tasks",
                    systemImage: "cloud.fill",
                    description: Text("No cloud sync tasks configured."))
            } else {
                List(vm.cloudSync) { task in
                    NavigationLink(destination: CloudSyncDetailView(task: task) {
                        Task { await vm.runCloudSync(task) }
                    }) {
                        CloudSyncRow(task: task) {
                            Task { await vm.runCloudSync(task) }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable { await vm.refresh() }
            }
        }
    }

    // MARK: - Rsync
    private var rsyncList: some View {
        Group {
            if vm.rsyncTasks.isEmpty {
                ContentUnavailableView("No Rsync Tasks",
                    systemImage: "arrow.left.arrow.right",
                    description: Text("No rsync tasks configured."))
            } else {
                List(vm.rsyncTasks) { task in
                    RsyncRow(task: task) {
                        Task { await vm.runRsync(task) }
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable { await vm.refresh() }
            }
        }
    }

    // MARK: - Scrub
    private var scrubList: some View {
        Group {
            if vm.scrubTasks.isEmpty {
                ContentUnavailableView("No Scrub Tasks",
                    systemImage: "sparkles",
                    description: Text("No scrub tasks configured."))
            } else {
                List(vm.scrubTasks) { task in
                    ScrubRow(task: task)
                }
                .listStyle(.insetGrouped)
                .refreshable { await vm.refresh() }
            }
        }
    }
}

// MARK: - Replication Detail View
struct ReplicationDetailView: View {
    let task: ReplicationTask
    let onRun: () -> Void

    var body: some View {
        List {
            Section("Task") {
                LabeledContent("Name", value: task.name)
                LabeledContent("Direction", value: task.direction)
                LabeledContent("Transport", value: task.transport)
                LabeledContent("Enabled", value: task.enabled ? "Yes" : "No")
            }

            Section("Paths") {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Source", systemImage: task.direction == "PUSH"
                          ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(task.sourcePath)
                        .font(.subheadline.monospaced())
                        .textSelection(.enabled)
                }
                .padding(.vertical, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Label("Destination", systemImage: "arrow.right.circle.fill")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(task.targetPath)
                        .font(.subheadline.monospaced())
                        .textSelection(.enabled)
                }
                .padding(.vertical, 2)
            }

            Section("Schedule & Status") {
                LabeledContent("Schedule", value: task.schedule)
                if let lastRun = task.lastRun {
                    LabeledContent("Last Run") {
                        Text(lastRun.formatted(.relative(presentation: .named)))
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Status")
                        Spacer()
                        RunStatusBadge(status: task.lastRunStatus)
                    }
                } else {
                    Text("No run history").foregroundStyle(.secondary)
                }
            }

            Section {
                Button {
                    onRun()
                } label: {
                    Label("Run Now", systemImage: "play.circle.fill")
                        .foregroundStyle(task.enabled ? .green : .secondary)
                }
                .disabled(!task.enabled)
            }
        }
        .navigationTitle(task.name)
        .toolbarTitleDisplayMode(.inline)
        .listStyle(.insetGrouped)
        .listSectionSpacing(.compact)
    }
}

// MARK: - Cloud Sync Detail View
struct CloudSyncDetailView: View {
    let task: CloudSyncTask
    let onRun: () -> Void

    private func formatBytes(_ b: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: b, countStyle: .binary)
    }

    var body: some View {
        List {
            Section("Task") {
                LabeledContent("Description", value: task.description)
                LabeledContent("Provider", value: task.provider)
                LabeledContent("Direction", value: task.directionLabel)
                LabeledContent("Enabled", value: task.enabled ? "Yes" : "No")
            }

            Section("Path") {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Local Path", systemImage: "folder.fill")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(task.path)
                        .font(.subheadline.monospaced())
                        .textSelection(.enabled)
                }
                .padding(.vertical, 2)
            }

            Section("Schedule & Status") {
                LabeledContent("Schedule", value: task.schedule)
                if let lastRun = task.lastRun {
                    LabeledContent("Last Run") {
                        Text(lastRun.formatted(.relative(presentation: .named)))
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Status")
                        Spacer()
                        RunStatusBadge(status: task.lastRunStatus)
                    }
                    if let bytes = task.bytesTransferred {
                        LabeledContent("Data Transferred", value: formatBytes(bytes))
                    }
                } else {
                    Text("No run history").foregroundStyle(.secondary)
                }
            }

            Section {
                Button {
                    onRun()
                } label: {
                    Label("Run Now", systemImage: "play.circle.fill")
                        .foregroundStyle(task.enabled ? .green : .secondary)
                }
                .disabled(!task.enabled)
            }
        }
        .navigationTitle(task.description)
        .toolbarTitleDisplayMode(.inline)
        .listStyle(.insetGrouped)
        .listSectionSpacing(.compact)
    }
}

// MARK: - Snapshot Task Row
private struct SnapshotTaskRow: View {
    let task: SnapshotTask
    let onRun: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(task.enabled ? Color.green : Color.secondary)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(task.dataset)
                        .font(.body.weight(.medium)).lineLimit(1)
                    if !task.enabled {
                        Label("Disabled", systemImage: "pause.circle")
                            .labelStyle(.iconOnly).font(.caption).foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 8) {
                    if task.recursive {
                        Label("Recursive", systemImage: "arrow.turn.down.right")
                            .labelStyle(.titleOnly).font(.caption2).foregroundStyle(.blue)
                    }
                    Text("Keep \(task.lifetime)").font(.caption2).foregroundStyle(.secondary)
                }

                Label(task.schedule, systemImage: "clock")
                    .font(.caption2).foregroundStyle(.secondary).labelStyle(.titleAndIcon)

                if let lastRun = task.lastRun {
                    Text("Last: \(lastRun, style: .relative) ago")
                        .font(.caption2).foregroundStyle(.secondary)
                } else if task.lastRunStatus != .unknown {
                    RunStatusBadge(status: task.lastRunStatus)
                }
            }

            Spacer()

            Button { onRun() } label: {
                Image(systemName: "play.circle.fill").font(.title3).foregroundStyle(.green)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Replication Row (compact, for list)
private struct ReplicationRow: View {
    let task: ReplicationTask
    let onRun: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(task.enabled ? Color.blue : Color.secondary)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(task.name).font(.body.weight(.medium))
                    Spacer()
                    RunStatusBadge(status: task.lastRunStatus)
                }

                HStack(spacing: 4) {
                    Image(systemName: task.direction == "PUSH"
                          ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .font(.caption)
                        .foregroundStyle(task.direction == "PUSH" ? .blue : .green)
                    Text(task.sourcePath)
                        .font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1)
                    Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.tertiary)
                    Text(task.targetPath)
                        .font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1)
                }

                HStack(spacing: 8) {
                    Text(task.transport)
                        .font(.caption2).foregroundStyle(.blue)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.blue.opacity(0.1), in: Capsule())
                    if !task.enabled { Text("Disabled").font(.caption2).foregroundStyle(.secondary) }
                }
            }

            Button { onRun() } label: {
                Image(systemName: "play.circle.fill").font(.title2).foregroundStyle(.green)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Cloud Sync Row (compact, for list)
private struct CloudSyncRow: View {
    let task: CloudSyncTask
    let onRun: () -> Void

    private func formatBytes(_ b: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: b, countStyle: .binary)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: task.directionIcon)
                .font(.title3)
                .foregroundStyle(task.direction == "PUSH" ? .blue : .green)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(task.description).font(.body.weight(.medium)).lineLimit(1)
                    Spacer()
                    RunStatusBadge(status: task.lastRunStatus)
                }

                HStack(spacing: 6) {
                    Text(task.directionLabel).font(.caption2).foregroundStyle(.secondary)
                    Text("·").foregroundStyle(.quaternary)
                    Text(task.provider).font(.caption2).foregroundStyle(.secondary)
                    if !task.enabled {
                        Text("·").foregroundStyle(.quaternary)
                        Text("Disabled").font(.caption2).foregroundStyle(.secondary)
                    }
                }

                if let lastRun = task.lastRun {
                    Text("Last: \(lastRun, style: .relative) ago")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }

            Button { onRun() } label: {
                Image(systemName: "play.circle.fill").font(.title2).foregroundStyle(.green)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Rsync Row
private struct RsyncRow: View {
    let task: RsyncTask
    let onRun: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: task.direction == "PUSH"
                  ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .font(.title3)
                .foregroundStyle(task.direction == "PUSH" ? .purple : .teal)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(task.path).font(.body.weight(.medium)).lineLimit(1)
                    Spacer()
                    RunStatusBadge(status: task.lastRunStatus)
                }

                HStack(spacing: 4) {
                    Text(task.remoteHost).font(.caption.monospaced()).foregroundStyle(.secondary)
                    Text(":").foregroundStyle(.tertiary)
                    Text(task.remotePath)
                        .font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1)
                }

                HStack(spacing: 8) {
                    Label(task.schedule, systemImage: "clock")
                        .font(.caption2).foregroundStyle(.secondary).labelStyle(.titleAndIcon)
                    if task.remotePort != 22 {
                        Text("Port \(task.remotePort)").font(.caption2).foregroundStyle(.secondary)
                    }
                    if !task.enabled { Text("Disabled").font(.caption2).foregroundStyle(.secondary) }
                }

                if let lastRun = task.lastRun {
                    Text("Last: \(lastRun, style: .relative) ago")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }

            Button { onRun() } label: {
                Image(systemName: "play.circle.fill").font(.title2).foregroundStyle(.green)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Scrub Row
private struct ScrubRow: View {
    let task: ScrubTask

    private func formatDuration(_ secs: TimeInterval) -> String {
        let s = Int(secs); if s < 60 { return "\(s)s" }
        let m = s / 60; let rem = s % 60
        return String(format: "%d:%02d", m, rem)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "sparkles").foregroundStyle(.blue)
                Text(task.poolName).font(.body.weight(.medium))
                Spacer()
                if task.isRunning {
                    Label("Running", systemImage: "arrow.clockwise.circle.fill")
                        .font(.caption.bold()).foregroundStyle(.blue)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(.blue.opacity(0.12), in: Capsule())
                } else {
                    RunStatusBadge(status: task.lastRunStatus)
                }
            }

            if task.isRunning, let pct = task.progress {
                VStack(alignment: .leading, spacing: 3) {
                    ProgressView(value: pct / 100).tint(.blue)
                    Text(String(format: "%.0f%% complete", pct))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                Label(task.schedule, systemImage: "clock")
                    .font(.caption2).foregroundStyle(.secondary).labelStyle(.titleAndIcon)
                if let run = task.lastRun {
                    Text("Last: \(run, style: .relative) ago")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                if let dur = task.lastRunDuration {
                    Text("(\(formatDuration(dur)))").font(.caption2).foregroundStyle(.tertiary)
                }
            }

            if !task.enabled {
                Label("Disabled", systemImage: "pause.circle").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    DataProtectionView()
        .environment(DataProtectionViewModel())
        .environment(SettingsViewModel())
}

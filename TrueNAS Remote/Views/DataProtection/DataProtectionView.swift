import SwiftUI

struct DataProtectionView: View {
    @Environment(DataProtectionViewModel.self) private var vm
    @Environment(SettingsViewModel.self)       private var settings
    @State private var segment = 0  // 0=Snapshots 1=Replication 2=Cloud 3=Rsync 4=Scrub

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(["Snapshots", "Replication", "Cloud Sync", "Rsync", "Scrub"].indices, id: \.self) { i in
                            Button {
                                withAnimation { segment = i }
                            } label: {
                                Text(["Snapshots", "Replication", "Cloud Sync", "Rsync", "Scrub"][i])
                                    .font(.subheadline.weight(segment == i ? .semibold : .regular))
                                    .foregroundStyle(segment == i ? .primary : .secondary)
                                    .padding(.horizontal, 16).padding(.vertical, 8)
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
                    case 0: snapshotsList
                    case 1: replicationList
                    case 2: cloudSyncList
                    case 3: rsyncList
                    default: scrubList
                    }
                }
            }
            .navigationTitle("Data Protection")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if vm.isLoading { ProgressView().controlSize(.small) }
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
            .alert("Error", isPresented: .constant(vm.errorMessage != nil)) {
                Button("OK") { vm.errorMessage = nil }
            } message: { Text(vm.errorMessage ?? "") }
        }
    }

    // MARK: - Snapshot Tasks
    private var snapshotsList: some View {
        List(vm.snapshotTasks) { task in
            SnapshotTaskRow(task: task) {
                Task { await vm.runSnapshotTask(task) }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Replication
    private var replicationList: some View {
        List(vm.replication) { task in
            ReplicationRow(task: task) {
                Task { await vm.runReplication(task) }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Cloud Sync
    private var cloudSyncList: some View {
        List(vm.cloudSync) { task in
            CloudSyncRow(task: task) {
                Task { await vm.runCloudSync(task) }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Rsync
    private var rsyncList: some View {
        List(vm.rsyncTasks) { task in
            RsyncRow(task: task) {
                Task { await vm.runRsync(task) }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Scrub
    private var scrubList: some View {
        List(vm.scrubTasks) { task in
            ScrubRow(task: task)
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Snapshot Task Row
private struct SnapshotTaskRow: View {
    let task: SnapshotTask
    let onRun: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            RunStatusBadge(status: task.lastRunStatus)
                .frame(width: 80, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(task.dataset).font(.body.weight(.medium)).lineLimit(1)
                HStack(spacing: 8) {
                    Text(task.schedule).font(.caption).foregroundStyle(.secondary)
                    if task.recursive { Text("Recursive").font(.caption2).foregroundStyle(.blue) }
                }
                Text("Keep: \(task.lifetime)").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 8) {
                if !task.enabled {
                    Image(systemName: "pause.circle").foregroundStyle(.secondary)
                }
                Button { onRun() } label: {
                    Image(systemName: "play.circle.fill").font(.title3).foregroundStyle(.green)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Replication Row
private struct ReplicationRow: View {
    let task: ReplicationTask
    let onRun: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    RunStatusBadge(status: task.lastRunStatus)
                    Spacer()
                    if !task.enabled {
                        Image(systemName: "pause.circle").foregroundStyle(.secondary).font(.caption)
                    }
                }
                Text(task.name).font(.body.weight(.medium))
                HStack(spacing: 4) {
                    Text(task.sourcePath).font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1)
                    Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.secondary)
                    Text(task.targetPath).font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1)
                }
                HStack(spacing: 8) {
                    Text(task.transport).font(.caption2).foregroundStyle(.blue)
                    Text(task.schedule).font(.caption2).foregroundStyle(.secondary)
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

// MARK: - Cloud Sync Row
private struct CloudSyncRow: View {
    let task: CloudSyncTask
    let onRun: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "cloud.fill").foregroundStyle(.blue).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(task.description).font(.body.weight(.medium)).lineLimit(1)
                    Spacer()
                    RunStatusBadge(status: task.lastRunStatus)
                }
                HStack(spacing: 8) {
                    Image(systemName: task.direction == "PUSH" ? "arrow.up.circle" : "arrow.down.circle")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(task.provider).font(.caption).foregroundStyle(.secondary)
                    if !task.enabled {
                        Image(systemName: "pause.circle").foregroundStyle(.secondary).font(.caption)
                    }
                }
                Text(task.schedule).font(.caption2).foregroundStyle(.secondary)
                if let bytes = task.bytesTransferred {
                    Text("Last: \(formatBytes(bytes))").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Button { onRun() } label: {
                Image(systemName: "play.circle.fill").font(.title2).foregroundStyle(.green)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }

    private func formatBytes(_ b: Int64) -> String {
        let gb = Double(b) / 1e9
        if gb >= 1 { return String(format: "%.2f GB", gb) }
        return String(format: "%.0f MB", Double(b) / 1e6)
    }
}

// MARK: - Rsync Row
private struct RsyncRow: View {
    let task: RsyncTask
    let onRun: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath").foregroundStyle(.purple).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("\(task.path) → \(task.remoteHost)").font(.body.weight(.medium)).lineLimit(1)
                    Spacer()
                    RunStatusBadge(status: task.lastRunStatus)
                }
                HStack(spacing: 8) {
                    Image(systemName: task.direction == "PUSH" ? "arrow.up.circle" : "arrow.down.circle")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(task.remotePath).font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1)
                }
                Text(task.schedule).font(.caption2).foregroundStyle(.secondary)
            }
            Button { onRun() } label: {
                Image(systemName: "play.circle.fill").font(.title2).foregroundStyle(.green)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Scrub Row
private struct ScrubRow: View {
    let task: ScrubTask

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "sparkles").foregroundStyle(.blue)
                Text(task.poolName).font(.body.weight(.medium))
                Spacer()
                RunStatusBadge(status: task.lastRunStatus)
            }
            if task.isRunning, let pct = task.progress {
                VStack(alignment: .leading, spacing: 2) {
                    ProgressView(value: pct / 100)
                        .tint(.blue)
                    Text(String(format: "%.0f%% complete", pct)).font(.caption2).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 8) {
                if let run = task.lastRun {
                    Text("Last: \(run, style: .relative) ago").font(.caption2).foregroundStyle(.secondary)
                }
                if let dur = task.lastRunDuration {
                    Text("Duration: \(formatDuration(dur))").font(.caption2).foregroundStyle(.secondary)
                }
                if !task.enabled {
                    Image(systemName: "pause.circle").foregroundStyle(.secondary).font(.caption)
                }
            }
            Text(task.schedule).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func formatDuration(_ secs: TimeInterval) -> String {
        let s = Int(secs)
        if s < 60 { return "\(s)s" }
        let m = s / 60; let rem = s % 60
        return String(format: "%d:%02d", m, rem)
    }
}

#Preview {
    DataProtectionView()
        .environment(DataProtectionViewModel())
        .environment(SettingsViewModel())
}

import SwiftUI

struct StorageRootView: View {
    @Environment(StorageViewModel.self)  private var vm
    @Environment(SettingsViewModel.self) private var settings
    @State private var segment = 0   // 0=Pools 1=Disks 2=Datasets

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Section", selection: $segment) {
                    Text("Pools").tag(0)
                    Text("Disks").tag(1)
                    Text("Datasets").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal).padding(.vertical, 8)

                Group {
                    switch segment {
                    case 0: poolsList
                    case 1: disksList
                    default: datasetsList
                    }
                }
            }
            .navigationTitle("Storage")
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

    // MARK: - Pools
    private var poolsList: some View {
        Group {
            if vm.pools.isEmpty {
                ContentUnavailableView("No Pools",
                    systemImage: "externaldrive.badge.questionmark",
                    description: Text("Configure your server in Settings."))
            } else {
                List(vm.pools) { pool in
                    NavigationLink(destination: PoolDetailView(pool: pool)) {
                        PoolRow(pool: pool)
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable { await vm.refresh() }
            }
        }
    }

    // MARK: - Disks
    private var disksList: some View {
        Group {
            if vm.disks.isEmpty {
                ContentUnavailableView("No Disks", systemImage: "internaldrive",
                    description: Text("No disk data available."))
            } else {
                List(vm.disks) { disk in
                    NavigationLink(destination: DiskDetailView(disk: disk)) {
                        DiskListRow(disk: disk)
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable { await vm.refresh() }
            }
        }
    }

    // MARK: - Datasets
    private var datasetsList: some View {
        Group {
            if vm.datasets.isEmpty {
                ContentUnavailableView("No Datasets", systemImage: "cylinder",
                    description: Text("No dataset data available."))
            } else {
                List {
                    ForEach(vm.datasets) { ds in
                        DatasetTreeRow(dataset: ds, depth: 0, vm: vm)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }
}

// MARK: - Pool Row
struct PoolRow: View {
    let pool: StoragePool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "cylinder.split.1x2.fill")
                    .foregroundStyle(.blue)
                Text(pool.name).font(.headline)
                Spacer()
                HealthBadge(status: pool.status)
            }
            CapacityBar(fraction: pool.usedFraction)
            HStack {
                Text("\(pool.formattedUsed) used")
                Spacer()
                Text(pool.formattedTotal)
            }
            .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Disk List Row
struct DiskListRow: View {
    let disk: Disk

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: disk.smartStatus.icon)
                .foregroundStyle(disk.smartStatus.color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(disk.id).font(.body.weight(.medium))
                Text(disk.model).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let temp = disk.temperature {
                    Label("\(temp)°C", systemImage: "thermometer")
                        .font(.caption2).foregroundStyle(tempColor(temp))
                }
                Text(formatBytes(disk.size)).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func tempColor(_ t: Int) -> Color {
        t > 55 ? .red : t > 45 ? .orange : .secondary
    }

    private func formatBytes(_ b: Int64) -> String {
        let tb = Double(b) / 1e12
        let gb = Double(b) / 1e9
        if tb >= 1 { return String(format: "%.1f TB", tb) }
        return String(format: "%.0f GB", gb)
    }
}

// MARK: - Dataset Tree Row
struct DatasetTreeRow: View {
    let dataset: Dataset
    let depth: Int
    let vm: StorageViewModel

    var body: some View {
        NavigationLink(destination: DatasetDetailView(dataset: dataset, vm: vm)) {
            HStack(spacing: 8) {
                if depth > 0 {
                    Color.clear.frame(width: CGFloat(depth) * 16)
                }
                Image(systemName: dataset.type == .volume ? "cylinder" : "folder")
                    .foregroundStyle(dataset.type == .volume ? .orange : .blue)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(dataset.name).font(.body.weight(.medium))
                    HStack(spacing: 8) {
                        Text(formatBytes(dataset.usedBytes)).font(.caption).foregroundStyle(.secondary)
                        if dataset.snapshotCount > 0 {
                            Label("\(dataset.snapshotCount)", systemImage: "camera")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        if case .encrypted(let locked) = dataset.encryption {
                            Image(systemName: locked ? "lock.fill" : "lock.open")
                                .font(.caption2).foregroundStyle(locked ? .red : .green)
                        }
                    }
                }
                Spacer()
                Text(String(format: "%.2fx", dataset.compressionRatio))
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }

        if !dataset.children.isEmpty {
            ForEach(dataset.children) { child in
                DatasetTreeRow(dataset: child, depth: depth + 1, vm: vm)
            }
        }
    }

    private func formatBytes(_ b: Int64) -> String {
        let tb = Double(b) / 1e12
        let gb = Double(b) / 1e9
        if tb >= 1 { return String(format: "%.2f TB", tb) }
        return String(format: "%.1f GB", gb)
    }
}

// MARK: - Disk Detail View
struct DiskDetailView: View {
    let disk: Disk
    @State private var showSmartAlert = false
    @State private var smartType: SmartTestType = .short

    var body: some View {
        List {
            Section("Identity") {
                LabeledContent("Device", value: disk.id)
                LabeledContent("Model", value: disk.model)
                LabeledContent("Serial", value: disk.serial)
                LabeledContent("Size", value: formatBytes(disk.size))
                if let pool = disk.poolName {
                    LabeledContent("Pool", value: pool)
                }
            }

            Section("Health") {
                HStack {
                    Text("S.M.A.R.T.")
                    Spacer()
                    Label(disk.smartStatus.label, systemImage: disk.smartStatus.icon)
                        .foregroundStyle(disk.smartStatus.color)
                        .font(.caption.bold())
                }
                if let temp = disk.temperature {
                    LabeledContent("Temperature", value: "\(temp) °C")
                }
                LabeledContent("Power-On Hours", value: disk.powerOnHours.map { "\($0) h" } ?? "—")
                LabeledContent("Read Errors",    value: "\(disk.readErrors)")
                LabeledContent("Write Errors",   value: "\(disk.writeErrors)")
                LabeledContent("Checksum Errors",value: "\(disk.checksumErrors)")
            }

            if !disk.smartResults.isEmpty {
                Section("S.M.A.R.T. Results") {
                    ForEach(disk.smartResults) { result in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(result.testType.rawValue).font(.subheadline.weight(.medium))
                                Spacer()
                                Text(result.status == .passed ? "Passed" : "Failed")
                                    .font(.caption.bold())
                                    .foregroundStyle(result.status == .passed ? .green : .red)
                            }
                            if !result.description.isEmpty {
                                Text(result.description).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section {
                Button {
                    smartType = .short
                    showSmartAlert = true
                } label: {
                    Label("Run Short S.M.A.R.T. Test", systemImage: "play.circle")
                }
                Button {
                    smartType = .long
                    showSmartAlert = true
                } label: {
                    Label("Run Long S.M.A.R.T. Test", systemImage: "play.circle.fill")
                }
            }
        }
        .navigationTitle(disk.id)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Run S.M.A.R.T. Test", isPresented: $showSmartAlert) {
            Button("Run \(smartType.rawValue)") { }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Run a \(smartType.rawValue.lowercased()) S.M.A.R.T. self-test on \(disk.id)?")
        }
    }

    private func formatBytes(_ b: Int64) -> String {
        let tb = Double(b) / 1e12
        let gb = Double(b) / 1e9
        if tb >= 1 { return String(format: "%.2f TB", tb) }
        return String(format: "%.1f GB", gb)
    }
}

private extension SmartStatus {
    var label: String {
        switch self {
        case .passed:  return "Passed"
        case .failed:  return "Failed"
        case .unknown: return "Unknown"
        }
    }
}

// MARK: - Dataset Detail View
struct DatasetDetailView: View {
    let dataset: Dataset
    let vm: StorageViewModel
    @State private var showSnapshot = false
    @State private var snapshotName = ""
    @State private var snapshotToDelete: Snapshot?
    @State private var snapshotToRollback: Snapshot?
    @State private var showDeleteConfirm = false
    @State private var showRollbackConfirm = false

    // Snapshots belonging to this dataset
    private var mySnapshots: [Snapshot] {
        vm.snapshots.filter { $0.dataset == dataset.id }
    }

    var body: some View {
        List {
            Section("Properties") {
                LabeledContent("Path", value: dataset.id)
                LabeledContent("Type", value: dataset.type == .volume ? "zvol" : "filesystem")
                LabeledContent("Used", value: formatBytes(dataset.usedBytes))
                LabeledContent("Available", value: formatBytes(dataset.availableBytes))
                LabeledContent("Compression", value: String(format: "%.2fx", dataset.compressionRatio))
                LabeledContent("Dedup", value: String(format: "%.2fx", dataset.deduplicationRatio))
            }

            Section("Security") {
                switch dataset.encryption {
                case .unencrypted:
                    Label("Not encrypted", systemImage: "lock.open").foregroundStyle(.secondary)
                case .encrypted(let locked):
                    Label(locked ? "Encrypted (Locked)" : "Encrypted (Unlocked)",
                          systemImage: locked ? "lock.fill" : "lock.open")
                        .foregroundStyle(locked ? .red : .green)
                }
            }

            if !dataset.comments.isEmpty {
                Section("Notes") {
                    Text(dataset.comments).font(.subheadline).foregroundStyle(.secondary)
                }
            }

            Section {
                Button {
                    snapshotName = ""
                    showSnapshot = true
                } label: {
                    Label("Create Snapshot", systemImage: "camera")
                }
            } header: {
                Text("Actions")
            }

            // Snapshots
            if !mySnapshots.isEmpty {
                Section("Snapshots (\(mySnapshots.count))") {
                    ForEach(mySnapshots) { snap in
                        SnapshotRow(snapshot: snap)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    snapshotToDelete = snap
                                    showDeleteConfirm = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    snapshotToRollback = snap
                                    showRollbackConfirm = true
                                } label: {
                                    Label("Rollback", systemImage: "arrow.uturn.backward.circle")
                                }
                                .tint(.orange)
                            }
                    }
                }
            } else {
                Section("Snapshots") {
                    Text("No snapshots").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(dataset.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.refreshSnapshots(dataset: dataset.id) }
        .alert("Create Snapshot", isPresented: $showSnapshot) {
            TextField("Snapshot name (e.g. auto-\(Date().formatted(.dateTime.month().day())))", text: $snapshotName)
            Button("Create") {
                let name = snapshotName.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty {
                    Task { await vm.createSnapshot(dataset: dataset.id, name: name) }
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .alert("Delete Snapshot?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let snap = snapshotToDelete {
                    Task { await vm.deleteSnapshot(snap) }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete \"\(snapshotToDelete?.name ?? "")\".")
        }
        .alert("Rollback to Snapshot?", isPresented: $showRollbackConfirm) {
            Button("Rollback", role: .destructive) {
                if let snap = snapshotToRollback {
                    Task { await vm.rollbackSnapshot(snap) }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Rolling back to \"\(snapshotToRollback?.name ?? "")\" will discard all data written after that snapshot.")
        }
    }

    private func formatBytes(_ b: Int64) -> String {
        let tb = Double(b) / 1e12
        let gb = Double(b) / 1e9
        if tb >= 1 { return String(format: "%.2f TB", tb) }
        return String(format: "%.1f GB", gb)
    }
}

// MARK: - Snapshot Row
private struct SnapshotRow: View {
    let snapshot: Snapshot

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "camera.fill").foregroundStyle(.blue).frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.name).font(.subheadline.weight(.medium))
                HStack(spacing: 8) {
                    Text(snapshot.created, style: .date).font(.caption).foregroundStyle(.secondary)
                    Text(formatBytes(snapshot.referencedBytes)).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if snapshot.holdCount > 0 {
                Image(systemName: "lock.fill").font(.caption2).foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 2)
    }

    private func formatBytes(_ b: Int64) -> String {
        let gb = Double(b) / 1e9
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        return String(format: "%.0f MB", Double(b) / 1e6)
    }
}

#Preview {
    StorageRootView()
        .environment(StorageViewModel())
        .environment(SettingsViewModel())
}

import SwiftUI

struct StorageRootView: View {
    @Environment(StorageViewModel.self)  private var vm
    @Environment(SettingsViewModel.self) private var settings
    @State private var segment = 0   // 0=Pools 1=Disks 2=Datasets
    @State private var diskSearch = ""

    var body: some View {
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
        .task(id: segment) {
            if segment == 2 { await vm.refreshDatasets() }
        }
        .alert("Error", isPresented: .constant(vm.errorMessage != nil)) {
            Button("OK") { vm.errorMessage = nil }
        } message: { Text(vm.errorMessage ?? "") }
    }

    // MARK: - Pools
    private var poolsList: some View {
        Group {
            if vm.isLoading && vm.pools.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.pools.isEmpty {
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
    private var filteredDisks: [Disk] {
        diskSearch.isEmpty ? vm.disks :
        vm.disks.filter { $0.id.localizedCaseInsensitiveContains(diskSearch) ||
                          $0.model.localizedCaseInsensitiveContains(diskSearch) ||
                          $0.serial.localizedCaseInsensitiveContains(diskSearch) ||
                          ($0.poolName ?? "").localizedCaseInsensitiveContains(diskSearch) }
    }

    private var disksList: some View {
        Group {
            if vm.isLoading && vm.disks.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.disks.isEmpty {
                ContentUnavailableView("No Disks",
                    systemImage: "internaldrive",
                    description: Text("No disk data available."))
            } else {
                List {
                    if filteredDisks.isEmpty {
                        ContentUnavailableView.search(text: diskSearch)
                    } else {
                        ForEach(filteredDisks) { disk in
                            NavigationLink(destination: DiskDetailView(disk: disk)) {
                                DiskListRow(disk: disk)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable { await vm.refresh() }
            }
        }
        .searchable(text: $diskSearch, prompt: "Search by device, model, serial, pool…")
    }

    // MARK: - Datasets
    private var datasetsList: some View {
        Group {
            if vm.isLoading && vm.datasets.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.datasets.isEmpty {
                ContentUnavailableView("No Datasets", systemImage: "cylinder",
                    description: Text("No dataset data available."))
            } else {
                List {
                    ForEach(vm.datasets) { ds in
                        DatasetTreeRow(dataset: ds, depth: 0, vm: vm)
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable { await vm.refreshDatasets() }
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
                    .foregroundStyle(pool.status.color)
                Text(pool.name).font(.headline)
                Spacer()
                HealthBadge(status: pool.status)
            }
            CapacityBar(fraction: pool.usedFraction)
            HStack {
                Text("\(pool.formattedUsed) used")
                Spacer()
                Text(String(format: "%.1f%% · \(pool.formattedTotal)", pool.usedFraction * 100))
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
            // Status icon (color indicates health)
            Image(systemName: "internaldrive")
                .foregroundStyle(statusColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(disk.id).font(.body.weight(.medium))
                    // Pool membership badge
                    if let pool = disk.poolName {
                        Text(pool)
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.blue.opacity(0.8), in: Capsule())
                    } else {
                        Text("Unallocated")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15), in: Capsule())
                    }
                }
                Text(disk.model).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                // Error / health row
                HStack(spacing: 8) {
                    if disk.totalErrors > 0 {
                        Label("\(disk.totalErrors) error(s)", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption2).foregroundStyle(.orange)
                    }
                    if let temp = disk.temperature {
                        Label("\(temp)°C", systemImage: "thermometer")
                            .font(.caption2).foregroundStyle(tempColor(temp))
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatBytes(disk.size)).font(.caption2).foregroundStyle(.secondary)
                // SMART status
                Label(disk.smartStatus == .passed ? "SMART OK"
                      : disk.smartStatus == .failed ? "SMART FAIL" : "—",
                      systemImage: disk.smartStatus.icon)
                    .font(.caption2.bold())
                    .foregroundStyle(disk.smartStatus.color)
            }
        }
        .padding(.vertical, 3)
    }

    private var statusColor: Color {
        if disk.totalErrors > 0 { return .orange }
        if disk.smartStatus == .failed { return .red }
        if disk.poolName != nil { return .blue }
        return .secondary
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
            HStack(spacing: 10) {
                if depth > 0 {
                    Rectangle().fill(Color.clear).frame(width: CGFloat(depth) * 16)
                }
                // Icon with colored background pill (like iOS Files)
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 34, height: 34)
                    Image(systemName: iconName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(iconColor)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(dataset.name)
                        .font(.body.weight(depth == 0 ? .semibold : .regular))
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(formatBytes(dataset.usedBytes))
                            .font(.caption2).foregroundStyle(.secondary)
                        if dataset.snapshotCount > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "camera.fill")
                                    .font(.caption2)
                                Text("\(dataset.snapshotCount)")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.secondary)
                        }
                        if case .encrypted(let locked) = dataset.encryption {
                            Image(systemName: locked ? "lock.fill" : "lock.open.fill")
                                .font(.caption2)
                                .foregroundStyle(locked ? Color.red : Color.green)
                        }
                        if dataset.compressionRatio > 1.05 {
                            Text(String(format: "%.1fx", dataset.compressionRatio))
                                .font(.caption2)
                                .foregroundStyle(.blue)
                                .padding(.horizontal, 4).padding(.vertical, 1)
                                .background(Color.blue.opacity(0.1), in: Capsule())
                        }
                    }
                }
                Spacer()
            }
            .padding(.vertical, 2)
        }

        if !dataset.children.isEmpty {
            ForEach(dataset.children) { child in
                DatasetTreeRow(dataset: child, depth: depth + 1, vm: vm)
            }
        }
    }

    // Contextual icon based on dataset name / type / depth
    private var iconName: String {
        if dataset.type == .volume { return "cylinder.split.1x2.fill" }
        if depth == 0 { return "externaldrive.fill" }
        let n = dataset.name.lowercased()
        if n.contains("media") || n.contains("movie") || n.contains("film") { return "film.stack" }
        if n.contains("tv")    || n.contains("show")  || n.contains("series") { return "tv.fill" }
        if n.contains("music") || n.contains("audio") { return "music.note" }
        if n.contains("photo") || n.contains("picture") || n.contains("image") { return "photo.on.rectangle.angled" }
        if n.contains("backup") || n.contains("archive") { return "archivebox.fill" }
        if n.contains("download") { return "arrow.down.circle.fill" }
        if n.contains("document") || n.contains("doc") { return "doc.fill" }
        if n.contains("data") { return "tablecells.fill" }
        if n.contains("app") || n.contains("vm") { return "app.fill" }
        if n.contains("log") { return "text.alignleft" }
        return "folder.fill"
    }

    private var iconColor: Color {
        if dataset.type == .volume { return .orange }
        if depth == 0 { return .gray }
        let n = dataset.name.lowercased()
        if n.contains("media") || n.contains("movie") || n.contains("film") { return .purple }
        if n.contains("tv")    || n.contains("show")  { return .indigo }
        if n.contains("music") || n.contains("audio") { return .pink }
        if n.contains("photo") || n.contains("picture") { return .green }
        if n.contains("backup") || n.contains("archive") { return .brown }
        if n.contains("download") { return .teal }
        if n.contains("data") { return .cyan }
        return .blue
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
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(disk.smartStatus.color.opacity(0.1), in: Capsule())
                }
                if let temp = disk.temperature {
                    HStack {
                        Text("Temperature")
                        Spacer()
                        Text("\(temp) °C")
                            .foregroundStyle(temp > 55 ? Color.red : temp > 45 ? Color.orange : Color.primary)
                            .fontWeight(temp > 45 ? .semibold : .regular)
                    }
                }
                if let poh = disk.powerOnHours {
                    LabeledContent("Power-On Hours") {
                        Text("\(poh) h")
                            .font(.subheadline.monospacedDigit())
                    }
                } else {
                    LabeledContent("Power-On Hours", value: "—")
                }
                HStack {
                    Text("Read Errors")
                    Spacer()
                    Text("\(disk.readErrors)")
                        .foregroundStyle(disk.readErrors > 0 ? Color.red : Color.secondary)
                        .fontWeight(disk.readErrors > 0 ? .semibold : .regular)
                }
                HStack {
                    Text("Write Errors")
                    Spacer()
                    Text("\(disk.writeErrors)")
                        .foregroundStyle(disk.writeErrors > 0 ? Color.red : Color.secondary)
                        .fontWeight(disk.writeErrors > 0 ? .semibold : .regular)
                }
                HStack {
                    Text("Checksum Errors")
                    Spacer()
                    Text("\(disk.checksumErrors)")
                        .foregroundStyle(disk.checksumErrors > 0 ? Color.orange : Color.secondary)
                        .fontWeight(disk.checksumErrors > 0 ? .semibold : .regular)
                }
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
                LabeledContent("Compression", value: dataset.compressionRatio > 1.05
                    ? String(format: "%.2fx", dataset.compressionRatio) : "1.00x (off)")
                LabeledContent("Dedup", value: dataset.deduplicationRatio > 1.05
                    ? String(format: "%.2fx", dataset.deduplicationRatio) : "Off")
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
                    Text(snapshot.created, format: .dateTime.month().day().year().hour().minute())
                        .font(.caption).foregroundStyle(.secondary)
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

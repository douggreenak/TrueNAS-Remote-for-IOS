import SwiftUI

struct SharesView: View {
    @Environment(SharesViewModel.self)   private var vm
    @Environment(SettingsViewModel.self) private var settings
    @State private var segment = 0   // 0=SMB 1=NFS 2=iSCSI

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Share Type", selection: $segment) {
                    Text("SMB").tag(0)
                    Text("NFS").tag(1)
                    Text("iSCSI").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal).padding(.vertical, 8)

                Group {
                    switch segment {
                    case 0: smbList
                    case 1: nfsList
                    default: iscsiList
                    }
                }
            }
            .navigationTitle("Shares")
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

    // MARK: - SMB
    private var smbList: some View {
        Group {
            if vm.smbShares.isEmpty {
                ContentUnavailableView("No SMB Shares",
                    systemImage: "folder.fill.badge.person.crop",
                    description: Text("No Windows shares configured."))
            } else {
                List(vm.smbShares) { share in
                    SMBShareRow(share: share) {
                        Task { await vm.toggleSMB(share: share) }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    // MARK: - NFS
    private var nfsList: some View {
        Group {
            if vm.nfsShares.isEmpty {
                ContentUnavailableView("No NFS Exports",
                    systemImage: "folder.fill.badge.gearshape",
                    description: Text("No NFS exports configured."))
            } else {
                List(vm.nfsShares) { share in
                    NFSShareRow(share: share)
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    // MARK: - iSCSI
    private var iscsiList: some View {
        Group {
            if vm.iscsiTargets.isEmpty && vm.iscsiExtents.isEmpty {
                ContentUnavailableView("No iSCSI Config",
                    systemImage: "externaldrive.connected.to.line.below",
                    description: Text("No iSCSI targets or extents."))
            } else {
                List {
                    if !vm.iscsiTargets.isEmpty {
                        Section("Targets") {
                            ForEach(vm.iscsiTargets) { target in
                                ISCSITargetRow(target: target)
                            }
                        }
                    }
                    if !vm.iscsiExtents.isEmpty {
                        Section("Extents") {
                            ForEach(vm.iscsiExtents) { extent in
                                ISCSIExtentRow(extent: extent)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }
}

// MARK: - SMB Share Row
private struct SMBShareRow: View {
    let share: SMBShare
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: share.enabled ? "folder.fill" : "folder")
                .foregroundStyle(share.enabled ? .blue : .secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(share.name).font(.body.weight(.medium))
                Text(share.path).font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1)
                if !share.comment.isEmpty {
                    Text(share.comment).font(.caption).foregroundStyle(.tertiary).lineLimit(1)
                }
                HStack(spacing: 8) {
                    if share.readOnly  { Tag("Read-only", color: .orange) }
                    if share.guestOk   { Tag("Guest OK",  color: .yellow) }
                    if share.browsable { Tag("Browsable", color: .blue)   }
                }
            }
            Spacer()
            Toggle("", isOn: .init(get: { share.enabled }, set: { _ in onToggle() }))
                .labelsHidden()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - NFS Share Row
private struct NFSShareRow: View {
    let share: NFSShare

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: share.enabled ? "folder.fill.badge.gear" : "folder.badge.gear")
                .foregroundStyle(share.enabled ? .blue : .secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(share.path).font(.body.weight(.medium)).lineLimit(1)
                if !share.comment.isEmpty {
                    Text(share.comment).font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    ForEach(share.networks, id: \.self) { net in
                        Text(net).font(.caption2.monospaced()).foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 8) {
                    if share.readOnly { Tag("Read-only", color: .orange) }
                    if share.alldirs  { Tag("All dirs",  color: .blue) }
                    if !share.mapallUser.isEmpty {
                        Tag("mapall:\(share.mapallUser)", color: .purple)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - iSCSI Rows
private struct ISCSITargetRow: View {
    let target: ISCSITarget

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "externaldrive.connected.to.line.below").foregroundStyle(.blue)
                Text(target.name).font(.body.weight(.medium))
                Spacer()
                Text(target.mode).font(.caption).foregroundStyle(.secondary)
            }
            Text(target.iqn).font(.caption2.monospaced()).foregroundStyle(.secondary).lineLimit(1)
            if !target.alias.isEmpty {
                Text(target.alias).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct ISCSIExtentRow: View {
    let extent: ISCSIExtent

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "cylinder.fill").foregroundStyle(extent.enabled ? .orange : .secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(extent.name).font(.body.weight(.medium))
                Text(extent.path).font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Text(formatBytes(extent.size)).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func formatBytes(_ b: Int64) -> String {
        let gb = Double(b) / 1_073_741_824
        if gb >= 1024 { return String(format: "%.1f TB", gb / 1024) }
        return String(format: "%.0f GB", gb)
    }
}

// MARK: - Tag
private struct Tag: View {
    let text: String
    let color: Color
    init(_ text: String, color: Color) { self.text = text; self.color = color }
    var body: some View {
        Text(text)
            .font(.caption2.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(color.opacity(0.12), in: Capsule())
    }
}

#Preview {
    SharesView()
        .environment(SharesViewModel())
        .environment(SettingsViewModel())
}

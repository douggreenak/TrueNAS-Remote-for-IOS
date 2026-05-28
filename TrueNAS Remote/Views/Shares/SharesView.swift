import SwiftUI

struct SharesView: View {
    @Environment(SharesViewModel.self)   private var vm
    @Environment(SettingsViewModel.self) private var settings
    @State private var segment = 0   // 0=SMB 1=NFS 2=iSCSI

    private let tabs: [(label: String, icon: String)] = [
        ("SMB",   "pc"),
        ("NFS",   "server.rack"),
        ("iSCSI", "externaldrive.connected.to.line.below.fill"),
    ]
    @Namespace private var tabNS

    var body: some View {
        tabContent
            .animation(.none, value: segment)   // instant switch, no flicker
            .pageLoading(vm.isLoading && vm.smbShares.isEmpty && vm.nfsShares.isEmpty)
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    tabBar
                    Divider()
                }
            }
            .navigationTitle("Shares")
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

    @ViewBuilder private var tabContent: some View {
        switch segment {
        case 0: smbList
        case 1: nfsList
        default: iscsiList
        }
    }

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
                                        .matchedGeometryEffect(id: "shrTab", in: tabNS)
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

    // MARK: - SMB
    private var smbList: some View {
        Group {
            if vm.isLoading && vm.smbShares.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.smbShares.isEmpty {
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
                .refreshable { await vm.refresh() }
            }
        }
    }

    // MARK: - NFS
    private var nfsList: some View {
        Group {
            if vm.isLoading && vm.nfsShares.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.nfsShares.isEmpty {
                ContentUnavailableView("No NFS Exports",
                    systemImage: "folder.fill.badge.gearshape",
                    description: Text("No NFS exports configured."))
            } else {
                List(vm.nfsShares) { share in
                    NFSShareRow(share: share)
                }
                .listStyle(.insetGrouped)
                .refreshable { await vm.refresh() }
            }
        }
    }

    // MARK: - iSCSI
    private var iscsiList: some View {
        Group {
            if vm.isLoading && vm.iscsiTargets.isEmpty && vm.iscsiExtents.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.iscsiTargets.isEmpty && vm.iscsiExtents.isEmpty {
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
                .refreshable { await vm.refresh() }
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
            VStack(alignment: .leading, spacing: 3) {
                Text(share.name).font(.body.weight(.medium))
                Text(share.path)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if !share.comment.isEmpty {
                    Text(share.comment)
                        .font(.caption).foregroundStyle(.tertiary).lineLimit(1)
                }
                if share.readOnly || share.guestOk || share.browsable {
                    HStack(spacing: 6) {
                        if share.readOnly  { Tag("Read-only", color: .orange) }
                        if share.guestOk   { Tag("Guest OK",  color: .yellow) }
                        if share.browsable { Tag("Browsable", color: .blue)   }
                    }
                }
            }
            Spacer(minLength: 8)
            Toggle("Enable \(share.name)", isOn: .init(get: { share.enabled }, set: { _ in onToggle() }))
                .labelsHidden()
        }
        .padding(.vertical, 4)
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
            Spacer()
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
        ByteCountFormatter.string(fromByteCount: b, countStyle: .binary)
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

import SwiftUI

struct PoolDetailView: View {
    let pool: StoragePool
    @Environment(StorageViewModel.self) private var vm
    @State private var showScrubAlert = false
    @State private var selectedSegment = 0

    var body: some View {
        List {
            // ── Health banner ─────────────────────────────────────────
            Section {
                HStack(spacing: 14) {
                    Image(systemName: pool.status.icon)
                        .font(.system(size: 36))
                        .foregroundStyle(pool.status.color)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pool.status.label)
                            .font(.title2.bold())
                            .foregroundStyle(pool.status.color)
                        HStack(spacing: 12) {
                            Label("\(pool.disks.count) disk\(pool.disks.count == 1 ? "" : "s")",
                                  systemImage: "internaldrive")
                                .font(.caption).foregroundStyle(.secondary)
                            Label("\(pool.vdevs.count) VDEV\(pool.vdevs.count == 1 ? "" : "s")",
                                  systemImage: "cylinder.split.1x2")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if pool.totalErrors > 0 {
                        VStack(spacing: 2) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("\(pool.totalErrors) error\(pool.totalErrors == 1 ? "" : "s")")
                                .font(.caption2.bold()).foregroundStyle(.orange)
                        }
                    }
                }
                .padding(.vertical, 6)
            }

            // ── Capacity ──────────────────────────────────────────────
            Section("Capacity") {
                LabeledContent("Total",     value: pool.formattedTotal).textSelection(.enabled)
                LabeledContent("Used",      value: pool.formattedUsed).textSelection(.enabled)
                LabeledContent("Free",      value: pool.formattedFree).textSelection(.enabled)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Usage")
                        Spacer()
                        Text(String(format: "%.1f%%", pool.usedFraction * 100))
                            .foregroundStyle(.secondary)
                    }
                    CapacityBar(fraction: pool.usedFraction)
                }
            }

            // ── Errors ───────────────────────────────────────────────
            if pool.totalErrors > 0 {
                Section("Errors") {
                    HStack {
                        Text("Read")
                        Spacer()
                        Text("\(pool.readErrors)")
                            .foregroundStyle(pool.readErrors > 0 ? Color.red : Color.secondary)
                            .fontWeight(pool.readErrors > 0 ? .semibold : .regular)
                    }
                    HStack {
                        Text("Write")
                        Spacer()
                        Text("\(pool.writeErrors)")
                            .foregroundStyle(pool.writeErrors > 0 ? Color.red : Color.secondary)
                            .fontWeight(pool.writeErrors > 0 ? .semibold : .regular)
                    }
                    HStack {
                        Text("Checksum")
                        Spacer()
                        Text("\(pool.checksumErrors)")
                            .foregroundStyle(pool.checksumErrors > 0 ? Color.orange : Color.secondary)
                            .fontWeight(pool.checksumErrors > 0 ? .semibold : .regular)
                    }
                }
            }

            // ── Last Scrub ───────────────────────────────────────────
            Section("Maintenance") {
                if let d = pool.lastScrub {
                    LabeledContent("Last Scrub") {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(d, format: .dateTime.month(.abbreviated).day().year())
                                .font(.subheadline)
                            Text(d, style: .relative)
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                } else {
                    LabeledContent("Last Scrub", value: "Never")
                }
                if let s = pool.lastScrubStatus {
                    HStack {
                        Text("Scrub Result")
                        Spacer()
                        Text(s.capitalized)
                            .foregroundStyle(s.lowercased().contains("finish") ? Color.green
                                             : s.lowercased().contains("error") ? Color.red : Color.primary)
                            .font(.subheadline.weight(.medium))
                    }
                }
                Button { showScrubAlert = true } label: {
                    Label("Start Scrub", systemImage: "wand.and.sparkles")
                }
            }

            // ── VDEVs ────────────────────────────────────────────────
            if !pool.vdevs.isEmpty {
                Section("VDEVs") {
                    ForEach(pool.vdevs) { vdev in
                        VDEVRow(vdev: vdev)
                    }
                }
            }

            // ── Disks ────────────────────────────────────────────────
            if !pool.disks.isEmpty {
                Section("Disks (\(pool.disks.count))") {
                    ForEach(pool.disks) { disk in
                        DiskRow(disk: disk)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(.compact)
        .navigationTitle(pool.name)
        .toolbarTitleDisplayMode(.inline)
        .alert("Start Scrub?", isPresented: $showScrubAlert) {
            Button("Scrub", role: .destructive) { Task { await vm.scrub(pool: pool) } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("A scrub will check all data on \"\(pool.name)\" for errors. This may take hours.")
        }
    }
}

// MARK: - Sub-views
private struct VDEVRow: View {
    let vdev: VDEV
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: vdev.type.icon)
                .foregroundStyle(vdev.status.color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(vdev.type.label).font(.subheadline.weight(.medium))
                Text("\(vdev.disks.count) disk\(vdev.disks.count == 1 ? "" : "s")")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Label(vdev.status.label, systemImage: vdev.status == .online
                  ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.caption.bold())
                .foregroundStyle(vdev.status.color)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(vdev.status.color.opacity(0.1), in: Capsule())
        }
    }
}

private struct DiskRow: View {
    let disk: Disk
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "internaldrive.fill").foregroundStyle(.tint)
                Text(disk.id).font(.headline)
                Spacer()
                Label(disk.smartStatus == .passed ? "SMART OK" : disk.smartStatus.rawValue,
                      systemImage: disk.smartStatus.icon)
                    .font(.caption.bold())
                    .foregroundStyle(disk.smartStatus.color)
            }
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(disk.model).font(.caption).foregroundStyle(.secondary)
                    Text("S/N: \(disk.serial)").font(.caption2).foregroundStyle(.tertiary).textSelection(.enabled)
                }
                Spacer()
                if let t = disk.temperature {
                    Label("\(t)°C", systemImage: "thermometer.medium")
                        .font(.caption).foregroundStyle(disk.temperatureColor)
                }
            }
            if disk.totalErrors > 0 {
                Label("\(disk.totalErrors) error(s)", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    let tb: Int64 = 1_099_511_627_776
    let disks = [
        Disk(id: "sda", serial: "WD-WXB1A34TPZ8F", model: "WDC WD80EAZZ", size: tb,
             temperature: 38, powerOnHours: 12000, poolName: "tank", smartStatus: .passed,
             readErrors: 0, writeErrors: 0, checksumErrors: 0, smartResults: []),
        Disk(id: "sdb", serial: "WD-WXB1A34TRK9G", model: "WDC WD80EAZZ", size: tb,
             temperature: nil, powerOnHours: 11500, poolName: "tank", smartStatus: .unknown,
             readErrors: 1, writeErrors: 0, checksumErrors: 2, smartResults: [])
    ]
    NavigationStack {
        PoolDetailView(pool: StoragePool(
            id: 1, name: "tank", status: .degraded,
            usedBytes: Int64(3.2 * Double(tb)), totalBytes: Int64(7.2 * Double(tb)),
            freeBytes: Int64(4.0 * Double(tb)),
            vdevs: [VDEV(id: "v0", type: .data, status: .degraded, disks: disks)],
            disks: disks, readErrors: 1, writeErrors: 0, checksumErrors: 2,
            lastScrub: Date(), lastScrubStatus: "FINISHED"
        ))
    }
    .environment(StorageViewModel())
}

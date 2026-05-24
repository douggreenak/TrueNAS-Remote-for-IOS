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
                HStack {
                    Image(systemName: pool.status.icon)
                        .font(.largeTitle)
                        .foregroundStyle(pool.status.color)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pool.status.label)
                            .font(.title2.bold())
                            .foregroundStyle(pool.status.color)
                        Text("\(pool.disks.count) disks · \(pool.vdevs.count) VDEVs")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 6)
            }

            // ── Capacity ──────────────────────────────────────────────
            Section("Capacity") {
                LabeledContent("Total",     value: pool.formattedTotal)
                LabeledContent("Used",      value: pool.formattedUsed)
                LabeledContent("Free",      value: pool.formattedFree)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Usage")
                        Spacer()
                        Text(String(format: "%.1f%%", pool.usedFraction * 100))
                            .foregroundStyle(.secondary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.secondary.opacity(0.2)).frame(height: 8)
                            Capsule()
                                .fill(pool.usedFraction > 0.9 ? Color.red
                                      : pool.usedFraction > 0.75 ? Color.orange : Color.blue)
                                .frame(width: geo.size.width * pool.usedFraction, height: 8)
                        }
                    }.frame(height: 8)
                }
            }

            // ── Errors ───────────────────────────────────────────────
            if pool.totalErrors > 0 {
                Section("Errors") {
                    LabeledContent("Read",     value: "\(pool.readErrors)")
                        .foregroundStyle(pool.readErrors > 0 ? .red : .primary)
                    LabeledContent("Write",    value: "\(pool.writeErrors)")
                        .foregroundStyle(pool.writeErrors > 0 ? .red : .primary)
                    LabeledContent("Checksum", value: "\(pool.checksumErrors)")
                        .foregroundStyle(pool.checksumErrors > 0 ? .orange : .primary)
                }
            }

            // ── Last Scrub ───────────────────────────────────────────
            Section("Maintenance") {
                if let d = pool.lastScrub {
                    LabeledContent("Last Scrub", value: d.formatted(date: .abbreviated, time: .shortened))
                }
                if let s = pool.lastScrubStatus {
                    LabeledContent("Scrub Result", value: s.capitalized)
                }
                Button(role: .none) { showScrubAlert = true } label: {
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
        .navigationTitle(pool.name)
        .navigationBarTitleDisplayMode(.large)
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
        HStack {
            Image(systemName: vdev.type.icon).foregroundStyle(.tint).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(vdev.type.label).font(.subheadline.weight(.medium))
                Text("\(vdev.disks.count) disk(s)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Circle().fill(vdev.status.color).frame(width: 8, height: 8)
            Text(vdev.status.label).font(.caption).foregroundStyle(vdev.status.color)
        }
    }
}

private struct DiskRow: View {
    let disk: Disk
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "internaldrive.fill").foregroundStyle(.tint)
                Text(disk.id.uppercased()).font(.headline)
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

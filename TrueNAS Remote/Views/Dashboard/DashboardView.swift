import SwiftUI
import Charts

struct DashboardView: View {
    @Environment(DashboardViewModel.self) private var vm
    @Environment(StorageViewModel.self)   private var storage
    @Environment(SystemViewModel.self)    private var system
    @Environment(SettingsViewModel.self)  private var settings

    private let cols = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    updateBanner
                    alertBanner
                    systemCard
                    metricsGrid
                    networkCard
                    poolHealthSection
                    temperatureSection
                }
                .padding()
            }
            .refreshable { await vm.refresh() }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
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
        }
    }

    // MARK: - Update Banner
    @ViewBuilder private var updateBanner: some View {
        if vm.systemInfo.updateAvailable, let v = vm.systemInfo.updateVersion {
            HStack(spacing: 10) {
                Image(systemName: "arrow.up.circle.fill").foregroundStyle(.blue).font(.title3)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Update Available").font(.subheadline.bold())
                    Text(v).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary).font(.caption)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.blue.opacity(0.3), lineWidth: 1))
        }
    }

    // MARK: - Alert Banner
    @ViewBuilder private var alertBanner: some View {
        if !system.activeAlerts.isEmpty {
            let top = system.activeAlerts.prefix(2)
            VStack(spacing: 6) {
                ForEach(top) { alert in
                    HStack(spacing: 10) {
                        Image(systemName: alert.level.icon).foregroundStyle(alert.level.color)
                        Text(alert.message).font(.caption).lineLimit(2)
                        Spacer()
                        Text(alert.relativeTime).font(.caption2).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(alert.level.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    // MARK: - System Card
    private var systemCard: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(vm.systemInfo.hostname)
                    .font(.title.bold())
                HStack(spacing: 6) {
                    Image(systemName: "clock").foregroundStyle(.secondary)
                    Text(vm.systemInfo.formattedUptime)
                        .font(.subheadline).foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Text(vm.systemInfo.version)
                    .font(.caption).foregroundStyle(.tertiary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                loadIndicator("1m",  value: vm.systemInfo.loadAvg1)
                loadIndicator("5m",  value: vm.systemInfo.loadAvg5)
                loadIndicator("15m", value: vm.systemInfo.loadAvg15)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func loadIndicator(_ label: String, value: Double) -> some View {
        HStack(spacing: 4) {
            Text(label).font(.caption2).foregroundStyle(.tertiary)
            Text(String(format: "%.2f", value))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(value > 4 ? .red : value > 2 ? .orange : .secondary)
        }
    }

    // MARK: - CPU + RAM Grid
    private var metricsGrid: some View {
        LazyVGrid(columns: cols, spacing: 12) {
            ringCard(value: vm.systemInfo.cpuUsage / 100, label: "CPU",
                     color: cpuColor(vm.systemInfo.cpuUsage),
                     sub: String(format: "%.1f%%", vm.systemInfo.cpuUsage),
                     history: vm.cpuHistory)
            ringCard(value: vm.systemInfo.memoryUsedFraction, label: "RAM",
                     color: ramColor(vm.systemInfo.memoryUsedFraction),
                     sub: vm.systemInfo.formattedMemory,
                     history: nil)
        }
    }

    @ViewBuilder
    private func ringCard(value: Double, label: String, color: Color, sub: String, history: [ReportingPoint]?) -> some View {
        VStack(spacing: 10) {
            CircularProgressRing(value: value, label: label, color: color)
                .frame(height: 120)
            if let h = history, !h.isEmpty {
                MiniSparkline(points: h.map(\.value), color: color)
                    .frame(height: 30)
            }
            Text(sub)
                .font(.caption2).foregroundStyle(.secondary)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Network Card
    @ViewBuilder private var networkCard: some View {
        MetricCard(title: "Network I/O", icon: "network") {
            if vm.networkSeries.isEmpty {
                Text("No data")
                    .font(.caption).foregroundStyle(.tertiary)
            } else {
                Chart {
                    ForEach(vm.networkSeries) { series in
                        ForEach(series.points) { pt in
                            LineMark(x: .value("t", pt.time), y: .value("MB/s", pt.value / 1e6))
                                .foregroundStyle(by: .value("Direction", series.name))
                        }
                    }
                }
                .chartLegend(position: .trailing, alignment: .center)
                .frame(height: 80)
            }
        }
    }

    // MARK: - Pool Health
    private var poolHealthSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Storage Pools", systemImage: "externaldrive.fill")
                .font(.headline)
            if storage.pools.isEmpty {
                Text("No pools").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(storage.pools) { pool in
                    poolMiniCard(pool)
                }
            }
        }
    }

    private func poolMiniCard(_ pool: StoragePool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: pool.status.icon).foregroundStyle(pool.status.color)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(pool.name).font(.subheadline.weight(.medium))
                    Spacer()
                    Text(String(format: "%.0f%%", pool.usedFraction * 100))
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                CapacityBar(fraction: pool.usedFraction)
                HStack {
                    Text(pool.formattedUsed).font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Text(pool.formattedTotal).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Temperature
    private var temperatureSection: some View {
        MetricCard(title: "CPU Temperature", icon: "thermometer.medium") {
            if vm.temperatures.isEmpty {
                Text("No data").font(.caption).foregroundStyle(.tertiary)
            } else {
                TemperatureChartView(data: vm.temperatures)
            }
        }
    }

    // MARK: - Color helpers
    private func cpuColor(_ pct: Double) -> Color {
        pct > 85 ? .red : pct > 60 ? .orange : .blue
    }
    private func ramColor(_ frac: Double) -> Color {
        frac > 0.9 ? .red : frac > 0.75 ? .orange : .purple
    }
}

// MARK: - Mini sparkline
private struct MiniSparkline: View {
    let points: [Double]
    let color: Color
    var body: some View {
        Chart {
            ForEach(Array(points.enumerated()), id: \.offset) { i, v in
                LineMark(x: .value("i", i), y: .value("v", v))
                    .interpolationMethod(.catmullRom)
                AreaMark(x: .value("i", i), y: .value("v", v))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(LinearGradient(colors: [color.opacity(0.3), color.opacity(0)], startPoint: .top, endPoint: .bottom))
            }
        }
        .foregroundStyle(color)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }
}

#Preview {
    DashboardView()
        .environment(DashboardViewModel())
        .environment(StorageViewModel())
        .environment(SystemViewModel())
        .environment(SettingsViewModel())
}

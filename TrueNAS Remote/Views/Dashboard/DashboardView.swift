import SwiftUI
import Charts

struct DashboardView: View {
    @Environment(DashboardViewModel.self) private var vm
    @Environment(StorageViewModel.self)   private var storage
    @Environment(SystemViewModel.self)    private var system
    @Environment(SettingsViewModel.self)  private var settings

    private let cols = [GridItem(.flexible()), GridItem(.flexible())]
    /// Manually managed so it can be cancelled when the tab goes off-screen.
    @State private var pollingTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                updateBanner
                if settings.showAlertBanner    { alertBanner }
                systemCard
                metricsGrid
                if settings.showNetworkCard    { networkCard }
                if settings.showPoolHealthCard { poolHealthSection }
                if settings.showTemperatureCard { temperatureSection }
            }
            .padding()
        }
        .pageLoading(vm.isLoading && vm.systemInfo.memoryTotal == 0)
        .refreshable {
            await vm.refresh()
            await vm.refreshCharts()   // pull-to-refresh also reloads charts immediately
        }
        .navigationTitle("Dashboard")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                // Show spinner while either system info or charts are loading
                if vm.isLoading || vm.isLoadingCharts {
                    ProgressView().controlSize(.small)
                }
            }
        }
        .onAppear  { startPolling() }
        .onDisappear { pollingTask?.cancel(); pollingTask = nil }
    }

    private func startPolling() {
        guard pollingTask == nil || pollingTask?.isCancelled == true else { return }
        pollingTask = Task {
            // Fast path: system.info first, then fire chart refresh in background
            await vm.refresh()
            // Load pool health data if the card is visible and pools haven't been fetched yet.
            // Using a lightweight "pools only" fetch to avoid triggering the full disk scan.
            if settings.showPoolHealthCard && storage.pools.isEmpty {
                Task { await storage.refreshPoolsOnly() }
            }
            // Polling loop — only runs while tab is visible and auto-refresh is enabled
            while !Task.isCancelled && settings.refreshInterval > 0 {
                try? await Task.sleep(for: .seconds(settings.refreshInterval))
                guard !Task.isCancelled else { return }
                await vm.refresh()
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
            let extra = system.activeAlerts.count - 2
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
                if extra > 0 {
                    Text("+ \(extra) more alert\(extra == 1 ? "" : "s")")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, 4)
                }
            }
        }
    }

    // MARK: - System Card
    private var systemCard: some View {
        NavigationLink(destination: SystemSummaryDetailView(vm: vm)) {
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(vm.systemInfo.hostname)
                        .font(.title2.bold())
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Image(systemName: "clock").foregroundStyle(.secondary).font(.caption)
                        Text("Up \(vm.systemInfo.formattedUptime)")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Text(vm.systemInfo.version)
                        .font(.caption).foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 5) {
                    Text("Load Average").font(.caption2).foregroundStyle(.tertiary)
                    HStack(spacing: 8) {
                        loadIndicator("1m",  value: vm.systemInfo.loadAvg1)
                        loadIndicator("5m",  value: vm.systemInfo.loadAvg5)
                        loadIndicator("15m", value: vm.systemInfo.loadAvg15)
                    }
                }
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                    .padding(.leading, 8)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private func loadIndicator(_ label: String, value: Double) -> some View {
        VStack(spacing: 1) {
            Text(String(format: "%.2f", value))
                .font(.caption.monospacedDigit().bold())
                .foregroundStyle(value > 4 ? .red : value > 2 ? .orange : .primary)
            Text(label).font(.caption2).foregroundStyle(.tertiary)
        }
    }

    // MARK: - CPU + RAM Grid
    private var metricsGrid: some View {
        LazyVGrid(columns: cols, spacing: 12) {
            NavigationLink(destination: CPUDetailView(vm: vm)) {
                ringCard(value: vm.systemInfo.cpuUsage / 100, label: "CPU",
                         color: cpuColor(vm.systemInfo.cpuUsage),
                         sub: String(format: "%.1f%%", vm.systemInfo.cpuUsage))
            }
            .buttonStyle(.plain)

            NavigationLink(destination: MemoryDetailView(vm: vm)) {
                ringCard(value: vm.systemInfo.memoryUsedFraction, label: "RAM",
                         color: .purple,
                         sub: vm.systemInfo.formattedMemory)
            }
            .buttonStyle(.plain)
        }
    }

    // Sparklines are in CPUDetailView / MemoryDetailView, not on the dashboard cards.
    private func ringCard(value: Double, label: String, color: Color, sub: String) -> some View {
        VStack(spacing: 8) {
            CircularProgressRing(value: value, label: label, color: color)
                .frame(height: 110)
            Text(sub)
                .font(.caption2).foregroundStyle(.secondary)
                .lineLimit(1).minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .center)
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
                let colors: [Color] = [.blue, .orange, .green, .purple]
                Chart {
                    ForEach(Array(vm.networkSeries.enumerated()), id: \.offset) { idx, series in
                        ForEach(series.points) { pt in
                            LineMark(x: .value("t", pt.time), y: .value("MB/s", pt.value / 1e6))
                                .foregroundStyle(colors[idx % colors.count])
                                .interpolationMethod(.catmullRom)
                        }
                    }
                }
                .chartLegend(.hidden)
                .chartYAxis {
                    AxisMarks(position: .trailing) { v in
                        AxisGridLine()
                        AxisValueLabel {
                            if let d = v.as(Double.self) {
                                Text(String(format: "%.1f", d)).font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 80)
                // Compact legend below chart
                HStack(spacing: 12) {
                    ForEach(Array(vm.networkSeries.enumerated()), id: \.offset) { idx, series in
                        Label(series.name, systemImage: "circle.fill")
                            .foregroundStyle(colors[idx % colors.count])
                            .font(.caption2)
                    }
                }
            }
        }
    }

    // MARK: - Pool Health
    private var poolHealthSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Storage Pools", systemImage: "externaldrive.fill")
                    .font(.headline)
                Spacer()
                if !storage.pools.isEmpty {
                    Text("\(storage.pools.count) pool\(storage.pools.count == 1 ? "" : "s")")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if storage.isLoading && storage.pools.isEmpty {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Loading pools…").font(.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else if storage.pools.isEmpty {
                Text("No pools found")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(storage.pools) { pool in
                    NavigationLink(destination: PoolDetailView(pool: pool)) {
                        poolMiniCard(pool)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func poolMiniCard(_ pool: StoragePool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: pool.status.icon).foregroundStyle(pool.status.color)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(pool.name).font(.subheadline.weight(.medium))
                    Spacer()
                    HealthBadge(status: pool.status)
                }
                CapacityBar(fraction: pool.usedFraction)
                HStack {
                    Text(pool.formattedUsed).font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.0f%% of \(pool.formattedTotal)", pool.usedFraction * 100))
                        .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
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
                VStack(alignment: .leading, spacing: 4) {
                    if let latest = vm.temperatures.last {
                        HStack {
                            Text(String(format: "%.0f °C", latest.value))
                                .font(.title3.bold().monospacedDigit())
                                .foregroundStyle(latest.value > 80 ? .red : latest.value > 60 ? .orange : .primary)
                            Text("current")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    TemperatureChartView(data: vm.temperatures)
                        .clipped()
                }
            }
        }
    }

    // MARK: - Color helpers
    // CPU changes color with load; RAM stays purple (high usage is normal with ZFS ARC)
    private func cpuColor(_ pct: Double) -> Color {
        pct > 85 ? .red : pct > 60 ? .orange : .blue
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

// MARK: - Generic Metric Detail (CPU / RAM)
struct MetricDetailView: View {
    let title: String
    let icon: String
    let color: Color
    let headline: String
    let subtitle: String
    let history: [ReportingPoint]?
    let yLabel: String
    let yDomain: ClosedRange<Double>?

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    Image(systemName: icon)
                        .font(.largeTitle)
                        .foregroundStyle(color)
                        .frame(width: 44)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(headline).font(.title.bold().monospacedDigit())
                            .foregroundStyle(color)
                        Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            if let h = history, !h.isEmpty {
                Section("History") {
                    Chart {
                        ForEach(Array(h.enumerated()), id: \.offset) { i, pt in
                            LineMark(x: .value("t", pt.time), y: .value(yLabel, pt.value))
                                .foregroundStyle(color)
                                .interpolationMethod(.catmullRom)
                            AreaMark(x: .value("t", pt.time), y: .value(yLabel, pt.value))
                                .foregroundStyle(color.opacity(0.15))
                                .interpolationMethod(.catmullRom)
                        }
                    }
                    .if(yDomain != nil) { $0.chartYScale(domain: yDomain!) }
                    .chartXAxis(.hidden)
                    .frame(height: 160)
                    .padding(.vertical, 4)
                }
            } else {
                Section("History") {
                    Text("No history available").font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(title)
        .toolbarTitleDisplayMode(.inline)
        .listStyle(.insetGrouped)
    }
}

private extension View {
    @ViewBuilder func `if`<T: View>(_ condition: Bool, transform: (Self) -> T) -> some View {
        if condition { transform(self) } else { self }
    }
}

// MARK: - System Summary Detail (pushed from Dashboard system card)
struct SystemSummaryDetailView: View {
    let vm: DashboardViewModel

    var body: some View {
        List {
            Section("System") {
                LabeledContent("Hostname", value: vm.systemInfo.hostname)
                LabeledContent("Version",  value: vm.systemInfo.version)
                LabeledContent("Uptime",   value: vm.systemInfo.formattedUptime)
                    .monospacedDigit()
            }
            Section("Performance") {
                HStack {
                    Text("CPU Usage")
                    Spacer()
                    Text(String(format: "%.1f%%", vm.systemInfo.cpuUsage))
                        .foregroundStyle(vm.systemInfo.cpuUsage > 85 ? .red
                                       : vm.systemInfo.cpuUsage > 60 ? .orange : .primary)
                        .fontWeight(.medium)
                }
                HStack {
                    Text("Memory Used")
                    Spacer()
                    Text(vm.systemInfo.formattedMemory).fontWeight(.medium)
                }
            }
            Section("Load Average") {
                LabeledContent("1 min",  value: String(format: "%.2f", vm.systemInfo.loadAvg1))
                LabeledContent("5 min",  value: String(format: "%.2f", vm.systemInfo.loadAvg5))
                LabeledContent("15 min", value: String(format: "%.2f", vm.systemInfo.loadAvg15))
            }
            if !vm.cpuHistory.isEmpty {
                Section("CPU History") {
                    Chart {
                        ForEach(Array(vm.cpuHistory.enumerated()), id: \.offset) { i, pt in
                            LineMark(x: .value("t", pt.time), y: .value("CPU %", pt.value))
                                .foregroundStyle(.blue)
                                .interpolationMethod(.catmullRom)
                            AreaMark(x: .value("t", pt.time), y: .value("CPU %", pt.value))
                                .foregroundStyle(.blue.opacity(0.15))
                                .interpolationMethod(.catmullRom)
                        }
                    }
                    .chartYScale(domain: 0...100)
                    .chartXAxis(.hidden)
                    .frame(height: 120)
                }
            }
            if !vm.temperatures.isEmpty {
                Section("CPU Temperature") {
                    HStack {
                        Text("Current")
                        Spacer()
                        if let t = vm.temperatures.last?.value {
                            Text(String(format: "%.0f °C", t))
                                .foregroundStyle(t > 80 ? .red : t > 60 ? .orange : .primary)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
        }
        .navigationTitle(vm.systemInfo.hostname)
        .toolbarTitleDisplayMode(.inline)
        .listStyle(.insetGrouped)
        .listSectionSpacing(.compact)
    }
}

// MARK: - CPU Detail View
struct CPUDetailView: View {
    let vm: DashboardViewModel

    private var color: Color {
        vm.systemInfo.cpuUsage > 85 ? .red : vm.systemInfo.cpuUsage > 60 ? .orange : .blue
    }

    var body: some View {
        List {
            // Current usage header
            Section {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 8)
                        Circle()
                            .trim(from: 0, to: vm.systemInfo.cpuUsage / 100)
                            .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 56, height: 56)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(format: "%.1f%%", vm.systemInfo.cpuUsage))
                            .font(.title.bold().monospacedDigit())
                            .foregroundStyle(color)
                        Text("Current CPU Usage")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            // Load averages
            Section("Load Average") {
                cpuLoadRow("1 Minute",   value: vm.systemInfo.loadAvg1)
                cpuLoadRow("5 Minutes",  value: vm.systemInfo.loadAvg5)
                cpuLoadRow("15 Minutes", value: vm.systemInfo.loadAvg15)
            }

            // CPU history chart
            if !vm.cpuHistory.isEmpty {
                Section("1-Hour History") {
                    Chart {
                        ForEach(Array(vm.cpuHistory.enumerated()), id: \.offset) { _, pt in
                            LineMark(x: .value("Time", pt.time), y: .value("CPU %", pt.value))
                                .foregroundStyle(color)
                                .interpolationMethod(.catmullRom)
                            AreaMark(x: .value("Time", pt.time), y: .value("CPU %", pt.value))
                                .foregroundStyle(color.opacity(0.15))
                                .interpolationMethod(.catmullRom)
                        }
                    }
                    .chartYScale(domain: 0...100)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .minute, count: 15)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.hour().minute())
                        }
                    }
                    .chartYAxis {
                        AxisMarks { v in
                            AxisGridLine()
                            AxisValueLabel {
                                if let d = v.as(Double.self) {
                                    Text(String(format: "%.0f%%", d)).font(.caption2)
                                }
                            }
                        }
                    }
                    .frame(height: 160)
                    .padding(.vertical, 4)
                }
            }

            // Temperature
            if !vm.temperatures.isEmpty {
                Section("CPU Temperature") {
                    if let latest = vm.temperatures.last {
                        HStack {
                            Text("Current")
                            Spacer()
                            Text(String(format: "%.0f °C", latest.value))
                                .fontWeight(.medium).monospacedDigit()
                                .foregroundStyle(latest.value > 80 ? .red : latest.value > 60 ? .orange : .primary)
                        }
                    }
                    Chart {
                        ForEach(Array(vm.temperatures.enumerated()), id: \.offset) { _, pt in
                            LineMark(x: .value("Time", pt.time), y: .value("°C", pt.value))
                                .foregroundStyle(.orange)
                                .interpolationMethod(.catmullRom)
                            AreaMark(x: .value("Time", pt.time), y: .value("°C", pt.value))
                                .foregroundStyle(.orange.opacity(0.15))
                                .interpolationMethod(.catmullRom)
                        }
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis {
                        AxisMarks(position: .leading) { v in
                            AxisGridLine()
                            AxisValueLabel {
                                if let d = v.as(Double.self) {
                                    Text(String(format: "%.0f°", d)).font(.caption2)
                                }
                            }
                        }
                    }
                    .frame(height: 100)
                    .clipped()
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("CPU Details")
        .toolbarTitleDisplayMode(.inline)
        .listStyle(.insetGrouped)
        .listSectionSpacing(.compact)
    }

    private func cpuLoadRow(_ label: String, value: Double) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(String(format: "%.2f", value))
                .fontWeight(.medium).monospacedDigit()
                .foregroundStyle(value > 4 ? .red : value > 2 ? .orange : .primary)
        }
    }
}

// MARK: - Memory Detail View
struct MemoryDetailView: View {
    let vm: DashboardViewModel

    private var appsUsed: Int64 {
        max(0, vm.systemInfo.memoryUsed - vm.systemInfo.memoryZFSCache)
    }
    private var arcUsed:  Int64 { vm.systemInfo.memoryZFSCache }
    private var free:     Int64 { max(0, vm.systemInfo.memoryTotal - vm.systemInfo.memoryUsed) }
    private var total:    Int64 { vm.systemInfo.memoryTotal }

    private func frac(_ bytes: Int64) -> Double {
        guard total > 0 else { return 0 }
        return Double(bytes) / Double(total)
    }

    private func fmt(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .binary)
    }

    private var ramColor: Color {
        vm.systemInfo.memoryUsedFraction > 0.9 ? .red
            : vm.systemInfo.memoryUsedFraction > 0.75 ? .orange : .purple
    }

    var body: some View {
        List {
            // Header
            Section {
                HStack(spacing: 16) {
                    Image(systemName: "memorychip")
                        .font(.largeTitle).foregroundStyle(ramColor)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(vm.systemInfo.formattedMemory)
                            .font(.title2.bold().monospacedDigit())
                            .foregroundStyle(ramColor)
                        Text(String(format: "%.0f%% used", vm.systemInfo.memoryUsedFraction * 100))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            // Breakdown
            Section("Memory Breakdown") {
                memRow("Apps & OS",      bytes: appsUsed, color: .blue)
                if arcUsed > 0 {
                    memRow("ZFS ARC Cache", bytes: arcUsed, color: .orange)
                }
                memRow("Free",           bytes: free,     color: .green)

                // Stacked colour bar
                GeometryReader { geo in
                    let w = geo.size.width
                    ZStack(alignment: .leading) {
                        // Layer 1: green background (free)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.green.opacity(0.55))
                        // Layer 2: orange up to total-used (ARC sits here)
                        Rectangle()
                            .fill(Color.orange)
                            .frame(width: max(0, w * frac(vm.systemInfo.memoryUsed)))
                        // Layer 3: blue up to apps used
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: max(0, w * frac(appsUsed)))
                    }
                    .frame(height: 12)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .frame(height: 12)
                .padding(.vertical, 4)
            }

            // Memory usage history
            if !vm.memoryHistory.isEmpty {
                Section("Usage History (1h)") {
                    Chart {
                        ForEach(Array(vm.memoryHistory.enumerated()), id: \.offset) { _, pt in
                            LineMark(
                                x: .value("Time", pt.time),
                                y: .value("GB",   pt.value / 1e9)
                            )
                            .foregroundStyle(ramColor)
                            .interpolationMethod(.catmullRom)
                            AreaMark(
                                x: .value("Time", pt.time),
                                y: .value("GB",   pt.value / 1e9)
                            )
                            .foregroundStyle(ramColor.opacity(0.15))
                            .interpolationMethod(.catmullRom)
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .minute, count: 15)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.hour().minute())
                        }
                    }
                    .chartYAxis {
                        AxisMarks { v in
                            AxisGridLine()
                            AxisValueLabel {
                                if let d = v.as(Double.self) {
                                    Text(String(format: "%.1f GB", d)).font(.caption2)
                                }
                            }
                        }
                    }
                    .frame(height: 160)
                    .padding(.vertical, 4)
                }
            }

            // ZFS ARC history
            if !vm.arcHistory.isEmpty {
                Section("ZFS ARC History (1h)") {
                    if arcUsed > 0 {
                        HStack {
                            Text("Current ARC Size")
                            Spacer()
                            Text(fmt(arcUsed))
                                .fontWeight(.medium).monospacedDigit()
                                .foregroundStyle(.orange)
                        }
                    }
                    Chart {
                        ForEach(Array(vm.arcHistory.enumerated()), id: \.offset) { _, pt in
                            LineMark(
                                x: .value("Time", pt.time),
                                y: .value("GB",   pt.value / 1e9)
                            )
                            .foregroundStyle(Color.orange)
                            .interpolationMethod(.catmullRom)
                            AreaMark(
                                x: .value("Time", pt.time),
                                y: .value("GB",   pt.value / 1e9)
                            )
                            .foregroundStyle(Color.orange.opacity(0.15))
                            .interpolationMethod(.catmullRom)
                        }
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis {
                        AxisMarks { v in
                            AxisGridLine()
                            AxisValueLabel {
                                if let d = v.as(Double.self) {
                                    Text(String(format: "%.1f GB", d)).font(.caption2)
                                }
                            }
                        }
                    }
                    .frame(height: 100)
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Memory Details")
        .toolbarTitleDisplayMode(.inline)
        .listStyle(.insetGrouped)
        .listSectionSpacing(.compact)
    }

    private func memRow(_ label: String, bytes: Int64, color: Color) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(label)
            Spacer()
            Text(fmt(bytes))
                .foregroundStyle(.secondary).monospacedDigit()
            Text(String(format: "(%.0f%%)", frac(bytes) * 100))
                .font(.caption).foregroundStyle(.tertiary).monospacedDigit()
        }
    }
}

#Preview {
    DashboardView()
        .environment(DashboardViewModel())
        .environment(StorageViewModel())
        .environment(SystemViewModel())
        .environment(SettingsViewModel())
}

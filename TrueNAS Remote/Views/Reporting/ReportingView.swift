import SwiftUI
import Charts

struct ReportingView: View {
    @Environment(ReportingViewModel.self) private var vm
    @Environment(SettingsViewModel.self)  private var settings

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Time range picker
                    Picker("Range", selection: Bindable(vm).selectedRange) {
                        ForEach(ReportingViewModel.TimeRange.allCases, id: \.self) { r in
                            Text(r.label).tag(r)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    VStack(spacing: 12) {
                        ReportingChartCard(title: "CPU Usage", icon: "cpu", unit: "%",
                                           series: vm.cpuSeries, yDomain: 0...100)
                        ReportingChartCard(title: "System Load", icon: "gauge.with.dots.needle.bottom.50percent", unit: "",
                                           series: vm.loadSeries)
                        ReportingChartCard(title: "Memory", icon: "memorychip", unit: " GB",
                                           series: vm.memorySeries.map { s in
                                               ReportingSeries(name: s.name,
                                                               points: s.points.map {
                                                                   ReportingPoint(time: $0.time, value: $0.value / 1e9)
                                                               })
                                           })
                        ReportingChartCard(title: "Network I/O", icon: "network", unit: " MB/s",
                                           series: vm.networkSeries.map { s in
                                               ReportingSeries(name: s.name,
                                                               points: s.points.map {
                                                                   ReportingPoint(time: $0.time, value: $0.value / 1e6)
                                                               })
                                           })
                        ReportingChartCard(title: "ZFS ARC Size", icon: "cylinder.split.1x2.fill", unit: " GB",
                                           series: vm.arcSeries.prefix(1).map { s in
                                               ReportingSeries(name: s.name,
                                                               points: s.points.map {
                                                                   ReportingPoint(time: $0.time, value: $0.value / 1e9)
                                                               })
                                           })
                        ReportingChartCard(title: "CPU Temperature", icon: "thermometer.medium", unit: " °C",
                                           series: vm.tempSeries)
                        if !vm.diskSeries.isEmpty {
                            ReportingChartCard(title: "Disk I/O", icon: "internaldrive", unit: " MB/s",
                                               series: vm.diskSeries.map { s in
                                                   ReportingSeries(name: s.name,
                                                                   points: s.points.map {
                                                                       ReportingPoint(time: $0.time, value: $0.value / 1e6)
                                                                   })
                                               })
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Reporting")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if vm.isLoading { ProgressView().controlSize(.small) }
                    else { Button("", systemImage: "arrow.clockwise") { Task { await vm.refresh() } } }
                }
            }
            .task(id: vm.selectedRange) { await vm.refresh() }
        }
    }
}

// MARK: - Chart Card
struct ReportingChartCard: View {
    let title: String
    let icon: String
    let unit: String
    let series: [ReportingSeries]
    var yDomain: ClosedRange<Double>? = nil

    private let colors: [Color] = [.blue, .orange, .green, .purple, .red, .yellow]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if series.isEmpty || series.allSatisfy({ $0.points.isEmpty }) {
                Text("No data").font(.caption).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 100, alignment: .center)
            } else {
                Chart {
                    ForEach(Array(series.enumerated()), id: \.offset) { idx, s in
                        let color = colors[idx % colors.count]
                        ForEach(s.points) { pt in
                            LineMark(x: .value("Time", pt.time),
                                     y: .value(s.name, pt.value))
                                .foregroundStyle(color)
                                .interpolationMethod(.catmullRom)
                        }
                        if series.count == 1 {
                            ForEach(s.points) { pt in
                                AreaMark(x: .value("Time", pt.time),
                                         y: .value(s.name, pt.value))
                                    .foregroundStyle(
                                        LinearGradient(colors: [color.opacity(0.3), color.opacity(0)],
                                                       startPoint: .top, endPoint: .bottom)
                                    )
                                    .interpolationMethod(.catmullRom)
                            }
                        }
                    }
                }
                .if(yDomain != nil) { chart in
                    chart.chartYScale(domain: yDomain!)
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
                                Text(String(format: "%.1f\(unit)", d))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 120)

                // Legend
                if series.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(series.enumerated()), id: \.offset) { idx, s in
                                Label(s.name, systemImage: "square.fill")
                                    .foregroundStyle(colors[idx % colors.count])
                                    .font(.caption2)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - View modifier helper
private extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }
}

#Preview {
    ReportingView()
        .environment(ReportingViewModel())
        .environment(SettingsViewModel())
}

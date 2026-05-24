import SwiftUI
import Charts

struct TemperatureChartView: View {
    let data: [ReportingPoint]

    private var yRange: ClosedRange<Double> {
        let vals = data.map(\.value)
        let lo = (vals.min() ?? 50) - 5
        let hi = (vals.max() ?? 80) + 5
        return lo...hi
    }

    var body: some View {
        Chart(data) { point in
            AreaMark(
                x: .value("Time", point.time),
                y: .value("°C",   point.value)
            )
            .foregroundStyle(
                LinearGradient(colors: [.orange.opacity(0.4), .orange.opacity(0.05)],
                               startPoint: .top, endPoint: .bottom)
            )
            LineMark(
                x: .value("Time", point.time),
                y: .value("°C",   point.value)
            )
            .foregroundStyle(.orange)
            .lineStyle(StrokeStyle(lineWidth: 2))
            .symbol(.circle)
            .symbolSize(20)
        }
        .chartYScale(domain: yRange)
        .chartXAxis {
            AxisMarks(values: .stride(by: .minute, count: 15)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour().minute())
            }
        }
        .chartYAxis {
            AxisMarks { v in
                AxisGridLine()
                AxisValueLabel { Text("\(v.as(Double.self).map { Int($0) } ?? 0)°C") }
            }
        }
        .frame(height: 160)
    }
}

#Preview {
    let now = Date()
    let pts: [Double] = [68, 71, 69, 73, 70, 72, 68, 71, 74, 70, 69, 72]
    let data = pts.enumerated().map { i, t in
        ReportingPoint(time: now.addingTimeInterval(Double(i - pts.count) * 300), value: t)
    }
    TemperatureChartView(data: data).padding()
}

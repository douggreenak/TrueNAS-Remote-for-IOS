import SwiftUI

struct CircularProgressRing: View {
    let value    : Double   // 0.0 – 1.0
    let label    : String
    let color    : Color
    var lineWidth: CGFloat = 14

    private var clampedValue: Double { max(0, min(1, value)) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: clampedValue)
                .stroke(color,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: clampedValue)
            VStack(spacing: 2) {
                Text("\(Int(clampedValue * 100))%")
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    HStack(spacing: 32) {
        CircularProgressRing(value: 0.425, label: "CPU", color: .blue)
            .frame(width: 120, height: 120)
        CircularProgressRing(value: 0.71, label: "RAM", color: .purple)
            .frame(width: 120, height: 120)
    }
    .padding()
}

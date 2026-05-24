import SwiftUI

struct StatusDot: View {
    let color: Color
    var size: CGFloat = 10
    var glow: Bool = true

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .shadow(color: glow ? color.opacity(0.6) : .clear, radius: 3)
    }
}

struct HealthBadge: View {
    let status: PoolStatus
    var body: some View {
        Label(status.label, systemImage: status.icon)
            .font(.caption.bold())
            .foregroundStyle(status.color)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(status.color.opacity(0.12), in: Capsule())
    }
}

struct RunStatusBadge: View {
    let status: TaskRunStatus
    var body: some View {
        Label(status.label, systemImage: status.icon)
            .font(.caption.bold())
            .foregroundStyle(status.color)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(status.color.opacity(0.12), in: Capsule())
    }
}

struct MetricCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct CapacityBar: View {
    let fraction: Double
    var height: CGFloat = 8

    private var color: Color {
        if fraction >= 0.90 { return .red }
        if fraction >= 0.75 { return .orange }
        return .blue
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.2)).frame(height: height)
                Capsule()
                    .fill(color)
                    .frame(width: geo.size.width * CGFloat(max(0, min(1, fraction))), height: height)
                    .animation(.easeInOut(duration: 0.5), value: fraction)
            }
        }
        .frame(height: height)
    }
}

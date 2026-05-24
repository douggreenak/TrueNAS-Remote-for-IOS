import SwiftUI

struct StorageView: View {
    @Environment(StorageViewModel.self)  private var viewModel
    @Environment(SettingsViewModel.self) private var settings

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.pools.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView("No Pools",
                                           systemImage: "externaldrive.badge.questionmark",
                                           description: Text("Configure your server in Settings."))
                } else {
                    poolList
                }
            }
            .navigationTitle("Storage")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Button("", systemImage: "arrow.clockwise") {
                            Task { await viewModel.refresh() }
                        }
                    }
                }
            }
            .task(id: settings.refreshInterval) {
                await viewModel.refresh()
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(settings.refreshInterval))
                    await viewModel.refresh()
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var poolList: some View {
        List(viewModel.pools) { pool in
            NavigationLink(destination: PoolDetailView(pool: pool)) {
                poolRow(pool)
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private func poolRow(_ pool: StoragePool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "cylinder.split.1x2.fill")
                    .foregroundStyle(.tint)
                Text(pool.name)
                    .font(.headline)
                Spacer()
                // Health badge
                Label(pool.status.label, systemImage: pool.status.isHealthy
                      ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(pool.status.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(pool.status.color.opacity(0.12),
                                in: Capsule())
            }

            // Capacity bar
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 8)
                        Capsule()
                            .fill(capacityColor(pool.usedFraction))
                            .frame(width: geo.size.width * pool.usedFraction, height: 8)
                            .animation(.easeInOut, value: pool.usedFraction)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("\(pool.formattedUsed) used")
                    Spacer()
                    Text("\(pool.formattedTotal) total")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func capacityColor(_ fraction: Double) -> Color {
        if fraction >= 0.9 { return .red }
        if fraction >= 0.75 { return .orange }
        return .blue
    }
}

#Preview {
    StorageView()
        .environment(StorageViewModel())
        .environment(SettingsViewModel())
}

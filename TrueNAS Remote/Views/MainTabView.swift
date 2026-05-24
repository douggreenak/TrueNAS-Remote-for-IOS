import SwiftUI

struct MainTabView: View {
    @Environment(SystemViewModel.self)  private var system

    var body: some View {
        TabView {
            Tab("Dashboard", systemImage: "gauge.with.dots.needle.bottom.50percent") {
                DashboardView()
            }
            Tab("Storage", systemImage: "externaldrive.fill") {
                StorageRootView()
            }
            Tab("Network", systemImage: "network") {
                NetworkView()
            }
            Tab("Shares", systemImage: "folder.fill.badge.person.crop") {
                SharesView()
            }
            Tab("Data Protection", systemImage: "shield.checkered") {
                DataProtectionView()
            }
            Tab("Services", systemImage: "server.rack") {
                ServicesView()
            }
            Tab("Reporting", systemImage: "chart.xyaxis.line") {
                ReportingView()
            }
            Tab("System", systemImage: "gearshape.2.fill") {
                SystemView()
            }
                .badge(system.criticalCount > 0 ? system.criticalCount : 0)
            Tab("Settings", systemImage: "wrench.and.screwdriver.fill") {
                SettingsView()
            }
        }
    }
}

#Preview {
    MainTabView()
        .environment(DashboardViewModel())
        .environment(StorageViewModel())
        .environment(NetworkViewModel())
        .environment(SharesViewModel())
        .environment(DataProtectionViewModel())
        .environment(ServicesViewModel())
        .environment(ReportingViewModel())
        .environment(SystemViewModel())
        .environment(SettingsViewModel())
}

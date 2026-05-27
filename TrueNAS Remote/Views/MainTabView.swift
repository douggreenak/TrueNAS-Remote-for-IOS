import SwiftUI

struct MainTabView: View {
    @Environment(SystemViewModel.self)  private var system

    var body: some View {
        // Each Tab owns exactly ONE NavigationStack.
        // The individual views must NOT wrap themselves in NavigationStack —
        // doing so creates a double-nesting that causes iOS 26 to inject a
        // spurious back button and adds extra blank space at the top.
        TabView {
            Tab("Dashboard", systemImage: "gauge.with.dots.needle.bottom.50percent") {
                NavigationStack { DashboardView() }
            }
            Tab("Storage", systemImage: "externaldrive.fill") {
                NavigationStack { StorageRootView() }
            }
            Tab("Network", systemImage: "network") {
                NavigationStack { NetworkView() }
            }
            Tab("Shares", systemImage: "folder.fill.badge.person.crop") {
                NavigationStack { SharesView() }
            }
            Tab("Data Protection", systemImage: "shield.checkered") {
                NavigationStack { DataProtectionView() }
            }
            Tab("Services", systemImage: "server.rack") {
                NavigationStack { ServicesView() }
            }
            Tab("Reporting", systemImage: "chart.xyaxis.line") {
                NavigationStack { ReportingView() }
            }
            Tab("System", systemImage: "gearshape.2.fill") {
                NavigationStack { SystemView() }
            }
            .badge(system.criticalCount > 0 ? system.criticalCount : 0)
            Tab("Settings", systemImage: "wrench.and.screwdriver.fill") {
                NavigationStack { SettingsView() }
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

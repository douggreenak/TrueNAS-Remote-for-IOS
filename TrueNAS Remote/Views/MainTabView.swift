import SwiftUI

struct MainTabView: View {
    @Environment(SystemViewModel.self)  private var system
    @Environment(SettingsViewModel.self) private var settings
    @State private var showSetup = false
    @State private var customization = TabViewCustomization()

    var body: some View {
        TabView {
            Tab("Dashboard", systemImage: "gauge.with.dots.needle.bottom.50percent") {
                NavigationStack { DashboardView() }
                    .toolbarTitleDisplayMode(.inline)
            }
            .customizationID("tab.dashboard")

            Tab("Storage", systemImage: "externaldrive.fill") {
                NavigationStack { StorageRootView() }
                    .toolbarTitleDisplayMode(.inline)
            }
            .customizationID("tab.storage")

            Tab("Network", systemImage: "network") {
                NavigationStack { NetworkView() }
                    .toolbarTitleDisplayMode(.inline)
            }
            .customizationID("tab.network")

            Tab("Shares", systemImage: "folder.fill.badge.person.crop") {
                NavigationStack { SharesView() }
                    .toolbarTitleDisplayMode(.inline)
            }
            .customizationID("tab.shares")

            Tab("Data Protection", systemImage: "shield.checkered") {
                NavigationStack { DataProtectionView() }
                    .toolbarTitleDisplayMode(.inline)
            }
            .customizationID("tab.dataprotection")

            Tab("Services", systemImage: "server.rack") {
                NavigationStack { ServicesView() }
                    .toolbarTitleDisplayMode(.inline)
            }
            .customizationID("tab.services")

            Tab("Reporting", systemImage: "chart.xyaxis.line") {
                NavigationStack { ReportingView() }
                    .toolbarTitleDisplayMode(.inline)
            }
            .customizationID("tab.reporting")

            Tab("System", systemImage: "gearshape.2.fill") {
                NavigationStack { SystemView() }
                    .toolbarTitleDisplayMode(.inline)
            }
            .badge(system.criticalCount > 0 ? system.criticalCount : 0)
            .customizationID("tab.system")

            Tab("Settings", systemImage: "wrench.and.screwdriver.fill") {
                NavigationStack { SettingsView() }
                    .toolbarTitleDisplayMode(.inline)
            }
            .customizationID("tab.settings")
        }
        // Enables long-press to rearrange/hide tabs; iOS will show a "More" overflow
        // automatically when too many tabs are active.
        .tabViewCustomization($customization)
        .sheet(isPresented: $showSetup) {
            SetupWizardView()
                .environment(settings)
                .interactiveDismissDisabled()
        }
        .onAppear {
            // Show setup wizard when no server URL has been configured yet
            if settings.hostURL.trimmingCharacters(in: .whitespaces).isEmpty {
                showSetup = true
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

import SwiftUI

@main
struct TrueNAS_RemoteApp: App {
    @State private var dashboard    = DashboardViewModel()
    @State private var storage      = StorageViewModel()
    @State private var network      = NetworkViewModel()
    @State private var shares       = SharesViewModel()
    @State private var dataProtect  = DataProtectionViewModel()
    @State private var services     = ServicesViewModel()
    @State private var reporting    = ReportingViewModel()
    @State private var system       = SystemViewModel()
    @State private var settings     = SettingsViewModel()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(dashboard)
                .environment(storage)
                .environment(network)
                .environment(shares)
                .environment(dataProtect)
                .environment(services)
                .environment(reporting)
                .environment(system)
                .environment(settings)
        }
    }
}

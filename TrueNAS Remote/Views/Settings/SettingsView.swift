import SwiftUI

struct SettingsView: View {
    @Environment(SettingsViewModel.self) private var viewModel

    private let intervalOptions = [10, 30, 60]

    var body: some View {
        NavigationStack {
            // @Observable requires @Bindable for two-way binding in Form
            let vm = viewModel
            Form {
                // ── Connection ────────────────────────────────────────────
                Section {
                    @Bindable var bvm = vm
                    TextField("http://192.168.1.100",
                               text: $bvm.hostURL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    SecureField("API Key", text: $bvm.apiKey)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Button {
                        Task { await vm.testConnection() }
                    } label: {
                        HStack {
                            Text("Test Connection")
                            Spacer()
                            statusView(vm.connectionStatus)
                        }
                    }
                } header: {
                    Text("Connection")
                } footer: {
                    Text("Credentials are stored in the iOS Keychain.")
                }

                // ── Preferences ───────────────────────────────────────────
                Section("Preferences") {
                    @Bindable var bvm = vm
                    Picker("Auto-Refresh", selection: $bvm.refreshInterval) {
                        ForEach(intervalOptions, id: \.self) { s in
                            Text("\(s)s").tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // ── About ─────────────────────────────────────────────────
                Section("About") {
                    LabeledContent("App Version", value: "1.0.0")
                    LabeledContent("API",         value: "TrueNAS v2.0")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") { vm.save() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    @ViewBuilder
    private func statusView(_ status: SettingsViewModel.ConnectionStatus) -> some View {
        switch status {
        case .untested:
            EmptyView()
        case .testing:
            ProgressView().controlSize(.small)
        case .success:
            Label("Connected", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .failure:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }
}

#Preview {
    SettingsView()
        .environment(SettingsViewModel())
}

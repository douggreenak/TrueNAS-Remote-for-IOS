import SwiftUI

struct SettingsView: View {
    @Environment(SettingsViewModel.self) private var viewModel

    private let intervalOptions = [10, 30, 60]

    var body: some View {
        // @Observable requires @Bindable for two-way binding in Form
        let vm = viewModel
        Form {
            // ── Connection ────────────────────────────────────────────
            Section {
                @Bindable var bvm = vm
                TextField("Server URL",
                           text: $bvm.hostURL,
                           prompt: Text("https://192.168.1.100"))
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
                Text("Credentials are stored securely in the system Keychain. The app always connects via encrypted WebSocket (WSS).")
            }

            // ── API Key Setup ─────────────────────────────────────────
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("To generate a TrueNAS API key:")
                        .font(.subheadline).fontWeight(.medium)
                    Group {
                        Text("1. Open your TrueNAS web interface")
                        Text("2. Go to Credentials → API Keys")
                        Text("3. Tap Add and give the key a name")
                        Text("4. Copy the generated key and paste it in the API Key field above")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)

                if !vm.hostURL.isEmpty,
                   let apiKeysURL = URL(string: vm.hostURL.hasSuffix("/")
                       ? vm.hostURL + "ui/apikeys"
                       : vm.hostURL + "/ui/apikeys") {
                    Link(destination: apiKeysURL) {
                        Label("Open API Keys Page in Browser", systemImage: "key.fill")
                    }
                }
            } header: {
                Text("API Key Setup")
            }

            // ── Preferences ───────────────────────────────────────────
            Section {
                @Bindable var bvm = vm
                Picker("Auto-Refresh", selection: $bvm.refreshInterval) {
                    ForEach(intervalOptions, id: \.self) { s in
                        Text("\(s)s").tag(s)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Preferences")
            } footer: {
                Text("How often the app polls for updated data while a tab is visible.")
            }

            // ── About ─────────────────────────────────────────────────
            Section("About") {
                LabeledContent("App Version", value: "1.0.0")
                LabeledContent("Protocol",    value: "WebSocket API (JSON-RPC 2.0)")
                LabeledContent("Compatible",  value: "TrueNAS SCALE 25.x")
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

    @ViewBuilder
    private func statusView(_ status: SettingsViewModel.ConnectionStatus) -> some View {
        switch status {
        case .untested:
            EmptyView()
        case .testing:
            ProgressView().controlSize(.small)
        case .success:
            Label("Connected", systemImage: "checkmark.circle.fill")
                .font(.caption.bold())
                .foregroundStyle(.green)
        case .failure:
            Label("Failed", systemImage: "xmark.circle.fill")
                .font(.caption.bold())
                .foregroundStyle(.red)
        }
    }
}

#Preview {
    SettingsView()
        .environment(SettingsViewModel())
}

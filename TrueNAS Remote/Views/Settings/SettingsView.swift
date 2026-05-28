import SwiftUI

struct SettingsView: View {
    @Environment(SettingsViewModel.self) private var viewModel

    var body: some View {
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

            // ── Polling ───────────────────────────────────────────────
            Section {
                @Bindable var bvm = vm
                Picker("Auto-Refresh", selection: $bvm.refreshInterval) {
                    ForEach(SettingsViewModel.refreshOptions, id: \.seconds) { opt in
                        Text(opt.label).tag(opt.seconds)
                    }
                }
            } header: {
                Text("Polling")
            } footer: {
                Text("How often the app re-fetches data while a tab is visible. Choose \"Never\" to refresh manually only.")
            }

            // ── Appearance ────────────────────────────────────────────
            Section {
                @Bindable var bvm = vm

                // Accent color swatch picker
                VStack(alignment: .leading, spacing: 10) {
                    Text("Accent Color")
                        .font(.subheadline)
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5),
                        spacing: 10
                    ) {
                        ForEach(SettingsViewModel.AccentColorOption.allCases) { option in
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    bvm.accentColorOption = option
                                    vm.save()
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(option.color)
                                        .frame(width: 36, height: 36)
                                    if bvm.accentColorOption == option {
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 4)

                Picker("Temperature", selection: Bindable(vm).temperatureUnit) {
                    ForEach(SettingsViewModel.TemperatureUnit.allCases) { unit in
                        Text(unit.label).tag(unit)
                    }
                }
            } header: {
                Text("Appearance")
            } footer: {
                Text("Accent color applies app-wide immediately. Temperature unit is used wherever temperatures are shown.")
            }

            // ── Dashboard Cards ───────────────────────────────────────
            Section {
                @Bindable var bvm = vm
                Toggle("Alert Banner", isOn: $bvm.showAlertBanner)
                Toggle("Pool Health", isOn: $bvm.showPoolHealthCard)
                Toggle("Network Sparkline", isOn: $bvm.showNetworkCard)
                Toggle("Temperature", isOn: $bvm.showTemperatureCard)
            } header: {
                Text("Dashboard Cards")
            } footer: {
                Text("Hide sections you don't need to keep the Dashboard focused.")
            }

            // ── About ─────────────────────────────────────────────────
            Section("About") {
                LabeledContent("App Version", value: "1.0.0")
                LabeledContent("Protocol",    value: "WebSocket API (JSON-RPC 2.0)")
                LabeledContent("Compatible",  value: "TrueNAS SCALE 25.x")
            }
        }
        .navigationTitle("Settings")
        .toolbarTitleDisplayMode(.inline)
        .listSectionSpacing(.compact)
        .onDisappear { viewModel.save() }
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

import SwiftUI

/// First-launch setup wizard shown when no server URL is configured.
struct SetupWizardView: View {
    @Environment(SettingsViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss

    @State private var step = 0         // 0 = URL, 1 = API key, 2 = test
    @State private var localURL = ""
    @State private var localKey = ""

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case 0:  urlStep
                case 1:  apiKeyStep
                default: testStep
                }
            }
            .navigationTitle("Welcome")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    // Allow dismiss only if already configured (re-opened wizard)
                    if !vm.hostURL.isEmpty {
                        Button("Skip") { dismiss() }
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onAppear {
            localURL = vm.hostURL
            localKey = vm.apiKey
        }
    }

    // MARK: - Step 0: Server URL
    private var urlStep: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 20)
            VStack(spacing: 16) {
                Image(systemName: "server.rack")
                    .font(.system(size: 56))
                    .foregroundStyle(.blue)
                Text("Connect to TrueNAS")
                    .font(.title.bold())
                Text("Enter the address of your TrueNAS SCALE server.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.bottom, 32)

            Form {
                Section {
                    TextField("Server URL",
                              text: $localURL,
                              prompt: Text("https://192.168.1.99"))
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Server Address")
                } footer: {
                    Text("Use the same address you type in a browser to reach the TrueNAS web UI. Always starts with https://")
                }
            }
            .scrollDisabled(true)
            .frame(height: 160)

            Spacer()

            Button {
                vm.hostURL = localURL
                vm.save()
                withAnimation { step = 1 }
            } label: {
                Text("Continue")
                    .font(.body.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(localURL.isEmpty ? Color.secondary.opacity(0.3) : Color.blue,
                                in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .disabled(localURL.isEmpty)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Step 1: API Key
    private var apiKeyStep: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 20)
            VStack(spacing: 16) {
                Image(systemName: "key.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.orange)
                Text("API Key")
                    .font(.title.bold())
                Text("An API key lets the app connect securely without your TrueNAS password.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.bottom, 32)

            Form {
                Section {
                    SecureField("Paste API Key here", text: $localKey)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("API Key")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("To create a key:")
                            .font(.footnote.bold())
                        Text("1. Open your TrueNAS web UI")
                        Text("2. Go to Credentials → API Keys")
                        Text("3. Tap Add, give the key a name, copy it here")
                    }
                    .font(.footnote)
                }

                if !localURL.isEmpty,
                   let url = URL(string: localURL.hasSuffix("/")
                       ? localURL + "ui/apikeys"
                       : localURL + "/ui/apikeys") {
                    Section {
                        Link(destination: url) {
                            Label("Open API Keys Page", systemImage: "arrow.up.right.square")
                        }
                    }
                }
            }
            .scrollDisabled(true)
            .frame(height: 260)

            Spacer()

            HStack(spacing: 12) {
                Button {
                    withAnimation { step = 0 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.bold())
                        .frame(width: 52, height: 52)
                        .background(Color.secondary.opacity(0.15),
                                    in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.primary)
                }

                Button {
                    vm.apiKey = localKey
                    vm.save()
                    withAnimation { step = 2 }
                } label: {
                    Text("Continue")
                        .font(.body.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(localKey.isEmpty ? Color.secondary.opacity(0.3) : Color.orange,
                                    in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
                .disabled(localKey.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Step 2: Test connection
    private var testStep: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 20)
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.15))
                        .frame(width: 88, height: 88)
                    Image(systemName: statusIcon)
                        .font(.system(size: 40))
                        .foregroundStyle(statusColor)
                }
                .animation(.spring(), value: vm.connectionStatus)

                Text(statusTitle)
                    .font(.title.bold())
                Text(statusMessage)
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.bottom, 32)

            Form {
                Section("Connection Details") {
                    LabeledContent("Server", value: vm.hostURL)
                    LabeledContent("API Key", value: "●●●●●●●●")
                }
                .listSectionSpacing(.compact)
            }
            .scrollDisabled(true)
            .frame(height: 130)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    Task { await vm.testConnection() }
                } label: {
                    Label("Test Connection", systemImage: "arrow.clockwise")
                        .font(.body.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }

                if case .success = vm.connectionStatus {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done — Start Using the App")
                            .font(.body.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.green, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .task { await vm.testConnection() }
    }

    // MARK: - Status helpers
    private var statusColor: Color {
        switch vm.connectionStatus {
        case .untested: return .secondary
        case .testing:  return .blue
        case .success:  return .green
        case .failure:  return .red
        }
    }
    private var statusIcon: String {
        switch vm.connectionStatus {
        case .untested: return "wifi.slash"
        case .testing:  return "arrow.clockwise"
        case .success:  return "checkmark.circle.fill"
        case .failure:  return "xmark.circle.fill"
        }
    }
    private var statusTitle: String {
        switch vm.connectionStatus {
        case .untested: return "Ready to Test"
        case .testing:  return "Connecting…"
        case .success:  return "Connected!"
        case .failure:  return "Connection Failed"
        }
    }
    private var statusMessage: String {
        switch vm.connectionStatus {
        case .untested: return "Tap the button below to verify your settings."
        case .testing:  return "Checking your TrueNAS server…"
        case .success:  return "Successfully connected to \(vm.hostURL)"
        case .failure(let e): return e
        }
    }
}

#Preview {
    SetupWizardView()
        .environment(SettingsViewModel())
}

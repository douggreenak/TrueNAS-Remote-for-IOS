import SwiftUI
import Charts

struct NetworkView: View {
    @Environment(NetworkViewModel.self)  private var vm
    @Environment(SettingsViewModel.self) private var settings
    @State private var segment = 0   // 0=Interfaces 1=Config 2=Routes

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Section", selection: $segment) {
                    Text("Interfaces").tag(0)
                    Text("Config").tag(1)
                    Text("Routes").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal).padding(.vertical, 8)

                Group {
                    switch segment {
                    case 0: interfacesList
                    case 1: configView
                    default: routesList
                    }
                }
            }
            .navigationTitle("Network")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if vm.isLoading { ProgressView().controlSize(.small) }
                    else { Button("", systemImage: "arrow.clockwise") { Task { await vm.refresh() } } }
                }
            }
            .task(id: settings.refreshInterval) {
                await vm.refresh()
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(settings.refreshInterval))
                    await vm.refresh()
                }
            }
        }
    }

    // MARK: - Interfaces
    private var interfacesList: some View {
        List(vm.interfaces) { iface in
            NavigationLink(destination: InterfaceDetailView(interface: iface)) {
                InterfaceRow(interface: iface)
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await vm.refresh() }
    }

    // MARK: - Global Config
    private var configView: some View {
        List {
            Section("Hostname") {
                LabeledContent("Hostname", value: vm.networkConfig.hostname)
                LabeledContent("Domain", value: vm.networkConfig.domain)
                if !vm.networkConfig.outboundInterface.isEmpty {
                    LabeledContent("Outbound Interface", value: vm.networkConfig.outboundInterface)
                }
            }
            Section("Gateways") {
                if !vm.networkConfig.ipv4Gateway.isEmpty {
                    LabeledContent("IPv4 Gateway", value: vm.networkConfig.ipv4Gateway)
                }
                if !vm.networkConfig.ipv6Gateway.isEmpty {
                    LabeledContent("IPv6 Gateway", value: vm.networkConfig.ipv6Gateway)
                }
            }
            Section("DNS") {
                ForEach(vm.networkConfig.nameservers, id: \.self) { ns in
                    Text(ns).font(.body.monospaced())
                }
                if vm.networkConfig.nameservers.isEmpty {
                    Text("No nameservers configured").foregroundStyle(.secondary)
                }
            }
            if !vm.networkConfig.httpProxy.isEmpty {
                Section("Proxy") {
                    LabeledContent("HTTP Proxy", value: vm.networkConfig.httpProxy)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Static Routes
    private var routesList: some View {
        Group {
            if vm.staticRoutes.isEmpty {
                ContentUnavailableView("No Static Routes",
                    systemImage: "arrow.triangle.branch",
                    description: Text("No static routes configured."))
            } else {
                List(vm.staticRoutes) { route in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(route.destination).font(.body.monospaced())
                            Spacer()
                            Text("via \(route.gateway)").font(.caption.monospaced()).foregroundStyle(.secondary)
                        }
                        if !route.description.isEmpty {
                            Text(route.description).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.insetGrouped)
            }
        }
    }
}

// MARK: - Interface Row
struct InterfaceRow: View {
    let interface: NetworkInterface

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(interface.linkState ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: typeIcon)
                    .foregroundStyle(interface.linkState ? .green : .red)
                    .font(.system(size: 16))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(interface.name).font(.body.weight(.medium))
                    Text(interface.type.label)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15), in: Capsule())
                }
                if let ip = interface.ipv4Addresses.first {
                    Text(ip).font(.caption.monospaced()).foregroundStyle(.secondary)
                }
                HStack(spacing: 10) {
                    if interface.inBytesPerSec > 0 || interface.outBytesPerSec > 0 {
                        Label(formatBps(interface.inBytesPerSec), systemImage: "arrow.down")
                            .font(.caption2).foregroundStyle(.blue)
                        Label(formatBps(interface.outBytesPerSec), systemImage: "arrow.up")
                            .font(.caption2).foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var typeIcon: String {
        switch interface.type {
        case .physical: return "cable.connector"
        case .vlan:     return "square.stack.3d.up"
        case .bridge:   return "network"
        case .lag:      return "link"
        case .unknown:  return "questionmark.circle"
        }
    }

    private func formatBps(_ bps: Double) -> String {
        let mbps = bps / 1_000_000
        if mbps >= 1000 { return String(format: "%.1f Gbps", mbps / 1000) }
        if mbps >= 1 { return String(format: "%.1f Mbps", mbps) }
        return String(format: "%.0f Kbps", bps / 1000)
    }
}

// MARK: - Interface Detail
struct InterfaceDetailView: View {
    let interface: NetworkInterface

    var body: some View {
        List {
            Section("Status") {
                HStack {
                    Text("Link State")
                    Spacer()
                    Label(interface.linkState ? "Up" : "Down",
                          systemImage: interface.linkState ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(interface.linkState ? .green : .red)
                        .font(.caption.bold())
                }
                LabeledContent("Type", value: interface.type.label)
                if let speed = interface.speed {
                    LabeledContent("Speed", value: "\(speed) Mbps")
                }
                LabeledContent("MTU", value: "\(interface.mtu)")
                LabeledContent("MAC", value: interface.macAddress)
            }

            Section("Addresses") {
                if interface.ipv4Addresses.isEmpty && interface.ipv6Addresses.isEmpty {
                    Text("No addresses assigned").foregroundStyle(.secondary)
                }
                ForEach(interface.ipv4Addresses, id: \.self) { ip in
                    LabeledContent("IPv4", value: ip)
                }
                ForEach(interface.ipv6Addresses, id: \.self) { ip in
                    LabeledContent("IPv6", value: ip)
                }
                LabeledContent("DHCP", value: interface.dhcp ? "Yes" : "No")
            }

            Section("Traffic") {
                LabeledContent("Total Received", value: formatBytes(interface.inBytes))
                LabeledContent("Total Sent",     value: formatBytes(interface.outBytes))
                LabeledContent("Current In",     value: formatBps(interface.inBytesPerSec))
                LabeledContent("Current Out",    value: formatBps(interface.outBytesPerSec))
            }

            if interface.trafficHistory.count > 1 {
                Section("Traffic History") {
                    Chart {
                        ForEach(interface.trafficHistory) { sample in
                            LineMark(x: .value("Time", sample.time),
                                     y: .value("In MB/s", sample.inBytes / 1_000_000))
                                .foregroundStyle(.blue)
                                .interpolationMethod(.catmullRom)
                            LineMark(x: .value("Time", sample.time),
                                     y: .value("Out MB/s", sample.outBytes / 1_000_000))
                                .foregroundStyle(.orange)
                                .interpolationMethod(.catmullRom)
                        }
                    }
                    .chartXAxis(.hidden)
                    .frame(height: 120)
                    HStack(spacing: 16) {
                        Label("In", systemImage: "square.fill").foregroundStyle(.blue).font(.caption)
                        Label("Out", systemImage: "square.fill").foregroundStyle(.orange).font(.caption)
                    }
                }
            }
        }
        .navigationTitle(interface.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func formatBytes(_ b: Int64) -> String {
        let gb = Double(b) / 1e9
        let mb = Double(b) / 1e6
        if gb >= 1 { return String(format: "%.2f GB", gb) }
        return String(format: "%.1f MB", mb)
    }

    private func formatBps(_ bps: Double) -> String {
        let mbps = bps / 1_000_000
        if mbps >= 1000 { return String(format: "%.1f Gbps", mbps / 1000) }
        if mbps >= 1 { return String(format: "%.1f Mbps", mbps) }
        return String(format: "%.0f Kbps", bps / 1000)
    }
}


#Preview {
    NetworkView()
        .environment(NetworkViewModel())
        .environment(SettingsViewModel())
}

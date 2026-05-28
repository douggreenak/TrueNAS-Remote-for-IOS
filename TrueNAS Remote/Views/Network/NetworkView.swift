import SwiftUI
import Charts


struct NetworkView: View {
    @Environment(NetworkViewModel.self)  private var vm
    @Environment(SettingsViewModel.self) private var settings
    @State private var segment = 0   // 0=Interfaces 1=Config 2=Routes

    private let tabs: [(label: String, icon: String)] = [
        ("Interfaces", "network"),
        ("Config",     "slider.horizontal.3"),
        ("Routes",     "arrow.triangle.swap"),
    ]
    @Namespace private var tabNS

    var body: some View {
        tabContent
            .animation(.none, value: segment)   // instant switch, no flicker
            .pageLoading(vm.isLoading && vm.interfaces.isEmpty)
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    tabBar
                    Divider()
                }
            }
            .navigationTitle("Network")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if vm.isLoading { ProgressView().controlSize(.small) }
                }
            }
            .task { await vm.refresh() }
    }

    @ViewBuilder private var tabContent: some View {
        switch segment {
        case 0: interfacesList
        case 1: configView
        default: routesList
        }
    }

    private var tabBar: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(tabs.indices, id: \.self) { i in
                        Button { segment = i } label: {
                            VStack(spacing: 4) {
                                HStack(spacing: 5) {
                                    Image(systemName: tabs[i].icon).font(.caption2)
                                    Text(tabs[i].label)
                                        .font(.subheadline.weight(segment == i ? .semibold : .regular))
                                }
                                .foregroundStyle(segment == i ? .primary : .secondary)
                                .padding(.horizontal, 14).padding(.vertical, 8)

                                if segment == i {
                                    RoundedRectangle(cornerRadius: 2).fill(Color.accentColor)
                                        .frame(height: 3)
                                        .matchedGeometryEffect(id: "netTab", in: tabNS)
                                } else {
                                    RoundedRectangle(cornerRadius: 2).fill(Color.clear).frame(height: 3)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .id(i)
                    }
                }
                .padding(.horizontal, 12)
                .animation(.spring(response: 0.3, dampingFraction: 0.75), value: segment)
            }
            .onChange(of: segment) { _, new in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    proxy.scrollTo(new, anchor: .center)
                }
            }
        }
        .padding(.vertical, 2)
        .background(.bar)
    }

    // MARK: - Interfaces
    private var interfacesList: some View {
        Group {
            if vm.isLoading && vm.interfaces.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.interfaces.isEmpty {
                ContentUnavailableView("No Interfaces",
                    systemImage: "network.slash",
                    description: Text("No network interfaces found."))
            } else {
                List(vm.interfaces) { iface in
                    NavigationLink(destination: InterfaceDetailView(interface: iface)) {
                        InterfaceRow(interface: iface)
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable { await vm.refresh() }
            }
        }
    }

    // MARK: - Global Config
    private var configView: some View {
        List {
            // Server addresses: IP + hostname/domain from live interface data
            let activeIfaces = vm.interfaces.filter { $0.linkState && !$0.ipv4Addresses.isEmpty }
            if !activeIfaces.isEmpty {
                Section("Server Addresses") {
                    ForEach(activeIfaces) { iface in
                        ForEach(iface.ipv4Addresses, id: \.self) { ip in
                            let fqdn = vm.networkConfig.domain.isEmpty
                                ? vm.networkConfig.hostname
                                : "\(vm.networkConfig.hostname).\(vm.networkConfig.domain)"
                            HStack(spacing: 10) {
                                Image(systemName: "server.rack")
                                    .foregroundStyle(.blue)
                                    .frame(width: 22)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ip)
                                        .font(.body.monospaced())
                                        .textSelection(.enabled)
                                    Text(fqdn)
                                        .font(.caption).foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                }
                                Spacer()
                                Text(iface.name)
                                    .font(.caption2).foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }

            Section("Hostname") {
                LabeledContent("Hostname", value: vm.networkConfig.hostname)
                if vm.networkConfig.domain != "—" && !vm.networkConfig.domain.isEmpty {
                    LabeledContent("Domain", value: vm.networkConfig.domain)
                }
                if vm.networkConfig.outboundInterface != "—" && !vm.networkConfig.outboundInterface.isEmpty {
                    LabeledContent("Outbound Interface", value: vm.networkConfig.outboundInterface)
                }
            }
            Section("Gateways") {
                if vm.networkConfig.ipv4Gateway != "—" && !vm.networkConfig.ipv4Gateway.isEmpty {
                    LabeledContent("IPv4 Gateway", value: vm.networkConfig.ipv4Gateway)
                        .textSelection(.enabled)
                } else {
                    LabeledContent("IPv4 Gateway", value: "Not configured")
                }
                if vm.networkConfig.ipv6Gateway != "—" && !vm.networkConfig.ipv6Gateway.isEmpty {
                    LabeledContent("IPv6 Gateway", value: vm.networkConfig.ipv6Gateway)
                        .textSelection(.enabled)
                } else {
                    LabeledContent("IPv6 Gateway", value: "Not configured")
                }
            }
            Section("DNS") {
                if vm.networkConfig.nameservers.isEmpty {
                    Text("No nameservers configured").font(.subheadline).foregroundStyle(.secondary)
                } else {
                    ForEach(vm.networkConfig.nameservers, id: \.self) { ns in
                        LabeledContent("Nameserver", value: ns)
                            .font(.body.monospaced())
                            .textSelection(.enabled)
                    }
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
            if vm.isLoading && vm.staticRoutes.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.staticRoutes.isEmpty {
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

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(interface.name).font(.body.weight(.medium))
                    Text(interface.type.label)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15), in: Capsule())
                    if interface.linkState {
                        if let speed = interface.speed {
                            Text("\(speed) Mbps")
                                .font(.caption2)
                                .foregroundStyle(.green)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Color.green.opacity(0.1), in: Capsule())
                        }
                    } else {
                        Text("Down").font(.caption2.bold()).foregroundStyle(.red)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.red.opacity(0.1), in: Capsule())
                    }
                }
                if let ip = interface.ipv4Addresses.first {
                    Text(ip).font(.caption.monospaced()).foregroundStyle(.secondary)
                } else if !interface.linkState {
                    Text("No link").font(.caption).foregroundStyle(.tertiary)
                }
                if interface.linkState {
                    HStack(spacing: 10) {
                        Label(formatBps(interface.inBytesPerSec), systemImage: "arrow.down")
                            .font(.caption2).foregroundStyle(.blue)
                        Label(formatBps(interface.outBytesPerSec), systemImage: "arrow.up")
                            .font(.caption2).foregroundStyle(.orange)
                    }
                }
            }

            Spacer()

            // Mini sparkline for active interfaces
            if interface.linkState && interface.trafficHistory.count > 2 {
                NetSparkline(samples: interface.trafficHistory)
                    .frame(width: 60, height: 28)
            }
        }
        .padding(.vertical, 4)
    }

    private var typeIcon: String { interface.type.icon }

    private func formatBps(_ bps: Double) -> String {
        let mbps = bps / 1_000_000
        if mbps >= 1000 { return String(format: "%.1f Gbps", mbps / 1000) }
        if mbps >= 1 { return String(format: "%.1f Mbps", mbps) }
        return String(format: "%.0f Kbps", bps / 1000)
    }
}

// MARK: - Net Sparkline
private struct NetSparkline: View {
    let samples: [TrafficSample]
    var body: some View {
        Chart {
            ForEach(Array(samples.enumerated()), id: \.offset) { i, s in
                AreaMark(x: .value("t", i), y: .value("in", s.inBytes / 1_000_000))
                    .foregroundStyle(LinearGradient(colors: [.blue.opacity(0.4), .blue.opacity(0)], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.catmullRom)
                LineMark(x: .value("t", i), y: .value("in", s.inBytes / 1_000_000))
                    .foregroundStyle(.blue)
                    .interpolationMethod(.catmullRom)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
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
                        Label("In", systemImage: "circle.fill").foregroundStyle(.blue).font(.caption)
                        Label("Out", systemImage: "circle.fill").foregroundStyle(.orange).font(.caption)
                    }
                }
            }
        }
        .navigationTitle(interface.name)
        .toolbarTitleDisplayMode(.inline)
        .listStyle(.insetGrouped)
        .listSectionSpacing(.compact)
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

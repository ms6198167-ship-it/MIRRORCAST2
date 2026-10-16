import SwiftUI

struct HomeDashboard: View {
    @EnvironmentObject private var discovery: ReceiverDiscovery
    @State private var selectedReceiver: Receiver?
    @State private var showAirPlayInfo = false
    @AppStorage("receiverHost", store: UserDefaults(suiteName: "group.com.example.MirrorCast")) private var receiverHost = ""
    @AppStorage("receiverPort", store: UserDefaults(suiteName: "group.com.example.MirrorCast")) private var receiverPort = 8765

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    statusCard
                    airPlayCard
                    receiverSetupCard
                    receiverSection
                    diagnosticsCard
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("MirrorCast")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        discovery.isBrowsing ? discovery.stop() : discovery.start()
                    } label: {
                        Image(systemName: discovery.isBrowsing ? "stop.circle" : "arrow.clockwise")
                    }
                    .accessibilityLabel(discovery.isBrowsing ? "Stop discovery" : "Search for receivers")
                }
            }
            .sheet(item: $selectedReceiver) { receiver in
                ReceiverDetailsView(receiver: receiver)
                    .presentationDetents([.medium])
            }
            .alert("About AirPlay", isPresented: $showAirPlayInfo) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("AirPlay uses Apple's system routing controls. Selecting a route here does not give MirrorCast permission to capture and send your entire iPhone screen to a custom receiver.")
            }
            .task { discovery.start() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your screen, connected.")
                .font(.largeTitle.bold())
            Text("Find compatible receivers on your local network.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusCard: some View {
        HStack(spacing: 14) {
            Image(systemName: discovery.isBrowsing ? "dot.radiowaves.left.and.right" : "wifi")
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 48, height: 48)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 4) {
                Text(discovery.state.title).font(.headline)
                Text(discovery.isBrowsing ? "Looking for _mirrorcast._tcp services" : "Discovery is stopped")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if discovery.isBrowsing { ProgressView() }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
    }

    private var airPlayCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Apple AirPlay", systemImage: "airplayvideo")
                .font(.headline)
            Text("Choose an available AirPlay destination using Apple's system picker.")
                .font(.subheadline).foregroundStyle(.secondary)
            HStack {
                AirPlayRoutePicker().frame(width: 48, height: 44)
                    .accessibilityLabel("Choose AirPlay destination")
                Text("Open AirPlay destinations")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Button { showAirPlayInfo = true } label: {
                    Image(systemName: "info.circle")
                }
                .accessibilityLabel("Learn about AirPlay limitations")
            }
            .padding(10)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
    }


    private var receiverSetupCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Windows receiver", systemImage: "desktopcomputer").font(.headline)
            Text("For this first prototype, enter the Windows PC's local IPv4 address. Keep both devices on the same trusted Wi-Fi network.")
                .font(.subheadline).foregroundStyle(.secondary)
            TextField("Windows PC IP (e.g. 192.168.1.20)", text: $receiverHost)
                .textContentType(.URL).keyboardType(.numbersAndPunctuation).textInputAutocapitalization(.never).autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
            HStack {
                Text("Receiver port")
                Spacer()
                TextField("8765", value: $receiverPort, format: .number)
                    .keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 90)
                    .textFieldStyle(.roundedBorder)
            }
            Text("After configuring the receiver, use iOS Control Center → Screen Recording → MirrorCast Broadcast to start a session. The broadcast extension must be added as a separate target in Xcode.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
    }

    private var receiverSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("MirrorCast receivers").font(.headline)
                Spacer()
                Text("\(discovery.receivers.count)")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            if discovery.receivers.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "display.2").font(.system(size: 34)).foregroundStyle(.secondary)
                    Text("No compatible receivers found").font(.headline)
                    Text("A receiver must run compatible MirrorCast software and advertise its service on this network.")
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button("Search again") { discovery.start() }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, minHeight: 210)
                .padding(18)
                .background(.background, in: RoundedRectangle(cornerRadius: 18))
            } else {
                VStack(spacing: 0) {
                    ForEach(discovery.receivers) { receiver in
                        Button { selectedReceiver = receiver } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "display")
                                    .font(.title3).frame(width: 42, height: 42)
                                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(receiver.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                    Text("Discovered • Not paired").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                            }
                            .padding(14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if receiver.id != discovery.receivers.last?.id { Divider().padding(.leading, 68) }
                    }
                }
                .background(.background, in: RoundedRectangle(cornerRadius: 18))
            }
            if case .error(let message) = discovery.state {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.red)
            }
        }
    }

    private var diagnosticsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Session diagnostics", systemImage: "waveform.path")
                .font(.headline)
            diagnosticRow("Connection", "Not connected")
            diagnosticRow("Latency", "Unavailable until connected")
            diagnosticRow("Stream quality", "No active stream")
            Text("MirrorCast never invents connection metrics. These values become available only when a compatible transport reports them.")
                .font(.caption).foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
    }

    private func diagnosticRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }.font(.subheadline)
    }
}

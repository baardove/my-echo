import SwiftUI

struct TVServersView: View {
    @Environment(TVEchoStore.self) private var store

    var body: some View {
        @Bindable var bindableStore = store

        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                TVSectionHeader(
                    eyebrow: "Connections & Pairing",
                    title: "My Echo Mac · Navidrome · Party TV"
                )

                // 1. My Echo Server (Unraid Docker) or My Echo on Mac (Bonjour + 6-Digit PIN)
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Label(
                            store.isConnectedToEchoServer
                                ? "My Echo Server (Unraid Docker · Independent)"
                                : "My Echo Server (Unraid Docker or Mac)",
                            systemImage: store.isConnectedToEchoServer ? "server.rack" : "laptopcomputer"
                        )
                            .font(.system(size: 28, weight: .black))
                            .foregroundStyle(EchoTVTheme.neoMint)
                        Spacer()
                        Text(store.isConnectedToMac ? (store.isConnectedToEchoServer ? "ECHO SERVER" : "MAC CONNECTED") : "DISCONNECTED")
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background((store.isConnectedToMac ? EchoTVTheme.neoMint : EchoTVTheme.textMuted).opacity(0.2))
                            .foregroundStyle(store.isConnectedToMac ? EchoTVTheme.neoMint : EchoTVTheme.textSecondary)
                            .clipShape(Capsule())
                    }

                    if !store.discoveredMacs.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("AUTO-DISCOVERED ON LOCAL NETWORK (BONJOUR)")
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                .foregroundStyle(EchoTVTheme.neoCyan)
                            HStack(spacing: 16) {
                                ForEach(store.discoveredMacs) { srv in
                                    Button {
                                        store.selectDiscoveredMac(srv)
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: "bonjour")
                                                .foregroundStyle(EchoTVTheme.neoMint)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(srv.name)
                                                    .font(.system(size: 20, weight: .bold))
                                                Text("\(srv.host):\(srv.port)")
                                                    .font(.system(size: 15, design: .monospaced))
                                                    .foregroundStyle(EchoTVTheme.textSecondary)
                                            }
                                        }
                                        .padding(.horizontal, 22)
                                        .padding(.vertical, 14)
                                        .background(EchoTVTheme.surfaceElevated)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                    .buttonStyle(EchoTVButtonStyle())
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 24) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Mac Server URL (LAN or Tailscale)")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(EchoTVTheme.textSecondary)
                                TextField("http://192.168.1.50:48721", text: $bindableStore.macServerURL)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("6-Digit Pairing PIN (from Mac Settings)")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(EchoTVTheme.textSecondary)
                                TextField("123456", text: $bindableStore.pairingPIN)
                                    .keyboardType(.numberPad)
                            }
                            .frame(maxWidth: 420)
                        }

                        HStack(spacing: 16) {
                            Button {
                                store.saveMacSettings()
                                Task { await store.refreshMacCatalog() }
                            } label: {
                                Label(store.isLoadingMacCatalog ? "Connecting..." : "Connect & Load Full Library", systemImage: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 21, weight: .bold))
                                    .padding(.horizontal, 28)
                                    .padding(.vertical, 14)
                                    .background(EchoTVTheme.neoMint)
                                    .foregroundStyle(Color.black)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(EchoTVButtonStyle())

                            Button {
                                store.macServerURL = TVEchoStore.presetUnraidEchoServerTailscaleURL
                                store.saveMacSettings()
                                Task { await store.refreshMacCatalog() }
                            } label: {
                                Text("Use Unraid Echo Server")
                                    .font(.system(size: 19, weight: .semibold))
                                    .padding(.horizontal, 22)
                                    .padding(.vertical, 14)
                                    .background(EchoTVTheme.surfaceElevated)
                                    .foregroundStyle(EchoTVTheme.neoMint)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(EchoTVButtonStyle())

                            Button {
                                store.macServerURL = store.macTailscaleURL
                                store.saveMacSettings()
                                Task { await store.refreshMacCatalog() }
                            } label: {
                                Text("Use Mac Tailscale URL")
                                    .font(.system(size: 19, weight: .semibold))
                                    .padding(.horizontal, 22)
                                    .padding(.vertical, 14)
                                    .background(EchoTVTheme.surfaceElevated)
                                    .foregroundStyle(EchoTVTheme.neoCyan)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(EchoTVButtonStyle())
                        }

                        Text(store.macStatusText)
                            .font(.system(size: 18, design: .monospaced))
                            .foregroundStyle(EchoTVTheme.textSecondary)

                        if let err = store.macError {
                            Text(err)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(EchoTVTheme.dangerCoral)
                        }
                    }
                }
                .padding(32)
                .background(EchoTVTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 20))

                // 2. Navidrome / OpenSubsonic Direct NAS Streaming
                VStack(alignment: .leading, spacing: 20) {
                    Label("Navidrome / OpenSubsonic (Direct NAS Streaming)", systemImage: "dot.radiowaves.left.and.right")
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(EchoTVTheme.neoCyan)

                    HStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Navidrome Server URL")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(EchoTVTheme.textSecondary)
                            TextField("http://192.168.0.10:4533", text: $bindableStore.navidromeConfig.serverURL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Username")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(EchoTVTheme.textSecondary)
                            TextField("username", text: $bindableStore.navidromeConfig.username)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Password")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(EchoTVTheme.textSecondary)
                            SecureField("password", text: $bindableStore.navidromeConfig.password)
                        }
                    }

                    // Stream Quality Selector
                    HStack(spacing: 14) {
                        Text("Stream Quality:")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(EchoTVTheme.textSecondary)
                        ForEach(TVNavidromeStreamQuality.allCases) { q in
                            let selected = store.navidromeConfig.streamQuality == q
                            Button(q.displayName) {
                                store.navidromeConfig.streamQuality = q
                                store.saveNavidromeSettings()
                            }
                            .font(.system(size: 16, weight: .bold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(selected ? EchoTVTheme.neoCyan : EchoTVTheme.surfaceElevated)
                            .foregroundStyle(selected ? Color.black : EchoTVTheme.textPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .buttonStyle(EchoTVButtonStyle())
                        }
                    }

                    HStack(spacing: 16) {
                        Button {
                            store.saveNavidromeSettings()
                            Task { await store.testNavidromeConnection() }
                        } label: {
                            Label("Test & Connect Navidrome", systemImage: "checkmark.shield.fill")
                                .font(.system(size: 21, weight: .bold))
                                .padding(.horizontal, 28)
                                .padding(.vertical, 14)
                                .background(EchoTVTheme.neoCyan)
                                .foregroundStyle(Color.black)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(EchoTVButtonStyle())

                        if let status = store.navidromeStatusText {
                            Text(status)
                                .font(.system(size: 18, design: .monospaced))
                                .foregroundStyle(EchoTVTheme.neoMint)
                        }
                    }

                    if let err = store.navidromeError {
                        Text(err)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(EchoTVTheme.dangerCoral)
                    }
                }
                .padding(32)
                .background(EchoTVTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 20))

                // 3. Optional Standalone Party Mode URL
                VStack(alignment: .leading, spacing: 14) {
                    Label("Standalone Party Mode Display URL (Optional)", systemImage: "sparkles.tv.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(EchoTVTheme.partyMagenta)
                    Text("When paired with My Echo on Mac above, Party TV connects automatically. You can also paste a direct Party Mode URL here (e.g. http://192.168.1.50:53333) to run the TV display without entering a PIN.")
                        .font(.system(size: 18))
                        .foregroundStyle(EchoTVTheme.textSecondary)
                    HStack(spacing: 16) {
                        TextField("http://192.168.1.50:53333", text: $bindableStore.standalonePartyURL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button("Save & Open Party TV") {
                            store.saveMacSettings()
                            store.selectedTab = .partyTV
                        }
                        .font(.system(size: 19, weight: .bold))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(EchoTVTheme.partyMagenta)
                        .foregroundStyle(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .buttonStyle(EchoTVButtonStyle())
                    }
                }
                .padding(32)
                .background(EchoTVTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 40)
        }
        .background(EchoTVTheme.canvas)
        .onChange(of: store.macServerURL) { _, _ in store.saveMacSettings() }
        .onChange(of: store.macTailscaleURL) { _, _ in store.saveMacSettings() }
        .onChange(of: store.pairingPIN) { _, _ in store.saveMacSettings() }
        .onChange(of: store.standalonePartyURL) { _, _ in store.saveMacSettings() }
        .onChange(of: store.navidromeConfig) { _, _ in store.saveNavidromeSettings() }
    }
}

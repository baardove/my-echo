import SwiftUI
import EchoCore

struct DeviceSyncView: View {
    @Environment(EchoStore.self) private var store
    let deviceID: UUID

    @State private var selectedDiffTab: DiffTab = .toCopy
    @State private var isEditingName: Bool = false
    @State private var draftName: String = ""

    enum DiffTab: String, CaseIterable {
        case toCopy = "To Copy"
        case playlists = "Playlists"
        case toRemove = "To Remove"
        case warnings = "Warnings"
    }

    var body: some View {
        if let idx = store.devices.firstIndex(where: { $0.id == deviceID }) {
            let device = store.devices[idx]
            let vol = store.volumeInfo(for: device)
            let plan = store.cachedSyncPlan(for: device)
                ?? SyncPlan.empty(for: device, projectedTracks: store.assignedTrackCount(for: device))

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    deviceHeader(device: device, vol: vol, plan: plan)

                    if device.isVirtualWireless {
                        wirelessIPhoneSyncHubCard(device: device, plan: plan)
                    }

                    if store.isSyncing, let prog = store.syncProgress {
                        liveSyncProgressCard(prog)
                    } else if let summary = store.lastSyncSummary {
                        lastSyncSummaryBanner(summary)
                    }

                    telemetryGrid(device: device, vol: vol, plan: plan)

                    // Two-column Configuration & Diff Preview
                    HStack(alignment: .top, spacing: 20) {
                        deviceSettingsCard(device: device)
                            .frame(width: 390)

                        syncDiffCard(device: device, plan: plan)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(26)
            }
            .task(id: device.id) {
                store.ensureSyncPlanLoaded(for: device.id)
            }
        } else {
            ContentUnavailableView("Device Not Found", systemImage: "sdcard")
        }
    }

    // MARK: - Header

    private func deviceHeader(device: DeviceProfile, vol: MountedVolumeInfo?, plan: SyncPlan) -> some View {
        ZStack(alignment: .leading) {
            LinearGradient(
                colors: [
                    (device.isConnected ? EchoTheme.neoMint : EchoTheme.warningAmber).opacity(0.22),
                    EchoTheme.neoCyan.opacity(0.10),
                    EchoTheme.surface
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous)
                    .strokeBorder(EchoTheme.borderStrong, lineWidth: 1)
            )

            HStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous)
                        .fill(Color.black.opacity(0.42))
                        .frame(width: 72, height: 72)
                        .overlay(
                            RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous)
                                .strokeBorder(EchoTheme.color(for: device.accentColor).opacity(0.55), lineWidth: 1.5)
                        )
                    Image(systemName: device.preset == .iphoneWireless ? "iphone.radiowaves.left.and.right" : (device.preset == .fiioDisc ? "opticaldisc.fill" : (device.preset == .fiioEchoMini || device.preset == .fiioNano ? "hifispeaker.fill" : "sdcard.fill")))
                        .font(.system(size: 30))
                        .foregroundStyle(EchoTheme.accentGradient)
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(device.isVirtualWireless ? (store.isWirelessServerRunning ? EchoTheme.neoMint : EchoTheme.warningAmber) : (device.isConnected ? EchoTheme.neoMint : EchoTheme.dangerCoral))
                            .frame(width: 8, height: 8)
                        Text(device.isVirtualWireless
                             ? (store.isWirelessServerRunning ? "WI-FI AUTO-SYNC LIVE · BONJOUR" : "WI-FI SERVER STARTING")
                             : (device.isConnected ? "CONNECTED" : "OFFLINE — PLUG IN TO SYNC"))
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .tracking(1.2)
                            .foregroundStyle(device.isConnected ? EchoTheme.neoMint : EchoTheme.dangerCoral)
                        if let vol {
                            Text("· \(vol.fileSystemType)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(EchoTheme.textMuted)
                            if vol.connectionKind != .unknown {
                                let connColor: Color = vol.connectionKind == .inPlayer ? EchoTheme.neoMint : (vol.connectionKind.isCardReader ? EchoTheme.warningAmber : EchoTheme.neoCyan)
                                HStack(spacing: 4) {
                                    Image(systemName: vol.connectionKind.iconName)
                                        .font(.system(size: 9, weight: .bold))
                                    Text(vol.connectionKind.shortBadge)
                                        .font(.system(size: 9, weight: .black, design: .monospaced))
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(connColor.opacity(0.16))
                                .foregroundStyle(connColor)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(connColor.opacity(0.45), lineWidth: 1))
                                .help(vol.connectionSummary)
                            }
                        } else if !device.isVirtualWireless, let lastKind = device.lastConnectionKind, lastKind != .unknown {
                            Text("· Last via \(lastKind.shortBadge)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(EchoTheme.textMuted)
                                .help(device.lastConnectionDetail ?? lastKind.displayName)
                        } else if device.isVirtualWireless, store.wirelessServerPort > 0 {
                            Text("· PORT \(store.wirelessServerPort)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(EchoTheme.neoCyan)
                        }
                    }

                    if isEditingName {
                        HStack(spacing: 8) {
                            TextField("Destination name", text: $draftName)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 240)
                                .onSubmit {
                                    store.renameDevice(device, to: draftName)
                                    isEditingName = false
                                }
                            Button("Save") {
                                store.renameDevice(device, to: draftName)
                                isEditingName = false
                            }
                            .buttonStyle(.borderedProminent)
                            Button("Cancel") {
                                isEditingName = false
                            }
                        }
                    } else {
                        HStack(spacing: 8) {
                            Text(device.name)
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundStyle(EchoTheme.textPrimary)
                            Button {
                                draftName = device.name
                                isEditingName = true
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.system(size: 12, weight: .semibold))
                                    .frame(width: 26, height: 26)
                                    .background(EchoTheme.surfaceElevated.opacity(0.8))
                                    .foregroundStyle(EchoTheme.textSecondary)
                                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                            }
                            .buttonStyle(.plain)
                            .help("Rename this destination (sets a custom display name).")

                            if device.hasCustomName {
                                Button {
                                    store.resetDeviceNameFromVolume(device)
                                } label: {
                                    Image(systemName: "arrow.uturn.backward")
                                        .font(.system(size: 11, weight: .semibold))
                                        .frame(width: 26, height: 26)
                                        .background(EchoTheme.surfaceElevated.opacity(0.8))
                                        .foregroundStyle(EchoTheme.neoCyan)
                                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                                }
                                .buttonStyle(.plain)
                                .help("Reset destination name back to the mounted volume's actual name.")
                            }
                        }
                    }

                    Text(device.isVirtualWireless
                         ? "http://\(store.wirelessServerLANIP ?? "localhost"):\(store.wirelessServerPort > 0 ? Int(store.wirelessServerPort) : Int(WirelessSyncServer.defaultPort)) · Bonjour \(WirelessSyncServer.bonjourServiceType)"
                         : device.mountPath)
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundStyle(EchoTheme.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 10) {
                    HStack(spacing: 10) {
                        let isSelectedTarget = store.activeDevice?.id == device.id
                        Button {
                            store.selectActiveDevice(device.id)
                        } label: {
                            Label(isSelectedTarget ? "Selected Target" : "Set as Target", systemImage: isSelectedTarget ? "checkmark.square.fill" : "target")
                                .font(.system(size: 11.5, weight: .bold))
                                .padding(.horizontal, 11)
                                .padding(.vertical, 7.5)
                                .background(isSelectedTarget ? EchoTheme.color(for: device.accentColor).opacity(0.22) : EchoTheme.surfaceElevated)
                                .foregroundStyle(isSelectedTarget ? EchoTheme.color(for: device.accentColor) : EchoTheme.textPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                                .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusControl).strokeBorder(isSelectedTarget ? EchoTheme.color(for: device.accentColor) : EchoTheme.borderStrong, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .help("Make '\(device.name)' the active destination for all sync toggles across your library, playlists, and podcasts.")

                        if !device.isConnected {
                            Button {
                                store.relinkDeviceVolumeViaPanel(device)
                            } label: {
                                Label("Relink Volume", systemImage: "link")
                                    .font(.system(size: 11.5, weight: .bold))
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 7.5)
                                    .background(EchoTheme.neoCyan.opacity(0.18))
                                    .foregroundStyle(EchoTheme.neoCyan)
                                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                                    .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusControl).strokeBorder(EchoTheme.neoCyan.opacity(0.5), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .help("Point '\(device.name)' to a newly formatted/renamed SD card or folder without losing your saved songs and podcasts.")
                        }

                        if device.isConnected && (vol?.isRemovable == true || device.mountPath.hasPrefix("/Volumes/")) {
                            HStack(spacing: 4) {
                                NeoSecondaryButton(
                                    title: "Clean ._* & Eject",
                                    icon: "eject.fill",
                                    disabled: store.isSyncing
                                ) {
                                    store.cleanAndEjectDevice(device, force: false)
                                }
                                .help("Flush writes, purge all hidden macOS ._* and .DS_Store files from '\(device.name)', and safely unmount/eject via diskutil.")

                                Button {
                                    store.cleanAndEjectDevice(device, force: true)
                                } label: {
                                    Image(systemName: "bolt.horizontal.circle.fill")
                                        .font(.system(size: 13))
                                        .frame(width: 30, height: 30)
                                        .background(EchoTheme.warningAmber.opacity(0.16))
                                        .foregroundStyle(EchoTheme.warningAmber)
                                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                                        .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusControl).strokeBorder(EchoTheme.warningAmber.opacity(0.45), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .disabled(store.isSyncing)
                                .help("Force Eject '\(device.name)' (use if Spotlight or Finder keeps the volume busy after normal eject).")
                            }
                        }

                        if store.isSyncing {
                            Button {
                                store.cancelSync()
                            } label: {
                                Text("Cancel Sync")
                                    .font(.system(size: 12.5, weight: .bold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7.5)
                                    .background(EchoTheme.dangerCoral.opacity(0.2))
                                    .foregroundStyle(EchoTheme.dangerCoral)
                                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                            }
                            .buttonStyle(.plain)
                            .help("Stop the currently running sync operation after the active file finishes.")
                        } else {
                            NeoPrimaryButton(
                                title: device.isVirtualWireless
                                    ? "Publish to iPhone"
                                    : (plan.hasPendingChanges ? "Sync \(plan.totalPendingCopies) Item\(plan.totalPendingCopies == 1 ? "" : "s")" : "Sync Now"),
                                icon: device.isVirtualWireless ? "wifi" : "arrow.triangle.2.circlepath",
                                disabled: !device.isConnected
                            ) {
                                store.selectActiveDevice(device.id)
                                store.startSync(for: device)
                            }
                            .help(device.isVirtualWireless
                                  ? "Refresh the Wi-Fi manifest immediately so My Echo iOS auto-syncs all pending changes over Wi-Fi."
                                  : "Execute the sync plan for '\(device.name)': copy music & podcasts, optimize cover art to Baseline JPEG, export M3U playlists, and clean ._* files.")
                        }
                    }

                    if let last = device.lastSyncedAt {
                        Text("Last synced \(last.formatted(date: .abbreviated, time: .shortened))")
                            .font(.system(size: 10.5))
                            .foregroundStyle(EchoTheme.textMuted)
                    }
                }
            }
            .padding(22)
        }
    }

    // MARK: - Virtual iPhone Wi-Fi Auto-Sync Hub

    private func wirelessIPhoneSyncHubCard(device: DeviceProfile, plan: SyncPlan) -> some View {
        let lanIP = store.wirelessServerLANIP ?? "127.0.0.1"
        let port = store.wirelessServerPort > 0 ? store.wirelessServerPort : WirelessSyncServer.defaultPort
        let serverURL = "http://\(lanIP):\(port)"
        let pin = device.wirelessSyncToken ?? "000000"
        let manifestVer = store.wirelessManifestVersions[device.id] ?? "—"

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "wifi")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(store.isWirelessServerRunning ? EchoTheme.neoMint : EchoTheme.warningAmber)
                VStack(alignment: .leading, spacing: 2) {
                    Text("iPhone Wi-Fi Auto-Sync Server (Bonjour + HTTP)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(EchoTheme.textPrimary)
                    Text("Open the standalone My Echo iOS app on the same Wi-Fi network — it auto-discovers this Mac and syncs all tracks, playlists, and podcasts marked for '\(device.name)'. On cellular/away from home, stream your full library from Navidrome over Tailscale.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(EchoTheme.textSecondary)
                }
                Spacer()
                Button("Open iOS Project") {
                    let fallback = URL(fileURLWithPath: "/Users/bard/Code/Echo/iOS")
                    NSWorkspace.shared.open(fallback)
                }
                .font(.system(size: 11, weight: .bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(EchoTheme.surfaceElevated)
                .foregroundStyle(EchoTheme.neoCyan)
                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                .buttonStyle(.plain)
                .help("Open the standalone My Echo iOS Xcode project folder in Finder.")
            }

            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("LOCAL WI-FI SYNC URL")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(EchoTheme.textMuted)
                    HStack(spacing: 8) {
                        Text(serverURL)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(EchoTheme.neoCyan)
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(serverURL, forType: .string)
                            store.showToast("Copied Wi-Fi Sync URL: \(serverURL)")
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 11))
                                .foregroundStyle(EchoTheme.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .help("Copy server URL to clipboard.")
                    }
                }
                .padding(10)
                .background(Color.black.opacity(0.28))
                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))

                VStack(alignment: .leading, spacing: 4) {
                    Text("6-DIGIT PAIRING PIN")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(EchoTheme.textMuted)
                    HStack(spacing: 8) {
                        Text(pin)
                            .font(.system(size: 15, weight: .black, design: .monospaced))
                            .tracking(2.0)
                            .foregroundStyle(EchoTheme.neoMint)
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(pin, forType: .string)
                            store.showToast("Copied Pairing PIN")
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 11))
                                .foregroundStyle(EchoTheme.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .help("Copy Pairing PIN.")
                        Button {
                            store.regenerateWirelessPIN(for: device)
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11))
                                .foregroundStyle(EchoTheme.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .help("Generate a new 6-digit pairing PIN.")
                    }
                }
                .padding(10)
                .background(Color.black.opacity(0.28))
                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))

                VStack(alignment: .leading, spacing: 4) {
                    Text("LIVE MANIFEST · \(manifestVer.uppercased())")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(EchoTheme.textMuted)
                    Text("\(plan.projectedTotalTracks) tracks · \(plan.playlistsToWrite.count) playlists · \(device.syncedTrackIDs.count) confirmed on iPhone")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(EchoTheme.textPrimary)
                    if let last = device.lastSyncedAt {
                        Text("Last iPhone sync: \(last.formatted(date: .abbreviated, time: .shortened))")
                            .font(.system(size: 10.5))
                            .foregroundStyle(EchoTheme.neoMint)
                    } else {
                        Text("Waiting for first iPhone connection on Wi-Fi...")
                            .font(.system(size: 10.5))
                            .foregroundStyle(EchoTheme.textMuted)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.28))
                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
            }
        }
        .padding(16)
        .background(EchoTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous)
                .strokeBorder(EchoTheme.neoCyan.opacity(0.45), lineWidth: 1)
        )
    }

    // MARK: - Telemetry Cards (Storage + Track Cap + Selection Summary)

    private func telemetryGrid(device: DeviceProfile, vol: MountedVolumeInfo?, plan: SyncPlan) -> some View {
        HStack(spacing: 14) {
            // Track Cap Card (crucial for Echo Mini's 8,191 database limit)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("DEVICE TRACK COUNT")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(EchoTheme.textMuted)
                    Spacer()
                    if let cap = device.maxTrackLimit {
                        Text("CAP: \(cap)")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(plan.exceedsTrackLimit ? EchoTheme.dangerCoral : EchoTheme.neoCyan)
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(plan.projectedTotalTracks)")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(plan.exceedsTrackLimit ? EchoTheme.dangerCoral : EchoTheme.textPrimary)
                    if let cap = device.maxTrackLimit {
                        Text("/ \(cap) tracks")
                            .font(.system(size: 12))
                            .foregroundStyle(EchoTheme.textSecondary)
                    } else {
                        Text("tracks projected")
                            .font(.system(size: 12))
                            .foregroundStyle(EchoTheme.textSecondary)
                    }
                }

                if let cap = device.maxTrackLimit, cap > 0 {
                    let ratio = min(1.0, Double(plan.projectedTotalTracks) / Double(cap))
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.08))
                            RoundedRectangle(cornerRadius: 2)
                                .fill(plan.exceedsTrackLimit ? EchoTheme.dangerCoral : (ratio > 0.85 ? EchoTheme.warningAmber : EchoTheme.neoMint))
                                .frame(width: max(4, geo.size.width * ratio))
                        }
                    }
                    .frame(height: 6)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(EchoTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous).strokeBorder(EchoTheme.border, lineWidth: 1))

            // Storage Telemetry Card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("STORAGE DELTA")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(EchoTheme.textMuted)
                    Spacer()
                    if let vol {
                        Text("\(Formatters.bytes(vol.availableBytes)) FREE")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(EchoTheme.neoMint)
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("+\(Formatters.bytes(plan.estimatedBytesToWrite))")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(EchoTheme.neoMint)
                    if plan.estimatedBytesToFree > 0 {
                        Text("-\(Formatters.bytes(plan.estimatedBytesToFree))")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(EchoTheme.dangerCoral)
                    }
                }

                Text("\(plan.tracksUpToDate.count) up-to-date · \(plan.tracksToCopy.count) to copy · \(plan.playlistsToWrite.count) M3U playlists")
                    .font(.system(size: 11))
                    .foregroundStyle(EchoTheme.textSecondary)
                    .lineLimit(1)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(EchoTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous).strokeBorder(EchoTheme.border, lineWidth: 1))

            // Active Selections Summary Card
            VStack(alignment: .leading, spacing: 8) {
                Text("SYNC SELECTIONS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(EchoTheme.textMuted)

                HStack(spacing: 12) {
                    miniCount(device.selectedArtistKeys.count, "Artists")
                    miniCount(device.selectedAlbumKeys.count, "Albums")
                    miniCount(device.selectedTrackIDs.count, "Tracks")
                    miniCount(device.selectedPlaylistIDs.count, "Playlists")
                    miniCount(device.selectedPodcastShowIDs.count + device.selectedEpisodeIDs.count, "Podcasts")
                }

                if !plan.unsupportedSkipped.isEmpty || !plan.offlineSkipped.isEmpty {
                    Text("⚠ \(plan.unsupportedSkipped.count) unsupported · \(plan.offlineSkipped.count) offline")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(EchoTheme.warningAmber)
                } else {
                    Text("All selected formats supported by \(device.preset.displayName)")
                        .font(.system(size: 11))
                        .foregroundStyle(EchoTheme.neoMint.opacity(0.9))
                        .lineLimit(1)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(EchoTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous).strokeBorder(EchoTheme.border, lineWidth: 1))
        }
    }

    private func miniCount(_ n: Int, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(n)")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(EchoTheme.textPrimary)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(EchoTheme.textMuted)
        }
    }

    // MARK: - Device Profile Settings Card

    private func deviceSettingsCard(device: DeviceProfile) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Player Profile & FiiO Settings")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(EchoTheme.textPrimary)
                Spacer()
                Button(role: .destructive) {
                    store.deleteDevice(device)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(EchoTheme.dangerCoral)
                }
                .buttonStyle(.plain)
                .help("Remove Device Profile")
            }

            // Preset Picker
            VStack(alignment: .leading, spacing: 6) {
                Text("HARDWARE PRESET")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(EchoTheme.textMuted)

                NeoPickerDropdown(
                    icon: "cpu",
                    fullWidth: true,
                    selection: Binding(
                        get: { device.preset },
                        set: { newPreset in
                            var updated = device
                            updated.applyPresetDefaults(newPreset)
                            store.updateDevice(updated)
                        }
                    ),
                    options: DevicePresetKind.allCases.map { ($0, $0.displayName) }
                )

                Text(device.preset.subtitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(EchoTheme.textMuted)
            }

            // Sync Mode (Mirror vs Additive)
            VStack(alignment: .leading, spacing: 6) {
                Text("SYNC MODE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(EchoTheme.textMuted)

                NeoSegmentedControl(
                    selection: Binding(
                        get: { device.syncMode },
                        set: { mode in
                            var updated = device
                            updated.syncMode = mode
                            store.updateDevice(updated)
                        }
                    ),
                    options: SyncMode.allCases.map { ($0, $0.displayName) }
                )

                Text(device.syncMode.detail)
                    .font(.system(size: 10.5))
                    .foregroundStyle(EchoTheme.textSecondary)
            }

            Divider().overlay(EchoTheme.border)

            // Folder & Playlist M3U Paths
            VStack(alignment: .leading, spacing: 10) {
                Text("STORAGE PATHS (ARTIST/ALBUM/TRACK)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(EchoTheme.textMuted)

                HStack {
                    Text("Music root folder")
                        .font(.system(size: 12))
                        .foregroundStyle(EchoTheme.textSecondary)
                    Spacer()
                    TextField("Music", text: Binding(
                        get: { device.musicSubfolder },
                        set: { val in
                            var updated = device
                            updated.musicSubfolder = val
                            store.updateDevice(updated)
                        }
                    ))
                    .neoTextField()
                    .frame(width: 150)
                }

                HStack {
                    Text("Podcasts folder")
                        .font(.system(size: 12))
                        .foregroundStyle(EchoTheme.textSecondary)
                    Spacer()
                    TextField("Podcasts", text: Binding(
                        get: { device.podcastsSubfolder },
                        set: { val in
                            var updated = device
                            updated.podcastsSubfolder = val
                            store.updateDevice(updated)
                        }
                    ))
                    .neoTextField()
                    .frame(width: 150)
                }

                HStack {
                    Text("Latest episodes / show")
                        .font(.system(size: 12))
                        .foregroundStyle(EchoTheme.textSecondary)
                    Spacer()
                    NeoPickerDropdown(
                        fullWidth: true,
                        selection: Binding(
                            get: { device.podcastEpisodesPerShowLimit },
                            set: { v in var d = device; d.podcastEpisodesPerShowLimit = v; store.updateDevice(d) }
                        ),
                        options: [
                            (3, "Latest 3"),
                            (5, "Latest 5"),
                            (10, "Latest 10"),
                            (20, "Latest 20")
                        ]
                    )
                    .frame(width: 150)
                }

                HStack {
                    Text("Playlists folder")
                        .font(.system(size: 12))
                        .foregroundStyle(EchoTheme.textSecondary)
                    Spacer()
                    TextField("Root (empty) or Playlists", text: Binding(
                        get: { device.playlistsSubfolder },
                        set: { val in
                            var updated = device
                            updated.playlistsSubfolder = val
                            store.updateDevice(updated)
                        }
                    ))
                    .neoTextField()
                    .frame(width: 150)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("M3U Path Format")
                        .font(.system(size: 11.5))
                        .foregroundStyle(EchoTheme.textSecondary)
                    NeoPickerDropdown(
                        fullWidth: true,
                        selection: Binding(
                            get: { device.playlistPathStyle },
                            set: { style in
                                var updated = device
                                updated.playlistPathStyle = style
                                store.updateDevice(updated)
                            }
                        ),
                        options: PlaylistPathStyle.allCases.map { ($0, $0.displayName) }
                    )
                }
            }

            Divider().overlay(EchoTheme.border)

            // FiiO Artwork & Metadata Optimizations
            VStack(alignment: .leading, spacing: 9) {
                Text("ARTWORK, METADATA & MACOS HYGIENE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(EchoTheme.textMuted)

                Toggle("Optimize embedded art (Baseline RGB JPEG)", isOn: Binding(
                    get: { device.optimizeArtwork },
                    set: { v in var d = device; d.optimizeArtwork = v; store.updateDevice(d) }
                ))
                .font(.system(size: 12))

                if device.optimizeArtwork {
                    HStack {
                        Text("Max cover size")
                            .font(.system(size: 11.5))
                            .foregroundStyle(EchoTheme.textSecondary)
                        Spacer()
                        NeoPickerDropdown(
                            fullWidth: true,
                            selection: Binding(
                                get: { device.maxArtworkDimension },
                                set: { v in var d = device; d.maxArtworkDimension = v; store.updateDevice(d) }
                            ),
                            options: [
                                (500, "500 × 500 (Nano / Ultra-safe)"),
                                (600, "600 × 600 (Echo)"),
                                (800, "800 × 800 (Standard)"),
                                (1000, "1000 × 1000 (Disc / Android)")
                            ]
                        )
                        .frame(width: 195)
                    }
                }

                Toggle("Write folder.jpg inside ARTIST/ALBUM/", isOn: Binding(
                    get: { device.writeFolderCoverJPG },
                    set: { v in var d = device; d.writeFolderCoverJPG = v; store.updateDevice(d) }
                ))
                .font(.system(size: 12))

                Toggle("Strip MP3 COMM tags (ID3v2.3 safe)", isOn: Binding(
                    get: { device.stripMP3Comments },
                    set: { v in var d = device; d.stripMP3Comments = v; store.updateDevice(d) }
                ))
                .font(.system(size: 12))

                Toggle("Copy synced .lrc lyrics sidecars", isOn: Binding(
                    get: { device.copySidecarLyrics },
                    set: { v in var d = device; d.copySidecarLyrics = v; store.updateDevice(d) }
                ))
                .font(.system(size: 12))

                Toggle("Auto-purge macOS ._* & .DS_Store files", isOn: Binding(
                    get: { device.cleanMacOSDotFiles },
                    set: { v in var d = device; d.cleanMacOSDotFiles = v; store.updateDevice(d) }
                ))
                .font(.system(size: 12))
            }
            .tint(EchoTheme.neoMint)
        }
        .padding(18)
        .background(EchoTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous).strokeBorder(EchoTheme.border, lineWidth: 1))
    }

    // MARK: - Pre-Sync Diff Preview Card

    private func syncDiffCard(device: DeviceProfile, plan: SyncPlan) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Pre-Sync Plan & Path Preview")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(EchoTheme.textPrimary)
                Spacer()
                NeoSegmentedControl(
                    selection: $selectedDiffTab,
                    options: [
                        (.toCopy, "Copy (\(plan.totalPendingCopies))"),
                        (.playlists, "Playlists (\(plan.playlistsToWrite.count))"),
                        (.toRemove, "Remove (\(plan.totalPendingRemovals))"),
                        (.warnings, "Warnings (\(plan.unsupportedSkipped.count + plan.offlineSkipped.count))")
                    ]
                )
                .frame(width: 390)
            }

            Divider().overlay(EchoTheme.border)

            switch selectedDiffTab {
            case .toCopy:
                if plan.tracksToCopy.isEmpty && plan.episodesToCopy.isEmpty {
                    emptyDiffState(
                        icon: "checkmark.seal.fill",
                        color: EchoTheme.neoMint,
                        title: "Everything selected is up to date",
                        subtitle: "Select artists, albums, tracks, playlists, or podcasts in your library to queue them for \(device.name)."
                    )
                } else {
                    VStack(spacing: 6) {
                        ForEach(plan.episodesToCopy.prefix(50), id: \.episode.id) { item in
                            HStack(spacing: 10) {
                                Image(systemName: item.needsDownloadFirst ? "icloud.and.arrow.down.fill" : "mic.fill")
                                    .foregroundStyle(EchoTheme.neoCyan)
                                    .font(.system(size: 12))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.relativeDestinationPath)
                                        .font(.system(size: 11.5, design: .monospaced))
                                        .foregroundStyle(EchoTheme.textPrimary)
                                        .lineLimit(1)
                                    Text("\(item.episode.showTitle)\(item.needsDownloadFirst ? " · Will download automatically" : "")")
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(EchoTheme.textMuted)
                                }
                                Spacer()
                                Text("PODCAST")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(EchoTheme.neoCyan.opacity(0.18))
                                    .foregroundStyle(EchoTheme.neoCyan)
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            }
                            .padding(.vertical, 5)
                            .padding(.horizontal, 8)
                            .background(EchoTheme.surfaceElevated.opacity(0.45))
                            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                        }

                        ForEach(plan.tracksToCopy.prefix(150), id: \.track.id) { item in
                            HStack(spacing: 10) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundStyle(EchoTheme.neoMint)
                                    .font(.system(size: 12))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.relativeDestinationPath)
                                        .font(.system(size: 11.5, design: .monospaced))
                                        .foregroundStyle(EchoTheme.textPrimary)
                                        .lineLimit(1)
                                    HStack(spacing: 4) {
                                        ArtistLinksView(
                                            rawArtists: item.track.artist,
                                            font: .system(size: 10.5),
                                            color: EchoTheme.textMuted,
                                            hoverColor: EchoTheme.neoMint
                                        ) { artistName in
                                            store.openArtist(name: artistName)
                                        }
                                        Text("·")
                                            .font(.system(size: 10.5))
                                            .foregroundStyle(EchoTheme.textMuted)
                                        HoverLinkText(
                                            text: item.track.effectiveAlbum,
                                            font: .system(size: 10.5),
                                            color: EchoTheme.textMuted,
                                            hoverColor: EchoTheme.neoCyan,
                                            tip: "Go to album '\(item.track.effectiveAlbum)'"
                                        ) {
                                            store.openAlbum(forTrack: item.track)
                                        }
                                    }
                                }
                                Spacer()
                                FormatBadge(track: item.track)
                                Text(Formatters.bytes(item.track.fileSize))
                                    .font(.system(size: 10.5, design: .monospaced))
                                    .foregroundStyle(EchoTheme.textMuted)
                                    .frame(width: 62, alignment: .trailing)
                            }
                            .padding(.vertical, 5)
                            .padding(.horizontal, 8)
                            .background(EchoTheme.surfaceElevated.opacity(0.45))
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                        }
                        if plan.tracksToCopy.count > 150 {
                            Text("…and \(plan.tracksToCopy.count - 150) more tracks")
                                .font(.system(size: 11))
                                .foregroundStyle(EchoTheme.textMuted)
                                .padding(.top, 4)
                        }
                    }
                }

            case .playlists:
                if store.playlists.isEmpty {
                    emptyDiffState(
                        icon: "music.note.list",
                        color: EchoTheme.neoCyan,
                        title: "No playlists created yet",
                        subtitle: "Create a playlist in the sidebar or drag & drop songs onto '+ New Playlist' to build one."
                    )
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(store.playlists) { playlist in
                            let isIncluded = device.selectedPlaylistIDs.contains(playlist.id)
                            let planned = plan.playlistsToWrite.first(where: { $0.playlist.id == playlist.id })
                            let relPath = PathFormatter.relativePlaylistPath(for: playlist, profile: device)

                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .center, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(playlist.name)
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundStyle(isIncluded ? EchoTheme.textPrimary : EchoTheme.textSecondary)
                                                .lineLimit(1)
                                            Text("\(playlist.trackIDs.count) tracks")
                                                .font(.system(size: 10.5, design: .monospaced))
                                                .foregroundStyle(isIncluded ? EchoTheme.neoMint : EchoTheme.textMuted)
                                        }
                                        Text(isIncluded ? "Will export \(relPath)" : "Excluded from sync")
                                            .font(.system(size: 10.5, design: .monospaced))
                                            .foregroundStyle(isIncluded ? EchoTheme.neoCyan : EchoTheme.textMuted)
                                            .lineLimit(1)
                                    }

                                    Spacer(minLength: 12)

                                    Toggle("", isOn: Binding(
                                        get: { isIncluded },
                                        set: { enabled in
                                            var updated = device
                                            if enabled {
                                                updated.selectedPlaylistIDs.insert(playlist.id)
                                            } else {
                                                updated.selectedPlaylistIDs.remove(playlist.id)
                                            }
                                            store.updateDevice(updated)
                                        }
                                    ))
                                    .labelsHidden()
                                    .toggleStyle(.switch)
                                    .controlSize(.small)
                                    .tint(EchoTheme.neoMint)
                                }

                                if isIncluded, let firstEntry = planned?.entries.first {
                                    let sampleLine = PathFormatter.buildM3UContent(
                                        playlist: playlist,
                                        trackRelativePaths: [firstEntry],
                                        profile: device
                                    ).split(whereSeparator: \.isNewline).last.map(String.init) ?? ""
                                    Text("M3U preview: \(sampleLine)")
                                        .font(.system(size: 10.5, design: .monospaced))
                                        .foregroundStyle(EchoTheme.textMuted)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(11)
                            .background(isIncluded ? EchoTheme.neoMint.opacity(0.08) : EchoTheme.surfaceElevated.opacity(0.35))
                            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard))
                            .overlay(
                                RoundedRectangle(cornerRadius: EchoTheme.radiusCard)
                                    .strokeBorder(isIncluded ? EchoTheme.neoMint.opacity(0.35) : EchoTheme.border, lineWidth: 1)
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

            case .toRemove:
                if plan.tracksToRemove.isEmpty {
                    emptyDiffState(
                        icon: "sparkles",
                        color: EchoTheme.textMuted,
                        title: device.syncMode == .mirror ? "No tracks scheduled for removal" : "Additive Copy mode active",
                        subtitle: device.syncMode == .mirror
                            ? "Deselecting a previously synced track or album will list it here."
                            : "Additive mode never deletes existing files from your player."
                    )
                } else {
                    VStack(spacing: 6) {
                        ForEach(plan.tracksToRemove, id: \.trackID) { entry in
                            HStack(spacing: 10) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(EchoTheme.dangerCoral)
                                Text(entry.relativePath)
                                    .font(.system(size: 11.5, design: .monospaced))
                                    .foregroundStyle(EchoTheme.textPrimary)
                                    .lineLimit(1)
                                Spacer()
                                Text(Formatters.bytes(entry.sourceFileSize))
                                    .font(.system(size: 10.5, design: .monospaced))
                                    .foregroundStyle(EchoTheme.textMuted)
                            }
                            .padding(.vertical, 5)
                            .padding(.horizontal, 8)
                            .background(EchoTheme.dangerCoral.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                        }
                    }
                }

            case .warnings:
                if plan.unsupportedSkipped.isEmpty && plan.offlineSkipped.isEmpty && !plan.exceedsTrackLimit {
                    emptyDiffState(
                        icon: "checkmark.shield.fill",
                        color: EchoTheme.neoMint,
                        title: "Zero compatibility warnings",
                        subtitle: "Every selected track is online, within the device track cap, and supported by \(device.preset.displayName)."
                    )
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        if plan.exceedsTrackLimit, let cap = plan.maxTrackLimit {
                            HStack(spacing: 10) {
                                Image(systemName: "exclamationmark.octagon.fill")
                                    .foregroundStyle(EchoTheme.dangerCoral)
                                Text("Projected \(plan.projectedTotalTracks) tracks exceeds \(device.preset.displayName)'s \(cap)-track database limit.")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(EchoTheme.dangerCoral)
                            }
                            .padding(10)
                            .background(EchoTheme.dangerCoral.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        ForEach(plan.unsupportedSkipped) { track in
                            HStack(spacing: 10) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(EchoTheme.warningAmber)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(track.artist) – \(track.title)")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(EchoTheme.textPrimary)
                                    Text("Unsupported format (\(track.format.displayBadge)) — skipped automatically")
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(EchoTheme.warningAmber)
                                }
                                Spacer()
                            }
                            .padding(8)
                            .background(EchoTheme.warningAmber.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        ForEach(plan.offlineSkipped) { track in
                            HStack(spacing: 10) {
                                Image(systemName: "wifi.slash")
                                    .foregroundStyle(EchoTheme.dangerCoral)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(track.artist) – \(track.title)")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(EchoTheme.textPrimary)
                                    Text("Source folder / NAS is currently offline")
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(EchoTheme.dangerCoral)
                                }
                                Spacer()
                            }
                            .padding(8)
                            .background(EchoTheme.dangerCoral.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(EchoTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous).strokeBorder(EchoTheme.border, lineWidth: 1))
    }

    private func emptyDiffState(icon: String, color: Color, title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(EchoTheme.textPrimary)
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(EchoTheme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity)
        .padding(36)
    }

    private func liveSyncProgressCard(_ prog: SyncProgress) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ProgressView().controlSize(.small)
                Text(prog.phase)
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(EchoTheme.neoMint)
                Spacer()
                Text("\(Int(prog.fraction * 100))% · \(Formatters.bytes(prog.bytesCopied)) / \(Formatters.bytes(prog.totalBytes))")
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(EchoTheme.textSecondary)
            }
            ProgressView(value: prog.fraction)
                .tint(EchoTheme.neoMint)
            Text(prog.currentItem)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(EchoTheme.textMuted)
                .lineLimit(1)
        }
        .padding(16)
        .background(EchoTheme.neoMint.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous).strokeBorder(EchoTheme.neoMint.opacity(0.35), lineWidth: 1))
    }

    private func lastSyncSummaryBanner(_ summary: SyncExecutionSummary) -> some View {
        HStack(spacing: 12) {
            Image(systemName: summary.errors.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 18))
                .foregroundStyle(summary.errors.isEmpty ? EchoTheme.neoMint : EchoTheme.warningAmber)
            VStack(alignment: .leading, spacing: 2) {
                Text("Last Sync Complete · \(summary.tracksCopied) copied, \(summary.tracksRemoved) removed, \(summary.playlistsWritten) playlists, \(summary.dotFilesCleaned) ._* files cleaned")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(EchoTheme.textPrimary)
                if !summary.errors.isEmpty {
                    Text(summary.errors.prefix(2).joined(separator: " · "))
                        .font(.system(size: 11))
                        .foregroundStyle(EchoTheme.warningAmber)
                }
            }
            Spacer()
        }
        .padding(14)
        .background(EchoTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous).strokeBorder(EchoTheme.neoMint.opacity(0.35), lineWidth: 1))
    }
}

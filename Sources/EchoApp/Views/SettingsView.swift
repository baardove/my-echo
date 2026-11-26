import SwiftUI
import AppKit
import EchoCore

struct SettingsView: View {
    @Environment(EchoStore.self) private var store
    @State private var renamingDevice: DeviceProfile?
    @State private var renameDraft: String = ""
    @State private var lastFMKeyDraft: String = ""
    @State private var showResetPlaysConfirm = false
    @State private var lidarrURLDraft: String = ""
    @State private var lidarrKeyDraft: String = ""
    @State private var echoServerLANURLDraft: String = ""
    @State private var echoServerTSURLDraft: String = ""
    @State private var echoServerPINDraft: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack(spacing: 16) {
                    EchoBrandLogo(size: 42, animate: true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SYSTEM DECK & PREFERENCES")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(1.4)
                            .foregroundStyle(EchoTheme.neoMint)
                        Text("Settings")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(EchoTheme.textPrimary)
                    }
                    Spacer()
                }

                // 1. Sync Destination Mode (Single vs Multi-Destination)
                VStack(alignment: .leading, spacing: 14) {
                    Text("SYNC DESTINATION MODE")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(EchoTheme.neoCyan)

                    HStack(spacing: 14) {
                        ForEach(DestinationMode.allCases, id: \.self) { mode in
                            let selected = store.destinationMode == mode
                            Button {
                                store.setDestinationMode(mode)
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: mode == .single ? "sdcard.fill" : "square.stack.3d.up.fill")
                                            .font(.system(size: 16))
                                            .foregroundStyle(selected ? EchoTheme.neoMint : EchoTheme.textSecondary)
                                        Text(mode.displayName)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(EchoTheme.textPrimary)
                                        Spacer()
                                        Image(systemName: selected ? "checkmark.square.fill" : "square")
                                            .foregroundStyle(selected ? EchoTheme.neoMint : EchoTheme.textMuted)
                                    }
                                    Text(mode.detail)
                                        .font(.system(size: 11.5))
                                        .foregroundStyle(EchoTheme.textSecondary)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(selected ? EchoTheme.neoMint.opacity(0.10) : EchoTheme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous)
                                        .strokeBorder(selected ? EchoTheme.neoMint : EchoTheme.border, lineWidth: selected ? 1.5 : 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .help(mode == .single
                                  ? "Single Destination Mode: automatically targets your primary audio player or SD card."
                                  : "Multi-Destination Mode: explicitly choose which destination (e.g. ECHO internal vs ECHO SD) to target; tracks and podcasts remember which destinations they sync to.")
                        }
                    }

                    // Active Sync Destination Selector
                    if !store.devices.isEmpty {
                        HStack(spacing: 12) {
                            Text("Selected Sync Target:")
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(EchoTheme.textSecondary)

                            NeoPickerDropdown(
                                icon: "sdcard.fill",
                                fullWidth: true,
                                selection: Binding<UUID?>(
                                    get: { store.activeDeviceID },
                                    set: { store.selectActiveDevice($0) }
                                ),
                                options: (store.destinationMode == .multi
                                          ? [(UUID?.none, "None — Prompt Me to Choose")]
                                          : []) + store.devices.map { (UUID?.some($0.id), "\($0.name) (\($0.preset.displayName))") }
                            )
                            .frame(width: 310)
                            .help("Choose which audio player or SD card receives track, album, playlist, and podcast sync selections.")

                            Spacer()

                            if store.destinationMode == .multi && store.activeDeviceID != nil {
                                NeoSecondaryButton(title: "Clear Target") {
                                    store.selectActiveDevice(nil)
                                }
                                .help("Unselect the active sync target so you are prompted before syncing in Multi-Destination mode.")
                            }
                        }
                        .padding(12)
                        .background(EchoTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                        .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusControl).strokeBorder(EchoTheme.border, lineWidth: 1))
                    }
                }

                // 2. Retro Themes Switcher (Cassette / FiiO Nano / FiiO Disc / Winamp 99)
                VStack(alignment: .leading, spacing: 12) {
                    Text("INTERFACE THEME (90s RETRO · MAX 8PX CORNERS)")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(EchoTheme.neoCyan)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 250, maximum: 340), spacing: 12)], spacing: 12) {
                        ForEach(AppThemeKind.allCases) { theme in
                            let selected = store.selectedTheme == theme
                            Button {
                                store.setTheme(theme)
                            } label: {
                                HStack(spacing: 12) {
                                    themeLogoPreview(theme)
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack {
                                            Text(theme.displayName)
                                                .font(.system(size: 13.5, weight: .bold))
                                                .foregroundStyle(EchoTheme.textPrimary)
                                            Spacer()
                                            if selected {
                                                Text("ACTIVE")
                                                    .font(.system(size: 8.5, weight: .black, design: .monospaced))
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 2)
                                                    .background(EchoTheme.neoMint.opacity(0.22))
                                                    .foregroundStyle(EchoTheme.neoMint)
                                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                                            }
                                        }
                                        Text(theme.subtitle)
                                            .font(.system(size: 11))
                                            .foregroundStyle(EchoTheme.textSecondary)
                                            .multilineTextAlignment(.leading)
                                            .lineLimit(2)
                                    }
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(selected ? EchoTheme.neoMint.opacity(0.10) : EchoTheme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous)
                                        .strokeBorder(selected ? EchoTheme.neoMint : EchoTheme.border, lineWidth: selected ? 1.5 : 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .help("Switch the entire interface immediately to the \(theme.displayName) theme.")
                        }
                    }
                }

                // 3. Destinations & Synced Memory Overview
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("CONFIGURED DESTINATIONS & REMEMBERED SYNC STATE")
                            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                            .tracking(1.2)
                            .foregroundStyle(EchoTheme.neoCyan)
                        Spacer()
                        Button {
                            store.addVirtualIPhoneDestination()
                        } label: {
                            Label("Add Virtual iPhone", systemImage: "iphone.radiowaves.left.and.right")
                                .font(.system(size: 11.5, weight: .bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(EchoTheme.neoCyan.opacity(0.16))
                                .foregroundStyle(EchoTheme.neoCyan)
                                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                                .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall).strokeBorder(EchoTheme.neoCyan.opacity(0.45), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .help("Create a virtual iPhone destination with automatic Wi-Fi Bonjour sync for the standalone My Echo iOS app.")

                        Button {
                            store.addCustomDeviceFolderViaPanel()
                        } label: {
                            Label("Add Destination", systemImage: "plus")
                                .font(.system(size: 11.5, weight: .bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(EchoTheme.surfaceElevated)
                                .foregroundStyle(EchoTheme.neoMint)
                                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                        }
                        .buttonStyle(.plain)
                        .help("Add a new audio player, SD card volume, or local folder as a sync destination.")
                    }

                    if store.devices.isEmpty {
                        Text("No destinations paired yet. Plug in your FiiO player or SD card and click Pair in the sidebar.")
                            .font(.system(size: 12))
                            .foregroundStyle(EchoTheme.textMuted)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(EchoTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard))
                    } else {
                        VStack(spacing: 10) {
                            ForEach(store.devices) { dev in
                                let isTarget = store.activeDevice?.id == dev.id
                                let assignedTracks = store.assignedTrackCount(for: dev)
                                let assignedEps = SyncPlanner.resolveSelectedEpisodeIDs(profile: dev, podcasts: store.podcasts).count

                                HStack(spacing: 14) {
                                    // Accent color tag picker
                                    NeoMenuButton {
                                        DeviceAccentColor.allCases.map { accent in
                                            .action(title: accent.displayName, isSelected: dev.accentColor == accent) {
                                                var updated = dev
                                                updated.accentColor = accent
                                                store.updateDevice(updated)
                                            }
                                        }
                                    } label: { isHovered in
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(EchoTheme.color(for: dev.accentColor))
                                            .frame(width: 22, height: 22)
                                            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(isHovered ? EchoTheme.neoMint : .white.opacity(0.45), lineWidth: isHovered ? 1.5 : 1))
                                    }
                                    .fixedSize()
                                    .help("Change the badge color tag used to identify '\(dev.name)' on tracks and podcasts in Multi-Destination mode.")

                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 8) {
                                            Text(dev.name)
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(EchoTheme.textPrimary)
                                            Text(dev.preset.displayName)
                                                .font(.system(size: 10.5, design: .monospaced))
                                                .foregroundStyle(EchoTheme.textMuted)
                                            Text(dev.isConnected ? "ONLINE" : "OFFLINE")
                                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 1.5)
                                                .background(dev.isConnected ? EchoTheme.neoMint.opacity(0.18) : EchoTheme.dangerCoral.opacity(0.18))
                                                .foregroundStyle(dev.isConnected ? EchoTheme.neoMint : EchoTheme.dangerCoral)
                                                .clipShape(RoundedRectangle(cornerRadius: 3))
                                        }
                                        Text("Assigned: \(assignedTracks) tracks, \(assignedEps) podcasts · Remembered synced: \(dev.syncedTrackIDs.count) tracks, \(dev.syncedEpisodeIDs.count) podcasts")
                                            .font(.system(size: 11.5))
                                            .foregroundStyle(EchoTheme.textSecondary)
                                    }

                                    Spacer()

                                    Button(isTarget ? "Selected Target" : "Set as Target") {
                                        store.selectActiveDevice(dev.id)
                                    }
                                    .font(.system(size: 11.5, weight: .bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(isTarget ? EchoTheme.neoMint.opacity(0.22) : EchoTheme.surfaceElevated)
                                    .foregroundStyle(isTarget ? EchoTheme.neoMint : EchoTheme.textPrimary)
                                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                                    .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall).strokeBorder(isTarget ? EchoTheme.neoMint : EchoTheme.border, lineWidth: 1))
                                    .buttonStyle(.plain)
                                    .help("Make '\(dev.name)' the active sync destination for sync toggles and the Sync button.")

                                    Button {
                                        renamingDevice = dev
                                        renameDraft = dev.name
                                    } label: {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 12, weight: .semibold))
                                            .frame(width: 28, height: 28)
                                            .background(EchoTheme.surfaceElevated)
                                            .foregroundStyle(EchoTheme.textSecondary)
                                            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Rename '\(dev.name)'.")

                                    Button("Configure") {
                                        store.navigate(to: .deviceSync(dev.id))
                                    }
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(EchoTheme.surfaceElevated)
                                    .foregroundStyle(EchoTheme.textSecondary)
                                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                                    .buttonStyle(.plain)
                                    .help("Open '\(dev.name)' profile settings, M3U path format, artwork limits, and sync diff.")

                                    Button(role: .destructive) {
                                        store.deleteDevice(dev)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 11.5))
                                            .frame(width: 28, height: 28)
                                            .background(EchoTheme.dangerCoral.opacity(0.16))
                                            .foregroundStyle(EchoTheme.dangerCoral)
                                            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Remove '\(dev.name)' from configured destinations.")
                                }
                                .padding(12)
                                .background(EchoTheme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard))
                                .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusCard).strokeBorder(isTarget ? EchoTheme.neoMint.opacity(0.45) : EchoTheme.border, lineWidth: 1))
                            }
                        }
                    }
                }

                // 4. Mac Playback & Crossfade
                VStack(alignment: .leading, spacing: 12) {
                    Text("MAC PLAYBACK & CROSSFADE")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(EchoTheme.neoCyan)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Enable Equal-Power Crossfade")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(EchoTheme.textPrimary)
                                Text("Smoothly blends the end of each track into the next during Mac playback using constant-energy equal-power curves. Does not alter audio files synced to FiiO players or SD cards.")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(EchoTheme.textSecondary)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { store.player.crossfadeEnabled },
                                set: { store.player.crossfadeEnabled = $0 }
                            ))
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .tint(EchoTheme.neoMint)
                        }

                        if store.player.crossfadeEnabled {
                            Divider().overlay(EchoTheme.border)
                            HStack(spacing: 14) {
                                Text("Crossfade Duration")
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .foregroundStyle(EchoTheme.textSecondary)

                                Slider(
                                    value: Binding(
                                        get: { store.player.crossfadeDuration },
                                        set: { store.player.crossfadeDuration = $0.rounded() }
                                    ),
                                    in: 1...12,
                                    step: 1
                                )
                                .frame(maxWidth: 260)
                                .tint(EchoTheme.neoCyan)

                                Text("\(Int(store.player.crossfadeDuration.rounded())) sec")
                                    .font(.system(size: 12, weight: .black, design: .monospaced))
                                    .foregroundStyle(EchoTheme.neoCyan)
                                    .frame(width: 52, alignment: .leading)

                                Spacer()

                                HStack(spacing: 6) {
                                    ForEach([2, 5, 8, 12], id: \.self) { secs in
                                        let active = Int(store.player.crossfadeDuration.rounded()) == secs
                                        Button("\(secs)s") {
                                            store.player.crossfadeDuration = Double(secs)
                                        }
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 4.5)
                                        .background(active ? EchoTheme.neoCyan.opacity(0.22) : EchoTheme.surfaceElevated)
                                        .foregroundStyle(active ? EchoTheme.neoCyan : EchoTheme.textSecondary)
                                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        Divider().overlay(EchoTheme.border)

                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Auto-Pause on Calls & Meetings")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(EchoTheme.textPrimary)
                                Text("Automatically pauses playback when WhatsApp, Messenger, Teams, Google Meet, Zoom, FaceTime, or a phone call activates an audio input, or when headphones/USB DAC disconnect.")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(EchoTheme.textSecondary)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { store.player.autoPauseOnCall },
                                set: { store.player.autoPauseOnCall = $0 }
                            ))
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .tint(EchoTheme.neoMint)
                        }

                        if store.player.autoPauseOnCall {
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Auto-Resume When Call Ends")
                                        .font(.system(size: 12.5, weight: .semibold))
                                        .foregroundStyle(EchoTheme.textPrimary)
                                    Text("Resumes playback automatically 1.5 seconds after the call or meeting finishes.")
                                        .font(.system(size: 11))
                                        .foregroundStyle(EchoTheme.textMuted)
                                }
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { store.player.autoResumeAfterCall },
                                    set: { store.player.autoResumeAfterCall = $0 }
                                ))
                                .toggleStyle(.switch)
                                .labelsHidden()
                                .tint(EchoTheme.neoMint)
                            }
                        }
                    }
                    .padding(14)
                    .background(EchoTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard))
                    .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusCard).strokeBorder(EchoTheme.border, lineWidth: 1))
                }

                // 5. Play Counters & Online Popularity
                VStack(alignment: .leading, spacing: 12) {
                    Text("PLAY COUNTERS & ONLINE POPULARITY")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(EchoTheme.neoCyan)

                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Automatic Online Popularity Lookup")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(EchoTheme.textPrimary)
                                Text("Automatically fetches global track popularity scores (0–100) and artist fan counts from Deezer when you open albums or artists. Zero API key required; cached locally in SQLite.")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(EchoTheme.textSecondary)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { store.onlinePopularityEnabled },
                                set: { store.setOnlinePopularityEnabled($0) }
                            ))
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .tint(EchoTheme.neoMint)
                        }

                        Divider().overlay(EchoTheme.border)

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Library Stats Summary")
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .foregroundStyle(EchoTheme.textPrimary)
                                Text("Your total plays: \(store.totalLibraryUserPlays) · Tracks with online popularity: \(store.tracksWithOnlinePopularityCount) / \(store.scopedTracks.count)")
                                    .font(.system(size: 11.5, design: .monospaced))
                                    .foregroundStyle(EchoTheme.textSecondary)
                            }
                            Spacer()

                            if store.isBatchFetchingPopularity, let prog = store.popularityBatchProgress {
                                HStack(spacing: 8) {
                                    ProgressView().controlSize(.small)
                                    Text("Scanning \(prog.done)/\(prog.total) albums")
                                        .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(EchoTheme.neoCyan)
                                    Button("Stop") {
                                        store.cancelPopularityBatchFetch()
                                    }
                                    .font(.system(size: 11, weight: .semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(EchoTheme.dangerCoral.opacity(0.18))
                                    .foregroundStyle(EchoTheme.dangerCoral)
                                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                                    .buttonStyle(.plain)
                                }
                            } else {
                                Button {
                                    store.batchFetchPopularityForLibrary(maxAlbums: 120)
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: "chart.bar.xaxis")
                                        Text("Scan Popularity")
                                    }
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 6)
                                    .background(EchoTheme.neoCyan.opacity(0.16))
                                    .foregroundStyle(EchoTheme.neoCyan)
                                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                                    .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall).strokeBorder(EchoTheme.neoCyan.opacity(0.45), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .help("Fetch online popularity scores for up to 120 albums missing popularity data.")
                            }

                            if store.totalLibraryUserPlays > 0 {
                                Button("Reset My Plays") {
                                    showResetPlaysConfirm = true
                                }
                                .font(.system(size: 11.5, weight: .semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(EchoTheme.dangerCoral.opacity(0.14))
                                .foregroundStyle(EchoTheme.dangerCoral)
                                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                                .buttonStyle(.plain)
                                .help("Reset all personal play counters back to 0 (online popularity cache is preserved).")
                            }
                        }

                        Divider().overlay(EchoTheme.border)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Optional: Last.fm API Key (Exact Global Scrobble Play Counts)")
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(EchoTheme.textPrimary)
                            Text("Leave blank to use built-in zero-config Deezer popularity. Add a free Last.fm API key to also display exact global play & listener counts in tooltips.")
                                .font(.system(size: 11))
                                .foregroundStyle(EchoTheme.textMuted)
                            HStack(spacing: 8) {
                                SecureField("Paste Last.fm API key (optional)", text: $lastFMKeyDraft)
                                    .neoTextField()
                                    .frame(maxWidth: 340)
                                NeoSecondaryButton(title: "Save Key") {
                                    store.setLastFMAPIKey(lastFMKeyDraft)
                                }
                                if !store.lastFMAPIKey.isEmpty {
                                    NeoSecondaryButton(title: "Clear", accent: EchoTheme.textSecondary) {
                                        lastFMKeyDraft = ""
                                        store.setLastFMAPIKey("")
                                    }
                                }
                            }
                        }
                    }
                    .padding(14)
                    .background(EchoTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard))
                    .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusCard).strokeBorder(EchoTheme.border, lineWidth: 1))
                }

                // 5. Optional Lidarr Integration
                VStack(alignment: .leading, spacing: 12) {
                    Text("LIDARR DOWNLOADS INTEGRATION (OPTIONAL)")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(EchoTheme.neoCyan)

                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 8) {
                                    Text("Enable Lidarr Downloads UI")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(EchoTheme.textPrimary)
                                    if let status = store.lidarrStatus {
                                        Text("CONNECTED · v\(status.version)")
                                            .font(.system(size: 8.5, weight: .black, design: .monospaced))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(EchoTheme.neoMint.opacity(0.18))
                                            .foregroundStyle(EchoTheme.neoMint)
                                            .clipShape(RoundedRectangle(cornerRadius: 3))
                                    }
                                }
                                Text("Adds a Downloads (Lidarr) section to the sidebar so you can search albums, tracks, or artists, order downloads into Lidarr, and monitor the live download queue.")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(EchoTheme.textSecondary)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { store.lidarrConfig.isEnabled },
                                set: { enabled in
                                    var cfg = store.lidarrConfig
                                    cfg.isEnabled = enabled
                                    store.saveLidarrConfig(cfg)
                                    if enabled && cfg.isConfigured {
                                        store.testLidarrConnection(silent: true)
                                    }
                                }
                            ))
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .tint(EchoTheme.neoMint)
                        }

                        if store.lidarrConfig.isEnabled {
                            Divider().overlay(EchoTheme.border)

                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Lidarr Server URL")
                                            .font(.system(size: 11.5, weight: .semibold))
                                            .foregroundStyle(EchoTheme.textSecondary)
                                        TextField("http://192.168.1.10:8686", text: $lidarrURLDraft)
                                            .neoTextField()
                                    }
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("API Key (Lidarr → Settings → General)")
                                            .font(.system(size: 11.5, weight: .semibold))
                                            .foregroundStyle(EchoTheme.textSecondary)
                                        SecureField("Paste Lidarr API key", text: $lidarrKeyDraft)
                                            .neoTextField()
                                    }
                                }

                                HStack(spacing: 10) {
                                    NeoPrimaryButton(
                                        title: store.isTestingLidarrConnection ? "Connecting..." : "Save & Test Connection",
                                        icon: "bolt.horizontal.fill",
                                        disabled: store.isTestingLidarrConnection
                                    ) {
                                        var cfg = store.lidarrConfig
                                        cfg.baseURL = lidarrURLDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                                        cfg.apiKey = lidarrKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                                        store.saveLidarrConfig(cfg)
                                        store.testLidarrConnection()
                                    }

                                    if store.lidarrConfig.isConfigured {
                                        NeoSecondaryButton(title: "Open Lidarr Downloads", icon: "arrow.down.to.line.compact") {
                                            store.navigate(to: .lidarr)
                                        }
                                    }

                                    Spacer()

                                    Toggle("Auto-search indexers on order", isOn: Binding(
                                        get: { store.lidarrConfig.searchOnAdd },
                                        set: { val in
                                            var cfg = store.lidarrConfig
                                            cfg.searchOnAdd = val
                                            store.saveLidarrConfig(cfg)
                                        }
                                    ))
                                    .toggleStyle(.checkbox)
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(EchoTheme.textSecondary)
                                }

                                if let err = store.lidarrConnectionError {
                                    Text(err)
                                        .font(.system(size: 11.5))
                                        .foregroundStyle(EchoTheme.dangerCoral)
                                }
                            }

                            if !store.lidarrRootFolders.isEmpty || !store.lidarrQualityProfiles.isEmpty || !store.lidarrMetadataProfiles.isEmpty {
                                Divider().overlay(EchoTheme.border)

                                HStack(spacing: 14) {
                                    if !store.lidarrRootFolders.isEmpty {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Root Folder")
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundStyle(EchoTheme.textSecondary)
                                            NeoPickerDropdown(
                                                fullWidth: true,
                                                selection: Binding(
                                                    get: { store.lidarrConfig.rootFolderPath },
                                                    set: { path in
                                                        var cfg = store.lidarrConfig
                                                        cfg.rootFolderPath = path
                                                        store.saveLidarrConfig(cfg)
                                                    }
                                                ),
                                                options: store.lidarrRootFolders.map { ($0.path, $0.path) }
                                            )
                                        }
                                    }

                                    if !store.lidarrQualityProfiles.isEmpty {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Quality Profile")
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundStyle(EchoTheme.textSecondary)
                                            NeoPickerDropdown(
                                                fullWidth: true,
                                                selection: Binding<Int?>(
                                                    get: { store.lidarrConfig.qualityProfileId },
                                                    set: { qid in
                                                        var cfg = store.lidarrConfig
                                                        cfg.qualityProfileId = qid
                                                        store.saveLidarrConfig(cfg)
                                                    }
                                                ),
                                                options: store.lidarrQualityProfiles.map { (Int?.some($0.id), $0.name) }
                                            )
                                        }
                                    }

                                    if !store.lidarrMetadataProfiles.isEmpty {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Metadata Profile")
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundStyle(EchoTheme.textSecondary)
                                            NeoPickerDropdown(
                                                fullWidth: true,
                                                selection: Binding<Int?>(
                                                    get: { store.lidarrConfig.metadataProfileId },
                                                    set: { mid in
                                                        var cfg = store.lidarrConfig
                                                        cfg.metadataProfileId = mid
                                                        store.saveLidarrConfig(cfg)
                                                    }
                                                ),
                                                options: store.lidarrMetadataProfiles.map { (Int?.some($0.id), $0.name) }
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(14)
                    .background(EchoTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard))
                    .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusCard).strokeBorder(EchoTheme.border, lineWidth: 1))
                }

                // 5.4 Optional Self-Hosted Echo Server (Unraid / Docker)
                VStack(alignment: .leading, spacing: 10) {
                    Text("MY ECHO SERVER (UNRAID / DOCKER · OPTIONAL)")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(EchoTheme.neoCyan)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "server.rack")
                                .font(.system(size: 20))
                                .foregroundStyle(store.echoServerConfig.isEnabled ? EchoTheme.neoMint : EchoTheme.textMuted)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 8) {
                                    Text("Offload NAS Indexing, Apple TV Backend & Always-On Party Mode")
                                        .font(.system(size: 13.5, weight: .bold))
                                        .foregroundStyle(EchoTheme.textPrimary)
                                    Text(store.echoServerConfig.isEnabled ? "ENABLED" : "STANDALONE")
                                        .font(.system(size: 9, weight: .black, design: .monospaced))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background((store.echoServerConfig.isEnabled ? EchoTheme.neoMint : EchoTheme.textMuted).opacity(0.18))
                                        .foregroundStyle(store.echoServerConfig.isEnabled ? EchoTheme.neoMint : EchoTheme.textMuted)
                                        .clipShape(RoundedRectangle(cornerRadius: 3))
                                }
                                Text("Optional Docker companion for Unraid/NAS. Pulls tiny compressed delta shards instead of scanning SMB from Mac, while keeping local folders & traditional NAS scanning 100% standalone.")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(EchoTheme.textSecondary)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { store.echoServerConfig.isEnabled },
                                set: { enabled in
                                    var updated = store.echoServerConfig
                                    updated.isEnabled = enabled
                                    store.saveEchoServerConfig(updated)
                                }
                            ))
                            .labelsHidden()
                            .toggleStyle(.switch)
                        }

                        if store.echoServerConfig.isEnabled {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("LAN URL")
                                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                            .foregroundStyle(EchoTheme.textMuted)
                                        TextField("http://192.168.1.50:48721", text: $echoServerLANURLDraft)
                                            .textFieldStyle(.roundedBorder)
                                    }
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("TAILSCALE URL (OPTIONAL)")
                                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                            .foregroundStyle(EchoTheme.textMuted)
                                        TextField("http://100.92.217.88:48721", text: $echoServerTSURLDraft)
                                            .textFieldStyle(.roundedBorder)
                                    }
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("6-DIGIT PIN")
                                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                            .foregroundStyle(EchoTheme.textMuted)
                                        TextField("123456", text: $echoServerPINDraft)
                                            .textFieldStyle(.roundedBorder)
                                            .frame(width: 110)
                                    }
                                }

                                HStack(spacing: 10) {
                                    Toggle("Sync Playlists, Ratings, Podcasts & Editorial to Echo Server (for Apple TV)", isOn: Binding(
                                        get: { store.echoServerConfig.syncSharedState },
                                        set: { v in
                                            var updated = store.echoServerConfig
                                            updated.syncSharedState = v
                                            store.saveEchoServerConfig(updated)
                                        }
                                    ))
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(EchoTheme.textSecondary)

                                    Spacer()

                                    Button(store.isTestingEchoServer ? "Connecting..." : "Save & Test") {
                                        var updated = store.echoServerConfig
                                        updated.lanURL = echoServerLANURLDraft
                                        updated.tailscaleURL = echoServerTSURLDraft
                                        updated.pairingPIN = echoServerPINDraft
                                        store.saveEchoServerConfig(updated)
                                        Task { await store.testEchoServerConnection() }
                                    }
                                    .font(.system(size: 11.5, weight: .bold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(EchoTheme.neoMint)
                                    .foregroundStyle(Color.black)
                                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                                    .buttonStyle(.plain)
                                    .disabled(store.isTestingEchoServer)

                                    Button(store.isSyncingEchoServerState ? "Syncing..." : "Sync Shared State") {
                                        Task { await store.syncSharedStateWithEchoServer() }
                                    }
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(EchoTheme.surfaceElevated)
                                    .foregroundStyle(EchoTheme.neoCyan)
                                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                                    .buttonStyle(.plain)
                                    .disabled(!store.echoServerConfig.isConfigured || store.isSyncingEchoServerState)

                                    Button(store.echoServerPartyStatus.isLive ? "Stop Server Party" : "Start Server Party") {
                                        Task { await store.setEchoServerPartyMode(active: !store.echoServerPartyStatus.isLive) }
                                    }
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(EchoTheme.neoMagenta.opacity(0.2))
                                    .foregroundStyle(EchoTheme.neoMagenta)
                                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                                    .buttonStyle(.plain)
                                    .disabled(!store.echoServerConfig.isConfigured)
                                }

                                Text(store.echoServerStatusText)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(EchoTheme.textSecondary)

                                if let err = store.echoServerError {
                                    Text(err)
                                        .font(.system(size: 11))
                                        .foregroundStyle(EchoTheme.dangerCoral)
                                }
                            }
                            .padding(10)
                            .background(EchoTheme.canvas.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                        }
                    }
                    .padding(14)
                    .background(EchoTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard))
                    .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusCard).strokeBorder(EchoTheme.border, lineWidth: 1))
                }

                // 5.5 Apple TV & Living-Room Companion Server
                VStack(alignment: .leading, spacing: 10) {
                    Text("APPLE TV & LIVING-ROOM COMPANION")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(EchoTheme.neoCyan)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "appletv.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(store.appleTVCompanionEnabled && store.isWirelessServerRunning ? EchoTheme.neoMint : EchoTheme.textMuted)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 8) {
                                    Text("Apple TV Full-Library Streaming & Mac Remote")
                                        .font(.system(size: 13.5, weight: .bold))
                                        .foregroundStyle(EchoTheme.textPrimary)
                                    Text(store.isWirelessServerRunning ? "ONLINE" : "OFF")
                                        .font(.system(size: 9, weight: .black, design: .monospaced))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background((store.isWirelessServerRunning ? EchoTheme.neoMint : EchoTheme.textMuted).opacity(0.18))
                                        .foregroundStyle(store.isWirelessServerRunning ? EchoTheme.neoMint : EchoTheme.textMuted)
                                        .clipShape(RoundedRectangle(cornerRadius: 3))
                                }
                                Text("Streams your full Mac library, podcasts, Party Mode TV display, and remote playback controls to My Echo on Apple TV via Bonjour (_myecho-sync._tcp).")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(EchoTheme.textSecondary)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { store.appleTVCompanionEnabled },
                                set: { store.setAppleTVCompanionEnabled($0) }
                            ))
                            .labelsHidden()
                            .toggleStyle(.switch)
                        }

                        if store.appleTVCompanionEnabled {
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("APPLE TV PAIRING PIN")
                                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                        .foregroundStyle(EchoTheme.textMuted)
                                    Text(store.appleTVPairingPIN)
                                        .font(.system(size: 20, weight: .black, design: .monospaced))
                                        .tracking(3)
                                        .foregroundStyle(EchoTheme.neoMint)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("LAN ADDRESS")
                                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                        .foregroundStyle(EchoTheme.textMuted)
                                    let port = store.wirelessServerPort > 0 ? store.wirelessServerPort : WirelessSyncServer.defaultPort
                                    Text("http://\(store.wirelessServerLANIP ?? "localhost"):\(port)")
                                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(EchoTheme.textPrimary)
                                }

                                Spacer()

                                Button("Copy PIN") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(store.appleTVPairingPIN, forType: .string)
                                    store.showToast("Copied Apple TV pairing PIN")
                                }
                                .font(.system(size: 11.5, weight: .semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(EchoTheme.surfaceElevated)
                                .foregroundStyle(EchoTheme.textPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                                .buttonStyle(.plain)

                                Button("New PIN") {
                                    store.regenerateAppleTVPairingPIN()
                                }
                                .font(.system(size: 11.5, weight: .semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(EchoTheme.surfaceElevated)
                                .foregroundStyle(EchoTheme.textSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                                .buttonStyle(.plain)
                            }
                            .padding(10)
                            .background(EchoTheme.canvas.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))

                            Text("Tip: Any existing iPhone/iPad Wi-Fi Sync PIN also works to pair Apple TV.")
                                .font(.system(size: 10.5))
                                .foregroundStyle(EchoTheme.textMuted)
                        }
                    }
                    .padding(14)
                    .background(EchoTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard))
                    .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusCard).strokeBorder(EchoTheme.border, lineWidth: 1))
                }

                // 6. Data & Storage Paths
                VStack(alignment: .leading, spacing: 10) {
                    Text("STORAGE & CACHE")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(EchoTheme.neoCyan)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("My Echo Database & Podcast Downloads")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(EchoTheme.textPrimary)
                            Text(store.database.dbURL.deletingLastPathComponent().path)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(EchoTheme.textMuted)
                        }
                        Spacer()
                        Button("Reveal in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([store.database.dbURL])
                        }
                        .font(.system(size: 11.5, weight: .semibold))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(EchoTheme.surfaceElevated)
                        .foregroundStyle(EchoTheme.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                        .buttonStyle(.plain)
                        .help("Open Echo's local Application Support folder containing the SQLite database and downloaded podcasts.")
                    }
                    .padding(14)
                    .background(EchoTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard))
                    .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusCard).strokeBorder(EchoTheme.border, lineWidth: 1))
                }
            }
            .padding(26)
        }
        .sheet(item: $renamingDevice) { dev in
            RenameDestinationSheet(currentName: dev.name, draftName: $renameDraft) {
                store.renameDevice(dev, to: renameDraft)
            }
        }
        .onAppear {
            lastFMKeyDraft = store.lastFMAPIKey
            lidarrURLDraft = store.lidarrConfig.baseURL
            lidarrKeyDraft = store.lidarrConfig.apiKey
            echoServerLANURLDraft = store.echoServerConfig.lanURL
            echoServerTSURLDraft = store.echoServerConfig.tailscaleURL
            echoServerPINDraft = store.echoServerConfig.pairingPIN
        }
        .alert("Reset All Personal Play Counters?", isPresented: $showResetPlaysConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset All Plays", role: .destructive) {
                store.resetAllUserPlayCounts()
            }
        } message: {
            Text("This resets your personal play counts across all tracks to 0. Cached online popularity data will be kept.")
        }
    }

    @ViewBuilder
    private func themeLogoPreview(_ theme: AppThemeKind) -> some View {
        switch theme {
        case .neonCassette:
            EchoCassetteLogo(size: 32)
        case .fiioNano:
            FiioNanoLogo(size: 32)
        case .fiioDisc:
            FiioDiscLogo(size: 32)
        case .winampClassic:
            WinampDeckLogo(size: 32)
        case .frostedGlass:
            GlassCassetteLogo(size: 32)
        }
    }
}

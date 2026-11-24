import SwiftUI
import AppKit
import EchoCore

struct SettingsView: View {
    @Environment(EchoStore.self) private var store
    @State private var renamingDevice: DeviceProfile?
    @State private var renameDraft: String = ""

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

                            Picker("", selection: Binding<UUID?>(
                                get: { store.activeDeviceID },
                                set: { store.selectActiveDevice($0) }
                            )) {
                                if store.destinationMode == .multi {
                                    Text("None — Prompt Me to Choose").tag(UUID?.none)
                                }
                                ForEach(store.devices) { dev in
                                    Text("\(dev.name) (\(dev.preset.displayName))").tag(UUID?.some(dev.id))
                                }
                            }
                            .frame(width: 310)
                            .help("Choose which audio player or SD card receives track, album, playlist, and podcast sync selections.")

                            Spacer()

                            if store.destinationMode == .multi && store.activeDeviceID != nil {
                                Button("Clear Target") {
                                    store.selectActiveDevice(nil)
                                }
                                .font(.system(size: 11.5, weight: .semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(EchoTheme.surfaceElevated)
                                .foregroundStyle(EchoTheme.textSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                                .buttonStyle(.plain)
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
                                let assignedTracks = SyncPlanner.resolveSelectedTrackIDs(profile: dev, allTracks: store.tracks, playlists: store.playlists).count
                                let assignedEps = SyncPlanner.resolveSelectedEpisodeIDs(profile: dev, podcasts: store.podcasts).count

                                HStack(spacing: 14) {
                                    // Accent color tag picker
                                    Menu {
                                        ForEach(DeviceAccentColor.allCases, id: \.self) { accent in
                                            Button(accent.displayName) {
                                                var updated = dev
                                                updated.accentColor = accent
                                                store.updateDevice(updated)
                                            }
                                        }
                                    } label: {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(EchoTheme.color(for: dev.accentColor))
                                            .frame(width: 22, height: 22)
                                            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.white.opacity(0.4), lineWidth: 1))
                                    }
                                    .menuStyle(.borderlessButton)
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

                // 4. Data & Storage Paths
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

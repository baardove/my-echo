import SwiftUI
import EchoCore

struct SidebarView: View {
    @Environment(EchoStore.self) private var store
    @State private var showNewPlaylistSheet = false
    @State private var newPlaylistName = ""
    @State private var newPlaylistDesc = ""
    @State private var isNewPlaylistDropTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Brand Header with Theme-Adaptive Echo Cassette / Disc / Nano / Winamp Logo
            HStack(spacing: 10) {
                EchoBrandLogo(size: 32, animate: store.player.isPlaying)
                VStack(alignment: .leading, spacing: 1) {
                    Text("MY ECHO")
                        .font(.system(size: 15.5, weight: .black, design: .monospaced))
                        .tracking(1.6)
                        .foregroundStyle(EchoTheme.textPrimary)
                    Text(store.selectedTheme.brandTagline)
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(EchoTheme.neoMint)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 14)
            .overlay(alignment: .bottom) {
                Rectangle().fill(EchoTheme.border).frame(height: 1)
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    // Library Section
                    VStack(alignment: .leading, spacing: 3) {
                        sidebarSectionTitle("LIBRARY")
                        sidebarRow(icon: "house.fill", title: "Home", destination: .home, tip: "Library overview for '\(store.selectedLibraryDisplayName)', recently indexed albums, and quick actions.")
                        sidebarRow(icon: "person.2.fill", title: "Artists", count: store.artists.count, destination: .artists, tip: "Browse artists in '\(store.selectedLibraryDisplayName)'. Drag or toggle entire artists to sync.")
                        sidebarRow(icon: "square.stack.fill", title: "Albums", count: store.albums.count, destination: .albums, tip: "Browse albums in '\(store.selectedLibraryDisplayName)' with cover art and path previews.")
                        sidebarRow(icon: "music.note", title: "Tracks", count: store.scopedTracks.count, destination: .tracks, tip: "View every track inside '\(store.selectedLibraryDisplayName)'.")
                        sidebarRow(icon: "mic.fill", title: "Podcasts", count: store.podcasts.count, destination: .podcasts, tip: "Search podcast directories, subscribe via RSS, download episodes, and sync to single or multiple players.")
                        sidebarRow(icon: "externaldrive.connected.to.line.below.fill", title: "Sources & NAS", count: store.sources.count, destination: .sources, tip: "Manage local music folders and mounted SMB/NFS NAS shares.")

                        // Library Scope Selector (stay inside selected library until another library is selected)
                        if !store.sources.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("ACTIVE LIBRARY SCOPE")
                                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                    .tracking(1.0)
                                    .foregroundStyle(EchoTheme.textMuted)
                                    .padding(.horizontal, 14)
                                    .padding(.top, 8)
                                    .padding(.bottom, 2)

                                libraryScopeRow(
                                    title: "All Libraries",
                                    count: store.tracks.count,
                                    icon: "books.vertical.fill",
                                    isOnline: true,
                                    isSelected: store.selectedSourceID == nil,
                                    tip: "Show and search music across all configured local and NAS libraries."
                                ) {
                                    store.selectLibrarySource(nil)
                                }

                                ForEach(store.sources) { src in
                                    libraryScopeRow(
                                        title: src.name,
                                        count: src.trackCount,
                                        icon: src.isNetworkVolume ? "externaldrive.connected.to.line.below" : "folder.fill",
                                        isOnline: src.isAvailable,
                                        isSelected: store.selectedSourceID == src.id,
                                        tip: "Stay inside library '\(src.name)' while exploring Artists, Albums, Tracks, and using Global Search until you select another library."
                                    ) {
                                        store.selectLibrarySource(src.id)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top, 10)

                    // Playlists Section
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            sidebarSectionTitle("PLAYLISTS")
                            Spacer()
                            Button {
                                newPlaylistName = ""
                                newPlaylistDesc = ""
                                showNewPlaylistSheet = true
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(EchoTheme.textSecondary)
                                    .frame(width: 22, height: 22)
                                    .background(EchoTheme.surfaceElevated.opacity(0.7))
                                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                            }
                            .buttonStyle(.plain)
                            .help("Create a new playlist to organize tracks and export as M3U/M3U8 to your player.")
                            .padding(.trailing, 12)
                        }

                        ForEach(store.playlists) { playlist in
                            SidebarPlaylistDropRow(playlist: playlist)
                        }

                        // Drop zone to create a brand-new playlist from any dragged song/album/artist
                        Button {
                            newPlaylistName = ""
                            newPlaylistDesc = ""
                            showNewPlaylistSheet = true
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: isNewPlaylistDropTargeted ? "tray.and.arrow.down.fill" : "plus.square.dashed")
                                    .font(.system(size: 12.5))
                                Text(isNewPlaylistDropTargeted ? "Drop to create playlist" : "Drop here or + New Playlist")
                                    .font(.system(size: 11, weight: isNewPlaylistDropTargeted ? .bold : .medium))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(isNewPlaylistDropTargeted ? EchoTheme.neoMint : EchoTheme.textMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous)
                                    .fill(isNewPlaylistDropTargeted ? EchoTheme.neoMint.opacity(0.16) : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous)
                                    .strokeBorder(
                                        isNewPlaylistDropTargeted ? EchoTheme.neoMint : EchoTheme.border,
                                        style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                                    )
                            )
                            .padding(.horizontal, 10)
                            .padding(.top, 2)
                        }
                        .buttonStyle(.plain)
                        .help("Click to create a new playlist, or drag & drop any song, album, or artist here to auto-create and populate one.")
                        .dropDestination(for: String.self) { items, _ in
                            store.handleDropToCreateNewPlaylist(items: items)
                        } isTargeted: { targeted in
                            isNewPlaylistDropTargeted = targeted
                        }
                    }

                    // Devices & SD Cards Section
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            sidebarSectionTitle(store.destinationMode == .multi ? "DESTINATIONS (MULTI)" : "PLAYERS & SD CARDS")
                            Spacer()
                            Button {
                                store.addCustomDeviceFolderViaPanel()
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(EchoTheme.textSecondary)
                                    .frame(width: 22, height: 22)
                                    .background(EchoTheme.surfaceElevated.opacity(0.7))
                                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                            }
                            .buttonStyle(.plain)
                            .help("Add a FiiO player, MicroSD card, or local target folder as a sync destination.")
                            .padding(.trailing, 12)
                        }

                        if store.requiresDestinationSelection && !store.devices.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 10.5))
                                Text("Click TARGET on a destination below to select where sync toggles apply.")
                                    .font(.system(size: 10))
                            }
                            .foregroundStyle(EchoTheme.warningAmber)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(EchoTheme.warningAmber.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                            .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusControl).strokeBorder(EchoTheme.warningAmber.opacity(0.35), lineWidth: 1))
                            .padding(.horizontal, 10)
                        }

                        ForEach(store.devices) { device in
                            SidebarDeviceDropCard(device: device)
                        }

                        // Auto-detected external volumes not yet paired
                        if !store.unrecognizedMountedVolumes.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("DETECTED VOLUMES")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(EchoTheme.neoCyan)
                                    .padding(.horizontal, 14)
                                    .padding(.top, 4)

                                ForEach(store.unrecognizedMountedVolumes) { vol in
                                    HStack(spacing: 8) {
                                        Image(systemName: "sdcard.fill")
                                            .font(.system(size: 12))
                                            .foregroundStyle(EchoTheme.neoCyan)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(vol.name)
                                                .font(.system(size: 11.5, weight: .semibold))
                                                .foregroundStyle(EchoTheme.textPrimary)
                                                .lineLimit(1)
                                            Text("\(Formatters.bytes(vol.availableBytes)) free · \(vol.fileSystemType)")
                                                .font(.system(size: 9.5))
                                                .foregroundStyle(EchoTheme.textMuted)
                                        }
                                        Spacer()
                                        Button("Pair") {
                                            store.addDevice(from: vol, preset: .fiioEchoMini)
                                        }
                                        .font(.system(size: 10.5, weight: .bold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(EchoTheme.neoCyan.opacity(0.2))
                                        .foregroundStyle(EchoTheme.neoCyan)
                                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                                        .buttonStyle(.plain)
                                        .help("Pair '\(vol.name)' as a managed FiiO / SD Card sync destination.")
                                    }
                                    .padding(9)
                                    .background(EchoTheme.surface.opacity(0.9))
                                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous)
                                            .strokeBorder(EchoTheme.neoCyan.opacity(0.35), lineWidth: 1)
                                    )
                                    .padding(.horizontal, 10)
                                }
                            }
                        } else if store.devices.isEmpty {
                            Button {
                                store.addCustomDeviceFolderViaPanel()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "sdcard")
                                            .foregroundStyle(EchoTheme.neoMint)
                                        Text("Add FiiO / SD Card")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(EchoTheme.textPrimary)
                                    }
                                    Text("Plug in your player or pick a target folder to start syncing.")
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(EchoTheme.textMuted)
                                        .multilineTextAlignment(.leading)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(EchoTheme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous)
                                        .strokeBorder(EchoTheme.border, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                                )
                            }
                            .buttonStyle(.plain)
                            .help("Choose an audio player volume, SD card, or local folder as a sync destination.")
                            .padding(.horizontal, 10)
                        }
                    }
                }
                .padding(.bottom, 16)
            }

            // Bottom Fixed Settings Button & Indexing Status
            VStack(spacing: 0) {
                if store.isIndexing, let prog = store.indexProgress {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.mini)
                            Text("Indexing \(prog.sourceName)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(EchoTheme.neoMint)
                                .lineLimit(1)
                        }
                        Text("\(prog.scannedCount)/\(max(1, prog.totalFound)) · \(prog.currentFile)")
                            .font(.system(size: 9.5, design: .monospaced))
                            .foregroundStyle(EchoTheme.textMuted)
                            .lineLimit(1)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(EchoTheme.surface)
                    .overlay(alignment: .top) { Rectangle().fill(EchoTheme.border).frame(height: 1) }
                }

                Rectangle().fill(EchoTheme.border).frame(height: 1)
                sidebarRow(
                    icon: "gearshape.fill",
                    title: "Settings & Themes",
                    destination: .settings,
                    tip: "Switch Single vs Multi-Destination mode, pick retro themes (Cassette, FiiO Nano, FiiO Disc, Winamp 99), and manage destination tags (⌘,)."
                )
                .padding(.vertical, 6)
            }
        }
        .frame(width: 260)
        .background(EchoTheme.sidebar)
        .overlay(alignment: .trailing) {
            Rectangle().fill(EchoTheme.border).frame(width: 1)
        }
        .sheet(isPresented: $showNewPlaylistSheet) {
            NewPlaylistSheet(name: $newPlaylistName, description: $newPlaylistDesc) {
                let pl = store.createPlaylist(name: newPlaylistName, description: newPlaylistDesc)
                store.navigate(to: .playlist(pl.id))
            }
        }
    }

    private func sidebarSectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .tracking(1.2)
            .foregroundStyle(EchoTheme.textMuted)
            .padding(.horizontal, 14)
            .padding(.bottom, 2)
    }

    private func isDestinationHighlighted(_ destination: NavDestination) -> Bool {
        if store.currentDestination == destination { return true }
        switch (destination, store.currentDestination) {
        case (.artists, .artistDetail): return true
        case (.albums, .albumDetail): return true
        case (.podcasts, .podcastDetail): return true
        default: return false
        }
    }

    private func libraryScopeRow(title: String, count: Int, icon: String, isOnline: Bool, isSelected: Bool, tip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(isSelected ? EchoTheme.neoCyan : (isOnline ? EchoTheme.textMuted.opacity(0.45) : EchoTheme.dangerCoral))
                    .frame(width: 5, height: 14)
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? EchoTheme.neoCyan : EchoTheme.textMuted)
                    .frame(width: 15)
                Text(title)
                    .font(.system(size: 11.5, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? EchoTheme.textPrimary : EchoTheme.textSecondary)
                    .lineLimit(1)
                Spacer()
                Text("\(count)")
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(isSelected ? EchoTheme.neoCyan : EchoTheme.textMuted)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: EchoTheme.radiusSmall)
                    .fill(isSelected ? EchoTheme.neoCyan.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: EchoTheme.radiusSmall)
                    .strokeBorder(isSelected ? EchoTheme.neoCyan.opacity(0.4) : Color.clear, lineWidth: 1)
            )
            .padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
        .help(tip)
    }

    private func sidebarRow(icon: String, title: String, count: Int? = nil, destination: NavDestination, tip: String) -> some View {
        let isActive = isDestinationHighlighted(destination)
        return Button {
            store.searchQuery = ""
            store.navigate(to: destination)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isActive ? EchoTheme.neoMint : EchoTheme.textSecondary)
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 13, weight: isActive ? .bold : .medium))
                    .foregroundStyle(isActive ? EchoTheme.textPrimary : EchoTheme.textSecondary)
                Spacer()
                if let count, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(EchoTheme.textMuted)
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7.5)
            .background(
                RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous)
                    .fill(isActive ? EchoTheme.surfaceElevated : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous)
                    .strokeBorder(isActive ? EchoTheme.neoMint.opacity(0.4) : Color.clear, lineWidth: 1)
            )
            .padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
        .help(tip)
    }
}

private struct SidebarPlaylistDropRow: View {
    @Environment(EchoStore.self) private var store
    let playlist: Playlist
    @State private var isDropTargeted = false
    @State private var isHovered = false

    var body: some View {
        let isActive = store.currentDestination == .playlist(playlist.id)
        let isFocused = store.focusedPlaylist?.id == playlist.id
        let isSynced = store.isPlaylistSelected(playlist)
        let firstArt = store.tracks(for: playlist).first?.artworkHash

        HStack(spacing: 8) {
            Button {
                store.navigate(to: .playlist(playlist.id))
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: isDropTargeted ? "tray.and.arrow.down.fill" : "music.note.list")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isDropTargeted ? EchoTheme.neoMint : (isActive ? EchoTheme.neoMint : (isFocused ? EchoTheme.neoCyan : EchoTheme.textMuted)))
                        .frame(width: 18)

                    VStack(alignment: .leading, spacing: 1.5) {
                        HStack(spacing: 5) {
                            Text(playlist.name)
                                .font(.system(size: 12.5, weight: (isActive || isFocused) ? .bold : .medium))
                                .foregroundStyle(isDropTargeted ? EchoTheme.neoMint : (isActive ? EchoTheme.textPrimary : EchoTheme.textSecondary))
                                .lineLimit(1)

                            if isFocused {
                                Image(systemName: "pin.fill")
                                    .font(.system(size: 8.5))
                                    .foregroundStyle(EchoTheme.neoCyan)
                                    .help("Focused playlist targeted by the + button on songs.")
                            }
                        }

                        Text(isDropTargeted ? "Drop to add tracks" : "\(playlist.trackIDs.count) tracks")
                            .font(.system(size: 10))
                            .foregroundStyle(isDropTargeted ? EchoTheme.neoMint : EchoTheme.textMuted)
                    }
                    Spacer(minLength: 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Open playlist '\(playlist.name)' and focus it for quick-add (+) buttons. Drag songs or albums here to copy them in.")

            // Explicit Sync Status Toggle Pill
            Button {
                store.togglePlaylistSync(playlist)
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: isSynced ? "checkmark.square.fill" : "square")
                        .font(.system(size: 11, weight: .semibold))
                    if isSynced {
                        Text("SYNC")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                    }
                }
                .padding(.horizontal, isSynced ? 5.5 : 4)
                .padding(.vertical, 3)
                .background(isSynced ? EchoTheme.neoMint.opacity(0.20) : Color.clear)
                .foregroundStyle(isSynced ? EchoTheme.neoMint : EchoTheme.textMuted.opacity(isHovered ? 0.9 : 0.55))
                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                .overlay(
                    RoundedRectangle(cornerRadius: EchoTheme.radiusSmall).strokeBorder(isSynced ? EchoTheme.neoMint.opacity(0.5) : Color.clear, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help(isSynced
                  ? "'\(playlist.name)' is included in sync for the selected destination. Click to exclude."
                  : "Click to include '\(playlist.name)' (and its M3U file + tracks) in the selected destination's sync.")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous)
                .fill(isDropTargeted ? EchoTheme.neoMint.opacity(0.18) : (isActive ? EchoTheme.surfaceElevated : (isHovered ? EchoTheme.surface.opacity(0.75) : Color.clear)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous)
                .strokeBorder(
                    isDropTargeted ? EchoTheme.neoMint : (isFocused ? EchoTheme.neoCyan.opacity(0.35) : Color.clear),
                    lineWidth: isDropTargeted ? 1.5 : 1
                )
        )
        .padding(.horizontal, 8)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Set as Focused (+) Target") {
                store.setFocusedPlaylist(playlist.id)
                store.showToast("Set '\(playlist.name)' as quick-add (+) target")
            }
            if !store.devices.isEmpty {
                Menu("Sync to Destinations") {
                    ForEach(store.devices) { dev in
                        let onDev = store.isPlaylistSelected(playlist, on: dev)
                        Button {
                            store.togglePlaylistSync(playlist, onDeviceID: dev.id)
                        } label: {
                            HStack {
                                Text(dev.name)
                                if onDev { Image(systemName: "checkmark") }
                            }
                        }
                    }
                }
            }
            Divider()
            Button("Delete Playlist", role: .destructive) {
                store.deletePlaylist(playlist)
            }
        }
        .draggable(EchoDragPayload.playlist(playlist.id).encode()) {
            DragPreviewPill(
                title: playlist.name,
                subtitle: "Playlist",
                artworkHash: firstArt,
                artworkCache: store.artworkCache,
                badge: "\(playlist.trackIDs.count) TRACKS"
            )
        }
        .dropDestination(for: String.self) { items, _ in
            store.handleDropOntoPlaylist(items: items, playlistID: playlist.id)
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
    }
}

private struct SidebarDeviceDropCard: View {
    @Environment(EchoStore.self) private var store
    let device: DeviceProfile
    @State private var isDropTargeted = false
    @State private var showRenameSheet = false
    @State private var renameDraft = ""

    var body: some View {
        let isActive = store.activeDevice?.id == device.id
        let isViewing = store.currentDestination == .deviceSync(device.id)
        let vol = store.volumeInfo(for: device)
        let connected = device.isConnected
        let accent = EchoTheme.color(for: device.accentColor)

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(connected ? accent : EchoTheme.textMuted)
                    .frame(width: 7, height: 7)
                    .shadow(color: connected ? accent : .clear, radius: 4)

                Button {
                    store.navigate(to: .deviceSync(device.id))
                } label: {
                    Text(device.name)
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(isDropTargeted ? EchoTheme.neoMint : EchoTheme.textPrimary)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                .help("Open '\(device.name)' sync control center, profile settings, and pre-sync diff.")

                Spacer(minLength: 4)

                if isDropTargeted {
                    Text("DROP TO SYNC")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(EchoTheme.neoMint.opacity(0.25))
                        .foregroundStyle(EchoTheme.neoMint)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                } else {
                    // Explicit One-Click Target Selector Pill (sets sync destination WITHOUT leaving current view!)
                    Button {
                        if isActive && store.destinationMode == .multi {
                            store.selectActiveDevice(nil)
                        } else {
                            store.selectActiveDevice(device.id)
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 9))
                            Text(isActive ? "TARGET" : "USE")
                                .font(.system(size: 8, weight: .black, design: .monospaced))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(isActive ? accent.opacity(0.24) : EchoTheme.surfaceElevated)
                        .foregroundStyle(isActive ? accent : EchoTheme.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(isActive ? accent.opacity(0.7) : EchoTheme.border, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .help(isActive
                          ? "'\(device.name)' is currently the selected sync destination.\(store.destinationMode == .multi ? " Click to unselect target." : "")"
                          : "Select '\(device.name)' as the active sync destination without leaving your current screen.")
                }
            }

            Button {
                store.navigate(to: .deviceSync(device.id))
            } label: {
                VStack(alignment: .leading, spacing: 5) {
                    Text(device.preset.displayName)
                        .font(.system(size: 10))
                        .foregroundStyle(EchoTheme.textSecondary)
                        .lineLimit(1)

                    if let vol, vol.totalBytes > 0 {
                        let ratio = min(1.0, max(0.0, Double(vol.usedBytes) / Double(vol.totalBytes)))
                        VStack(alignment: .leading, spacing: 3) {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.08))
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(ratio > 0.9 ? EchoTheme.dangerCoral : accent)
                                        .frame(width: max(4, geo.size.width * ratio))
                                }
                            }
                            .frame(height: 4)
                            HStack {
                                Text("\(Formatters.bytes(vol.availableBytes)) free")
                                    .font(.system(size: 9.5, design: .monospaced))
                                    .foregroundStyle(EchoTheme.textMuted)
                                Spacer()
                                Text(device.syncMode.displayName)
                                    .font(.system(size: 9.5))
                                    .foregroundStyle(EchoTheme.neoCyan)
                            }
                        }
                    } else {
                        Text(connected ? "Ready · \(device.syncMode.displayName)" : "Offline · \(device.syncedTrackIDs.count) synced remembered")
                            .font(.system(size: 9.5))
                            .foregroundStyle(EchoTheme.textMuted)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Click to open '\(device.name)' sync screen. Drag any track, album, artist, playlist, or podcast here to assign it to '\(device.name)'.")
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous)
                .fill(isDropTargeted ? EchoTheme.neoMint.opacity(0.16) : (isViewing ? EchoTheme.surfaceElevated : EchoTheme.surface))
        )
        .overlay(
            RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous)
                .strokeBorder(
                    isDropTargeted ? EchoTheme.neoMint : (isActive ? accent.opacity(0.75) : EchoTheme.border),
                    lineWidth: (isDropTargeted || isActive) ? 1.5 : 1
                )
        )
        .padding(.horizontal, 10)
        .dropDestination(for: String.self) { items, _ in
            store.handleDropOntoDevice(items: items, deviceID: device.id)
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
        .contextMenu {
            Button("Set as Sync Target") {
                store.selectActiveDevice(device.id)
            }
            Button("Open Sync Settings") {
                store.navigate(to: .deviceSync(device.id))
            }
            Divider()
            Button("Rename Destination...") {
                renameDraft = device.name
                showRenameSheet = true
            }
            Button("Sync Name from Volume") {
                store.resetDeviceNameFromVolume(device)
            }
            Button("Relink Volume / Folder...") {
                store.relinkDeviceVolumeViaPanel(device)
            }
            if device.isConnected && (vol?.isRemovable == true || device.mountPath.hasPrefix("/Volumes/")) {
                Divider()
                Button("Clean ._* & Eject") {
                    store.cleanAndEjectDevice(device, force: false)
                }
                Button("Force Eject Volume") {
                    store.cleanAndEjectDevice(device, force: true)
                }
            }
            Divider()
            Button("Remove Destination", role: .destructive) {
                store.deleteDevice(device)
            }
        }
        .sheet(isPresented: $showRenameSheet) {
            RenameDestinationSheet(currentName: device.name, draftName: $renameDraft) {
                store.renameDevice(device, to: renameDraft)
            }
        }
    }
}

struct RenameDestinationSheet: View {
    let currentName: String
    @Binding var draftName: String
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Rename Destination")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(EchoTheme.textPrimary)
            TextField("e.g. Echo SD, Nano, Car SD", text: $draftName)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    if !draftName.trimmingCharacters(in: .whitespaces).isEmpty {
                        onSave()
                        dismiss()
                    }
                }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                NeoPrimaryButton(title: "Save", icon: "checkmark", disabled: draftName.trimmingCharacters(in: .whitespaces).isEmpty) {
                    onSave()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 340)
        .background(EchoTheme.surface)
    }
}

struct NewPlaylistSheet: View {
    @Binding var name: String
    @Binding var description: String
    let onCreate: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Playlist")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(EchoTheme.textPrimary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Name")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(EchoTheme.textSecondary)
                TextField("e.g. Late Night Hi-Res, Commute Mix", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Description (optional)")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(EchoTheme.textSecondary)
                TextField("Notes about this playlist...", text: $description)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                NeoPrimaryButton(title: "Create Playlist", icon: "plus", disabled: name.trimmingCharacters(in: .whitespaces).isEmpty) {
                    onCreate()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 380)
        .background(EchoTheme.surface)
    }
}

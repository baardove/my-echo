import SwiftUI
import EchoCore

struct MainContentView: View {
    @Environment(EchoStore.self) private var store

    var body: some View {
        @Bindable var bindableStore = store

        ZStack {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    SidebarView()

                    VStack(spacing: 0) {
                        topBar(searchBinding: $bindableStore.searchQuery)

                        ZStack(alignment: .bottom) {
                            detailCanvas
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(EchoTheme.canvas)

                            if let toast = store.toastMessage {
                                toastBanner(toast, isError: store.toastIsError)
                                    .padding(.bottom, 16)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                        .animation(.easeOut(duration: 0.2), value: store.toastMessage)
                    }
                }

                PlayerBarView()
            }

            if let album = store.lightboxAlbum {
                AlbumLightboxView(album: album)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    .zIndex(100)
            }
        }
        .animation(.easeOut(duration: 0.18), value: store.lightboxAlbum?.id)
        .onKeyPress(.escape) {
            if store.lightboxAlbum != nil {
                store.closeAlbumLightbox()
                return .handled
            }
            return .ignored
        }
        .background {
            ZStack {
                GlassWindowBackdrop(isGlass: store.selectedTheme == .frostedGlass)
                EchoTheme.canvas
            }
            .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
    }

    private func topBar(searchBinding: Binding<String>) -> some View {
        HStack(spacing: 12) {
            // Back / Forward Navigation
            HStack(spacing: 5) {
                Button { store.goBack() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 28, height: 28)
                        .background(
                            ZStack {
                                EchoTheme.surfaceElevated
                                if store.canGoBack { EchoTheme.neoMint.opacity(0.06) }
                            }
                        )
                        .foregroundStyle(store.canGoBack ? EchoTheme.textPrimary : EchoTheme.textMuted.opacity(0.45))
                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous)
                                .strokeBorder(store.canGoBack ? EchoTheme.neoMint.opacity(0.50) : EchoTheme.border.opacity(0.6), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!store.canGoBack)
                .help("Navigate back to the previous view.")

                Button { store.goForward() } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 28, height: 28)
                        .background(
                            ZStack {
                                EchoTheme.surfaceElevated
                                if store.canGoForward { EchoTheme.neoMint.opacity(0.06) }
                            }
                        )
                        .foregroundStyle(store.canGoForward ? EchoTheme.textPrimary : EchoTheme.textMuted.opacity(0.45))
                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous)
                                .strokeBorder(store.canGoForward ? EchoTheme.neoMint.opacity(0.50) : EchoTheme.border.opacity(0.6), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!store.canGoForward)
                .help("Navigate forward in history.")
            }

            // Active Library Scope Picker + Crisp Retro Global Search Input
            HStack(spacing: 8) {
                if (!store.sources.isEmpty || store.lidarrConfig.isEnabled) && !store.isViewingPodcasts {
                    NeoMenuButton {
                        var items: [NeoMenuItem] = [
                            .action(
                                title: "All Libraries (\(store.tracks.count))",
                                icon: "books.vertical.fill",
                                isSelected: !store.isLidarrLibraryScope && store.selectedSourceID == nil
                            ) {
                                store.selectLibrarySource(nil)
                            }
                        ]
                        if !store.sources.isEmpty {
                            items.append(.divider)
                            for src in store.sources {
                                items.append(.action(
                                    title: "\(src.name) (\(src.trackCount))",
                                    icon: src.isNetworkVolume ? "externaldrive.connected.to.line.below" : "folder.fill",
                                    isSelected: !store.isLidarrLibraryScope && store.selectedSourceID == src.id
                                ) {
                                    store.selectLibrarySource(src.id)
                                })
                            }
                        }
                        if store.lidarrConfig.isEnabled {
                            items.append(.divider)
                            items.append(.action(
                                title: "Lidarr (Search & Mark for Download)",
                                icon: "arrow.down.to.line.compact",
                                isSelected: store.isLidarrLibraryScope
                            ) {
                                store.selectLidarrLibraryScope()
                            })
                        }
                        return items
                    } label: { isHovered in
                        let scopeAccent = EchoTheme.neoMint
                        let isScoped = store.selectedSourceID != nil || store.isLidarrLibraryScope
                        HStack(spacing: 5.5) {
                            Image(systemName: store.isLidarrLibraryScope
                                  ? "arrow.down.to.line.compact"
                                  : (store.selectedSource == nil
                                     ? "books.vertical.fill"
                                     : (store.selectedSource?.isNetworkVolume == true ? "externaldrive.connected.to.line.below" : "folder.fill")))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(scopeAccent)
                            Text(store.selectedLibraryDisplayName)
                                .font(.system(size: 11.5, weight: .bold))
                                .foregroundStyle(EchoTheme.textPrimary)
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundStyle(scopeAccent.opacity(isHovered ? 0.95 : 0.72))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            ZStack {
                                EchoTheme.surfaceElevated
                                scopeAccent.opacity(isHovered ? 0.14 : (isScoped ? 0.10 : 0.05))
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous)
                                .strokeBorder(scopeAccent.opacity(isHovered ? 0.90 : (isScoped ? 0.72 : 0.52)), lineWidth: 1)
                        )
                        .shadow(color: scopeAccent.opacity(isHovered ? 0.20 : 0.08), radius: 4, y: 1)
                    }
                    .fixedSize()
                    .help("Active library scope: browsing and Global Search stay inside '\(store.selectedLibraryDisplayName)' until you switch libraries.")
                }

                HStack(spacing: 8) {
                    Image(systemName: store.isLidarrLibraryScope ? "arrow.down.to.line.compact" : "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(EchoTheme.neoMint)
                    TextField(
                        store.isViewingPodcasts
                            ? "Search subscribed podcasts & episodes..."
                            : (store.isLidarrLibraryScope
                               ? "Search Lidarr (albums, tracks, artists to download)..."
                               : "Search \(store.selectedLibraryDisplayName) (artists, albums, tracks)..."),
                        text: searchBinding
                    )
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .foregroundStyle(EchoTheme.textPrimary)
                    .onSubmit {
                        if store.isLidarrLibraryScope {
                            store.searchLidarrUnified(query: store.searchQuery, immediate: true)
                        }
                    }
                    .onChange(of: store.searchQuery) { _, newValue in
                        if store.isLidarrLibraryScope {
                            store.searchLidarrUnified(query: newValue, immediate: false)
                        }
                    }
                    if !store.searchQuery.isEmpty {
                        Button {
                            store.searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.square.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(EchoTheme.textMuted)
                        }
                        .buttonStyle(.plain)
                        .help("Clear global search and return to your current view.")
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: 340)
                .background(EchoTheme.surfaceElevated.opacity(0.88))
                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous)
                        .strokeBorder(EchoTheme.neoMint.opacity(store.isGlobalSearchActive ? 0.85 : 0.42), lineWidth: 1)
                )
            }

            Spacer()

            // Focused Playlist Quick-Target Picker
            NeoMenuButton {
                if store.playlists.isEmpty {
                    return [
                        .action(title: "Create First Playlist", icon: "plus") {
                            let pl = store.createPlaylist(name: "My Playlist")
                            store.navigate(to: .playlist(pl.id))
                        }
                    ]
                }
                var items: [NeoMenuItem] = store.playlists.map { pl in
                    .action(
                        title: pl.name,
                        icon: "music.note.list",
                        isSelected: store.focusedPlaylist?.id == pl.id
                    ) {
                        store.setFocusedPlaylist(pl.id)
                        store.showToast("Quick-add (P) target: '\(pl.name)'")
                    }
                }
                items.append(.divider)
                items.append(.action(title: "New Playlist", icon: "plus") {
                    let pl = store.createPlaylist(name: "Playlist \(store.playlists.count + 1)")
                    store.navigate(to: .playlist(pl.id))
                })
                return items
            } label: { isHovered in
                HStack(spacing: 6) {
                    Image(systemName: "plus.square.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(EchoTheme.neoMint)
                    Text(store.focusedPlaylist?.name ?? "No Playlist")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(EchoTheme.textPrimary)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(EchoTheme.neoMint.opacity(isHovered ? 0.95 : 0.72))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    ZStack {
                        EchoTheme.surfaceElevated
                        EchoTheme.neoMint.opacity(isHovered ? 0.14 : 0.05)
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous)
                        .strokeBorder(EchoTheme.neoMint.opacity(isHovered ? 0.90 : 0.55), lineWidth: 1)
                )
                .shadow(color: EchoTheme.neoMint.opacity(isHovered ? 0.20 : 0.08), radius: 4, y: 1)
            }
            .fixedSize()
            .help("Focused playlist: clicking P on any song, album, or artist adds it directly to this playlist. Click to switch target playlist.")

            // Selected Sync Destination Picker (Supports Single & Multi-Destination switching!)
            if !store.devices.isEmpty {
                let device = store.activeDevice
                let plan = store.activeSyncPlan

                NeoMenuButton {
                    var items: [NeoMenuItem] = store.devices.map { dev in
                        .action(
                            title: "\(dev.isConnected ? "●" : "○") \(dev.name) — \(dev.preset.displayName)",
                            icon: dev.isVirtualWireless ? "iphone" : "sdcard.fill",
                            isSelected: device?.id == dev.id
                        ) {
                            store.selectActiveDevice(dev.id)
                        }
                    }
                    if store.destinationMode == .multi && device != nil {
                        items.append(.divider)
                        items.append(.action(title: "Clear Selected Destination") {
                            store.selectActiveDevice(nil)
                        })
                    }
                    items.append(.divider)
                    if let device {
                        items.append(.action(title: "Open \(device.name) Sync Settings...", icon: "slider.horizontal.3") {
                            store.navigate(to: .deviceSync(device.id))
                        })
                    }
                    items.append(.action(title: "Switch Single / Multi-Destination Mode...", icon: "gearshape") {
                        store.navigate(to: .settings)
                    })
                    return items
                } label: { isHovered in
                    let borderAccent: Color = device == nil ? EchoTheme.warningAmber : EchoTheme.neoMint
                    HStack(spacing: 6.5) {
                        if let device {
                            let dotColor = EchoTheme.color(for: device.accentColor)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(device.isConnected ? dotColor : EchoTheme.dangerCoral)
                                .frame(width: 7, height: 7)
                            Text(device.name)
                                .font(.system(size: 11.5, weight: .bold))
                                .foregroundStyle(EchoTheme.textPrimary)
                                .lineLimit(1)
                            if let plan {
                                if let cap = plan.maxTrackLimit {
                                    Text("\(plan.projectedTotalTracks)/\(cap)")
                                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(plan.exceedsTrackLimit ? EchoTheme.dangerCoral : EchoTheme.neoMint.opacity(0.9))
                                } else {
                                    Text("\(plan.projectedTotalTracks)")
                                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(EchoTheme.neoMint.opacity(0.9))
                                }
                            }
                        } else {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(EchoTheme.warningAmber)
                            Text("Select Destination")
                                .font(.system(size: 11.5, weight: .bold))
                                .foregroundStyle(EchoTheme.warningAmber)
                        }
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundStyle(borderAccent.opacity(isHovered ? 0.95 : 0.72))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        ZStack {
                            EchoTheme.surfaceElevated
                            borderAccent.opacity(isHovered ? 0.14 : (device == nil ? 0.12 : 0.05))
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous)
                            .strokeBorder(borderAccent.opacity(isHovered ? 0.90 : 0.55), lineWidth: 1)
                    )
                    .shadow(color: borderAccent.opacity(isHovered ? 0.20 : 0.08), radius: 4, y: 1)
                }
                .fixedSize()
                .help(device == nil
                      ? "Multi-Destination mode is active: click to choose which player or SD card to target for syncing."
                      : "Selected sync destination: '\(device!.name)'. Click to switch between destinations (e.g. ECHO internal vs ECHO SD) without leaving this view.")

                if store.isSyncing, let prog = store.syncProgress {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.mini)
                        Text("\(Int(prog.fraction * 100))%")
                            .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(EchoTheme.neoMint)
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6.5)
                    .background(EchoTheme.neoMint.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                    .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusControl).strokeBorder(EchoTheme.neoMint.opacity(0.55), lineWidth: 1))
                    .help("Sync in progress: \(prog.phase) — \(prog.currentItem)")
                } else if let device, device.isConnected {
                    let pending = (plan?.totalPendingCopies ?? 0) + (plan?.totalPendingRemovals ?? 0)
                    NeoPrimaryButton(
                        title: pending > 0 ? "Sync (\(pending))" : "Sync",
                        icon: "arrow.triangle.2.circlepath"
                    ) {
                        store.startSync(for: device)
                    }
                    .help("Copy selected music, podcasts, and playlists to '\(device.name)', optimize cover art, and clean macOS ._* files.")
                } else {
                    let connectedDevices = store.devices.filter(\.isConnected)
                    if !connectedDevices.isEmpty {
                        NeoPrimaryMenuButton(title: "Sync to", icon: "arrow.triangle.2.circlepath") {
                            connectedDevices.map { dev in
                                .action(title: "Sync to \(dev.name)", icon: dev.isVirtualWireless ? "iphone" : "sdcard.fill") {
                                    store.selectActiveDevice(dev.id)
                                    store.startSync(for: dev)
                                }
                            }
                        }
                        .fixedSize()
                        .help("Choose a connected destination to select and sync immediately.")
                    } else {
                        NeoPrimaryButton(
                            title: "Sync",
                            icon: "arrow.triangle.2.circlepath",
                            disabled: true
                        ) {}
                        .help("No destination is currently connected. Plug in your FiiO player or SD card to sync.")
                    }
                }
            } else {
                NeoSecondaryButton(title: "Connect Player", icon: "sdcard") {
                    store.addCustomDeviceFolderViaPanel()
                }
                .help("Pair a FiiO player, MicroSD card, or local target folder to enable syncing.")
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 54)
        .background(EchoTheme.canvas.opacity(0.96))
        .overlay(alignment: .bottom) {
            Rectangle().fill(EchoTheme.border).frame(height: 1)
        }
    }

    @ViewBuilder
    private var detailCanvas: some View {
        if store.isGlobalSearchActive {
            GlobalSearchResultsView()
        } else {
            switch store.currentDestination {
            case .home:
                HomeView()
            case .artists:
                ArtistsView()
            case .artistDetail(let key):
                ArtistDetailView(artistKey: key)
            case .albums:
                AlbumsView()
            case .albumDetail(let key):
                AlbumDetailView(albumKey: key)
            case .tracks:
                TracksView()
            case .podcasts:
                PodcastsView()
            case .podcastDetail(let id):
                PodcastDetailView(showID: id)
            case .playlist(let id):
                PlaylistDetailView(playlistID: id)
            case .lidarr:
                LidarrView()
            case .sources:
                SourcesView()
            case .deviceSync(let id):
                DeviceSyncView(deviceID: id)
            case .settings:
                SettingsView()
            }
        }
    }

    private func toastBanner(_ message: String, isError: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.square.fill")
                .foregroundStyle(isError ? EchoTheme.warningAmber : EchoTheme.neoMint)
            Text(message)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(EchoTheme.textPrimary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(EchoTheme.surfaceElevated.opacity(0.97))
        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
        .overlay(
            RoundedRectangle(cornerRadius: EchoTheme.radiusControl)
                .strokeBorder(isError ? EchoTheme.warningAmber.opacity(0.6) : EchoTheme.neoMint.opacity(0.6), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.55), radius: 12, y: 4)
    }
}

/// Unified Global Search view scoped strictly to the currently selected library (or Podcasts when in Podcasts)
struct GlobalSearchResultsView: View {
    @Environment(EchoStore.self) private var store

    var body: some View {
        let query = store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.isViewingPodcasts
                             ? "GLOBAL SEARCH · PODCASTS"
                             : "GLOBAL SEARCH · \(store.selectedLibraryDisplayName.uppercased())")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(1.4)
                            .foregroundStyle(EchoTheme.neoCyan)

                        Text("Results for \"\(query)\"")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(EchoTheme.textPrimary)
                    }
                    Spacer()

                    if store.isViewingPodcasts {
                        NeoPrimaryButton(title: "Search Directories", icon: "magnifyingglass") {
                            store.podcastSearchQuery = query
                            store.searchQuery = ""
                            store.navigate(to: .podcasts)
                            store.searchPodcasts()
                        }
                        .help("Run '\(query)' against Apple Podcasts & gPodder Open Directories to discover new shows.")
                    } else if !store.isLidarrLibraryScope && store.lidarrConfig.isEnabled {
                        Button {
                            store.isLidarrLibraryScope = true
                            store.selectedSourceID = nil
                            store.searchLidarrUnified(query: query, immediate: true)
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.down.to.line.compact")
                                    .font(.system(size: 11, weight: .bold))
                                Text("Search in Lidarr")
                                    .font(.system(size: 11.5, weight: .bold))
                            }
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6.5)
                            .background(EchoTheme.neoMint.opacity(0.16))
                            .foregroundStyle(EchoTheme.neoMint)
                            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                            .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusControl).strokeBorder(EchoTheme.neoMint.opacity(0.45), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .help("Switch active library to Lidarr and search '\(query)' to mark albums/tracks for download.")
                    } else if store.isLidarrLibraryScope {
                        NeoPrimaryButton(
                            title: store.isSearchingLidarr ? "Searching..." : "Search Lidarr",
                            icon: "magnifyingglass",
                            disabled: store.isSearchingLidarr
                        ) {
                            store.searchLidarrUnified(query: query, immediate: true)
                        }
                    }

                    Button {
                        store.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .frame(width: 30, height: 30)
                            .background(EchoTheme.surfaceElevated)
                            .foregroundStyle(EchoTheme.textSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                    }
                    .buttonStyle(.plain)
                    .help("Close search results and return to the previous screen.")
                }

                if store.isLidarrLibraryScope {
                    if store.lidarrMarkedCount > 0 {
                        LidarrMarkedDownloadsBar()
                    }

                    if store.isSearchingLidarr {
                        HStack(spacing: 10) {
                            ProgressView().controlSize(.small)
                            Text("Searching Lidarr albums, artists, and tracks for \"\(query)\"...")
                                .font(.system(size: 13))
                                .foregroundStyle(EchoTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(36)
                        .background(EchoTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard))
                    } else if let err = store.lidarrSearchError,
                              store.lidarrAlbumResults.isEmpty && store.lidarrTrackResults.isEmpty && store.lidarrArtistResults.isEmpty {
                        emptySearchCard(err)
                    } else if store.lidarrAlbumResults.isEmpty && store.lidarrTrackResults.isEmpty && store.lidarrArtistResults.isEmpty {
                        emptySearchCard("Type an artist, album, or track name and press Enter to search Lidarr and mark releases for download.")
                    } else {
                        if !store.lidarrAlbumResults.isEmpty {
                            sectionTitle("LIDARR ALBUMS (\(store.lidarrAlbumResults.count)) · CHECK BOXES TO MARK FOR DOWNLOAD")
                            LazyVStack(spacing: 8) {
                                ForEach(store.lidarrAlbumResults.prefix(20)) { album in
                                    LidarrAlbumResultRow(album: album)
                                }
                            }
                        }

                        if !store.lidarrTrackResults.isEmpty {
                            sectionTitle("TRACKS · MARK PARENT ALBUM FOR DOWNLOAD (\(store.lidarrTrackResults.count))")
                            LazyVStack(spacing: 8) {
                                ForEach(store.lidarrTrackResults.prefix(12)) { track in
                                    LidarrTrackResultRow(track: track)
                                }
                            }
                        }

                        if !store.lidarrArtistResults.isEmpty {
                            sectionTitle("LIDARR ARTISTS (\(store.lidarrArtistResults.count))")
                            LazyVStack(spacing: 8) {
                                ForEach(store.lidarrArtistResults.prefix(8)) { artist in
                                    LidarrArtistResultRow(artist: artist)
                                }
                            }
                        }
                    }
                } else if store.isViewingPodcasts {
                    let matchingShows = store.filteredPodcastShows
                    let matchingEps = store.filteredPodcastEpisodes

                    if matchingShows.isEmpty && matchingEps.isEmpty {
                        emptySearchCard("No subscribed podcasts or episodes matched \"\(query)\". Use Search Directories to find new shows.")
                    } else {
                        if !matchingShows.isEmpty {
                            sectionTitle("SUBSCRIBED SHOWS (\(matchingShows.count))")
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 175, maximum: 210), spacing: 14)], spacing: 14) {
                                ForEach(matchingShows) { show in
                                    PodcastShowCardView(show: show)
                                        .simultaneousGesture(TapGesture().onEnded { store.searchQuery = "" })
                                }
                            }
                        }
                        if !matchingEps.isEmpty {
                            sectionTitle("EPISODES (\(matchingEps.count))")
                            LazyVStack(spacing: 6) {
                                ForEach(matchingEps.prefix(60)) { ep in
                                    PodcastEpisodeRowView(episode: ep)
                                }
                            }
                        }
                    }
                } else {
                    let artists = store.filteredArtists
                    let albums = store.filteredAlbums
                    let tracks = store.filteredTracks
                    let playlists = store.filteredPlaylists

                    if artists.isEmpty && albums.isEmpty && tracks.isEmpty && playlists.isEmpty {
                        emptySearchCard("No matches in \(store.selectedLibraryDisplayName) for \"\(query)\".")
                    } else {
                        if !artists.isEmpty {
                            sectionTitle("ARTISTS (\(artists.count))")
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 155, maximum: 185), spacing: 14)], spacing: 14) {
                                ForEach(artists.prefix(12)) { artist in
                                    ArtistCardView(artist: artist)
                                        .simultaneousGesture(TapGesture().onEnded { store.searchQuery = "" })
                                }
                            }
                        }

                        if !albums.isEmpty {
                            sectionTitle("ALBUMS (\(albums.count))")
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 162, maximum: 192), spacing: 14)], spacing: 14) {
                                ForEach(albums.prefix(12)) { album in
                                    AlbumCardView(album: album)
                                        .simultaneousGesture(TapGesture().onEnded { store.searchQuery = "" })
                                }
                            }
                        }

                        if !tracks.isEmpty {
                            sectionTitle("TRACKS (\(tracks.count))")
                            LazyVStack(spacing: 2) {
                                ForEach(Array(tracks.prefix(100).enumerated()), id: \.element.id) { idx, track in
                                    TrackRowView(track: track, index: idx, showAlbumColumn: true) {
                                        store.player.play(tracks: tracks, startingAt: idx)
                                    }
                                }
                            }
                        }

                        if !playlists.isEmpty {
                            sectionTitle("PLAYLISTS (\(playlists.count))")
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 12)], spacing: 12) {
                                ForEach(playlists) { pl in
                                    Button {
                                        store.searchQuery = ""
                                        store.navigate(to: .playlist(pl.id))
                                    } label: {
                                        HStack(spacing: 10) {
                                            PlaylistMosaicArtwork(tracks: store.tracks(for: pl), artworkCache: store.artworkCache, cornerRadius: EchoTheme.radiusSmall)
                                                .frame(width: 44, height: 44)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(pl.name)
                                                    .font(.system(size: 13, weight: .bold))
                                                    .foregroundStyle(EchoTheme.textPrimary)
                                                    .lineLimit(1)
                                                Text("\(pl.trackIDs.count) tracks")
                                                    .font(.system(size: 10.5, design: .monospaced))
                                                    .foregroundStyle(EchoTheme.textMuted)
                                            }
                                            Spacer()
                                        }
                                        .padding(10)
                                        .background(EchoTheme.surface)
                                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard))
                                        .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusCard).strokeBorder(EchoTheme.border, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            .padding(26)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
            .tracking(1.2)
            .foregroundStyle(EchoTheme.neoMint)
    }

    private func emptySearchCard(_ message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(EchoTheme.textMuted)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(EchoTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(EchoTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard))
        .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusCard).strokeBorder(EchoTheme.border, lineWidth: 1))
    }
}

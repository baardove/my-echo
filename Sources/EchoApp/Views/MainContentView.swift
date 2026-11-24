import SwiftUI
import EchoCore

struct MainContentView: View {
    @Environment(EchoStore.self) private var store

    var body: some View {
        @Bindable var bindableStore = store

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
                        .background(EchoTheme.surface)
                        .foregroundStyle(store.canGoBack ? EchoTheme.textPrimary : EchoTheme.textMuted)
                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                        .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusControl).strokeBorder(EchoTheme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(!store.canGoBack)
                .help("Navigate back to the previous view.")

                Button { store.goForward() } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 28, height: 28)
                        .background(EchoTheme.surface)
                        .foregroundStyle(store.canGoForward ? EchoTheme.textPrimary : EchoTheme.textMuted)
                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                        .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusControl).strokeBorder(EchoTheme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(!store.canGoForward)
                .help("Navigate forward in history.")
            }

            // Active Library Scope Picker + Crisp Retro Global Search Input
            HStack(spacing: 6) {
                if !store.sources.isEmpty && !store.isViewingPodcasts {
                    Menu {
                        Button {
                            store.selectLibrarySource(nil)
                        } label: {
                            HStack {
                                Text("All Libraries (\(store.tracks.count))")
                                if store.selectedSourceID == nil { Image(systemName: "checkmark") }
                            }
                        }
                        Divider()
                        ForEach(store.sources) { src in
                            Button {
                                store.selectLibrarySource(src.id)
                            } label: {
                                HStack {
                                    Text("\(src.name) (\(src.trackCount))")
                                    if store.selectedSourceID == src.id { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: store.selectedSource == nil ? "books.vertical.fill" : (store.selectedSource?.isNetworkVolume == true ? "externaldrive.connected.to.line.below" : "folder.fill"))
                                .font(.system(size: 10.5))
                                .foregroundStyle(EchoTheme.neoCyan)
                            Text(store.selectedLibraryDisplayName)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(EchoTheme.textPrimary)
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(EchoTheme.textMuted)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(EchoTheme.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                        .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusControl).strokeBorder(store.selectedSourceID != nil ? EchoTheme.neoCyan.opacity(0.45) : EchoTheme.border, lineWidth: 1))
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help("Active library scope: browsing and Global Search stay inside '\(store.selectedLibraryDisplayName)' until you switch libraries.")
                }

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(EchoTheme.neoCyan)
                    TextField(
                        store.isViewingPodcasts
                            ? "Search subscribed podcasts & episodes..."
                            : "Search \(store.selectedLibraryDisplayName) (artists, albums, tracks)...",
                        text: searchBinding
                    )
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .foregroundStyle(EchoTheme.textPrimary)
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
                .padding(.vertical, 6.5)
                .frame(maxWidth: 320)
                .background(EchoTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusControl).strokeBorder(store.isGlobalSearchActive ? EchoTheme.neoCyan.opacity(0.6) : EchoTheme.border, lineWidth: 1))
            }

            Spacer()

            // Focused Playlist Quick-Target Picker
            Menu {
                if store.playlists.isEmpty {
                    Button("Create First Playlist") {
                        let pl = store.createPlaylist(name: "My Playlist")
                        store.navigate(to: .playlist(pl.id))
                    }
                } else {
                    ForEach(store.playlists) { pl in
                        Button {
                            store.setFocusedPlaylist(pl.id)
                            store.showToast("Quick-add (+) target: '\(pl.name)'")
                        } label: {
                            HStack {
                                Text(pl.name)
                                if store.focusedPlaylist?.id == pl.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    Divider()
                    Button("+ New Playlist") {
                        let pl = store.createPlaylist(name: "Playlist \(store.playlists.count + 1)")
                        store.navigate(to: .playlist(pl.id))
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.square.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(EchoTheme.neoCyan)
                    Text(store.focusedPlaylist?.name ?? "No Playlist")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(EchoTheme.textPrimary)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(EchoTheme.textMuted)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(EchoTheme.neoCyan.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusControl).strokeBorder(EchoTheme.neoCyan.opacity(0.35), lineWidth: 1))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Focused playlist: clicking the + button on any song adds it directly to this playlist. Click to switch target playlist.")

            // Selected Sync Destination Picker (Supports Single & Multi-Destination switching!)
            if !store.devices.isEmpty {
                let device = store.activeDevice
                let plan = store.activeSyncPlan

                Menu {
                    ForEach(store.devices) { dev in
                        Button {
                            store.selectActiveDevice(dev.id)
                        } label: {
                            HStack {
                                Text("\(dev.isConnected ? "●" : "○") \(dev.name) — \(dev.preset.displayName)")
                                if device?.id == dev.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    if store.destinationMode == .multi && device != nil {
                        Divider()
                        Button("Clear Selected Destination") {
                            store.selectActiveDevice(nil)
                        }
                    }
                    Divider()
                    if let device {
                        Button("Open \(device.name) Sync Settings...") {
                            store.navigate(to: .deviceSync(device.id))
                        }
                    }
                    Button("Switch Single / Multi-Destination Mode...") {
                        store.navigate(to: .settings)
                    }
                } label: {
                    HStack(spacing: 7) {
                        if let device {
                            let accent = EchoTheme.color(for: device.accentColor)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(device.isConnected ? accent : EchoTheme.dangerCoral)
                                .frame(width: 7, height: 7)
                            Text(device.name)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(EchoTheme.textPrimary)
                            if let plan {
                                if let cap = plan.maxTrackLimit {
                                    Text("\(plan.projectedTotalTracks)/\(cap)")
                                        .font(.system(size: 10.5, design: .monospaced))
                                        .foregroundStyle(plan.exceedsTrackLimit ? EchoTheme.dangerCoral : EchoTheme.neoCyan)
                                } else {
                                    Text("\(plan.projectedTotalTracks) items")
                                        .font(.system(size: 10.5, design: .monospaced))
                                        .foregroundStyle(EchoTheme.neoCyan)
                                }
                            }
                        } else {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(EchoTheme.warningAmber)
                            Text("Select Destination")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(EchoTheme.warningAmber)
                        }
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(EchoTheme.textMuted)
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(device == nil ? EchoTheme.warningAmber.opacity(0.14) : EchoTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                    .overlay(
                        RoundedRectangle(cornerRadius: EchoTheme.radiusControl)
                            .strokeBorder(device == nil ? EchoTheme.warningAmber.opacity(0.6) : EchoTheme.borderStrong, lineWidth: 1)
                    )
                }
                .menuStyle(.borderlessButton)
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
                        Menu {
                            ForEach(connectedDevices) { dev in
                                Button("Sync to \(dev.name)") {
                                    store.selectActiveDevice(dev.id)
                                    store.startSync(for: dev)
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 11.5, weight: .bold))
                                Text("Sync to")
                                    .font(.system(size: 12, weight: .black))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 8.5, weight: .black))
                            }
                            .padding(.horizontal, 13)
                            .padding(.vertical, 7.5)
                            .background(EchoTheme.accentGradient)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                        }
                        .menuStyle(.borderlessButton)
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
                Button {
                    store.addCustomDeviceFolderViaPanel()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sdcard")
                        Text("Connect Player")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6.5)
                    .background(EchoTheme.surfaceElevated)
                    .foregroundStyle(EchoTheme.neoMint)
                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                    .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusControl).strokeBorder(EchoTheme.borderStrong, lineWidth: 1))
                }
                .buttonStyle(.plain)
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

                if store.isViewingPodcasts {
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

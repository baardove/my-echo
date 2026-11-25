import SwiftUI
import EchoCore

// MARK: - Home / Overview View

struct HomeView: View {
    @Environment(EchoStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Hero Greeting & Active Device Banner
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(
                        colors: [EchoTheme.neoMint.opacity(0.22), EchoTheme.neoCyan.opacity(0.10), EchoTheme.canvas],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 170)
                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous)
                            .strokeBorder(EchoTheme.borderStrong, lineWidth: 1)
                    )

                    HStack(alignment: .bottom, spacing: 20) {
                        EchoBrandLogo(size: 56, animate: store.player.isPlaying)
                            .padding(.bottom, 4)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(store.selectedTheme.brandTagline)
                                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                .tracking(1.4)
                                .foregroundStyle(EchoTheme.neoMint)

                            Text(store.selectedSource == nil ? "My Echo Music Studio" : store.selectedLibraryDisplayName)
                                .font(.system(size: 30, weight: .black, design: .rounded))
                                .foregroundStyle(EchoTheme.textPrimary)

                            HStack(spacing: 10) {
                                statPill("\(store.artists.count) Artists", icon: "person.2")
                                statPill("\(store.albums.count) Albums", icon: "square.stack")
                                statPill("\(store.scopedTracks.count) Tracks", icon: "music.note")
                                statPill("\(store.totalLibraryUserPlays) Plays", icon: "play.circle")
                                statPill("\(store.playlists.count) Playlists", icon: "music.note.list")
                                statPill("\(store.podcasts.count) Podcasts", icon: "mic")
                            }
                        }
                        Spacer()

                        HStack(spacing: 10) {
                            Button {
                                store.addLibrarySourceViaPanel()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "folder.badge.plus")
                                    Text("Add Folder / NAS")
                                        .font(.system(size: 12.5, weight: .semibold))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8.5)
                                .background(EchoTheme.surfaceElevated)
                                .foregroundStyle(EchoTheme.textPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                                .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusControl).strokeBorder(EchoTheme.borderStrong, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .help("Index a local folder or mounted SMB/NFS NAS share into your Echo library.")

                            if let device = store.activeDevice {
                                NeoPrimaryButton(
                                    title: "Manage \(device.name)",
                                    icon: "arrow.triangle.2.circlepath"
                                ) {
                                    store.navigate(to: .deviceSync(device.id))
                                }
                                .help("Open the sync control center for '\(device.name)' to review diff, optimize cover art, and sync.")
                            } else {
                                NeoPrimaryButton(title: "Add FiiO / SD Card", icon: "sdcard") {
                                    store.addCustomDeviceFolderViaPanel()
                                }
                                .help("Pair a FiiO Echo, Nano, Disc, Android DAP, or SD card folder.")
                            }
                        }
                    }
                    .padding(24)
                }

                if store.scopedTracks.isEmpty {
                    emptyLibraryOnboarding
                } else {
                    let topUserTracks = store.mostPlayedTracks(limit: 5)
                    let topOnlineTracks = store.mostPopularOnlineTracks(limit: 5)

                    // 1. New Arrivals (Newly Downloaded / Added)
                    if !store.newArrivalAlbums.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .firstTextBaseline) {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.system(size: 14.5))
                                        .foregroundStyle(EchoTheme.neoMint)
                                    Text("New Arrivals")
                                        .font(.system(size: 19, weight: .bold))
                                        .foregroundStyle(EchoTheme.textPrimary)
                                    Text("Newly downloaded & added")
                                        .font(.system(size: 11.5))
                                        .foregroundStyle(EchoTheme.textMuted)
                                }
                                Spacer()
                                Button("See all") {
                                    store.albumSortOrder = .newArrivals
                                    store.navigate(to: .albums)
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(EchoTheme.neoMint)
                                .buttonStyle(.plain)
                                .help("View all albums sorted by most recently downloaded or added to your library.")
                            }

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 168, maximum: 195), spacing: 16)], spacing: 18) {
                                ForEach(store.newArrivalAlbums.prefix(10)) { album in
                                    let arrivalTag = Formatters.relativeArrival(album.latestArrivalDate)
                                    AlbumCardView(
                                        album: album,
                                        cornerBadge: arrivalTag.isEmpty ? nil : arrivalTag,
                                        cornerBadgeColor: EchoTheme.neoMint
                                    )
                                }
                            }
                        }
                    }

                    // 2. New Releases (Newly Released Albums)
                    if !store.newReleaseAlbums.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .firstTextBaseline) {
                                HStack(spacing: 8) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 14))
                                        .foregroundStyle(EchoTheme.neoCyan)
                                    Text("New Releases")
                                        .font(.system(size: 19, weight: .bold))
                                        .foregroundStyle(EchoTheme.textPrimary)
                                    Text("Latest album releases")
                                        .font(.system(size: 11.5))
                                        .foregroundStyle(EchoTheme.textMuted)
                                }
                                Spacer()
                                Button("See all") {
                                    store.albumSortOrder = .newReleases
                                    store.navigate(to: .albums)
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(EchoTheme.neoCyan)
                                .buttonStyle(.plain)
                                .help("View all albums sorted by newest release year.")
                            }

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 168, maximum: 195), spacing: 16)], spacing: 18) {
                                ForEach(store.newReleaseAlbums.prefix(10)) { album in
                                    AlbumCardView(
                                        album: album,
                                        cornerBadge: album.year.map { String($0) },
                                        cornerBadgeColor: EchoTheme.neoCyan
                                    )
                                }
                            }
                        }
                    }

                    if !topUserTracks.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                HStack(spacing: 8) {
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(EchoTheme.neoMint)
                                    Text("Most Played by You")
                                        .font(.system(size: 19, weight: .bold))
                                        .foregroundStyle(EchoTheme.textPrimary)
                                }
                                Spacer()
                                Button("Sort All Tracks by Plays") {
                                    store.trackSortOrder = .mostPlayed
                                    store.navigate(to: .tracks)
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(EchoTheme.neoMint)
                                .buttonStyle(.plain)
                            }

                            VStack(spacing: 2) {
                                trackTableHeader(showAlbum: true)
                                Divider().overlay(EchoTheme.border).padding(.bottom, 2)
                                ForEach(Array(topUserTracks.enumerated()), id: \.element.id) { idx, track in
                                    TrackRowView(track: track, index: idx, showAlbumColumn: true) {
                                        store.player.play(tracks: topUserTracks, startingAt: idx)
                                    }
                                }
                            }
                            .padding(10)
                            .background(EchoTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous).strokeBorder(EchoTheme.border, lineWidth: 1))
                        }
                    }

                    if !topOnlineTracks.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                HStack(spacing: 8) {
                                    Image(systemName: "chart.bar.fill")
                                        .font(.system(size: 13.5))
                                        .foregroundStyle(EchoTheme.neoCyan)
                                    Text("Most Popular Online in Your Library")
                                        .font(.system(size: 19, weight: .bold))
                                        .foregroundStyle(EchoTheme.textPrimary)
                                }
                                Spacer()
                                Button("Sort All Tracks by Popularity") {
                                    store.trackSortOrder = .onlinePopularity
                                    store.navigate(to: .tracks)
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(EchoTheme.neoCyan)
                                .buttonStyle(.plain)
                            }

                            VStack(spacing: 2) {
                                trackTableHeader(showAlbum: true)
                                Divider().overlay(EchoTheme.border).padding(.bottom, 2)
                                ForEach(Array(topOnlineTracks.enumerated()), id: \.element.id) { idx, track in
                                    TrackRowView(track: track, index: idx, showAlbumColumn: true) {
                                        store.player.play(tracks: topOnlineTracks, startingAt: idx)
                                    }
                                }
                            }
                            .padding(10)
                            .background(EchoTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous).strokeBorder(EchoTheme.border, lineWidth: 1))
                        }
                    }

                    // Featured Albums Shelf
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Albums in \(store.selectedLibraryDisplayName)")
                                .font(.system(size: 19, weight: .bold))
                                .foregroundStyle(EchoTheme.textPrimary)
                            Spacer()
                            Button("See all") { store.navigate(to: .albums) }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(EchoTheme.neoMint)
                                .buttonStyle(.plain)
                        }

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 168, maximum: 195), spacing: 16)], spacing: 18) {
                            ForEach(store.albums.prefix(10)) { album in
                                AlbumCardView(album: album)
                            }
                        }
                    }

                    // Artists Shelf
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Artists")
                                .font(.system(size: 19, weight: .bold))
                                .foregroundStyle(EchoTheme.textPrimary)
                            Spacer()
                            Button("See all") { store.navigate(to: .artists) }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(EchoTheme.neoMint)
                                .buttonStyle(.plain)
                        }

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 152, maximum: 175), spacing: 16)], spacing: 18) {
                            ForEach(store.artists.prefix(8)) { artist in
                                ArtistCardView(artist: artist)
                            }
                        }
                    }
                }
            }
            .padding(26)
        }
    }

    private func statPill(_ text: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10.5))
                .foregroundStyle(EchoTheme.neoCyan)
            Text(text)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(EchoTheme.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.black.opacity(0.32))
        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
    }

    private var emptyLibraryOnboarding: some View {
        VStack(spacing: 16) {
            EchoBrandLogo(size: 52, animate: true)
            Text("Start by Indexing Your Music Library")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(EchoTheme.textPrimary)
            Text("Add one or more local folders or mounted NAS shares. My Echo indexes FLAC, MP3, M4A/ALAC, WAV, OGG, APE & DSD, preserves ARTIST/ALBUM/TRACK structure, optimizes album art to Baseline JPEG for FiiO Echo / Nano / Disc, and keeps your SD card free of macOS ._* junk files.")
                .font(.system(size: 13))
                .foregroundStyle(EchoTheme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 540)

            HStack(spacing: 12) {
                NeoPrimaryButton(title: "Add Music Folder / NAS", icon: "folder.badge.plus") {
                    store.addLibrarySourceViaPanel()
                }
                Button("Add Target Player / SD Card") {
                    store.addCustomDeviceFolderViaPanel()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(EchoTheme.surfaceElevated)
                .foregroundStyle(EchoTheme.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(44)
        .background(EchoTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous).strokeBorder(EchoTheme.border, lineWidth: 1))
    }
}

// MARK: - Artists Grid & Detail

struct ArtistsView: View {
    @Environment(EchoStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Artists")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(EchoTheme.textPrimary)
                    Text("\(store.filteredArtists.count)")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(EchoTheme.textMuted)
                    Spacer()
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 162, maximum: 190), spacing: 16)], spacing: 18) {
                    ForEach(store.filteredArtists) { artist in
                        ArtistCardView(artist: artist)
                    }
                }
            }
            .padding(26)
        }
    }
}

struct ArtistCardView: View {
    @Environment(EchoStore.self) private var store
    let artist: ArtistGroup
    @State private var isHovered = false

    var body: some View {
        let state = store.selectionState(forArtist: artist)
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                ArtworkView(hash: artist.artworkHash, artworkCache: store.artworkCache, cornerRadius: EchoTheme.radiusCard, iconSize: 34)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard))
                    .shadow(color: .black.opacity(0.45), radius: 10, y: 4)

                if isHovered {
                    Button {
                        store.player.play(tracks: artist.tracks, startingAt: 0)
                    } label: {
                        RoundedRectangle(cornerRadius: EchoTheme.radiusControl)
                            .fill(EchoTheme.neoMint.opacity(0.76))
                            .frame(width: 28, height: 28)
                            .overlay(
                                RoundedRectangle(cornerRadius: EchoTheme.radiusControl)
                                    .strokeBorder(Color.white.opacity(0.28), lineWidth: 0.75)
                            )
                            .overlay(Image(systemName: "play.fill").foregroundStyle(.black.opacity(0.9)).font(.system(size: 11, weight: .bold)))
                            .shadow(color: Color.black.opacity(0.35), radius: 5, y: 2)
                    }
                    .buttonStyle(.plain)
                    .padding(6)
                }

                // Top-right P (Playlist) & S (Sync / Subscription) corner pills
                let plState = store.focusedPlaylistState(for: artist.tracks)
                let plName = store.focusedPlaylist?.name ?? "My Playlist"
                let targetName = store.activeDevice?.name ?? "selected destination"
                CardPSBadgeStrip(
                    playlistState: plState,
                    syncState: state,
                    isCardHovered: isHovered,
                    playlistTooltip: plState == .full
                        ? "Remove '\(artist.name)' from playlist '\(plName)'."
                        : "Add all tracks by '\(artist.name)' to playlist '\(plName)'.",
                    syncTooltip: state == .full
                        ? "Synced to '\(targetName)'. Click to remove '\(artist.name)'."
                        : "Include '\(artist.name)' in '\(targetName)' sync.",
                    onTogglePlaylist: { store.toggleTracksInFocusedPlaylist(artist.tracks, label: artist.name) },
                    onToggleSync: { store.toggleArtistSync(artist) }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(5)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(artist.name)
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(EchoTheme.textPrimary)
                    .lineLimit(1)
                Text("\(artist.albums.count) album\(artist.albums.count == 1 ? "" : "s") · \(artist.tracks.count) tracks")
                    .font(.system(size: 11))
                    .foregroundStyle(EchoTheme.textMuted)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous)
                .fill(isHovered ? EchoTheme.surfaceElevated : EchoTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous)
                .strokeBorder(state == .full ? EchoTheme.neoMint.opacity(0.35) : EchoTheme.border, lineWidth: 1)
        )
        .onHover { isHovered = $0 }
        .onTapGesture { store.navigate(to: .artistDetail(artist.id)) }
        .draggable(EchoDragPayload.artist(artist.id).encode()) {
            DragPreviewPill(
                title: artist.name,
                subtitle: "\(artist.albums.count) albums",
                artworkHash: artist.artworkHash,
                artworkCache: store.artworkCache,
                badge: "\(artist.tracks.count) TRACKS"
            )
        }
    }
}

struct ArtistDetailView: View {
    @Environment(EchoStore.self) private var store
    let artistKey: String
    @State private var tracksSort = TrackTableSortState()

    var body: some View {
        if let resolved = store.resolveArtist(forKey: artistKey) {
            let artist = resolved.artist
            let appearsOnTracks = resolved.appearsOnTracks
            let combinedTracks = artist.tracks + appearsOnTracks
            let glow = ArtworkImageLoader.shared.dominantColor(forHash: artist.artworkHash, artworkCache: store.artworkCache)
            let state = store.selectionState(forArtist: artist)
            let totalPlays = store.totalUserPlays(for: artist)
            let avgPop = store.averageOnlinePopularity(for: artist)
            let onlineFans = store.artistStats[artist.id]?.fans
            let isFetchingPop = store.fetchingPopularityKeys.contains("artist:\(artist.id)")
            let popularTracks: [Track] = combinedTracks
                .filter { (store.stats(for: $0).onlinePopularity ?? 0) > 0 || store.userPlayCount(for: $0) > 0 }
                .sorted { a, b in
                    let popA = store.stats(for: a).onlinePopularity ?? 0
                    let popB = store.stats(for: b).onlinePopularity ?? 0
                    if popA != popB { return popA > popB }
                    return store.userPlayCount(for: a) > store.userPlayCount(for: b)
                }
                .prefix(5)
                .map { $0 }

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    // Spotify-style Artist Hero
                    ZStack(alignment: .bottomLeading) {
                        LinearGradient(
                            colors: [glow.opacity(0.55), EchoTheme.canvas],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 220)

                        HStack(alignment: .bottom, spacing: 22) {
                            ArtworkView(hash: artist.artworkHash, artworkCache: store.artworkCache, cornerRadius: EchoTheme.radiusCard, iconSize: 48)
                                .frame(width: 156, height: 156)
                                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard))
                                .shadow(color: .black.opacity(0.55), radius: 18, y: 8)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("ARTIST")
                                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                    .tracking(1.4)
                                    .foregroundStyle(EchoTheme.neoMint)

                                Text(artist.name)
                                    .font(.system(size: 36, weight: .black, design: .rounded))
                                    .foregroundStyle(EchoTheme.textPrimary)

                                HStack(spacing: 8) {
                                    Text("\(artist.albums.count) albums · \(artist.tracks.count) tracks · \(Formatters.bytes(artist.totalSize))")
                                        .foregroundStyle(EchoTheme.textSecondary)
                                    if totalPlays > 0 {
                                        Text("· \(totalPlays) plays")
                                            .foregroundStyle(EchoTheme.neoMint)
                                            .fontWeight(.semibold)
                                    }
                                    if let onlineFans, onlineFans > 0 {
                                        Text("· \(Formatters.compactCount(onlineFans)) online fans")
                                            .foregroundStyle(EchoTheme.neoCyan)
                                            .fontWeight(.semibold)
                                    }
                                    if let avgPop {
                                        Text("· Avg pop \(avgPop)/100")
                                            .foregroundStyle(EchoTheme.hiResGold)
                                            .fontWeight(.semibold)
                                    }
                                }
                                .font(.system(size: 12.5))

                                HStack(spacing: 10) {
                                    NeoPrimaryButton(title: "Play All", icon: "play.fill") {
                                        store.player.play(tracks: artist.tracks, startingAt: 0)
                                    }
                                    SyncStatePillButton(state: state, label: "Sync Entire Artist") {
                                        store.toggleArtistSync(artist)
                                    }
                                    Button {
                                        store.ensurePopularityLoaded(forArtist: artist, force: true)
                                    } label: {
                                        Group {
                                            if isFetchingPop {
                                                ProgressView()
                                                    .controlSize(.small)
                                                    .frame(width: 30, height: 30)
                                            } else {
                                                Image(systemName: "chart.bar.xaxis")
                                                    .font(.system(size: 12.5, weight: .semibold))
                                                    .frame(width: 30, height: 30)
                                            }
                                        }
                                        .background(EchoTheme.surfaceElevated)
                                        .foregroundStyle(EchoTheme.neoCyan)
                                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                                        .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusControl).strokeBorder(EchoTheme.borderStrong, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(isFetchingPop)
                                    .help("Fetch or refresh online popularity scores and fan counts for '\(artist.name)'.")

                                    if store.lidarrConfig.isEnabled {
                                        Button {
                                            store.openLidarrSearch(query: artist.name, mode: .albums)
                                        } label: {
                                            Image(systemName: "arrow.down.to.line.compact")
                                                .font(.system(size: 12.5, weight: .bold))
                                                .frame(width: 30, height: 30)
                                                .background(EchoTheme.surfaceElevated)
                                                .foregroundStyle(EchoTheme.neoMint)
                                                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                                                .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusControl).strokeBorder(EchoTheme.neoMint.opacity(0.45), lineWidth: 1))
                                        }
                                        .buttonStyle(.plain)
                                        .help("Search Lidarr for more albums by '\(artist.name)' to order & download.")
                                    }
                                    if let focused = store.focusedPlaylist {
                                        Button {
                                            store.addTracks(artist.tracks, toPlaylistID: focused.id)
                                        } label: {
                                            Image(systemName: "plus")
                                                .font(.system(size: 13, weight: .black))
                                                .frame(width: 30, height: 30)
                                                .background(EchoTheme.neoCyan.opacity(0.18))
                                                .foregroundStyle(EchoTheme.neoCyan)
                                                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                                                .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusControl).strokeBorder(EchoTheme.neoCyan.opacity(0.45), lineWidth: 1))
                                        }
                                        .buttonStyle(.plain)
                                        .help("Add all tracks by '\(artist.name)' to focused playlist '\(focused.name)'.")
                                    }
                                    if !store.playlists.isEmpty {
                                        NeoIconMenuButton(icon: "text.badge.plus", accent: EchoTheme.neoMint, size: 30) {
                                            store.playlists.map { pl in
                                                .action(title: pl.name, icon: "music.note.list") {
                                                    store.addTracks(artist.tracks, toPlaylistID: pl.id)
                                                }
                                            }
                                        }
                                        .fixedSize()
                                        .help("Choose any playlist to add all tracks by '\(artist.name)'.")
                                    }
                                }
                                .padding(.top, 4)
                            }
                            .layoutPriority(1)

                            Spacer(minLength: 16)

                            ViewThatFits(in: .horizontal) {
                                ArtistHeroEditorialPanel(artist: artist)
                                EmptyView()
                            }
                        }
                        .padding(26)
                    }
                    .task(id: artist.id) {
                        store.ensureEditorialLoaded(forArtist: artist)
                    }

                    // Spotify-style Popular Tracks for this Artist
                    if !popularTracks.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: "chart.bar.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(EchoTheme.neoCyan)
                                Text("Popular")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(EchoTheme.textPrimary)
                            }
                            .padding(.bottom, 2)

                            trackTableHeader(showAlbum: true)
                            Divider().overlay(EchoTheme.border).padding(.bottom, 2)

                            ForEach(Array(popularTracks.enumerated()), id: \.element.id) { idx, track in
                                TrackRowView(track: track, index: idx, showAlbumColumn: true) {
                                    store.player.play(tracks: popularTracks, startingAt: idx)
                                }
                            }
                        }
                        .padding(.horizontal, 26)
                    }

                    // Albums by Artist
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Albums")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(EchoTheme.textPrimary)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 168, maximum: 195), spacing: 16)], spacing: 18) {
                            ForEach(artist.albums) { album in
                                AlbumCardView(album: album)
                            }
                        }
                    }
                    .padding(.horizontal, 26)

                    // All Tracks by Artist (grouped by compact album headers with same height as track rows)
                    let sortedArtistTracks = store.sortTracks(combinedTracks, by: tracksSort)
                    let groupedTrackSections: [(albumKey: String, albumTitle: String, year: Int?, artworkHash: String?, isCollabAlbum: Bool, tracks: [Track])] = {
                        var order: [String] = []
                        var map: [String: [Track]] = [:]
                        for tr in sortedArtistTracks {
                            let resolvedKey = store.albumByTrackID[tr.id]?.id ?? tr.albumKey
                            if map[resolvedKey] == nil {
                                order.append(resolvedKey)
                            }
                            map[resolvedKey, default: []].append(tr)
                        }
                        let ownAlbumKeys = Set(artist.albums.map(\.id))
                        return order.compactMap { key in
                            guard let list = map[key], let first = list.first else { return nil }
                            let albumObj = store.albumsByKey[key]
                            return (
                                albumKey: key,
                                albumTitle: albumObj?.title ?? first.effectiveAlbum,
                                year: albumObj?.year ?? list.compactMap(\.year).first,
                                artworkHash: albumObj?.artworkHash ?? list.first(where: { $0.artworkHash != nil })?.artworkHash,
                                isCollabAlbum: !ownAlbumKeys.contains(key),
                                tracks: list
                            )
                        }
                    }()
                    let flattenedOrderedTracks = groupedTrackSections.flatMap(\.tracks)
                    let flatIndexByID = Dictionary(uniqueKeysWithValues: flattenedOrderedTracks.enumerated().map { ($0.element.id, $0.offset) })

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("All Tracks")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(EchoTheme.textPrimary)
                            if !appearsOnTracks.isEmpty {
                                Text("incl. \(appearsOnTracks.count) collab\(appearsOnTracks.count == 1 ? "" : "s")")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(EchoTheme.neoCyan)
                            }
                        }
                        .padding(.bottom, 4)

                        SortableTrackTableHeader(showAlbum: false, sortState: $tracksSort)
                        Divider().overlay(EchoTheme.border).padding(.bottom, 2)

                        ForEach(groupedTrackSections, id: \.albumKey) { section in
                            CompactAlbumGroupHeaderRow(
                                albumKey: section.albumKey,
                                title: section.albumTitle,
                                year: section.year,
                                artworkHash: section.artworkHash,
                                isCollabAlbum: section.isCollabAlbum,
                                tracks: section.tracks
                            ) {
                                if let first = section.tracks.first, let startIdx = flatIndexByID[first.id] {
                                    store.player.play(tracks: flattenedOrderedTracks, startingAt: startIdx)
                                }
                            }
                            .padding(.top, section.albumKey == groupedTrackSections.first?.albumKey ? 0 : 6)

                            ForEach(Array(section.tracks.enumerated()), id: \.element.id) { localIdx, track in
                                let flatIdx = flatIndexByID[track.id] ?? localIdx
                                TrackRowView(track: track, index: localIdx, showAlbumColumn: false) {
                                    store.player.play(tracks: flattenedOrderedTracks, startingAt: flatIdx)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 26)
                    .padding(.bottom, 28)
                }
            }
            .task(id: artist.id) {
                store.ensurePopularityLoaded(forArtist: artist)
            }
        } else {
            ContentUnavailableView("Artist Not Found", systemImage: "person.slash")
        }
    }
}

/// Compact album group header with the exact same vertical height & alignment as `TrackRowView` (36×36 art, 6pt v-padding).
private struct CompactAlbumGroupHeaderRow: View {
    @Environment(EchoStore.self) private var store
    let albumKey: String
    let title: String
    let year: Int?
    let artworkHash: String?
    let isCollabAlbum: Bool
    let tracks: [Track]
    let onPlayAlbum: () -> Void

    @State private var isHovered = false

    private var totalDuration: TimeInterval {
        tracks.reduce(0) { $0 + $1.duration }
    }

    var body: some View {
        let albumObj = store.albumsByKey[albumKey]
        let syncState: SyncSelectionState = albumObj.map { store.selectionState(forAlbum: $0) } ?? .none

        HStack(spacing: 12) {
            // 26pt leading slot matching TrackRowView's `#` column
            Button(action: onPlayAlbum) {
                Image(systemName: isHovered ? "play.fill" : "opticaldisc.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(isHovered ? EchoTheme.neoMint : EchoTheme.neoCyan)
            }
            .buttonStyle(.plain)
            .frame(width: 26)
            .help("Play tracks from '\(title)'")

            // 36×36 artwork + album title & metadata (same dimensions as TrackRowView)
            Button {
                store.openAlbum(key: albumKey)
            } label: {
                HStack(spacing: 10) {
                    ArtworkView(hash: artworkHash, artworkCache: store.artworkCache, cornerRadius: EchoTheme.radiusSmall, iconSize: 13)
                        .frame(width: 36, height: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(title)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(isHovered ? EchoTheme.neoMint : EchoTheme.textPrimary)
                                .lineLimit(1)

                            if isCollabAlbum {
                                Text("APPEARS ON")
                                    .font(.system(size: 8, weight: .black, design: .monospaced))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1.5)
                                    .background(EchoTheme.neoCyan.opacity(0.16))
                                    .foregroundStyle(EchoTheme.neoCyan)
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            }
                        }

                        Text("\(year.map { "\($0) · " } ?? "")\(tracks.count) track\(tracks.count == 1 ? "" : "s")")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(EchoTheme.textMuted)
                            .lineLimit(1)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(minWidth: 180, maxWidth: .infinity, alignment: .leading)
            .help("Open album '\(title)'")

            // Album Rating aligned with TrackRowView's `RATING` column
            if let albumObj {
                StarRatingControl(
                    rating: store.explicitAlbumRating(for: albumObj) ?? 0,
                    derivedAverage: store.averageTrackRating(for: albumObj),
                    starSize: 9.5,
                    spacing: 1.5,
                    showEmptyWhenUnrated: isHovered,
                    labelPrefix: "Album Rating"
                ) { newRating in
                    store.setAlbumRating(newRating, for: albumObj)
                }
                .frame(width: 68, alignment: .center)
            }

            // Sync toggle aligned with TrackRowView's `S` column
            if let albumObj {
                let isSynced = syncState == .full
                let isPartial = syncState == .partial
                Button {
                    store.toggleAlbumSync(albumObj)
                } label: {
                    Text(isPartial ? "·" : "S")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .frame(width: 24, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: EchoTheme.radiusSmall)
                                .fill(isSynced ? EchoTheme.neoMint.opacity(0.24) : (isPartial ? EchoTheme.neoCyan.opacity(0.18) : EchoTheme.surfaceElevated.opacity(0.55)))
                        )
                        .foregroundStyle(isSynced ? EchoTheme.neoMint : (isPartial ? EchoTheme.neoCyan : EchoTheme.textMuted))
                        .overlay(
                            RoundedRectangle(cornerRadius: EchoTheme.radiusSmall)
                                .strokeBorder(isSynced ? EchoTheme.neoMint.opacity(0.8) : EchoTheme.border, lineWidth: isSynced ? 1.1 : 0.85)
                        )
                }
                .buttonStyle(.plain)
                .frame(width: 30)
                .help("Toggle entire album '\(title)' for sync.")
            }

            // Total duration aligned with TrackRowView's `TIME` column
            Text(Formatters.duration(totalDuration))
                .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(EchoTheme.textSecondary)
                .frame(width: 44, alignment: .trailing)

            // Trailing 24pt spacer matching TrackRowView's ellipsis button column
            Color.clear.frame(width: 24, height: 24)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous)
                .fill(EchoTheme.surfaceElevated.opacity(isHovered ? 0.82 : 0.52))
        )
        .overlay(
            RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous)
                .strokeBorder(isHovered ? EchoTheme.neoCyan.opacity(0.45) : EchoTheme.border, lineWidth: 1)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Albums Grid & Detail

struct AlbumsView: View {
    @Environment(EchoStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    Text("Albums")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(EchoTheme.textPrimary)
                    Text("\(store.filteredAlbums.count)")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(EchoTheme.textMuted)
                    Spacer()

                    if store.isBatchFetchingPopularity, let prog = store.popularityBatchProgress {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("Popularity \(prog.done)/\(prog.total)")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(EchoTheme.neoCyan)
                            Button {
                                store.cancelPopularityBatchFetch()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9.5, weight: .bold))
                                    .foregroundStyle(EchoTheme.textMuted)
                            }
                            .buttonStyle(.plain)
                            .help("Stop scanning online popularity.")
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(EchoTheme.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                    } else {
                        NeoSecondaryButton(title: "Fetch Popularity", icon: "chart.bar.xaxis") {
                            store.batchFetchPopularityForLibrary()
                        }
                        .help("Batch-fetch online popularity scores from Deezer (plus Last.fm if configured) for albums in this library.")
                    }

                    NeoPickerDropdown(
                        prefix: "Sort",
                        icon: "arrow.up.arrow.down",
                        selection: Binding(
                            get: { store.albumSortOrder },
                            set: { store.albumSortOrder = $0 }
                        ),
                        options: AlbumSortOrder.allCases.map { ($0, $0.rawValue) }
                    )
                    .fixedSize()
                    .help("Sort albums alphabetically, by your plays, by online popularity, or by release year.")
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 168, maximum: 198), spacing: 16)], spacing: 18) {
                    ForEach(store.filteredAlbums) { album in
                        let badge: (String, Color)? = {
                            switch store.albumSortOrder {
                            case .newArrivals:
                                let tag = Formatters.relativeArrival(album.latestArrivalDate)
                                return tag.isEmpty ? nil : (tag, EchoTheme.neoMint)
                            case .newReleases:
                                return album.year.map { (String($0), EchoTheme.neoCyan) }
                            default:
                                return nil
                            }
                        }()
                        AlbumCardView(
                            album: album,
                            cornerBadge: badge?.0,
                            cornerBadgeColor: badge?.1 ?? EchoTheme.neoMint
                        )
                    }
                }
            }
            .padding(26)
        }
    }
}

struct AlbumCardView: View {
    @Environment(EchoStore.self) private var store
    let album: AlbumGroup
    var cornerBadge: String? = nil
    var cornerBadgeColor: Color = EchoTheme.neoMint
    @State private var isHovered = false

    var body: some View {
        let state = store.selectionState(forAlbum: album)
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                ArtworkView(hash: album.artworkHash, artworkCache: store.artworkCache, cornerRadius: EchoTheme.radiusCard, iconSize: 34)
                    .aspectRatio(1, contentMode: .fit)
                    .shadow(color: .black.opacity(0.45), radius: 10, y: 4)

                if let cornerBadge {
                    Text(cornerBadge)
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Color.black.opacity(0.76))
                        .foregroundStyle(cornerBadgeColor)
                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                        .overlay(
                            RoundedRectangle(cornerRadius: EchoTheme.radiusSmall)
                                .strokeBorder(cornerBadgeColor.opacity(0.55), lineWidth: 0.9)
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(6)
                }

                if isHovered {
                    Button {
                        store.player.play(tracks: album.tracks, startingAt: 0)
                    } label: {
                        RoundedRectangle(cornerRadius: EchoTheme.radiusControl)
                            .fill(EchoTheme.neoMint.opacity(0.76))
                            .frame(width: 28, height: 28)
                            .overlay(
                                RoundedRectangle(cornerRadius: EchoTheme.radiusControl)
                                    .strokeBorder(Color.white.opacity(0.28), lineWidth: 0.75)
                            )
                            .overlay(Image(systemName: "play.fill").foregroundStyle(.black.opacity(0.9)).font(.system(size: 11, weight: .bold)))
                            .shadow(color: Color.black.opacity(0.35), radius: 5, y: 2)
                    }
                    .buttonStyle(.plain)
                    .padding(6)
                }

                // Top-right P (Playlist) & S (Sync / Subscription) corner pills + overlaid Album Star Rating pill
                let plState = store.focusedPlaylistState(for: album.tracks)
                let plName = store.focusedPlaylist?.name ?? "My Playlist"
                let targetName = store.activeDevice?.name ?? "selected destination"
                let explicitRating = store.explicitAlbumRating(for: album) ?? 0
                let avgTrackRating = store.averageTrackRating(for: album)
                VStack(alignment: .trailing, spacing: 5) {
                    CardPSBadgeStrip(
                        playlistState: plState,
                        syncState: state,
                        isCardHovered: isHovered,
                        playlistTooltip: plState == .full
                            ? "Remove '\(album.title)' from playlist '\(plName)'."
                            : "Add '\(album.title)' to playlist '\(plName)'.",
                        syncTooltip: state == .full
                            ? "Synced to '\(targetName)'. Click to remove '\(album.title)'."
                            : "Include '\(album.title)' in '\(targetName)' sync.",
                        onTogglePlaylist: { store.toggleTracksInFocusedPlaylist(album.tracks, label: album.title) },
                        onToggleSync: { store.toggleAlbumSync(album) }
                    )

                    if explicitRating > 0 || avgTrackRating != nil || isHovered {
                        HStack(spacing: 3) {
                            StarRatingControl(
                                rating: explicitRating,
                                derivedAverage: avgTrackRating,
                                starSize: 9,
                                spacing: 1.5,
                                showEmptyWhenUnrated: true,
                                labelPrefix: "Album Rating"
                            ) { newRating in
                                store.setAlbumRating(newRating, for: album)
                            }
                            if explicitRating == 0, let avg = avgTrackRating {
                                Text(String(format: "%.1f", avg))
                                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                    .foregroundStyle(EchoTheme.textSecondary)
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.76))
                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: EchoTheme.radiusSmall, style: .continuous)
                                .strokeBorder(
                                    explicitRating > 0 ? EchoTheme.hiResGold.opacity(0.55) : Color.white.opacity(0.20),
                                    lineWidth: 0.9
                                )
                        )
                        .shadow(color: Color.black.opacity(0.45), radius: 4, y: 1)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(6)
            }

            VStack(alignment: .leading, spacing: 3) {
                HoverLinkText(
                    text: album.title,
                    font: .system(size: 13.5, weight: .bold),
                    color: EchoTheme.textPrimary,
                    hoverColor: EchoTheme.neoMint,
                    tip: "Open album '\(album.title)'"
                ) {
                    store.openAlbum(key: album.id)
                }
                ArtistLinksView(
                    rawArtists: album.artist,
                    font: .system(size: 11.5),
                    color: EchoTheme.textSecondary,
                    hoverColor: EchoTheme.neoCyan
                ) { artistName in
                    store.openArtist(name: artistName)
                }
                HStack(spacing: 6) {
                    let albumPlays = store.totalUserPlays(for: album)
                    let albumPop = store.averageOnlinePopularity(for: album)
                    if let year = album.year {
                        Text(String(year))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(EchoTheme.textMuted)
                    }
                    Text("\(album.tracks.count) tracks")
                        .font(.system(size: 10))
                        .foregroundStyle(EchoTheme.textMuted)
                    Spacer(minLength: 2)
                    if albumPlays > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 7.5))
                            Text(Formatters.compactCount(albumPlays))
                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        }
                        .foregroundStyle(EchoTheme.neoMint)
                        .help("Total user plays across tracks in '\(album.title)': \(albumPlays)")
                    }
                    if let albumPop {
                        HStack(spacing: 2) {
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 7.5))
                            Text("\(albumPop)")
                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        }
                        .foregroundStyle(EchoTheme.neoCyan)
                        .help("Average online popularity score for '\(album.title)': \(albumPop)/100")
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous)
                .fill(isHovered ? EchoTheme.surfaceElevated : EchoTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous)
                .strokeBorder(state == .full ? EchoTheme.neoMint.opacity(0.35) : EchoTheme.border, lineWidth: 1)
        )
        .onHover { isHovered = $0 }
        .onTapGesture { store.openAlbum(key: album.id) }
        .contextMenu {
            Button("Play Album") {
                store.player.play(tracks: album.tracks, startingAt: 0)
            }
            Button("Open Album") {
                store.openAlbum(key: album.id)
            }
            Divider()
            Menu("Rate Album") {
                let current = store.explicitAlbumRating(for: album) ?? 0
                ForEach((1...5).reversed(), id: \.self) { stars in
                    let glyphs = String(repeating: "★", count: stars) + String(repeating: "☆", count: 5 - stars)
                    Button {
                        store.setAlbumRating(stars, for: album)
                    } label: {
                        HStack {
                            Text("\(glyphs) (\(stars))")
                            if current == stars { Image(systemName: "checkmark") }
                        }
                    }
                }
                if current > 0 {
                    Divider()
                    Button("Clear Album Rating") {
                        store.setAlbumRating(nil, for: album)
                    }
                }
            }
        }
        .draggable(EchoDragPayload.album(album.id).encode()) {
            DragPreviewPill(
                title: album.title,
                subtitle: album.artist,
                artworkHash: album.artworkHash,
                artworkCache: store.artworkCache,
                badge: "\(album.tracks.count) TRACKS"
            )
        }
    }
}

struct AlbumDetailView: View {
    @Environment(EchoStore.self) private var store
    let albumKey: String
    @State private var tracksSort = TrackTableSortState()

    var body: some View {
        if let album = store.albumsByKey[albumKey] {
            let glow = ArtworkImageLoader.shared.dominantColor(forHash: album.artworkHash, artworkCache: store.artworkCache)
            let state = store.selectionState(forAlbum: album)
            let albumPlays = store.totalUserPlays(for: album)
            let avgPop = store.averageOnlinePopularity(for: album)
            let isFetchingPop = store.fetchingPopularityKeys.contains("album:\(album.id)")
            let samplePath: String? = {
                guard let first = album.tracks.first, let dev = store.activeDevice else { return nil }
                return PathFormatter.relativeTrackPath(for: first, profile: dev, albumArtistOverride: album.artist)
            }()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ZStack(alignment: .bottomLeading) {
                        LinearGradient(
                            colors: [glow.opacity(0.6), EchoTheme.canvas],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 235)

                        HStack(alignment: .bottom, spacing: 22) {
                            AlbumHeroCoverButton(album: album, artworkCache: store.artworkCache) {
                                store.openAlbumLightbox(album)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("ALBUM")
                                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                    .tracking(1.4)
                                    .foregroundStyle(EchoTheme.neoMint)

                                Text(album.title)
                                    .font(.system(size: 32, weight: .black, design: .rounded))
                                    .foregroundStyle(EchoTheme.textPrimary)
                                    .lineLimit(2)

                                HStack(spacing: 8) {
                                    ArtistLinksView(
                                        rawArtists: album.artist,
                                        font: .system(size: 13.5, weight: .bold),
                                        color: EchoTheme.textPrimary,
                                        hoverColor: EchoTheme.neoMint
                                    ) { artistName in
                                        store.openArtist(name: artistName)
                                    }

                                    if let y = album.year {
                                        Text("· \(String(y))")
                                            .foregroundStyle(EchoTheme.textSecondary)
                                    }
                                    Text("· \(album.tracks.count) songs · \(Formatters.duration(album.totalDuration)) · \(Formatters.bytes(album.totalSize))")
                                        .foregroundStyle(EchoTheme.textSecondary)
                                    if albumPlays > 0 {
                                        Text("· \(albumPlays) plays")
                                            .foregroundStyle(EchoTheme.neoMint)
                                            .fontWeight(.semibold)
                                    }
                                    if let avgPop {
                                        Text("· Pop \(avgPop)/100")
                                            .foregroundStyle(EchoTheme.neoCyan)
                                            .fontWeight(.semibold)
                                    }
                                }
                                .font(.system(size: 12.5))

                                // Interactive 1–5 Star Album Rating Pill
                                HStack(spacing: 8) {
                                    let explicitRating = store.explicitAlbumRating(for: album) ?? 0
                                    let avgTrackRating = store.averageTrackRating(for: album)
                                    StarRatingControl(
                                        rating: explicitRating,
                                        derivedAverage: avgTrackRating,
                                        starSize: 13,
                                        spacing: 3,
                                        showEmptyWhenUnrated: true,
                                        labelPrefix: "Album Rating"
                                    ) { newRating in
                                        store.setAlbumRating(newRating, for: album)
                                    }
                                    if explicitRating > 0 {
                                        Text("\(explicitRating)/5")
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundStyle(EchoTheme.hiResGold)
                                    } else if let avgTrackRating {
                                        Text(String(format: "Tracks avg %.1f★", avgTrackRating))
                                            .font(.system(size: 10.5, design: .monospaced))
                                            .foregroundStyle(EchoTheme.textSecondary)
                                    } else {
                                        Text("Rate album")
                                            .font(.system(size: 11))
                                            .foregroundStyle(EchoTheme.textMuted)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4.5)
                                .background(Color.black.opacity(0.32))
                                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                                .overlay(
                                    RoundedRectangle(cornerRadius: EchoTheme.radiusSmall)
                                        .strokeBorder(
                                            (store.explicitAlbumRating(for: album) ?? 0) > 0
                                                ? EchoTheme.hiResGold.opacity(0.45)
                                                : EchoTheme.border,
                                            lineWidth: 1
                                        )
                                )

                                if let samplePath {
                                    HStack(spacing: 6) {
                                        Image(systemName: "folder.fill")
                                            .font(.system(size: 10))
                                            .foregroundStyle(EchoTheme.neoCyan)
                                        Text("Device path: \(samplePath)")
                                            .font(.system(size: 10.5, design: .monospaced))
                                            .foregroundStyle(EchoTheme.textSecondary)
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.32))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }

                                HStack(spacing: 10) {
                                    NeoPrimaryButton(title: "Play Album", icon: "play.fill") {
                                        store.player.play(tracks: album.tracks, startingAt: 0)
                                    }
                                    SyncStatePillButton(state: state, label: "Sync Entire Album") {
                                        store.toggleAlbumSync(album)
                                    }
                                    Button {
                                        store.ensurePopularityLoaded(forAlbum: album, force: true)
                                    } label: {
                                        Group {
                                            if isFetchingPop {
                                                ProgressView()
                                                    .controlSize(.small)
                                                    .frame(width: 30, height: 30)
                                            } else {
                                                Image(systemName: "chart.bar.xaxis")
                                                    .font(.system(size: 12.5, weight: .semibold))
                                                    .frame(width: 30, height: 30)
                                            }
                                        }
                                        .background(EchoTheme.surfaceElevated)
                                        .foregroundStyle(EchoTheme.neoCyan)
                                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                                        .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusControl).strokeBorder(EchoTheme.borderStrong, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(isFetchingPop)
                                    .help("Fetch or refresh online popularity scores for all tracks on '\(album.title)'.")
                                    if let focused = store.focusedPlaylist {
                                        Button {
                                            store.addTracks(album.tracks, toPlaylistID: focused.id)
                                        } label: {
                                            Image(systemName: "plus")
                                                .font(.system(size: 13, weight: .black))
                                                .frame(width: 30, height: 30)
                                                .background(EchoTheme.neoCyan.opacity(0.18))
                                                .foregroundStyle(EchoTheme.neoCyan)
                                                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                                                .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusControl).strokeBorder(EchoTheme.neoCyan.opacity(0.45), lineWidth: 1))
                                        }
                                        .buttonStyle(.plain)
                                        .help("Add entire album '\(album.title)' to focused playlist '\(focused.name)'.")
                                    }
                                    if !store.playlists.isEmpty {
                                        NeoIconMenuButton(icon: "text.badge.plus", accent: EchoTheme.neoMint, size: 30) {
                                            store.playlists.map { pl in
                                                .action(title: pl.name, icon: "music.note.list") {
                                                    store.addTracks(album.tracks, toPlaylistID: pl.id)
                                                }
                                            }
                                        }
                                        .fixedSize()
                                        .help("Choose any playlist to add entire album '\(album.title)'.")
                                    }
                                }
                                .padding(.top, 4)
                            }
                            .layoutPriority(1)

                            Spacer(minLength: 16)

                            ViewThatFits(in: .horizontal) {
                                AlbumHeroEditorialPanel(album: album)
                                EmptyView()
                            }
                        }
                        .padding(26)
                    }
                    .task(id: album.id) {
                        store.ensureEditorialLoaded(forAlbum: album)
                    }

                    // Tracklist
                    let sortedAlbumTracks = store.sortTracks(album.tracks, by: tracksSort)
                    VStack(spacing: 2) {
                        SortableTrackTableHeader(showAlbum: false, sortState: $tracksSort)
                        Divider().overlay(EchoTheme.border).padding(.bottom, 4)

                        ForEach(Array(sortedAlbumTracks.enumerated()), id: \.element.id) { idx, track in
                            TrackRowView(track: track, index: idx, showAlbumColumn: false) {
                                store.player.play(tracks: sortedAlbumTracks, startingAt: idx)
                            }
                        }
                    }
                    .padding(.horizontal, 26)
                    .padding(.bottom, 28)
                }
            }
            .task(id: album.id) {
                store.ensurePopularityLoaded(forAlbum: album)
            }
        } else {
            ContentUnavailableView("Album Not Found", systemImage: "opticaldisc")
        }
    }
}

// MARK: - Tracks View

struct TracksView: View {
    @Environment(EchoStore.self) private var store

    var body: some View {
        let items = store.filteredTracks
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Text("All Tracks")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(EchoTheme.textPrimary)
                Text("\(items.count)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(EchoTheme.textMuted)
                Spacer()

                if store.isBatchFetchingPopularity, let prog = store.popularityBatchProgress {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Popularity \(prog.done)/\(prog.total)")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(EchoTheme.neoCyan)
                        Button {
                            store.cancelPopularityBatchFetch()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundStyle(EchoTheme.textMuted)
                        }
                        .buttonStyle(.plain)
                        .help("Stop scanning online popularity.")
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(EchoTheme.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                } else {
                    NeoSecondaryButton(title: "Fetch Popularity", icon: "chart.bar.xaxis") {
                        store.batchFetchPopularityForLibrary()
                    }
                    .help("Batch-fetch online popularity scores from Deezer (plus Last.fm if configured) for albums in this library.")
                }

                NeoPickerDropdown(
                    prefix: "Sort",
                    icon: "arrow.up.arrow.down",
                    selection: Binding(
                        get: { store.trackSortOrder },
                        set: { newOrder in
                            store.trackTableColumn = nil
                            store.trackSortOrder = newOrder
                            switch newOrder {
                            case .highestRated, .mostPlayed, .onlinePopularity, .recentlyPlayed, .newArrivals:
                                store.trackSortAscending = false
                            case .library, .title, .artist:
                                store.trackSortAscending = true
                            }
                        }
                    ),
                    options: TrackSortOrder.allCases.map { ($0, $0.rawValue) }
                )
                .fixedSize()
                .help("Sort tracks by library order, your most played, online popularity, recently played, title, or artist.")

                if !items.isEmpty {
                    NeoPrimaryButton(title: "Play All", icon: "play.fill") {
                        store.player.play(tracks: items, startingAt: 0)
                    }
                }
            }
            .padding(.horizontal, 26)
            .padding(.top, 22)
            .padding(.bottom, 14)

            SortableTrackTableHeader(
                showAlbum: true,
                sortState: Binding(
                    get: { store.tracksViewSortState },
                    set: { store.tracksViewSortState = $0 }
                )
            )
            .padding(.horizontal, 26)
            Divider().overlay(EchoTheme.border).padding(.horizontal, 26)

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { idx, track in
                        TrackRowView(track: track, index: idx, showAlbumColumn: true) {
                            store.player.play(tracks: items, startingAt: idx)
                        }
                    }
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 8)
            }
        }
    }
}

// MARK: - Playlist Detail View

struct PlaylistDetailView: View {
    @Environment(EchoStore.self) private var store
    let playlistID: UUID

    @State private var isEditing = false
    @State private var editName = ""
    @State private var editDesc = ""
    @State private var isDropTargeted = false
    @State private var tracksSort = TrackTableSortState()
    @State private var selectedRowIndex: Int? = nil
    @FocusState private var focusedRowIndex: Int?

    var body: some View {
        if let playlist = store.playlists.first(where: { $0.id == playlistID }) {
            let playlistTracks = store.tracks(for: playlist)
            let isPartyLocked = store.isPartyLockedPlaylist(playlist)
            let partyCurrentTrack = isPartyLocked ? store.player.currentTrack : nil
            let heroArtHash = partyCurrentTrack?.artworkHash ?? playlistTracks.first?.artworkHash
            let isSynced = store.isPlaylistSelected(playlist)
            let isFocused = store.focusedPlaylist?.id == playlist.id
            let totalDuration = playlistTracks.reduce(0) { $0 + $1.duration }
            let totalBytes = playlistTracks.reduce(Int64(0)) { $0 + $1.fileSize }
            let glow = ArtworkImageLoader.shared.dominantColor(forHash: heroArtHash, artworkCache: store.artworkCache)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ZStack(alignment: .bottomLeading) {
                        LinearGradient(
                            colors: [glow.opacity(0.55), EchoTheme.canvas],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 250)

                        HStack(alignment: .bottom, spacing: 22) {
                            Group {
                                if isPartyLocked, let playing = partyCurrentTrack {
                                    ArtworkView(hash: playing.artworkHash, artworkCache: store.artworkCache, cornerRadius: EchoTheme.radiusCard, iconSize: 36)
                                } else {
                                    PlaylistMosaicArtwork(tracks: playlistTracks, artworkCache: store.artworkCache, cornerRadius: EchoTheme.radiusCard)
                                }
                            }
                            .frame(width: 170, height: 170)
                            .shadow(color: .black.opacity(0.55), radius: 18, y: 8)
                            .draggable(EchoDragPayload.playlist(playlist.id).encode()) {
                                DragPreviewPill(
                                    title: playlist.name,
                                    subtitle: "Playlist",
                                    artworkHash: heroArtHash,
                                    artworkCache: store.artworkCache,
                                    badge: "\(playlistTracks.count) TRACKS"
                                )
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Text("PLAYLIST")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .tracking(1.4)
                                        .foregroundStyle(EchoTheme.neoMint)

                                    if isPartyLocked {
                                        Button {
                                            store.navigate(to: .partyMode)
                                        } label: {
                                            Label(
                                                store.partyServerPort > 0
                                                    ? "PARTY MODE LOCKED · :\(String(store.partyServerPort))"
                                                    : "PARTY MODE LOCKED",
                                                systemImage: "lock.fill"
                                            )
                                            .font(.system(size: 9, weight: .black, design: .monospaced))
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 2.5)
                                            .background(EchoTheme.neoMagenta.opacity(0.22))
                                            .foregroundStyle(EchoTheme.neoMagenta)
                                            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                                        }
                                        .buttonStyle(.plain)
                                        .help("Open Party Mode control center (QR code, guests, chat & port settings).")
                                    } else if isFocused {
                                        Label("ACTIVE + TARGET", systemImage: "pin.fill")
                                            .font(.system(size: 9, weight: .black, design: .monospaced))
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 2.5)
                                            .background(EchoTheme.neoCyan.opacity(0.22))
                                            .foregroundStyle(EchoTheme.neoCyan)
                                            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                                    }
                                }

                                if isEditing {
                                    TextField("Playlist Name", text: $editName)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(maxWidth: 320)
                                    TextField("Description", text: $editDesc)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(maxWidth: 420)
                                    HStack {
                                        Button("Save") {
                                            var updated = playlist
                                            updated.name = editName.trimmingCharacters(in: .whitespaces).isEmpty ? playlist.name : editName
                                            updated.description = editDesc
                                            store.updatePlaylist(updated)
                                            isEditing = false
                                        }
                                        .buttonStyle(.borderedProminent)
                                        Button("Cancel") { isEditing = false }
                                    }
                                } else {
                                    Text(playlist.name)
                                        .font(.system(size: 34, weight: .black, design: .rounded))
                                        .foregroundStyle(EchoTheme.textPrimary)

                                    if isPartyLocked, let playing = partyCurrentTrack {
                                        HStack(spacing: 6) {
                                            Image(systemName: store.player.isPlaying ? "waveform" : "pause.fill")
                                                .font(.system(size: 10.5, weight: .bold))
                                                .foregroundStyle(EchoTheme.neoMint)
                                            Text("Now Playing: \(playing.title) — \(playing.artist.isEmpty ? playing.effectiveArtist : playing.artist)")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundStyle(EchoTheme.neoMint)
                                                .lineLimit(1)
                                        }
                                    } else if !playlist.description.isEmpty {
                                        Text(playlist.description)
                                            .font(.system(size: 13))
                                            .foregroundStyle(EchoTheme.textSecondary)
                                    }

                                    Text("\(playlistTracks.count) tracks · \(Formatters.duration(totalDuration)) · \(Formatters.bytes(totalBytes))")
                                        .font(.system(size: 12.5))
                                        .foregroundStyle(EchoTheme.textSecondary)

                                    if let dev = store.activeDevice, !store.isPartyPlaylist(playlist) {
                                        let m3uPath = PathFormatter.relativePlaylistPath(for: playlist, profile: dev)
                                        HStack(spacing: 10) {
                                            Toggle(isOn: Binding(
                                                get: { isSynced },
                                                set: { _ in store.togglePlaylistSync(playlist) }
                                            )) {
                                                HStack(spacing: 6) {
                                                    Image(systemName: isSynced ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                                                        .foregroundStyle(isSynced ? EchoTheme.neoMint : EchoTheme.textMuted)
                                                    Text(isSynced
                                                         ? "Included in \(dev.name) Sync (\(m3uPath))"
                                                         : "Include in \(dev.name) Sync")
                                                        .font(.system(size: 11.5, weight: .semibold))
                                                        .foregroundStyle(isSynced ? EchoTheme.neoMint : EchoTheme.textSecondary)
                                                }
                                            }
                                            .toggleStyle(.switch)
                                            .controlSize(.small)
                                            .tint(EchoTheme.neoMint)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(isSynced ? EchoTheme.neoMint.opacity(0.12) : Color.black.opacity(0.32))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .strokeBorder(isSynced ? EchoTheme.neoMint.opacity(0.45) : EchoTheme.border, lineWidth: 1)
                                        )
                                    }
                                }

                                HStack(spacing: 8) {
                                    NeoPrimaryButton(title: "Play", icon: "play.fill", disabled: playlistTracks.isEmpty) {
                                        if store.isPartyLockedPlaylist(playlist) {
                                            store.playPartyModeTrack(at: 0)
                                        } else {
                                            store.player.play(tracks: playlistTracks, startingAt: 0)
                                        }
                                    }
                                    .help("Play all tracks in '\(playlist.name)'.")

                                    if !isFocused {
                                        Button {
                                            store.setFocusedPlaylist(playlist.id)
                                            store.showToast("Set '\(playlist.name)' as quick-add (+) target")
                                        } label: {
                                            Image(systemName: "pin")
                                                .font(.system(size: 12.5, weight: .semibold))
                                                .frame(width: 30, height: 30)
                                                .background(EchoTheme.neoCyan.opacity(0.16))
                                                .foregroundStyle(EchoTheme.neoCyan)
                                                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                                        }
                                        .buttonStyle(.plain)
                                        .help("Pin '\(playlist.name)' as the focused playlist targeted by + buttons on songs.")
                                    }

                                    Button {
                                        editName = playlist.name
                                        editDesc = playlist.description
                                        isEditing = true
                                    } label: {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 12.5, weight: .semibold))
                                            .frame(width: 30, height: 30)
                                            .background(EchoTheme.surfaceElevated)
                                            .foregroundStyle(EchoTheme.textPrimary)
                                            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Rename '\(playlist.name)' or edit its description.")

                                    Button(role: .destructive) {
                                        store.deletePlaylist(playlist)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 12))
                                            .frame(width: 30, height: 30)
                                            .background(EchoTheme.dangerCoral.opacity(0.16))
                                            .foregroundStyle(EchoTheme.dangerCoral)
                                            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Delete playlist '\(playlist.name)' permanently.")
                                }
                                .padding(.top, 4)
                            }
                            Spacer(minLength: 16)

                            // Persistent Guest Address + Port + QR Code card on the right specifically for Partymode
                            if isPartyLocked, let urlStr = store.partyServerURLString {
                                HStack(spacing: 12) {
                                    VStack(alignment: .trailing, spacing: 6) {
                                        HStack(spacing: 5) {
                                            Circle()
                                                .fill(EchoTheme.neoMint)
                                                .frame(width: 6.5, height: 6.5)
                                                .shadow(color: EchoTheme.neoMint, radius: 4)
                                            Text("GUEST WEB JUKEBOX")
                                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                                .tracking(1.1)
                                                .foregroundStyle(EchoTheme.neoCyan)
                                        }

                                        Text(urlStr)
                                            .font(.system(size: 14, weight: .black, design: .monospaced))
                                            .foregroundStyle(EchoTheme.neoMint)
                                            .textSelection(.enabled)
                                            .lineLimit(1)

                                        HStack(spacing: 6) {
                                            Button {
                                                NSPasteboard.general.clearContents()
                                                NSPasteboard.general.setString(urlStr, forType: .string)
                                                store.showToast("Copied \(urlStr)")
                                            } label: {
                                                HStack(spacing: 3) {
                                                    Image(systemName: "doc.on.doc")
                                                    Text("Copy")
                                                }
                                                .font(.system(size: 10, weight: .bold))
                                                .padding(.horizontal, 7)
                                                .padding(.vertical, 4)
                                                .background(EchoTheme.neoMint.opacity(0.16))
                                                .foregroundStyle(EchoTheme.neoMint)
                                                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                                                .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall).strokeBorder(EchoTheme.neoMint.opacity(0.5), lineWidth: 1))
                                            }
                                            .buttonStyle(.plain)

                                            if let shareURL = URL(string: urlStr) {
                                                NeoShareButton(
                                                    items: [shareURL],
                                                    title: "Share",
                                                    accent: EchoTheme.neoMint,
                                                    fontSize: 10,
                                                    horizontalPadding: 7,
                                                    verticalPadding: 4,
                                                    helpText: "Share Guest Web Jukebox link via AirDrop, Messages, Mail, or other apps."
                                                )
                                            }

                                            Button {
                                                store.navigate(to: .partyMode)
                                            } label: {
                                                HStack(spacing: 3) {
                                                    Image(systemName: "slider.horizontal.3")
                                                    Text("Party Controls")
                                                }
                                                .font(.system(size: 10, weight: .bold))
                                                .padding(.horizontal, 7)
                                                .padding(.vertical, 4)
                                                .background(EchoTheme.neoCyan.opacity(0.15))
                                                .foregroundStyle(EchoTheme.neoCyan)
                                                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                                                .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall).strokeBorder(EchoTheme.neoCyan.opacity(0.45), lineWidth: 1))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }

                                    if let qr = PartyQRCodeGenerator.makeImage(from: urlStr) {
                                        Image(nsImage: qr)
                                            .interpolation(.none)
                                            .resizable()
                                            .scaledToFit()
                                            .padding(10)
                                            .frame(width: 170, height: 170)
                                            .background(Color.white)
                                            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: EchoTheme.radiusCard)
                                                    .strokeBorder(EchoTheme.neoMint.opacity(0.65), lineWidth: 1.5)
                                            )
                                            .shadow(color: .black.opacity(0.45), radius: 14, y: 6)
                                            .help("Scan to open \(urlStr) on a phone.")
                                    }
                                }
                                .padding(12)
                                .background(Color.black.opacity(0.45))
                                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard))
                                .overlay(
                                    RoundedRectangle(cornerRadius: EchoTheme.radiusCard)
                                        .strokeBorder(EchoTheme.neoMint.opacity(0.38), lineWidth: 1)
                                )
                            }
                        }
                        .padding(26)
                    }

                    if playlistTracks.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: isDropTargeted ? "tray.and.arrow.down.fill" : "music.note.list")
                                .font(.system(size: 36))
                                .foregroundStyle(isDropTargeted ? EchoTheme.neoMint : EchoTheme.textMuted)
                            Text(isDropTargeted ? "Drop to add tracks to '\(playlist.name)'" : "This playlist is empty")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(isDropTargeted ? EchoTheme.neoMint : EchoTheme.textPrimary)
                            Text("Drag & drop songs, albums, or artists here (or onto '\(playlist.name)' in the sidebar), or click the + button on any track.")
                                .font(.system(size: 12.5))
                                .foregroundStyle(EchoTheme.textSecondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 460)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(44)
                        .background(isDropTargeted ? EchoTheme.neoMint.opacity(0.12) : EchoTheme.surface.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous)
                                .strokeBorder(isDropTargeted ? EchoTheme.neoMint : EchoTheme.border, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                        )
                        .padding(.horizontal, 26)
                    } else {
                        let isCustomOrder = tracksSort.column == .index && tracksSort.ascending
                        let indexedSource: [(originalIndex: Int, track: Track)] = playlist.trackIDs.enumerated().compactMap { offset, tid in
                            guard let t = store.tracksByID[tid] else { return nil }
                            return (offset, t)
                        }
                        let displayedEntries: [(originalIndex: Int, track: Track)] = {
                            if isCustomOrder { return indexedSource }
                            let sorted = store.sortTracks(indexedSource.map(\.track), by: tracksSort)
                            var buckets: [String: [Int]] = [:]
                            for entry in indexedSource {
                                buckets[entry.track.id, default: []].append(entry.originalIndex)
                            }
                            var cursor: [String: Int] = [:]
                            return sorted.compactMap { track in
                                let pos = cursor[track.id, default: 0]
                                guard let indices = buckets[track.id], pos < indices.count else { return nil }
                                cursor[track.id] = pos + 1
                                return (indices[pos], track)
                            }
                        }()
                        let displayedTracks = displayedEntries.map(\.track)

                        VStack(spacing: 2) {
                            SortableTrackTableHeader(showAlbum: true, isPlaylist: true, sortState: $tracksSort)
                            Divider().overlay(EchoTheme.border).padding(.bottom, 4)

                            let isPartymodePlaylist = isPartyLocked || playlist.name.caseInsensitiveCompare(EchoStore.partyPlaylistName) == .orderedSame
                            ForEach(Array(displayedEntries.enumerated()), id: \.offset) { idx, entry in
                                TrackRowView(
                                    track: entry.track,
                                    index: idx,
                                    showAlbumColumn: true,
                                    playlistContext: (playlist.id, entry.originalIndex),
                                    allowPlaylistReorder: isCustomOrder,
                                    isSelected: selectedRowIndex == idx || focusedRowIndex == idx,
                                    partyRequester: isPartymodePlaylist ? store.partyRequesterName(for: entry.track.id) : nil,
                                    partyVoiceIntroDuration: isPartymodePlaylist ? store.partyVoiceIntrosByTrackID[entry.track.id]?.duration : nil,
                                    onRemovePartyVoiceIntro: isPartymodePlaylist ? {
                                        store.deletePartyVoiceIntro(trackID: entry.track.id, fromHost: true)
                                    } : nil,
                                    onSelect: {
                                        selectedRowIndex = idx
                                        focusedRowIndex = idx
                                    }
                                ) {
                                    if store.isPartyLockedPlaylist(playlist) && isCustomOrder {
                                        store.playPartyModeTrack(at: idx)
                                    } else {
                                        store.player.play(tracks: displayedTracks, startingAt: idx)
                                    }
                                }
                                .focusable()
                                .focusEffectDisabled()
                                .focused($focusedRowIndex, equals: idx)
                            }
                        }
                        .padding(.horizontal, 26)
                        .padding(.bottom, 28)
                        .background(
                            WindowKeyDownMonitor { event in
                                guard !isEditing, store.lightboxAlbum == nil else { return false }
                                switch event.keyCode {
                                case 51, 117: // Delete (Backspace) or Forward Delete
                                    guard let targetIdx = selectedRowIndex ?? focusedRowIndex,
                                          targetIdx >= 0 && targetIdx < displayedEntries.count else {
                                        return false
                                    }
                                    let origIdx = displayedEntries[targetIdx].originalIndex
                                    store.removeTrack(at: origIdx, fromPlaylistID: playlist.id)
                                    let remaining = displayedEntries.count - 1
                                    let nextSel: Int? = remaining > 0 ? min(targetIdx, remaining - 1) : nil
                                    selectedRowIndex = nextSel
                                    focusedRowIndex = nextSel
                                    return true
                                case 125: // Down arrow
                                    guard !displayedEntries.isEmpty, let cur = selectedRowIndex ?? focusedRowIndex else { return false }
                                    let next = min(displayedEntries.count - 1, cur + 1)
                                    selectedRowIndex = next
                                    focusedRowIndex = next
                                    return true
                                case 126: // Up arrow
                                    guard !displayedEntries.isEmpty, let cur = selectedRowIndex ?? focusedRowIndex else { return false }
                                    let prev = max(0, cur - 1)
                                    selectedRowIndex = prev
                                    focusedRowIndex = prev
                                    return true
                                case 36, 76: // Return / Enter
                                    guard let targetIdx = selectedRowIndex ?? focusedRowIndex,
                                          targetIdx >= 0 && targetIdx < displayedEntries.count else {
                                        return false
                                    }
                                    if store.isPartyLockedPlaylist(playlist) && isCustomOrder {
                                        store.playPartyModeTrack(at: targetIdx)
                                    } else {
                                        store.player.play(tracks: displayedTracks, startingAt: targetIdx)
                                    }
                                    return true
                                case 53: // Escape
                                    guard selectedRowIndex != nil || focusedRowIndex != nil else { return false }
                                    selectedRowIndex = nil
                                    focusedRowIndex = nil
                                    return true
                                default:
                                    return false
                                }
                            }
                        )
                    }
                }
            }
            .onChange(of: playlistID) { _, _ in
                selectedRowIndex = nil
                focusedRowIndex = nil
            }
            .onChange(of: tracksSort) { _, _ in
                selectedRowIndex = nil
                focusedRowIndex = nil
            }
            .overlay(
                RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous)
                    .strokeBorder(isDropTargeted ? EchoTheme.neoMint : Color.clear, lineWidth: 2)
                    .padding(6)
                    .allowsHitTesting(false)
            )
            .dropDestination(for: String.self) { items, _ in
                store.handleDropOntoPlaylist(items: items, playlistID: playlist.id)
            } isTargeted: { targeted in
                isDropTargeted = targeted
            }
        } else {
            ContentUnavailableView("Playlist Not Found", systemImage: "music.note.list")
        }
    }
}

// MARK: - Library Sources & NAS View

struct SourcesView: View {
    @Environment(EchoStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Library Sources & NAS")
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(EchoTheme.textPrimary)
                        Text("Index local music folders, external drives, or mounted SMB/NFS NAS shares. Offline NAS sources preserve your playlists and sync selections.")
                            .font(.system(size: 12.5))
                            .foregroundStyle(EchoTheme.textSecondary)
                    }
                    Spacer()

                    HStack(spacing: 10) {
                        NeoPickerDropdown(
                            prefix: "Auto-Scan",
                            icon: "clock.arrow.2.circlepath",
                            selection: Binding(
                                get: { store.autoIndexInterval },
                                set: { store.setAutoIndexInterval($0) }
                            ),
                            options: AutoIndexInterval.allCases.map { ($0, $0.displayName) }
                        )
                        .fixedSize()
                        .help("Automatically re-scan online library folders and NAS shares on a schedule. Silent unless new tracks are found.")

                        NeoSecondaryButton(
                            title: "Re-Index All",
                            icon: "arrow.clockwise",
                            disabled: store.isIndexing || store.sources.isEmpty
                        ) {
                            store.indexAllSources()
                        }

                        NeoPrimaryButton(title: "Add Folder / NAS", icon: "folder.badge.plus") {
                            store.addLibrarySourceViaPanel()
                        }
                    }
                }

                if store.sources.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "externaldrive.badge.plus")
                            .font(.system(size: 40))
                            .foregroundStyle(EchoTheme.neoMint)
                        Text("No library folders added yet")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(EchoTheme.textPrimary)
                        Text("Add your local Music folder or a mounted NAS volume under /Volumes/...")
                            .font(.system(size: 12.5))
                            .foregroundStyle(EchoTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(44)
                    .background(EchoTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard))
                } else {
                    VStack(spacing: 12) {
                        ForEach(store.sources) { source in
                            let online = source.isAvailable
                            HStack(spacing: 16) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: EchoTheme.radiusCard)
                                        .fill(online ? EchoTheme.neoMint.opacity(0.14) : EchoTheme.dangerCoral.opacity(0.14))
                                        .frame(width: 48, height: 48)
                                    Image(systemName: source.isNetworkVolume ? "externaldrive.connected.to.line.below.fill" : "folder.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(online ? EchoTheme.neoMint : EchoTheme.dangerCoral)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 8) {
                                        Text(source.name)
                                            .font(.system(size: 14.5, weight: .bold))
                                            .foregroundStyle(EchoTheme.textPrimary)
                                        Text(online ? "ONLINE" : "OFFLINE")
                                            .font(.system(size: 9, weight: .black, design: .monospaced))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(online ? EchoTheme.neoMint.opacity(0.2) : EchoTheme.dangerCoral.opacity(0.2))
                                            .foregroundStyle(online ? EchoTheme.neoMint : EchoTheme.dangerCoral)
                                            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                                        if source.isNetworkVolume {
                                            Text("NAS / NETWORK")
                                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(EchoTheme.neoCyan.opacity(0.16))
                                                .foregroundStyle(EchoTheme.neoCyan)
                                                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                                        }
                                    }

                                    Text(source.path)
                                        .font(.system(size: 11.5, design: .monospaced))
                                        .foregroundStyle(EchoTheme.textMuted)
                                        .lineLimit(1)

                                    HStack(spacing: 12) {
                                        Text("\(source.trackCount) indexed tracks")
                                            .font(.system(size: 11.5))
                                            .foregroundStyle(EchoTheme.textSecondary)
                                        if let date = source.lastIndexedAt {
                                            Text("Last scanned \(date.formatted(date: .abbreviated, time: .shortened))")
                                                .font(.system(size: 11.5))
                                                .foregroundStyle(EchoTheme.textMuted)
                                        }
                                    }
                                }

                                Spacer()

                                let isScopedHere = store.selectedSourceID == source.id
                                Button {
                                    store.selectLibrarySource(isScopedHere ? nil : source.id)
                                    if !isScopedHere {
                                        store.navigate(to: .albums)
                                    }
                                } label: {
                                    Image(systemName: isScopedHere ? "checkmark.square.fill" : "scope")
                                        .font(.system(size: 12.5, weight: .semibold))
                                        .frame(width: 30, height: 30)
                                        .background(isScopedHere ? EchoTheme.neoCyan.opacity(0.22) : EchoTheme.surfaceElevated)
                                        .foregroundStyle(isScopedHere ? EchoTheme.neoCyan : EchoTheme.textPrimary)
                                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                                        .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusControl).strokeBorder(isScopedHere ? EchoTheme.neoCyan : EchoTheme.border, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .help(isScopedHere
                                      ? "Currently exploring inside '\(source.name)'. Click to return to All Libraries."
                                      : "Focus & stay inside '\(source.name)' while browsing Artists, Albums, Tracks, and using Global Search.")

                                Button {
                                    Task { await store.indexSource(source) }
                                } label: {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 12.5, weight: .semibold))
                                        .frame(width: 30, height: 30)
                                        .background(EchoTheme.surfaceElevated)
                                        .foregroundStyle(EchoTheme.neoMint)
                                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous))
                                        .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous).strokeBorder(EchoTheme.neoMint.opacity(0.45), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .disabled(store.isIndexing)
                                .help("Re-scan '\(source.name)' for newly added, modified, or removed audio files.")

                                Button(role: .destructive) {
                                    store.removeLibrarySource(source)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12.5))
                                        .padding(8)
                                        .background(EchoTheme.dangerCoral.opacity(0.15))
                                        .foregroundStyle(EchoTheme.dangerCoral)
                                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard))
                                }
                                .buttonStyle(.plain)
                                .help("Remove Source")
                            }
                            .padding(16)
                            .background(EchoTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous)
                                    .strokeBorder(EchoTheme.border, lineWidth: 1)
                            )
                        }
                    }
                }
            }
            .padding(26)
        }
    }
}

struct SortableTrackTableHeader: View {
    let showAlbum: Bool
    var isPlaylist: Bool = false
    @Binding var sortState: TrackTableSortState

    var body: some View {
        HStack(spacing: 12) {
            sortableColumn(column: .index, title: "#", width: 26, alignment: .center, tip: "Sort by track order (click again to reverse).")
            sortableColumn(column: .title, title: "TITLE", minWidth: 180, maxWidth: .infinity, alignment: .leading, tip: "Sort by track title A–Z / Z–A.")
            if showAlbum {
                sortableColumn(column: .album, title: "ALBUM", width: 150, alignment: .leading, tip: "Sort by album name.")
            }
            sortableColumn(column: .plays, title: "PLAYS", width: 44, alignment: .trailing, tip: "Sort by your personal play count.")
            sortableColumn(column: .popularity, title: "POP", width: 50, alignment: .trailing, tip: "Sort by online popularity score.")
            sortableColumn(column: .rating, title: "RATING", width: 68, alignment: .center, tip: "Sort by your 1–5 star track rating.")
            sortableColumn(column: .format, title: "FORMAT", width: 86, alignment: .center, tip: "Sort by audio quality (DSD / Hi-Res / Lossless / Bitrate).")
            Text(isPlaylist ? "MOVE" : "P")
                .frame(width: 30)
                .help(isPlaylist ? "Drag handle to reorder tracks in playlist." : "Playlist membership (P): click to toggle track in your focused playlist.")
            sortableColumn(column: .sync, title: "S", width: 30, alignment: .center, tip: "Sync status (S): click column header to sort by synced tracks.")
            sortableColumn(column: .duration, icon: "clock", width: 44, alignment: .trailing, tip: "Sort by track duration.")
            Color.clear.frame(width: 24, height: 1)
        }
        .font(.system(size: 10, weight: .bold, design: .monospaced))
        .foregroundStyle(EchoTheme.textMuted)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func sortableColumn(
        column: TrackTableSortColumn,
        title: String? = nil,
        icon: String? = nil,
        width: CGFloat? = nil,
        minWidth: CGFloat? = nil,
        maxWidth: CGFloat? = nil,
        alignment: Alignment,
        tip: String
    ) -> some View {
        let isActive = sortState.column == column && !(column == .index && sortState.ascending)
        Button {
            sortState.toggle(column)
        } label: {
            HStack(spacing: 3) {
                if alignment == .trailing && isActive {
                    sortArrow
                }
                if let icon {
                    Image(systemName: icon)
                }
                if let title {
                    Text(title)
                }
                if alignment != .trailing && isActive {
                    sortArrow
                }
            }
            .foregroundStyle(isActive ? EchoTheme.neoMint : EchoTheme.textMuted)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(width: width, alignment: alignment)
        .frame(minWidth: minWidth, maxWidth: maxWidth, alignment: alignment)
        .help(tip)
    }

    private var sortArrow: some View {
        Image(systemName: sortState.ascending ? "chevron.up" : "chevron.down")
            .font(.system(size: 7.5, weight: .black))
            .foregroundStyle(EchoTheme.neoMint)
    }
}

@MainActor
private func trackTableHeader(showAlbum: Bool, isPlaylist: Bool = false) -> some View {
    HStack(spacing: 12) {
        Text("#")
            .frame(width: 26)
        Text("TITLE")
            .frame(minWidth: 180, maxWidth: .infinity, alignment: .leading)
        if showAlbum {
            Text("ALBUM")
                .frame(width: 150, alignment: .leading)
        }
        Text("PLAYS")
            .frame(width: 44, alignment: .trailing)
        Text("POP")
            .frame(width: 50, alignment: .trailing)
        Text("RATING")
            .frame(width: 68, alignment: .center)
        Text("FORMAT")
            .frame(width: 86, alignment: .center)
        Text(isPlaylist ? "MOVE" : "P")
            .frame(width: 30)
        Text("S")
            .frame(width: 30)
        Image(systemName: "clock")
            .frame(width: 44, alignment: .trailing)
        Color.clear.frame(width: 24, height: 1)
    }
    .font(.system(size: 10, weight: .bold, design: .monospaced))
    .foregroundStyle(EchoTheme.textMuted)
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .fixedSize(horizontal: false, vertical: true)
}

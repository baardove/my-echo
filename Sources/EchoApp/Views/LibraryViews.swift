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

private enum PlaylistDisplayRow: Identifiable {
    case available(originalIndex: Int, track: Track, playableIndex: Int)
    case missing(originalIndex: Int, item: MissingPlaylistTrack)

    var id: String {
        switch self {
        case .available(let origIdx, let track, _): return "avail:\(origIdx):\(track.id)"
        case .missing(let origIdx, let item): return "miss:\(origIdx):\(item.id)"
        }
    }

    var originalIndex: Int {
        switch self {
        case .available(let origIdx, _, _): return origIdx
        case .missing(let origIdx, _): return origIdx
        }
    }
}

// MARK: - Playlists Grid & Detail

struct PlaylistsView: View {
    @Environment(EchoStore.self) private var store
    @State private var showNewPlaylistSheet = false
    @State private var newPlaylistName = ""
    @State private var newPlaylistDesc = ""
    @State private var isEmptyDropTargeted = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    Text("Playlists")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(EchoTheme.textPrimary)
                    Text("\(store.sortedPlaylists.count)")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(EchoTheme.textMuted)
                    Spacer()

                    if store.echoServerConfig.isConfigured {
                        if let err = store.echoServerError {
                            Button {
                                store.navigate(to: .settings)
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 10.5))
                                    Text("Server Sync Error")
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(EchoTheme.dangerCoral.opacity(0.18))
                                .foregroundStyle(EchoTheme.dangerCoral)
                                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                                .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusControl).strokeBorder(EchoTheme.dangerCoral.opacity(0.45), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .help("\(err) Click to open Settings → My Echo Server.")
                        } else {
                            NeoSecondaryButton(
                                title: store.isSyncingEchoServerState ? "Syncing..." : "Sync Server",
                                icon: "arrow.triangle.2.circlepath",
                                disabled: store.isSyncingEchoServerState
                            ) {
                                Task { await store.syncSharedStateWithEchoServer() }
                            }
                            .help("Sync playlists, ratings, and editorial cache with \(store.echoServerConfig.serverName).")
                        }
                    }

                    NeoSecondaryButton(title: "Import Spotify", icon: "waveform.badge.plus") {
                        store.showSpotifyImportSheet = true
                    }
                    .help("Import a public Spotify playlist by URL (⌘⇧I) — retains missing tracks and supports automatic Lidarr search.")

                    NeoPrimaryButton(title: "New Playlist", icon: "plus") {
                        newPlaylistName = ""
                        newPlaylistDesc = ""
                        showNewPlaylistSheet = true
                    }
                    .help("Create a new playlist to organize tracks, sync to Echo Server / Apple TV, or export to your player.")

                    NeoPickerDropdown(
                        prefix: "Sort",
                        icon: "arrow.up.arrow.down",
                        selection: Binding(
                            get: { store.playlistSortOrder },
                            set: { store.playlistSortOrder = $0 }
                        ),
                        options: PlaylistSortOrder.allCases.map { ($0, $0.rawValue) }
                    )
                    .fixedSize()
                    .help("Sort playlists by recently updated, alphabetically, track count, duration, or creation date.")
                }

                if store.sortedPlaylists.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: isEmptyDropTargeted ? "tray.and.arrow.down.fill" : "music.note.list")
                            .font(.system(size: 38, weight: .semibold))
                            .foregroundStyle(isEmptyDropTargeted ? EchoTheme.neoMint : EchoTheme.neoCyan)

                        Text(isEmptyDropTargeted ? "Drop to Create Playlist" : "No Playlists Yet")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(EchoTheme.textPrimary)

                        Text("Create a playlist, import one from Spotify, or drag any track, album, or artist here to start a collection.")
                            .font(.system(size: 12.5))
                            .foregroundStyle(EchoTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 420)

                        HStack(spacing: 10) {
                            NeoPrimaryButton(title: "New Playlist", icon: "plus") {
                                newPlaylistName = ""
                                newPlaylistDesc = ""
                                showNewPlaylistSheet = true
                            }
                            NeoSecondaryButton(title: "Import Spotify", icon: "waveform.badge.plus") {
                                store.showSpotifyImportSheet = true
                            }
                        }
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 52)
                    .padding(.horizontal, 24)
                    .background(
                        RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous)
                            .fill(isEmptyDropTargeted ? EchoTheme.neoMint.opacity(0.10) : EchoTheme.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous)
                            .strokeBorder(
                                isEmptyDropTargeted ? EchoTheme.neoMint : EchoTheme.border,
                                style: StrokeStyle(lineWidth: isEmptyDropTargeted ? 1.5 : 1, dash: isEmptyDropTargeted ? [6, 4] : [])
                            )
                    )
                    .dropDestination(for: String.self) { items, _ in
                        store.handleDropToCreateNewPlaylist(items: items)
                    } isTargeted: { targeted in
                        isEmptyDropTargeted = targeted
                    }
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 168, maximum: 198), spacing: 16)], spacing: 18) {
                        ForEach(store.sortedPlaylists) { playlist in
                            PlaylistCardView(playlist: playlist)
                        }
                    }
                }
            }
            .padding(26)
        }
        .sheet(isPresented: $showNewPlaylistSheet) {
            NewPlaylistSheet(
                name: $newPlaylistName,
                description: $newPlaylistDesc,
                onCreate: {
                    let pl = store.createPlaylist(name: newPlaylistName, description: newPlaylistDesc)
                    store.navigate(to: .playlist(pl.id))
                },
                onImportSpotify: {
                    store.showSpotifyImportSheet = true
                }
            )
        }
    }
}

struct PlaylistCardView: View {
    @Environment(EchoStore.self) private var store
    let playlist: Playlist
    @State private var isHovered = false
    @State private var isDropTargeted = false

    private func subtitleText(for playlistTracks: [Track]) -> String {
        let trimmedDesc = playlist.description.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedDesc.isEmpty { return trimmedDesc }
        var seen: Set<String> = []
        var artists: [String] = []
        for t in playlistTracks {
            let name = t.effectiveArtist
            if !name.isEmpty, seen.insert(name.lowercased()).inserted {
                artists.append(name)
                if artists.count == 3 { break }
            }
        }
        if !artists.isEmpty {
            return artists.joined(separator: ", ")
        }
        if playlist.missingTrackCount > 0 {
            return "\(playlist.missingTrackCount) missing track\(playlist.missingTrackCount == 1 ? "" : "s")"
        }
        return "Empty playlist"
    }

    var body: some View {
        let playlistTracks = store.tracks(for: playlist)
        let isParty = store.isPartyPlaylist(playlist)
        let isSynced = !isParty && store.isPlaylistSelected(playlist)
        let isFocused = store.focusedPlaylist?.id == playlist.id
        let heroArtHash = playlistTracks.first?.artworkHash

        let cardFill: Color = isDropTargeted
            ? EchoTheme.neoMint.opacity(0.14)
            : (isHovered ? EchoTheme.surfaceElevated : EchoTheme.surface)
        let cardBorder: Color = isDropTargeted
            ? EchoTheme.neoMint
            : (isSynced ? EchoTheme.neoMint.opacity(0.35) : (isFocused ? EchoTheme.neoCyan.opacity(0.35) : EchoTheme.border))

        VStack(alignment: .leading, spacing: 10) {
            artworkTile(
                playlistTracks: playlistTracks,
                isParty: isParty,
                isSynced: isSynced,
                isFocused: isFocused
            )
            metadataSection(playlistTracks: playlistTracks)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous)
                .fill(cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous)
                .strokeBorder(cardBorder, lineWidth: isDropTargeted ? 1.5 : 1)
        )
        .onHover { isHovered = $0 }
        .onTapGesture { store.navigate(to: .playlist(playlist.id)) }
        .dropDestination(for: String.self) { items, _ in
            store.handleDropOntoPlaylist(items: items, playlistID: playlist.id)
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
        .draggable(EchoDragPayload.playlist(playlist.id).encode()) {
            DragPreviewPill(
                title: playlist.name,
                subtitle: "Playlist",
                artworkHash: heroArtHash,
                artworkCache: store.artworkCache,
                badge: "\(playlistTracks.count) TRACKS"
            )
        }
        .contextMenu {
            cardContextMenu(playlistTracks: playlistTracks, isParty: isParty)
        }
    }

    @ViewBuilder
    private func artworkTile(
        playlistTracks: [Track],
        isParty: Bool,
        isSynced: Bool,
        isFocused: Bool
    ) -> some View {
        let isPartyLocked = store.isPartyLockedPlaylist(playlist)
        let cornerBadge: (String, Color)? = {
            if isPartyLocked { return ("LIVE PARTY", EchoTheme.neoMagenta) }
            if playlist.spotifyPlaylistID != nil { return ("SPOTIFY", EchoTheme.neoMint) }
            if isParty { return ("PARTY", EchoTheme.neoMagenta) }
            return nil
        }()

        ZStack(alignment: .bottomTrailing) {
            PlaylistMosaicArtwork(tracks: playlistTracks, artworkCache: store.artworkCache, cornerRadius: EchoTheme.radiusCard)
                .aspectRatio(1, contentMode: .fit)
                .shadow(color: .black.opacity(0.45), radius: 10, y: 4)

            if let (badgeLabel, badgeColor) = cornerBadge {
                Text(badgeLabel)
                    .font(.system(size: 8.5, weight: .black, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Color.black.opacity(0.78))
                    .foregroundStyle(badgeColor)
                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                    .overlay(
                        RoundedRectangle(cornerRadius: EchoTheme.radiusSmall)
                            .strokeBorder(badgeColor.opacity(0.55), lineWidth: 0.9)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(6)
            }

            topRightCornerPills(isParty: isParty, isSynced: isSynced, isFocused: isFocused)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(6)

            if isHovered && !playlistTracks.isEmpty {
                Button {
                    if isPartyLocked {
                        store.playPartyModeTrack(at: 0)
                    } else {
                        store.player.play(tracks: playlistTracks, startingAt: 0)
                    }
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
                .help("Play '\(playlist.name)'")
            }
        }
    }

    @ViewBuilder
    private func topRightCornerPills(isParty: Bool, isSynced: Bool, isFocused: Bool) -> some View {
        let targetName = store.activeDevice?.name ?? "selected destination"
        let focusFill: Color = isFocused ? EchoTheme.neoCyan.opacity(0.88) : Color.black.opacity(0.76)
        let focusFG: Color = isFocused ? Color.black : EchoTheme.textPrimary
        let focusStroke: Color = isFocused ? EchoTheme.neoCyan : Color.white.opacity(0.24)
        let syncFill: Color = isSynced ? EchoTheme.neoMint.opacity(0.90) : Color.black.opacity(0.76)
        let syncFG: Color = isSynced ? Color.black : EchoTheme.textPrimary
        let syncStroke: Color = isSynced ? EchoTheme.neoMint : Color.white.opacity(0.24)

        HStack(spacing: 4) {
            if isFocused || isHovered {
                Button {
                    store.setFocusedPlaylist(playlist.id)
                    store.showToast("Set '\(playlist.name)' as quick-add (+) target")
                } label: {
                    Image(systemName: isFocused ? "plus.square.fill" : "plus.square")
                        .font(.system(size: 10.5, weight: .bold))
                        .frame(width: 22, height: 22)
                        .background(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall).fill(focusFill))
                        .foregroundStyle(focusFG)
                        .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall).strokeBorder(focusStroke, lineWidth: 0.9))
                }
                .buttonStyle(.plain)
                .help(isFocused
                    ? "'\(playlist.name)' is the active quick-add (+) playlist target."
                    : "Set '\(playlist.name)' as the quick-add (+) playlist target.")
            }

            if !isParty && store.activeDevice != nil && (isSynced || isHovered) {
                Button {
                    store.togglePlaylistSync(playlist)
                } label: {
                    Text("S")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .frame(width: 22, height: 22)
                        .background(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall).fill(syncFill))
                        .foregroundStyle(syncFG)
                        .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall).strokeBorder(syncStroke, lineWidth: 0.9))
                }
                .buttonStyle(.plain)
                .help(isSynced
                    ? "Synced to '\(targetName)'. Click to remove '\(playlist.name)'."
                    : "Include '\(playlist.name)' in '\(targetName)' sync.")
            }
        }
    }

    @ViewBuilder
    private func metadataSection(playlistTracks: [Track]) -> some View {
        let missingCount = playlist.missingTrackCount
        let totalDuration = playlistTracks.reduce(0) { $0 + $1.duration }

        VStack(alignment: .leading, spacing: 3) {
            HoverLinkText(
                text: playlist.name,
                font: .system(size: 13.5, weight: .bold),
                color: EchoTheme.textPrimary,
                hoverColor: EchoTheme.neoMint,
                tip: "Open playlist '\(playlist.name)'"
            ) {
                store.navigate(to: .playlist(playlist.id))
            }

            Text(subtitleText(for: playlistTracks))
                .font(.system(size: 11.5))
                .foregroundStyle(EchoTheme.textSecondary)
                .lineLimit(1)

            HStack(spacing: 6) {
                Text("\(playlistTracks.count) track\(playlistTracks.count == 1 ? "" : "s")")
                    .font(.system(size: 10))
                    .foregroundStyle(EchoTheme.textMuted)
                if missingCount > 0 {
                    Text("\(missingCount) missing")
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(EchoTheme.warningAmber)
                }
                Spacer(minLength: 2)
                if totalDuration > 0 {
                    Text(Formatters.duration(totalDuration))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(EchoTheme.textMuted)
                }
            }
        }
    }

    @ViewBuilder
    private func cardContextMenu(playlistTracks: [Track], isParty: Bool) -> some View {
        let missingCount = playlist.missingTrackCount
        let isPartyLocked = store.isPartyLockedPlaylist(playlist)

        if !playlistTracks.isEmpty {
            Button("Play Playlist") {
                if isPartyLocked {
                    store.playPartyModeTrack(at: 0)
                } else {
                    store.player.play(tracks: playlistTracks, startingAt: 0)
                }
            }
            Button("Shuffle Play") {
                store.player.isShuffled = true
                store.player.play(tracks: playlistTracks.shuffled(), startingAt: 0)
            }
        }
        Button("Open Playlist") {
            store.navigate(to: .playlist(playlist.id))
        }
        Divider()
        Button("Set as Focused (+) Target") {
            store.setFocusedPlaylist(playlist.id)
            store.showToast("Set '\(playlist.name)' as quick-add (+) target")
        }
        if !isParty && !store.devices.isEmpty {
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
        if missingCount > 0 {
            if store.lidarrConfig.isConfigured {
                Button("Auto-Search Missing in Lidarr (\(missingCount))") {
                    store.autoSearchMissingTracksInLidarr(playlistID: playlist.id)
                }
            }
            Button("Re-Match Missing Tracks in Library") {
                store.reMatchMissingTracks(forPlaylistID: playlist.id)
            }
        }
        if playlist.spotifyPlaylistID != nil {
            Button("Re-Sync from Spotify") {
                store.resyncSpotifyPlaylist(playlist)
            }
        }
        Button("Duplicate Playlist") {
            store.duplicatePlaylist(playlist)
        }
        Menu("Export Playlist") {
            Button("Export as .pls (Winamp)...") {
                store.exportPlaylist(playlist, format: .pls)
            }
            Button("Export as .m3u8 (Extended M3U)...") {
                store.exportPlaylist(playlist, format: .m3u8)
            }
        }
        if !isPartyLocked {
            Divider()
            Button("Delete Playlist", role: .destructive) {
                store.deletePlaylist(playlist)
            }
        }
    }
}

struct PlaylistDetailView: View {
    @Environment(EchoStore.self) private var store
    let playlistID: UUID

    @State private var isEditing = false
    @State private var editName = ""
    @State private var editDesc = ""
    @State private var isDropTargeted = false
    @State private var tracksSort = TrackTableSortState()
    @State private var selectedRowIndex: Int? = nil
    @State private var hideMissingTracks = false
    @FocusState private var focusedRowIndex: Int?

    var body: some View {
        if let playlist = store.playlists.first(where: { $0.id == playlistID }) {
            let playlistTracks = store.tracks(for: playlist)
            let missingByID = playlist.missingTracksByID
            let activeMissing = playlist.activeMissingTracks
            let missingCount = activeMissing.count
            let orderedInLidarrCount = activeMissing.filter { $0.lidarrStatus == .ordered }.count
            let isPartyLocked = store.isPartyLockedPlaylist(playlist)
            let partyCurrentTrack = isPartyLocked ? store.player.currentTrack : nil
            let heroArtHash = partyCurrentTrack?.artworkHash ?? playlistTracks.first?.artworkHash
            let isSynced = store.isPlaylistSelected(playlist)
            let isFocused = store.focusedPlaylist?.id == playlist.id
            let totalDuration = playlistTracks.reduce(0) { $0 + $1.duration }
            let totalBytes = playlistTracks.reduce(Int64(0)) { $0 + $1.fileSize }
            let glow = ArtworkImageLoader.shared.dominantColor(forHash: heroArtHash, artworkCache: store.artworkCache)
            let isResyncingSpotify = store.resyncingSpotifyPlaylistIDs.contains(playlist.id)
            let isAutoSearchingThisPlaylist = store.isSearchingMissingTracksInLidarr && store.activeLidarrMissingSearchPlaylistID == playlist.id

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

                                    if playlist.spotifyPlaylistID != nil {
                                        Label("SPOTIFY", systemImage: "waveform")
                                            .font(.system(size: 9, weight: .black, design: .monospaced))
                                            .padding(.horizontal, 6.5)
                                            .padding(.vertical, 2.5)
                                            .background(EchoTheme.neoMint.opacity(0.18))
                                            .foregroundStyle(EchoTheme.neoMint)
                                            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                                    }

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

                                    HStack(spacing: 6) {
                                        Text("\(playlistTracks.count) track\(playlistTracks.count == 1 ? "" : "s")")
                                        if missingCount > 0 {
                                            Text("· \(missingCount) missing (muted & skipped)")
                                                .foregroundStyle(EchoTheme.warningAmber.opacity(0.9))
                                        }
                                        if !playlistTracks.isEmpty {
                                            Text("· \(Formatters.duration(totalDuration)) · \(Formatters.bytes(totalBytes))")
                                        }
                                    }
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

                                    if playlist.spotifyPlaylistID != nil {
                                        Button {
                                            store.resyncSpotifyPlaylist(playlist)
                                        } label: {
                                            HStack(spacing: 5) {
                                                if isResyncingSpotify {
                                                    ProgressView().controlSize(.mini)
                                                } else {
                                                    Image(systemName: "arrow.triangle.2.circlepath")
                                                        .font(.system(size: 11, weight: .bold))
                                                }
                                                Text(isResyncingSpotify ? "Syncing..." : "Re-Sync Spotify")
                                                    .font(.system(size: 11.5, weight: .semibold))
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6.5)
                                            .background(EchoTheme.neoMint.opacity(0.14))
                                            .foregroundStyle(EchoTheme.neoMint)
                                            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                                            .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusControl).strokeBorder(EchoTheme.neoMint.opacity(0.45), lineWidth: 1))
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(isResyncingSpotify)
                                        .help("Re-fetch this public Spotify playlist to pull newly added songs and re-match against your local library.")
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

                    // Missing Tracks Retention & Automatic Lidarr Search Banner
                    if missingCount > 0 {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.down.to.line.compact")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(isAutoSearchingThisPlaylist ? EchoTheme.neoCyan : EchoTheme.warningAmber)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 8) {
                                        Text("\(missingCount) Missing Track\(missingCount == 1 ? "" : "s") Retained")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(EchoTheme.textPrimary)
                                        if orderedInLidarrCount > 0 {
                                            Text("\(orderedInLidarrCount) ORDERED IN LIDARR")
                                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(EchoTheme.neoCyan.opacity(0.18))
                                                .foregroundStyle(EchoTheme.neoCyan)
                                                .clipShape(RoundedRectangle(cornerRadius: 3))
                                        }
                                    }
                                    Text("Shown muted in original playlist order and automatically skipped during playback, export & sync. Tracks light up automatically once added to your library.")
                                        .font(.system(size: 11))
                                        .foregroundStyle(EchoTheme.textSecondary)
                                }

                                Spacer(minLength: 10)

                                HStack(spacing: 7) {
                                    if isAutoSearchingThisPlaylist {
                                        Button {
                                            store.stopLidarrMissingTracksSearch()
                                        } label: {
                                            HStack(spacing: 5) {
                                                Image(systemName: "stop.fill")
                                                    .font(.system(size: 9.5))
                                                Text("Stop")
                                                    .font(.system(size: 11.5, weight: .bold))
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(EchoTheme.dangerCoral.opacity(0.18))
                                            .foregroundStyle(EchoTheme.dangerCoral)
                                            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                                            .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusControl).strokeBorder(EchoTheme.dangerCoral.opacity(0.45), lineWidth: 1))
                                        }
                                        .buttonStyle(.plain)
                                    } else if store.lidarrConfig.isConfigured {
                                        let unsearchedCount = activeMissing.filter { $0.lidarrStatus != .ordered }.count
                                        NeoPrimaryButton(
                                            title: unsearchedCount > 0
                                                ? "Auto-Search Missing in Lidarr (\(unsearchedCount))"
                                                : "Re-Search All in Lidarr (\(missingCount))",
                                            icon: "arrow.down.to.line.compact",
                                            disabled: store.isSearchingMissingTracksInLidarr
                                        ) {
                                            store.autoSearchMissingTracksInLidarr(
                                                playlistID: playlist.id,
                                                onlyUnsearched: unsearchedCount > 0
                                            )
                                        }
                                        .help("Automatically resolve parent albums and order missing tracks in Lidarr (shared albums are ordered once).")
                                    } else {
                                        Button {
                                            store.navigate(to: .settings)
                                        } label: {
                                            HStack(spacing: 5) {
                                                Image(systemName: "gearshape")
                                                Text("Configure Lidarr")
                                            }
                                            .font(.system(size: 11.5, weight: .semibold))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(EchoTheme.surfaceElevated)
                                            .foregroundStyle(EchoTheme.neoCyan)
                                            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                                            .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusControl).strokeBorder(EchoTheme.neoCyan.opacity(0.45), lineWidth: 1))
                                        }
                                        .buttonStyle(.plain)
                                        .help("Configure Lidarr URL and API Key in Settings to automatically search & download missing tracks.")
                                    }

                                    Button {
                                        store.reMatchMissingTracks(forPlaylistID: playlist.id)
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "magnifyingglass")
                                                .font(.system(size: 10.5, weight: .bold))
                                            Text("Re-Match")
                                                .font(.system(size: 11.5, weight: .semibold))
                                        }
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 6)
                                        .background(EchoTheme.surfaceElevated)
                                        .foregroundStyle(EchoTheme.textPrimary)
                                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                                        .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusControl).strokeBorder(EchoTheme.border, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Re-check your indexed library right now to resolve newly downloaded missing tracks.")

                                    Button {
                                        hideMissingTracks.toggle()
                                    } label: {
                                        Image(systemName: hideMissingTracks ? "eye" : "eye.slash")
                                            .font(.system(size: 11.5, weight: .semibold))
                                            .frame(width: 28, height: 28)
                                            .background(EchoTheme.surfaceElevated)
                                            .foregroundStyle(hideMissingTracks ? EchoTheme.neoCyan : EchoTheme.textSecondary)
                                            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                                            .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusControl).strokeBorder(EchoTheme.border, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                    .help(hideMissingTracks ? "Show muted missing tracks in playlist" : "Temporarily hide muted missing tracks from view")

                                    Button(role: .destructive) {
                                        store.clearMissingTracks(inPlaylistID: playlist.id)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 11))
                                            .frame(width: 28, height: 28)
                                            .background(EchoTheme.dangerCoral.opacity(0.14))
                                            .foregroundStyle(EchoTheme.dangerCoral)
                                            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Remove all retained missing tracks from this playlist.")
                                }
                            }

                            if isAutoSearchingThisPlaylist, let prog = store.lidarrMissingSearchProgress {
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack(spacing: 8) {
                                        ProgressView().controlSize(.mini)
                                        Text("Searching Lidarr (\(prog.done)/\(max(1, prog.total))): \(prog.currentTrack)")
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(EchoTheme.neoCyan)
                                            .lineLimit(1)
                                        Spacer()
                                    }
                                    ProgressView(value: Double(prog.done), total: Double(max(1, prog.total)))
                                        .tint(EchoTheme.neoCyan)
                                }
                            }
                        }
                        .padding(14)
                        .background(EchoTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous)
                                .strokeBorder(isAutoSearchingThisPlaylist ? EchoTheme.neoCyan.opacity(0.45) : EchoTheme.warningAmber.opacity(0.32), lineWidth: 1)
                        )
                        .padding(.horizontal, 26)
                    }

                    if playlistTracks.isEmpty && missingCount == 0 {
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
                        let builtRows: (rows: [PlaylistDisplayRow], playableTracks: [Track]) = {
                            if isCustomOrder {
                                var rows: [PlaylistDisplayRow] = []
                                var playable: [Track] = []
                                for (offset, tid) in playlist.trackIDs.enumerated() {
                                    if Playlist.isMissingTrackID(tid) {
                                        if !hideMissingTracks, let m = missingByID[tid] {
                                            rows.append(.missing(originalIndex: offset, item: m))
                                        }
                                    } else if let t = store.tracksByID[tid] {
                                        let pIdx = playable.count
                                        playable.append(t)
                                        rows.append(.available(originalIndex: offset, track: t, playableIndex: pIdx))
                                    }
                                }
                                return (rows, playable)
                            } else {
                                let indexedAvail: [(originalIndex: Int, track: Track)] = playlist.trackIDs.enumerated().compactMap { offset, tid in
                                    guard !Playlist.isMissingTrackID(tid), let t = store.tracksByID[tid] else { return nil }
                                    return (offset, t)
                                }
                                let sorted = store.sortTracks(indexedAvail.map(\.track), by: tracksSort)
                                var buckets: [String: [Int]] = [:]
                                for entry in indexedAvail {
                                    buckets[entry.track.id, default: []].append(entry.originalIndex)
                                }
                                var cursor: [String: Int] = [:]
                                var rows: [PlaylistDisplayRow] = []
                                var playable: [Track] = []
                                for track in sorted {
                                    let pos = cursor[track.id, default: 0]
                                    guard let indices = buckets[track.id], pos < indices.count else { continue }
                                    cursor[track.id] = pos + 1
                                    let pIdx = playable.count
                                    playable.append(track)
                                    rows.append(.available(originalIndex: indices[pos], track: track, playableIndex: pIdx))
                                }
                                if !hideMissingTracks {
                                    for (offset, tid) in playlist.trackIDs.enumerated() where Playlist.isMissingTrackID(tid) {
                                        if let m = missingByID[tid] {
                                            rows.append(.missing(originalIndex: offset, item: m))
                                        }
                                    }
                                }
                                return (rows, playable)
                            }
                        }()
                        let displayedRows = builtRows.rows
                        let displayedPlayableTracks = builtRows.playableTracks

                        VStack(spacing: 2) {
                            SortableTrackTableHeader(showAlbum: true, isPlaylist: true, sortState: $tracksSort)
                            Divider().overlay(EchoTheme.border).padding(.bottom, 4)

                            let isPartymodePlaylist = isPartyLocked || playlist.name.caseInsensitiveCompare(EchoStore.partyPlaylistName) == .orderedSame
                            ForEach(Array(displayedRows.enumerated()), id: \.element.id) { idx, row in
                                switch row {
                                case .available(let origIdx, let track, let playableIdx):
                                    TrackRowView(
                                        track: track,
                                        index: idx,
                                        showAlbumColumn: true,
                                        playlistContext: (playlist.id, origIdx),
                                        allowPlaylistReorder: isCustomOrder,
                                        isSelected: selectedRowIndex == idx || focusedRowIndex == idx,
                                        partyRequester: isPartymodePlaylist ? store.partyRequesterName(for: track.id) : nil,
                                        partyVoiceIntroDuration: isPartymodePlaylist ? store.partyVoiceIntrosByTrackID[track.id]?.duration : nil,
                                        onRemovePartyVoiceIntro: isPartymodePlaylist ? {
                                            store.deletePartyVoiceIntro(trackID: track.id, fromHost: true)
                                        } : nil,
                                        onSelect: {
                                            selectedRowIndex = idx
                                            focusedRowIndex = idx
                                        }
                                    ) {
                                        if store.isPartyLockedPlaylist(playlist) && isCustomOrder {
                                            store.playPartyModeTrack(at: playableIdx)
                                        } else {
                                            store.player.play(tracks: displayedPlayableTracks, startingAt: playableIdx)
                                        }
                                    }
                                    .focusable()
                                    .focusEffectDisabled()
                                    .focused($focusedRowIndex, equals: idx)

                                case .missing(let origIdx, let missing):
                                    MissingPlaylistTrackRowView(
                                        missing: missing,
                                        index: idx,
                                        playlistID: playlist.id,
                                        originalIndex: origIdx,
                                        showAlbumColumn: true,
                                        allowPlaylistReorder: isCustomOrder,
                                        isSelected: selectedRowIndex == idx || focusedRowIndex == idx,
                                        onSelect: {
                                            selectedRowIndex = idx
                                            focusedRowIndex = idx
                                        }
                                    )
                                    .focusable()
                                    .focusEffectDisabled()
                                    .focused($focusedRowIndex, equals: idx)
                                }
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
                                          targetIdx >= 0 && targetIdx < displayedRows.count else {
                                        return false
                                    }
                                    let origIdx = displayedRows[targetIdx].originalIndex
                                    store.removeTrack(at: origIdx, fromPlaylistID: playlist.id)
                                    let remaining = displayedRows.count - 1
                                    let nextSel: Int? = remaining > 0 ? min(targetIdx, remaining - 1) : nil
                                    selectedRowIndex = nextSel
                                    focusedRowIndex = nextSel
                                    return true
                                case 125: // Down arrow
                                    guard !displayedRows.isEmpty, let cur = selectedRowIndex ?? focusedRowIndex else { return false }
                                    let next = min(displayedRows.count - 1, cur + 1)
                                    selectedRowIndex = next
                                    focusedRowIndex = next
                                    return true
                                case 126: // Up arrow
                                    guard !displayedRows.isEmpty, let cur = selectedRowIndex ?? focusedRowIndex else { return false }
                                    let prev = max(0, cur - 1)
                                    selectedRowIndex = prev
                                    focusedRowIndex = prev
                                    return true
                                case 36, 76: // Return / Enter — skip/ignore missing tracks!
                                    guard let targetIdx = selectedRowIndex ?? focusedRowIndex,
                                          targetIdx >= 0 && targetIdx < displayedRows.count else {
                                        return false
                                    }
                                    if case .available(_, _, let playableIdx) = displayedRows[targetIdx] {
                                        if store.isPartyLockedPlaylist(playlist) && isCustomOrder {
                                            store.playPartyModeTrack(at: playableIdx)
                                        } else {
                                            store.player.play(tracks: displayedPlayableTracks, startingAt: playableIdx)
                                        }
                                        return true
                                    }
                                    return false
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

/// Muted/dimmed row for missing tracks retained in an imported playlist — visually muted, skipped on playback & sync,
/// with one-click individual Lidarr search/order and automatic live upgrade once downloaded.
private struct MissingPlaylistTrackRowView: View {
    @Environment(EchoStore.self) private var store
    let missing: MissingPlaylistTrack
    let index: Int
    let playlistID: UUID
    let originalIndex: Int
    var showAlbumColumn: Bool = true
    var allowPlaylistReorder: Bool = true
    var isSelected: Bool = false
    var onSelect: (() -> Void)? = nil

    @State private var isHovered = false
    @State private var isReorderDropTargeted = false

    private var dragPayloadString: String {
        EchoDragPayload.reorder(playlistID: playlistID, sourceIndex: originalIndex).encode()
    }

    var body: some View {
        rowContent
            .draggable(allowPlaylistReorder ? dragPayloadString : "") {
                HStack(spacing: 8) {
                    Image(systemName: "music.note")
                        .font(.system(size: 11))
                        .foregroundStyle(EchoTheme.textMuted)
                    Text("\(missing.title) — \(missing.artist)")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(EchoTheme.textSecondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(EchoTheme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
            }
            .dropDestination(for: String.self) { items, _ in
                guard allowPlaylistReorder else { return false }
                return store.handlePlaylistReorderDrop(items: items, playlistID: playlistID, targetIndex: originalIndex)
            } isTargeted: { targeted in
                if allowPlaylistReorder {
                    isReorderDropTargeted = targeted
                }
            }
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            // Track index (always muted; never shows play button because missing tracks are skipped)
            Text("\(index + 1)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(EchoTheme.textMuted.opacity(0.45))
                .frame(width: 26)

            // Dimmed artwork thumbnail + muted title & artist (matching Spotify unavailable track aesthetic)
            HStack(spacing: 10) {
                dimmedThumbnail
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2.5) {
                    Text(missing.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(EchoTheme.textSecondary.opacity(0.55))
                        .lineLimit(1)

                    Text(missing.artist.isEmpty ? "Unknown Artist" : missing.artist)
                        .font(.system(size: 11.5))
                        .foregroundStyle(EchoTheme.textMuted.opacity(0.55))
                        .lineLimit(1)
                }
            }
            .frame(minWidth: 180, maxWidth: .infinity, alignment: .leading)

            if showAlbumColumn {
                Text(missing.album ?? "—")
                    .font(.system(size: 12))
                    .foregroundStyle(EchoTheme.textMuted.opacity(0.45))
                    .lineLimit(1)
                    .frame(width: 150, alignment: .leading)
            }

            // Aligned span covering Plays(44) + Pop(50) + Rating(68) + Format(86) + 3×12pt spacings = 284pt
            HStack(spacing: 6) {
                Spacer(minLength: 0)
                statusPill
            }
            .frame(width: 284, alignment: .trailing)

            // Reorder drag handle (aligned with TrackRowView's 30pt column)
            HStack(spacing: 4) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 10.5))
                    .foregroundStyle(
                        allowPlaylistReorder
                            ? (isHovered ? EchoTheme.textMuted.opacity(0.75) : EchoTheme.textMuted.opacity(0.25))
                            : EchoTheme.textMuted.opacity(0.14)
                    )
            }
            .frame(width: 30)

            // Individual Lidarr Search button (aligned with TrackRowView's 30pt Sync column)
            Button {
                if store.lidarrConfig.isConfigured {
                    store.searchSingleMissingTrackInLidarr(missingTrackID: missing.id, playlistID: playlistID)
                } else {
                    store.navigate(to: .settings)
                }
            } label: {
                Group {
                    if missing.lidarrStatus == .searching {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        Image(systemName: missing.lidarrStatus == .ordered ? "checkmark" : "arrow.down.to.line.compact")
                            .font(.system(size: 10.5, weight: .bold))
                    }
                }
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: EchoTheme.radiusSmall)
                        .fill(
                            missing.lidarrStatus == .ordered
                                ? EchoTheme.neoCyan.opacity(0.18)
                                : (isHovered ? EchoTheme.neoMint.opacity(0.18) : EchoTheme.surfaceElevated.opacity(0.30))
                        )
                )
                .foregroundStyle(
                    missing.lidarrStatus == .ordered
                        ? EchoTheme.neoCyan
                        : (isHovered ? EchoTheme.neoMint : EchoTheme.textMuted.opacity(0.45))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: EchoTheme.radiusSmall)
                        .strokeBorder(
                            missing.lidarrStatus == .ordered
                                ? EchoTheme.neoCyan.opacity(0.5)
                                : (isHovered ? EchoTheme.neoMint.opacity(0.55) : EchoTheme.border.opacity(0.6)),
                            lineWidth: 0.85
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(missing.lidarrStatus == .searching)
            .frame(width: 30)
            .help(lidarrButtonTooltip)

            // Muted duration (aligned with TrackRowView's 44pt column)
            Text(missing.duration > 0 ? Formatters.duration(missing.duration) : "—")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(EchoTheme.textMuted.opacity(0.45))
                .frame(width: 44, alignment: .trailing)

            // Quick actions menu (aligned with TrackRowView's 24pt column)
            Menu {
                missingTrackMenuItems
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12))
                    .foregroundStyle(isHovered ? EchoTheme.textSecondary : EchoTheme.textMuted.opacity(0.45))
                    .frame(width: 24, height: 24)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 24)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous)
                .fill(
                    isSelected
                        ? EchoTheme.neoCyan.opacity(0.10)
                        : (isHovered ? EchoTheme.surfaceElevated.opacity(0.35) : Color.clear)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous)
                .strokeBorder(isSelected ? EchoTheme.neoCyan.opacity(0.4) : Color.clear, lineWidth: 1)
                .allowsHitTesting(false)
        )
        .overlay(alignment: .top) {
            if isReorderDropTargeted {
                Rectangle()
                    .fill(EchoTheme.neoMint)
                    .frame(height: 2.5)
                    .padding(.horizontal, 8)
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture(count: 1) {
            onSelect?()
        }
        .contextMenu {
            missingTrackMenuItems
        }
        .help("Missing from local library (skipped during playback & sync).\(missing.lidarrStatusDetail.map { " \($0)" } ?? "")")
    }

    @ViewBuilder
    private var dimmedThumbnail: some View {
        let r = EchoTheme.radiusSmall
        Group {
            if let artStr = missing.artworkURL, let url = URL(string: artStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .saturation(0.30)
                            .opacity(0.38)
                    default:
                        mutedPlaceholderArt
                    }
                }
            } else {
                mutedPlaceholderArt
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: r, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: r, style: .continuous)
                .strokeBorder(EchoTheme.border.opacity(0.55), lineWidth: 1)
        )
    }

    private var mutedPlaceholderArt: some View {
        ZStack {
            EchoTheme.surfaceElevated.opacity(0.42)
            Image(systemName: "music.note")
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(EchoTheme.textMuted.opacity(0.38))
        }
    }

    @ViewBuilder
    private var statusPill: some View {
        switch missing.lidarrStatus {
        case .missing:
            Text("MISSING")
                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.04))
                .foregroundStyle(EchoTheme.textMuted.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 3))
        case .searching:
            HStack(spacing: 4) {
                ProgressView().controlSize(.mini)
                Text("SEARCHING LIDARR")
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(EchoTheme.neoCyan.opacity(0.14))
            .foregroundStyle(EchoTheme.neoCyan)
            .clipShape(RoundedRectangle(cornerRadius: 3))
        case .ordered:
            HStack(spacing: 4) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 8.5))
                Text("LIDARR ORDERED")
                    .font(.system(size: 8.5, weight: .black, design: .monospaced))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(EchoTheme.neoCyan.opacity(0.16))
            .foregroundStyle(EchoTheme.neoCyan)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .help(missing.lidarrStatusDetail ?? "Ordered in Lidarr — waiting for download & library re-index.")
        case .notFound:
            Text("NOT IN LIDARR")
                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(EchoTheme.warningAmber.opacity(0.14))
                .foregroundStyle(EchoTheme.warningAmber.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .help(missing.lidarrStatusDetail ?? "Could not match automatically — use manual Lidarr search from the menu.")
        case .failed:
            Text("LIDARR RETRY")
                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(EchoTheme.dangerCoral.opacity(0.14))
                .foregroundStyle(EchoTheme.dangerCoral.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .help(missing.lidarrStatusDetail ?? "Lidarr search failed — click to retry.")
        }
    }

    private var lidarrButtonTooltip: String {
        if !store.lidarrConfig.isConfigured {
            return "Configure Lidarr in Settings to search & download this missing track."
        }
        switch missing.lidarrStatus {
        case .ordered:
            return "Already ordered in Lidarr (\(missing.lidarrAlbumTitle ?? "parent album")). Click to re-trigger search."
        case .searching:
            return "Searching Lidarr..."
        default:
            return "Automatically resolve parent album and search/order '\(missing.title)' by \(missing.artist) in Lidarr."
        }
    }

    @ViewBuilder
    private var missingTrackMenuItems: some View {
        if store.lidarrConfig.isConfigured {
            Button("Auto-Search & Order in Lidarr") {
                store.searchSingleMissingTrackInLidarr(missingTrackID: missing.id, playlistID: playlistID)
            }
        }
        if store.lidarrConfig.isEnabled {
            Button("Open Manual Lidarr Search...") {
                let query = missing.album.map { "\(missing.artist) \($0)" } ?? "\(missing.artist) \(missing.title)"
                store.openLidarrSearch(query: query, mode: .tracks)
            }
        }
        Button("Copy Artist & Title") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString("\(missing.artist) - \(missing.title)", forType: .string)
            store.showToast("Copied '\(missing.artist) - \(missing.title)'")
        }
        Divider()
        Button("Remove Missing Track", role: .destructive) {
            store.removeMissingTrack(id: missing.id, fromPlaylistID: playlistID)
        }
    }
}

// MARK: - Library Sources & NAS View

struct SourcesView: View {
    @Environment(EchoStore.self) private var store
    @State private var configuringSourceID: UUID? = nil
    @State private var draftSourceName: String = ""
    @State private var draftIndexingMode: LibraryIndexingMode = .localDirect
    @State private var draftRemoteLibID: String = "music"
    @State private var draftLANURL: String = ""
    @State private var draftTailscaleURL: String = ""
    @State private var draftPIN: String = ""
    @State private var draftSyncSharedState: Bool = true

    private var configuringSource: LibrarySource? {
        guard let id = configuringSourceID else { return nil }
        return store.sources.first(where: { $0.id == id })
    }

    private func openSourceSettings(_ source: LibrarySource) {
        configuringSourceID = source.id
        draftSourceName = source.name
        draftIndexingMode = source.indexingMode
        let detected = store.detectedEchoServersBySourceID[source.id]
        draftRemoteLibID = source.remoteLibraryID ?? detected?.libraryID ?? store.echoServerLibraries.first?.id ?? "music"
        draftLANURL = store.echoServerConfig.lanURL.isEmpty ? (detected?.baseURL ?? "") : store.echoServerConfig.lanURL
        draftTailscaleURL = store.echoServerConfig.tailscaleURL
        draftPIN = store.echoServerConfig.pairingPIN
        draftSyncSharedState = store.echoServerConfig.syncSharedState
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Library Sources & NAS")
                                .font(.system(size: 26, weight: .black, design: .rounded))
                                .foregroundStyle(EchoTheme.textPrimary)
                            Text("Index local music folders, external drives, or mounted SMB/NFS NAS shares. Click the gear button on any volume to enable My Echo Server / .myecho indexing.")
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
                                let detected = store.detectedEchoServersBySourceID[source.id]
                                HStack(spacing: 16) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: EchoTheme.radiusCard)
                                            .fill(online ? EchoTheme.neoMint.opacity(0.14) : EchoTheme.dangerCoral.opacity(0.14))
                                            .frame(width: 48, height: 48)
                                        Image(systemName: source.indexingMode == .echoServer ? "server.rack" : (source.isNetworkVolume ? "externaldrive.connected.to.line.below.fill" : "folder.fill"))
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
                                            if source.indexingMode == .echoServer {
                                                Text("ECHO SERVER\(source.lastSyncedRevision.map { " · REV #\($0)" } ?? "")")
                                                    .font(.system(size: 9, weight: .black, design: .monospaced))
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(EchoTheme.neoMint.opacity(0.20))
                                                    .foregroundStyle(EchoTheme.neoMint)
                                                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                                            } else if source.isNetworkVolume {
                                                Text("NAS / NETWORK")
                                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(EchoTheme.neoCyan.opacity(0.16))
                                                    .foregroundStyle(EchoTheme.neoCyan)
                                                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                                            }
                                            if let det = detected, source.indexingMode != .echoServer {
                                                Button {
                                                    openSourceSettings(source)
                                                } label: {
                                                    Text(det.hasDotMyEchoIndex ? ".MYECHO DETECTED · ENABLE" : "ECHO SERVER DETECTED · ENABLE")
                                                        .font(.system(size: 9, weight: .black, design: .monospaced))
                                                        .padding(.horizontal, 7)
                                                        .padding(.vertical, 2)
                                                        .background(EchoTheme.neoMagenta.opacity(0.2))
                                                        .foregroundStyle(EchoTheme.neoMagenta)
                                                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                                                }
                                                .buttonStyle(.plain)
                                                .help("Detected \(det.serverName) (\(det.baseURL)). Click to enable fast compressed index syncing for this volume.")
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

                                    // Source Configuration Settings Lightbox Button
                                    Button {
                                        openSourceSettings(source)
                                    } label: {
                                        Image(systemName: "gearshape.fill")
                                            .font(.system(size: 12.5, weight: .semibold))
                                            .frame(width: 30, height: 30)
                                            .background(source.indexingMode == .echoServer ? EchoTheme.neoCyan.opacity(0.18) : EchoTheme.surfaceElevated)
                                            .foregroundStyle(source.indexingMode == .echoServer ? EchoTheme.neoCyan : EchoTheme.textPrimary)
                                            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous))
                                            .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous).strokeBorder(source.indexingMode == .echoServer ? EchoTheme.neoCyan.opacity(0.55) : EchoTheme.border, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Configure '\(source.name)' — switch between Local/SMB direct scan and My Echo Server / .myecho share index.")

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
                                    .help(source.indexingMode == .echoServer
                                          ? "Sync latest compressed index delta from My Echo Server / .myecho."
                                          : "Re-scan '\(source.name)' for newly added, modified, or removed audio files.")

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

            // Source Configuration Lightbox Dialog
            if let src = configuringSource {
                sourceSettingsLightbox(for: src)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    .zIndex(50)
            }
        }
        .animation(.easeOut(duration: 0.16), value: configuringSourceID != nil)
        .onAppear {
            Task { await store.detectEchoServersForSources() }
        }
        .onKeyPress(.escape) {
            if configuringSourceID != nil {
                configuringSourceID = nil
                return .handled
            }
            return .ignored
        }
    }

    @ViewBuilder
    private func sourceSettingsLightbox(for source: LibrarySource) -> some View {
        let detected = store.detectedEchoServersBySourceID[source.id]
        ZStack {
            Color.black.opacity(0.68)
                .ignoresSafeArea()
                .onTapGesture { configuringSourceID = nil }

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("VOLUME & INDEXING SETTINGS")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(1.3)
                            .foregroundStyle(EchoTheme.neoCyan)
                        Text(source.name)
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(EchoTheme.textPrimary)
                    }
                    Spacer()
                    Button {
                        configuringSourceID = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .frame(width: 28, height: 28)
                            .background(EchoTheme.surfaceElevated)
                            .foregroundStyle(EchoTheme.textSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                    }
                    .buttonStyle(.plain)
                }

                // Volume Name & Path
                VStack(alignment: .leading, spacing: 6) {
                    Text("VOLUME DISPLAY NAME")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(EchoTheme.textMuted)
                    TextField("Volume Name", text: $draftSourceName)
                        .textFieldStyle(.roundedBorder)
                    Text(source.path)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(EchoTheme.textMuted)
                }

                // Auto-Detected Echo Server Banner
                if let det = detected {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(EchoTheme.neoMint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto-Detected: \(det.serverName) (\(det.detectionMethod == ".myecho" ? ".myecho share index" : "LAN server"))")
                                .font(.system(size: 12.5, weight: .bold))
                                .foregroundStyle(EchoTheme.neoMint)
                            Text("\(det.baseURL.isEmpty ? source.path + "/.myecho" : det.baseURL)\(det.dotMyEchoTrackCount.map { " · \($0) tracks" } ?? "")\(det.dotMyEchoRevision.map { " · Rev #\($0)" } ?? "")")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(EchoTheme.textSecondary)
                        }
                        Spacer()
                        Button("Use Detected") {
                            draftIndexingMode = .echoServer
                            if !det.baseURL.isEmpty { draftLANURL = det.baseURL }
                            draftRemoteLibID = det.libraryID
                        }
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(EchoTheme.neoMint)
                        .foregroundStyle(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                        .buttonStyle(.plain)
                    }
                    .padding(10)
                    .background(EchoTheme.neoMint.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                    .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusControl).strokeBorder(EchoTheme.neoMint.opacity(0.4), lineWidth: 1))
                }

                // Indexing Mode Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("INDEXING ENGINE FOR THIS VOLUME")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(EchoTheme.textMuted)

                    HStack(spacing: 10) {
                        modeOptionCard(
                            title: "Local / Traditional NAS",
                            subtitle: "Standalone Mac scanning of local folders or SMB/NFS shares.",
                            icon: "externaldrive.fill",
                            selected: draftIndexingMode == .localDirect
                        ) {
                            draftIndexingMode = .localDirect
                        }

                        modeOptionCard(
                            title: "My Echo Server / .myecho",
                            subtitle: "Reads compressed .myecho shards or fetches deltas from Unraid Docker.",
                            icon: "server.rack",
                            selected: draftIndexingMode == .echoServer
                        ) {
                            draftIndexingMode = .echoServer
                        }
                    }
                }

                // Echo Server Connection Fields when enabled
                if draftIndexingMode == .echoServer {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("SERVER LAN URL")
                                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                    .foregroundStyle(EchoTheme.textMuted)
                                TextField("http://192.168.0.12:48721", text: $draftLANURL)
                                    .textFieldStyle(.roundedBorder)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("TAILSCALE URL (OPTIONAL)")
                                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                    .foregroundStyle(EchoTheme.textMuted)
                                TextField("http://100.92.217.88:48721", text: $draftTailscaleURL)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("6-DIGIT PAIRING PIN")
                                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                    .foregroundStyle(EchoTheme.textMuted)
                                TextField("581688", text: $draftPIN)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 130)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("REMOTE LIBRARY ID")
                                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                    .foregroundStyle(EchoTheme.textMuted)
                                TextField("music", text: $draftRemoteLibID)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 130)
                            }
                            Spacer()
                            Button(store.isTestingEchoServer ? "Testing..." : "Test Connection") {
                                var cfg = store.echoServerConfig
                                cfg.isEnabled = true
                                cfg.lanURL = draftLANURL
                                cfg.tailscaleURL = draftTailscaleURL
                                cfg.pairingPIN = draftPIN
                                cfg.syncSharedState = draftSyncSharedState
                                store.saveEchoServerConfig(cfg)
                                Task { await store.testEchoServerConnection() }
                            }
                            .font(.system(size: 11.5, weight: .bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(EchoTheme.surfaceElevated)
                            .foregroundStyle(EchoTheme.neoCyan)
                            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                            .buttonStyle(.plain)
                        }

                        Toggle("Sync Playlists, Ratings, Podcasts & Editorial to Echo Server (for Apple TV & Web UI)", isOn: $draftSyncSharedState)
                            .font(.system(size: 11.5))
                            .foregroundStyle(EchoTheme.textSecondary)

                        Text("Tip: If `.myecho/manifest.json` exists in this share root, compressed shards can be read directly even without a PIN. Adding the PIN enables remote HTTP deltas, Unraid scan triggers & Apple TV shared playlists.")
                            .font(.system(size: 10.5))
                            .foregroundStyle(EchoTheme.textMuted)

                        if !store.echoServerStatusText.isEmpty {
                            Text(store.echoServerStatusText)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(EchoTheme.neoMint)
                        }
                        if let err = store.echoServerError {
                            Text(err)
                                .font(.system(size: 11))
                                .foregroundStyle(EchoTheme.dangerCoral)
                        }
                    }
                    .padding(12)
                    .background(EchoTheme.canvas.opacity(0.65))
                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                }

                // Footer Actions
                HStack(spacing: 10) {
                    if draftIndexingMode == .echoServer && store.echoServerConfig.isConfigured {
                        Button("Trigger Remote Scan") {
                            Task { await store.triggerRemoteEchoServerScanAndSync(for: source) }
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(EchoTheme.surfaceElevated)
                        .foregroundStyle(EchoTheme.neoCyan)
                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                        .buttonStyle(.plain)
                    }
                    Spacer()
                    Button("Cancel") {
                        configuringSourceID = nil
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(EchoTheme.surfaceElevated)
                    .foregroundStyle(EchoTheme.textSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                    .buttonStyle(.plain)

                    Button("Save & Apply") {
                        store.updateSourceName(source.id, newName: draftSourceName)
                        if draftIndexingMode == .echoServer {
                            var cfg = store.echoServerConfig
                            cfg.isEnabled = !draftLANURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !draftTailscaleURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            cfg.lanURL = draftLANURL
                            cfg.tailscaleURL = draftTailscaleURL
                            cfg.pairingPIN = draftPIN
                            cfg.syncSharedState = draftSyncSharedState
                            store.saveEchoServerConfig(cfg)
                            let libID = draftRemoteLibID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "music" : draftRemoteLibID.trimmingCharacters(in: .whitespacesAndNewlines)
                            store.linkSourceToEchoServer(source.id, remoteLibraryID: libID)
                        } else {
                            store.unlinkSourceFromEchoServer(source.id)
                        }
                        configuringSourceID = nil
                    }
                    .font(.system(size: 12, weight: .black))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(EchoTheme.neoMint)
                    .foregroundStyle(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                    .buttonStyle(.plain)
                }
            }
            .padding(22)
            .frame(maxWidth: 640)
            .background(EchoTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous)
                    .strokeBorder(EchoTheme.borderStrong, lineWidth: 1.2)
            )
            .shadow(color: .black.opacity(0.6), radius: 32, y: 12)
            .padding(24)
        }
    }

    private func modeOptionCard(
        title: String,
        subtitle: String,
        icon: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(selected ? EchoTheme.neoMint : EchoTheme.textSecondary)
                    Text(title)
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(EchoTheme.textPrimary)
                    Spacer()
                    Image(systemName: selected ? "checkmark.square.fill" : "square")
                        .foregroundStyle(selected ? EchoTheme.neoMint : EchoTheme.textMuted)
                }
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(EchoTheme.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? EchoTheme.neoMint.opacity(0.10) : EchoTheme.surfaceElevated.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
            .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusControl).strokeBorder(selected ? EchoTheme.neoMint : EchoTheme.border, lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
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

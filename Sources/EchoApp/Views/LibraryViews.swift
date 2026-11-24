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
                            .fill(EchoTheme.neoMint)
                            .frame(width: 38, height: 36)
                            .overlay(Image(systemName: "play.fill").foregroundStyle(.black).font(.system(size: 15, weight: .bold)))
                            .shadow(color: EchoTheme.neoMint.opacity(0.45), radius: 8, y: 3)
                    }
                    .buttonStyle(.plain)
                    .padding(4)
                }

                // Sync status corner pill
                if state != .none || isHovered {
                    SyncStatePillButton(state: state, compact: true) {
                        store.toggleArtistSync(artist)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(2)
                }
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

    var body: some View {
        if let artist = store.artistsByKey[artistKey] {
            let glow = ArtworkImageLoader.shared.dominantColor(forHash: artist.artworkHash, artworkCache: store.artworkCache)
            let state = store.selectionState(forArtist: artist)

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

                                Text("\(artist.albums.count) albums · \(artist.tracks.count) tracks · \(Formatters.bytes(artist.totalSize))")
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(EchoTheme.textSecondary)

                                HStack(spacing: 10) {
                                    NeoPrimaryButton(title: "Play All", icon: "play.fill") {
                                        store.player.play(tracks: artist.tracks, startingAt: 0)
                                    }
                                    SyncStatePillButton(state: state, label: "Sync Entire Artist") {
                                        store.toggleArtistSync(artist)
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
                                        Menu {
                                            ForEach(store.playlists) { pl in
                                                Button(pl.name) {
                                                    store.addTracks(artist.tracks, toPlaylistID: pl.id)
                                                }
                                            }
                                        } label: {
                                            Image(systemName: "text.badge.plus")
                                                .font(.system(size: 12.5, weight: .semibold))
                                                .frame(width: 30, height: 30)
                                                .background(EchoTheme.surfaceElevated)
                                                .foregroundStyle(EchoTheme.textPrimary)
                                                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                                        }
                                        .menuStyle(.borderlessButton)
                                        .fixedSize()
                                        .help("Choose any playlist to add all tracks by '\(artist.name)'.")
                                    }
                                }
                                .padding(.top, 4)
                            }
                            Spacer()
                        }
                        .padding(26)
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

                    // All Tracks by Artist
                    VStack(alignment: .leading, spacing: 8) {
                        Text("All Tracks")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(EchoTheme.textPrimary)
                            .padding(.bottom, 4)

                        ForEach(Array(artist.tracks.enumerated()), id: \.element.id) { idx, track in
                            TrackRowView(track: track, index: idx, showAlbumColumn: true) {
                                store.player.play(tracks: artist.tracks, startingAt: idx)
                            }
                        }
                    }
                    .padding(.horizontal, 26)
                    .padding(.bottom, 28)
                }
            }
        } else {
            ContentUnavailableView("Artist Not Found", systemImage: "person.slash")
        }
    }
}

// MARK: - Albums Grid & Detail

struct AlbumsView: View {
    @Environment(EchoStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Albums")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(EchoTheme.textPrimary)
                    Text("\(store.filteredAlbums.count)")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(EchoTheme.textMuted)
                    Spacer()
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 168, maximum: 198), spacing: 16)], spacing: 18) {
                    ForEach(store.filteredAlbums) { album in
                        AlbumCardView(album: album)
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
    @State private var isHovered = false

    var body: some View {
        let state = store.selectionState(forAlbum: album)
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                ArtworkView(hash: album.artworkHash, artworkCache: store.artworkCache, cornerRadius: EchoTheme.radiusCard, iconSize: 34)
                    .aspectRatio(1, contentMode: .fit)
                    .shadow(color: .black.opacity(0.45), radius: 10, y: 4)

                if isHovered {
                    Button {
                        store.player.play(tracks: album.tracks, startingAt: 0)
                    } label: {
                        RoundedRectangle(cornerRadius: EchoTheme.radiusControl)
                            .fill(EchoTheme.neoMint)
                            .frame(width: 38, height: 36)
                            .overlay(Image(systemName: "play.fill").foregroundStyle(.black).font(.system(size: 15, weight: .bold)))
                            .shadow(color: EchoTheme.neoMint.opacity(0.45), radius: 8, y: 3)
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                }

                if state != .none || isHovered {
                    SyncStatePillButton(state: state, compact: true) {
                        store.toggleAlbumSync(album)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(6)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(album.title)
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(EchoTheme.textPrimary)
                    .lineLimit(1)
                Text(album.artist)
                    .font(.system(size: 11.5))
                    .foregroundStyle(EchoTheme.textSecondary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let year = album.year {
                        Text("\(year)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(EchoTheme.textMuted)
                    }
                    Text("\(album.tracks.count) tracks")
                        .font(.system(size: 10))
                        .foregroundStyle(EchoTheme.textMuted)
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
        .onTapGesture { store.navigate(to: .albumDetail(album.id)) }
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

    var body: some View {
        if let album = store.albumsByKey[albumKey] {
            let glow = ArtworkImageLoader.shared.dominantColor(forHash: album.artworkHash, artworkCache: store.artworkCache)
            let state = store.selectionState(forAlbum: album)
            let samplePath: String? = {
                guard let first = album.tracks.first, let dev = store.activeDevice else { return nil }
                return PathFormatter.relativeTrackPath(for: first, profile: dev)
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
                            ArtworkView(hash: album.artworkHash, artworkCache: store.artworkCache, cornerRadius: EchoTheme.radiusCard, iconSize: 50)
                                .frame(width: 174, height: 174)
                                .shadow(color: .black.opacity(0.55), radius: 20, y: 10)

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
                                    Button(album.artist) {
                                        store.navigate(to: .artistDetail(album.artist.lowercased()))
                                    }
                                    .font(.system(size: 13.5, weight: .bold))
                                    .foregroundStyle(EchoTheme.textPrimary)
                                    .buttonStyle(.plain)

                                    if let y = album.year {
                                        Text("· \(y)")
                                            .foregroundStyle(EchoTheme.textSecondary)
                                    }
                                    Text("· \(album.tracks.count) songs · \(Formatters.duration(album.totalDuration)) · \(Formatters.bytes(album.totalSize))")
                                        .foregroundStyle(EchoTheme.textSecondary)
                                }
                                .font(.system(size: 12.5))

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
                                        Menu {
                                            ForEach(store.playlists) { pl in
                                                Button(pl.name) {
                                                    store.addTracks(album.tracks, toPlaylistID: pl.id)
                                                }
                                            }
                                        } label: {
                                            Image(systemName: "text.badge.plus")
                                                .font(.system(size: 12.5, weight: .semibold))
                                                .frame(width: 30, height: 30)
                                                .background(EchoTheme.surfaceElevated)
                                                .foregroundStyle(EchoTheme.textPrimary)
                                                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                                        }
                                        .menuStyle(.borderlessButton)
                                        .fixedSize()
                                        .help("Choose any playlist to add entire album '\(album.title)'.")
                                    }
                                }
                                .padding(.top, 4)
                            }
                            Spacer()
                        }
                        .padding(26)
                    }

                    // Tracklist
                    VStack(spacing: 2) {
                        trackTableHeader(showAlbum: false)
                        Divider().overlay(EchoTheme.border).padding(.bottom, 4)

                        ForEach(Array(album.tracks.enumerated()), id: \.element.id) { idx, track in
                            TrackRowView(track: track, index: idx, showAlbumColumn: false) {
                                store.player.play(tracks: album.tracks, startingAt: idx)
                            }
                        }
                    }
                    .padding(.horizontal, 26)
                    .padding(.bottom, 28)
                }
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
            HStack {
                Text("All Tracks")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(EchoTheme.textPrimary)
                Text("\(items.count)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(EchoTheme.textMuted)
                Spacer()
                if !items.isEmpty {
                    NeoPrimaryButton(title: "Play All", icon: "play.fill") {
                        store.player.play(tracks: items, startingAt: 0)
                    }
                }
            }
            .padding(.horizontal, 26)
            .padding(.top, 22)
            .padding(.bottom, 14)

            trackTableHeader(showAlbum: true)
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

    var body: some View {
        if let playlist = store.playlists.first(where: { $0.id == playlistID }) {
            let playlistTracks = store.tracks(for: playlist)
            let isSynced = store.isPlaylistSelected(playlist)
            let isFocused = store.focusedPlaylist?.id == playlist.id
            let totalDuration = playlistTracks.reduce(0) { $0 + $1.duration }
            let totalBytes = playlistTracks.reduce(Int64(0)) { $0 + $1.fileSize }
            let glow = ArtworkImageLoader.shared.dominantColor(forHash: playlistTracks.first?.artworkHash, artworkCache: store.artworkCache)

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
                            PlaylistMosaicArtwork(tracks: playlistTracks, artworkCache: store.artworkCache, cornerRadius: EchoTheme.radiusCard)
                                .frame(width: 170, height: 170)
                                .shadow(color: .black.opacity(0.55), radius: 18, y: 8)
                                .draggable(EchoDragPayload.playlist(playlist.id).encode()) {
                                    DragPreviewPill(
                                        title: playlist.name,
                                        subtitle: "Playlist",
                                        artworkHash: playlistTracks.first?.artworkHash,
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

                                    if isFocused {
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

                                    if !playlist.description.isEmpty {
                                        Text(playlist.description)
                                            .font(.system(size: 13))
                                            .foregroundStyle(EchoTheme.textSecondary)
                                    }

                                    Text("\(playlistTracks.count) tracks · \(Formatters.duration(totalDuration)) · \(Formatters.bytes(totalBytes))")
                                        .font(.system(size: 12.5))
                                        .foregroundStyle(EchoTheme.textSecondary)

                                    if let dev = store.activeDevice {
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
                                        store.player.play(tracks: playlistTracks, startingAt: 0)
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
                            Spacer()
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
                        VStack(spacing: 2) {
                            trackTableHeader(showAlbum: true, isPlaylist: true)
                            Divider().overlay(EchoTheme.border).padding(.bottom, 4)

                            ForEach(Array(playlistTracks.enumerated()), id: \.offset) { idx, track in
                                TrackRowView(
                                    track: track,
                                    index: idx,
                                    showAlbumColumn: true,
                                    playlistContext: (playlist.id, idx)
                                ) {
                                    store.player.play(tracks: playlistTracks, startingAt: idx)
                                }
                            }
                        }
                        .padding(.horizontal, 26)
                        .padding(.bottom, 28)
                    }
                }
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
                        Button {
                            store.indexAllSources()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise")
                                Text("Re-Index All")
                                    .font(.system(size: 12.5, weight: .semibold))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(EchoTheme.surfaceElevated)
                            .foregroundStyle(EchoTheme.textPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                        }
                        .buttonStyle(.plain)
                        .disabled(store.isIndexing || store.sources.isEmpty)

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
                                        .foregroundStyle(EchoTheme.textPrimary)
                                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
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

@MainActor
private func trackTableHeader(showAlbum: Bool, isPlaylist: Bool = false) -> some View {
    HStack(spacing: 12) {
        Text("#")
            .frame(width: 26)
        Text("TITLE")
            .frame(minWidth: 180, maxWidth: .infinity, alignment: .leading)
        if showAlbum {
            Text("ALBUM")
                .frame(width: 170, alignment: .leading)
        }
        Text("FORMAT")
            .frame(width: 124, alignment: .trailing)
        Text(isPlaylist ? "MOVE" : "ADD")
            .frame(width: 34)
        Text("SYNC")
            .frame(width: 68, alignment: .trailing)
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

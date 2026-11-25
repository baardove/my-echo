import SwiftUI

// MARK: - Home Living-Room Hub

struct TVHomeView: View {
    @Environment(TVEchoStore.self) private var store
    @State private var selectedMacAlbum: TVAlbumGroup?
    @State private var selectedMacPlaylist: TVPlaylist?
    @State private var selectedNavAlbum: TVNavidromeAlbum?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 44) {
                // Hero Status Strip
                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("MY ECHO · LIVING ROOM HI-FI")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .tracking(2.4)
                            .foregroundStyle(EchoTVTheme.neoMint)
                        Text(store.activeSource == .mac
                             ? (store.isConnectedToMac ? store.macServerName : "Connect Your Mac or Navidrome")
                             : "Navidrome Streaming")
                            .font(.system(size: 46, weight: .black, design: .rounded))
                            .foregroundStyle(EchoTVTheme.textPrimary)
                    }

                    Spacer()

                    // Source Switcher Pills
                    HStack(spacing: 14) {
                        ForEach(TVLibrarySource.allCases) { src in
                            let selected = store.activeSource == src
                            Button {
                                store.activeSource = src
                                if src == .navidrome && store.navidromeAlbums.isEmpty && store.navidromeConfig.isConfigured {
                                    Task { await store.refreshNavidromeHome() }
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: src == .mac ? "laptopcomputer" : "dot.radiowaves.left.and.right")
                                    Text(src.rawValue)
                                }
                                .font(.system(size: 20, weight: .bold))
                                .padding(.horizontal, 22)
                                .padding(.vertical, 12)
                                .background(selected ? EchoTVTheme.neoMint : EchoTVTheme.surfaceElevated)
                                .foregroundStyle(selected ? Color.black : EchoTVTheme.textPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Live Party Mode Banner (one click to jump to Party TV Display)
                if store.partyStatus.isLive {
                    Button {
                        store.selectedTab = .partyTV
                    } label: {
                        HStack(spacing: 20) {
                            Image(systemName: "sparkles.tv.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(EchoTVTheme.partyMagenta)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("PARTY MODE IS LIVE ON MAC")
                                    .font(.system(size: 16, weight: .black, design: .monospaced))
                                    .foregroundStyle(EchoTVTheme.partyMagenta)
                                Text("Open Big-Screen Party Jukebox Display & Guest QR Code")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundStyle(EchoTVTheme.textPrimary)
                            }
                            Spacer()
                            Text("OPEN PARTY TV →")
                                .font(.system(size: 18, weight: .black, design: .monospaced))
                                .foregroundStyle(EchoTVTheme.neoMint)
                        }
                        .padding(24)
                        .background(
                            LinearGradient(
                                colors: [EchoTVTheme.partyMagenta.opacity(0.22), EchoTVTheme.surfaceElevated],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(EchoTVTheme.partyMagenta.opacity(0.6), lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }

                // Active Now Playing Strip (if playing on Apple TV)
                if let current = store.player.currentItem {
                    Button {
                        store.selectedTab = .nowPlaying
                    } label: {
                        HStack(spacing: 22) {
                            TVArtworkView(url: current.artworkURL, cornerRadius: 10)
                                .frame(width: 84, height: 84)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(store.player.isPlaying ? "NOW PLAYING ON APPLE TV" : "PAUSED ON APPLE TV")
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundStyle(EchoTVTheme.neoMint)
                                Text(current.title)
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundStyle(EchoTVTheme.textPrimary)
                                    .lineLimit(1)
                                Text("\(current.artist) · \(current.album)")
                                    .font(.system(size: 19))
                                    .foregroundStyle(EchoTVTheme.textSecondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            TVQualityBadge(
                                primary: current.formatPrimary,
                                detail: current.formatDetail,
                                isHiRes: current.isHiRes,
                                isLossless: current.isLossless
                            )
                        }
                        .padding(20)
                        .background(EchoTVTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(EchoTVTheme.neoMint.opacity(0.35), lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }

                // Main Home Shelves
                if store.activeSource == .mac {
                    macHomeShelves
                } else {
                    navidromeHomeShelves
                }
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 40)
        }
        .background(EchoTVTheme.canvas)
        .navigationDestination(item: $selectedMacAlbum) { album in
            TVMacAlbumDetailView(album: album)
        }
        .navigationDestination(item: $selectedMacPlaylist) { playlist in
            TVMacPlaylistDetailView(playlist: playlist)
        }
        .navigationDestination(item: $selectedNavAlbum) { album in
            TVNavidromeAlbumDetailView(album: album)
        }
    }

    @ViewBuilder
    private var macHomeShelves: some View {
        if !store.isConnectedToMac && store.albums.isEmpty {
            VStack(alignment: .leading, spacing: 20) {
                Text("Connect to My Echo on Mac")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(EchoTVTheme.textPrimary)
                Text("Stream your entire lossless FLAC/ALAC library, podcasts, Party Mode TV display, and control Mac playback from the couch.")
                    .font(.system(size: 22))
                    .foregroundStyle(EchoTVTheme.textSecondary)
                HStack(spacing: 18) {
                    Button {
                        store.selectedTab = .servers
                    } label: {
                        Label("Pair Mac or Configure Navidrome", systemImage: "server.rack")
                            .font(.system(size: 22, weight: .bold))
                            .padding(.horizontal, 28)
                            .padding(.vertical, 16)
                            .background(EchoTVTheme.neoMint)
                            .foregroundStyle(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    if let first = store.discoveredMacs.first {
                        Button {
                            store.selectDiscoveredMac(first)
                            store.selectedTab = .servers
                        } label: {
                            Label("Found: \(first.name) (\(first.host))", systemImage: "bonjour")
                                .font(.system(size: 20, weight: .semibold))
                                .padding(.horizontal, 24)
                                .padding(.vertical, 16)
                                .background(EchoTVTheme.surfaceElevated)
                                .foregroundStyle(EchoTVTheme.neoCyan)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(36)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(EchoTVTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        } else {
            // Recently Added Albums Shelf
            if !store.recentAlbums.isEmpty {
                VStack(alignment: .leading, spacing: 20) {
                    TVSectionHeader(
                        eyebrow: "Recently Added",
                        title: "Fresh Arrivals",
                        trailing: "\(store.albums.count) Albums · \(store.tracks.count) Tracks"
                    )
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 36) {
                            ForEach(store.recentAlbums.prefix(20)) { album in
                                TVAlbumCardTile(
                                    title: album.title,
                                    subtitle: album.artist,
                                    year: album.year,
                                    artworkURL: store.macArtworkURL(for: album.artworkHash)
                                ) {
                                    selectedMacAlbum = album
                                }
                            }
                        }
                        .padding(.vertical, 24)
                        .padding(.horizontal, 8)
                    }
                }
            }

            // Playlists Shelf
            if !store.playlists.isEmpty {
                VStack(alignment: .leading, spacing: 20) {
                    TVSectionHeader(eyebrow: "Mac Library", title: "Playlists", trailing: "\(store.playlists.count) Playlists")
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 28) {
                            ForEach(store.playlists) { pl in
                                let plTracks = store.tracks(for: pl)
                                let artHash = plTracks.compactMap(\.artworkHash).first
                                Button {
                                    selectedMacPlaylist = pl
                                } label: {
                                    HStack(spacing: 18) {
                                        TVArtworkView(url: store.macArtworkURL(for: artHash), cornerRadius: 10, fallbackIcon: "music.note.list")
                                            .frame(width: 110, height: 110)
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(pl.name)
                                                .font(.system(size: 24, weight: .bold))
                                                .foregroundStyle(EchoTVTheme.textPrimary)
                                                .lineLimit(1)
                                            Text("\(plTracks.count) tracks")
                                                .font(.system(size: 18, design: .monospaced))
                                                .foregroundStyle(EchoTVTheme.neoMint)
                                        }
                                        Spacer()
                                    }
                                    .padding(18)
                                    .frame(width: 420)
                                    .background(EchoTVTheme.surface)
                                }
                                .buttonStyle(.card)
                            }
                        }
                        .padding(.vertical, 18)
                        .padding(.horizontal, 8)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var navidromeHomeShelves: some View {
        if !store.navidromeConfig.isConfigured {
            VStack(alignment: .leading, spacing: 18) {
                Text("Configure Navidrome Streaming")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(EchoTVTheme.textPrimary)
                Text("Connect directly to your NAS / Tailscale Navidrome server to stream lossless audio even when your Mac is asleep.")
                    .font(.system(size: 22))
                    .foregroundStyle(EchoTVTheme.textSecondary)
                Button {
                    store.selectedTab = .servers
                } label: {
                    Label("Open Server Settings", systemImage: "server.rack")
                        .font(.system(size: 22, weight: .bold))
                        .padding(.horizontal, 28)
                        .padding(.vertical, 16)
                        .background(EchoTVTheme.neoCyan)
                        .foregroundStyle(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            .padding(36)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(EchoTVTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        } else {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    TVSectionHeader(eyebrow: "Navidrome", title: "Albums (\(store.navidromeAlbumListType.capitalized))")
                    HStack(spacing: 10) {
                        ForEach(["newest", "recent", "frequent", "random"], id: \.self) { kind in
                            Button(kind.capitalized) {
                                store.navidromeAlbumListType = kind
                                Task { await store.refreshNavidromeHome() }
                            }
                            .font(.system(size: 17, weight: .bold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(store.navidromeAlbumListType == kind ? EchoTVTheme.neoCyan : EchoTVTheme.surfaceElevated)
                            .foregroundStyle(store.navidromeAlbumListType == kind ? Color.black : EchoTVTheme.textPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .buttonStyle(.plain)
                        }
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 36) {
                        ForEach(store.navidromeAlbums) { alb in
                            TVAlbumCardTile(
                                title: alb.name,
                                subtitle: alb.artist,
                                year: alb.year,
                                artworkURL: store.navidromeArtworkURL(for: alb.coverArt)
                            ) {
                                selectedNavAlbum = alb
                            }
                        }
                    }
                    .padding(.vertical, 24)
                    .padding(.horizontal, 8)
                }
            }
        }
    }
}

// MARK: - Full Library Browser (Albums / Artists / Playlists)

struct TVLibraryView: View {
    enum Section: String, CaseIterable, Identifiable {
        case albums = "Albums"
        case artists = "Artists"
        case playlists = "Playlists"
        var id: String { rawValue }
    }

    @Environment(TVEchoStore.self) private var store
    @State private var section: Section = .albums
    @State private var selectedMacAlbum: TVAlbumGroup?
    @State private var selectedMacArtist: TVArtistGroup?
    @State private var selectedMacPlaylist: TVPlaylist?
    @State private var selectedNavAlbum: TVNavidromeAlbum?
    @State private var selectedNavArtist: TVNavidromeArtist?
    @State private var selectedNavPlaylist: TVNavidromePlaylist?

    private let gridColumns = [
        GridItem(.adaptive(minimum: 270, maximum: 300), spacing: 36)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                HStack(spacing: 18) {
                    ForEach(Section.allCases) { s in
                        Button(s.rawValue) {
                            section = s
                        }
                        .font(.system(size: 22, weight: .bold))
                        .padding(.horizontal, 26)
                        .padding(.vertical, 12)
                        .background(section == s ? EchoTVTheme.neoMint : EchoTVTheme.surfaceElevated)
                        .foregroundStyle(section == s ? Color.black : EchoTVTheme.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    ForEach(TVLibrarySource.allCases) { src in
                        Button(src.rawValue) {
                            store.activeSource = src
                            if src == .navidrome && store.navidromeAlbums.isEmpty && store.navidromeConfig.isConfigured {
                                Task { await store.refreshNavidromeHome() }
                            }
                        }
                        .font(.system(size: 18, weight: .bold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(store.activeSource == src ? EchoTVTheme.neoCyan : EchoTVTheme.surface)
                        .foregroundStyle(store.activeSource == src ? Color.black : EchoTVTheme.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .buttonStyle(.plain)
                    }
                }

                if store.activeSource == .mac {
                    macLibraryContent
                } else {
                    navidromeLibraryContent
                }
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 36)
        }
        .background(EchoTVTheme.canvas)
        .navigationDestination(item: $selectedMacAlbum) { TVMacAlbumDetailView(album: $0) }
        .navigationDestination(item: $selectedMacArtist) { TVMacArtistDetailView(artist: $0) }
        .navigationDestination(item: $selectedMacPlaylist) { TVMacPlaylistDetailView(playlist: $0) }
        .navigationDestination(item: $selectedNavAlbum) { TVNavidromeAlbumDetailView(album: $0) }
        .navigationDestination(item: $selectedNavArtist) { TVNavidromeArtistDetailView(artist: $0) }
        .navigationDestination(item: $selectedNavPlaylist) { TVNavidromePlaylistDetailView(playlist: $0) }
    }

    @ViewBuilder
    private var macLibraryContent: some View {
        switch section {
        case .albums:
            LazyVGrid(columns: gridColumns, spacing: 40) {
                ForEach(store.albums) { album in
                    TVAlbumCardTile(
                        title: album.title,
                        subtitle: album.artist,
                        year: album.year,
                        artworkURL: store.macArtworkURL(for: album.artworkHash)
                    ) {
                        selectedMacAlbum = album
                    }
                }
            }

        case .artists:
            LazyVGrid(columns: gridColumns, spacing: 36) {
                ForEach(store.artists) { artist in
                    Button {
                        selectedMacArtist = artist
                    } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            TVArtworkView(url: store.macArtworkURL(for: artist.artworkHash), cornerRadius: 130, fallbackIcon: "person.wave.2.fill")
                                .frame(width: 240, height: 240)
                            Text(artist.name)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(EchoTVTheme.textPrimary)
                                .lineLimit(1)
                            Text("\(artist.albums.count) albums · \(artist.trackCount) tracks")
                                .font(.system(size: 16, design: .monospaced))
                                .foregroundStyle(EchoTVTheme.textSecondary)
                        }
                        .padding(14)
                        .background(EchoTVTheme.surface)
                    }
                    .buttonStyle(.card)
                }
            }

        case .playlists:
            LazyVStack(spacing: 16) {
                ForEach(store.playlists) { pl in
                    let count = store.tracks(for: pl).count
                    Button {
                        selectedMacPlaylist = pl
                    } label: {
                        HStack(spacing: 22) {
                            let artHash = store.tracks(for: pl).compactMap(\.artworkHash).first
                            TVArtworkView(url: store.macArtworkURL(for: artHash), cornerRadius: 10, fallbackIcon: "music.note.list")
                                .frame(width: 84, height: 84)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(pl.name)
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundStyle(EchoTVTheme.textPrimary)
                                if !pl.description.isEmpty {
                                    Text(pl.description)
                                        .font(.system(size: 18))
                                        .foregroundStyle(EchoTVTheme.textSecondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                            Text("\(count) tracks")
                                .font(.system(size: 19, weight: .semibold, design: .monospaced))
                                .foregroundStyle(EchoTVTheme.neoMint)
                        }
                        .padding(20)
                        .background(EchoTVTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var navidromeLibraryContent: some View {
        switch section {
        case .albums:
            LazyVGrid(columns: gridColumns, spacing: 40) {
                ForEach(store.navidromeAlbums) { alb in
                    TVAlbumCardTile(
                        title: alb.name,
                        subtitle: alb.artist,
                        year: alb.year,
                        artworkURL: store.navidromeArtworkURL(for: alb.coverArt)
                    ) {
                        selectedNavAlbum = alb
                    }
                }
            }

        case .artists:
            LazyVStack(spacing: 14) {
                ForEach(store.navidromeArtists) { artist in
                    Button {
                        selectedNavArtist = artist
                    } label: {
                        HStack {
                            Text(artist.name)
                                .font(.system(size: 25, weight: .bold))
                                .foregroundStyle(EchoTVTheme.textPrimary)
                            Spacer()
                            Text("\(artist.albumCount) albums")
                                .font(.system(size: 18, design: .monospaced))
                                .foregroundStyle(EchoTVTheme.neoCyan)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 18)
                        .background(EchoTVTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }

        case .playlists:
            LazyVStack(spacing: 14) {
                ForEach(store.navidromePlaylists) { pl in
                    Button {
                        selectedNavPlaylist = pl
                    } label: {
                        HStack {
                            Text(pl.name)
                                .font(.system(size: 25, weight: .bold))
                                .foregroundStyle(EchoTVTheme.textPrimary)
                            Spacer()
                            Text("\(pl.songCount) songs")
                                .font(.system(size: 18, design: .monospaced))
                                .foregroundStyle(EchoTVTheme.neoCyan)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 18)
                        .background(EchoTVTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Mac Album, Artist & Playlist Detail Views

struct TVMacAlbumDetailView: View {
    @Environment(TVEchoStore.self) private var store
    let album: TVAlbumGroup

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 36) {
                HStack(alignment: .top, spacing: 40) {
                    TVArtworkView(url: store.macArtworkURL(for: album.artworkHash), cornerRadius: 18)
                        .frame(width: 360, height: 360)

                    VStack(alignment: .leading, spacing: 16) {
                        Text("ALBUM · MAC FULL CATALOG")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundStyle(EchoTVTheme.neoMint)
                        Text(album.title)
                            .font(.system(size: 46, weight: .black, design: .rounded))
                            .foregroundStyle(EchoTVTheme.textPrimary)
                        HStack(spacing: 12) {
                            Text(album.artist)
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(EchoTVTheme.textSecondary)
                            if let year = album.year {
                                Text("· \(String(year))")
                                    .font(.system(size: 24, design: .monospaced))
                                    .foregroundStyle(EchoTVTheme.textMuted)
                            }
                        }

                        if let first = album.tracks.first {
                            TVQualityBadge(
                                primary: first.formatPrimaryLabel,
                                detail: first.formatDetailLabel,
                                isHiRes: first.isHiRes,
                                isLossless: first.isLossless
                            )
                        }

                        HStack(spacing: 18) {
                            Button {
                                store.playMacAlbum(album, startingAt: 0)
                            } label: {
                                Label("Play on Apple TV", systemImage: "play.fill")
                                    .font(.system(size: 22, weight: .bold))
                                    .padding(.horizontal, 28)
                                    .padding(.vertical, 14)
                                    .background(EchoTVTheme.neoMint)
                                    .foregroundStyle(Color.black)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)

                            Button {
                                Task {
                                    await store.sendRemoteCommand("playAlbum", albumKey: album.title)
                                }
                            } label: {
                                Label("Play on Mac", systemImage: "desktopcomputer")
                                    .font(.system(size: 20, weight: .bold))
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 14)
                                    .background(EchoTVTheme.surfaceElevated)
                                    .foregroundStyle(EchoTVTheme.neoCyan)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 8)

                        if let ed = store.albumEditorialByKey[album.id.lowercased()],
                           let summary = ed.albumSummary ?? ed.artistSummary, !summary.isEmpty {
                            Text(summary)
                                .font(.system(size: 19))
                                .foregroundStyle(EchoTVTheme.textSecondary)
                                .lineLimit(4)
                                .padding(.top, 8)
                        }
                    }
                    Spacer()
                }

                LazyVStack(spacing: 12) {
                    ForEach(Array(album.tracks.enumerated()), id: \.element.id) { idx, track in
                        Button {
                            store.playMacAlbum(album, startingAt: idx)
                        } label: {
                            HStack(spacing: 20) {
                                Text(track.trackNumber.map { String(format: "%02d", $0) } ?? String(format: "%02d", idx + 1))
                                    .font(.system(size: 19, weight: .bold, design: .monospaced))
                                    .foregroundStyle(EchoTVTheme.textMuted)
                                    .frame(width: 48, alignment: .trailing)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(track.title)
                                        .font(.system(size: 23, weight: .bold))
                                        .foregroundStyle(EchoTVTheme.textPrimary)
                                    if track.artist.lowercased() != album.artist.lowercased() {
                                        Text(track.artist)
                                            .font(.system(size: 17))
                                            .foregroundStyle(EchoTVTheme.textSecondary)
                                    }
                                }

                                Spacer()

                                Text(track.formatPrimaryLabel)
                                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                                    .foregroundStyle(track.isHiRes ? EchoTVTheme.hiResGold : EchoTVTheme.neoMint)

                                Text(TVFormatters.duration(track.duration))
                                    .font(.system(size: 19, design: .monospaced))
                                    .foregroundStyle(EchoTVTheme.textSecondary)
                                    .frame(width: 90, alignment: .trailing)
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .background(EchoTVTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 40)
        }
        .background(EchoTVTheme.canvas)
    }
}

struct TVMacArtistDetailView: View {
    @Environment(TVEchoStore.self) private var store
    let artist: TVArtistGroup
    @State private var selectedAlbum: TVAlbumGroup?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                TVSectionHeader(
                    eyebrow: "Artist",
                    title: artist.name,
                    trailing: "\(artist.albums.count) Albums · \(artist.trackCount) Tracks"
                )

                if let bio = store.artistEditorialByKey[artist.name.lowercased()]?.summary, !bio.isEmpty {
                    Text(bio)
                        .font(.system(size: 20))
                        .foregroundStyle(EchoTVTheme.textSecondary)
                        .lineLimit(5)
                        .padding(22)
                        .background(EchoTVTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 270, maximum: 300), spacing: 36)], spacing: 36) {
                    ForEach(artist.albums) { alb in
                        TVAlbumCardTile(
                            title: alb.title,
                            subtitle: alb.artist,
                            year: alb.year,
                            artworkURL: store.macArtworkURL(for: alb.artworkHash)
                        ) {
                            selectedAlbum = alb
                        }
                    }
                }
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 40)
        }
        .background(EchoTVTheme.canvas)
        .navigationDestination(item: $selectedAlbum) { TVMacAlbumDetailView(album: $0) }
    }
}

struct TVMacPlaylistDetailView: View {
    @Environment(TVEchoStore.self) private var store
    let playlist: TVPlaylist

    var body: some View {
        let plTracks = store.tracks(for: playlist)
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                HStack {
                    TVSectionHeader(eyebrow: "Playlist", title: playlist.name, trailing: "\(plTracks.count) tracks")
                }

                HStack(spacing: 18) {
                    Button {
                        store.playMacPlaylist(playlist, startingAt: 0)
                    } label: {
                        Label("Play on Apple TV", systemImage: "play.fill")
                            .font(.system(size: 22, weight: .bold))
                            .padding(.horizontal, 28)
                            .padding(.vertical, 14)
                            .background(EchoTVTheme.neoMint)
                            .foregroundStyle(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task {
                            await store.sendRemoteCommand("playPlaylist", playlistID: playlist.id)
                        }
                    } label: {
                        Label("Play on Mac", systemImage: "desktopcomputer")
                            .font(.system(size: 20, weight: .bold))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(EchoTVTheme.surfaceElevated)
                            .foregroundStyle(EchoTVTheme.neoCyan)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }

                LazyVStack(spacing: 12) {
                    ForEach(Array(plTracks.enumerated()), id: \.element.id) { idx, track in
                        Button {
                            store.playMacPlaylist(playlist, startingAt: idx)
                        } label: {
                            HStack(spacing: 18) {
                                TVArtworkView(url: store.macArtworkURL(for: track.artworkHash), cornerRadius: 8)
                                    .frame(width: 60, height: 60)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(track.title)
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundStyle(EchoTVTheme.textPrimary)
                                    Text("\(track.artist) · \(track.effectiveAlbum)")
                                        .font(.system(size: 17))
                                        .foregroundStyle(EchoTVTheme.textSecondary)
                                }
                                Spacer()
                                Text(TVFormatters.duration(track.duration))
                                    .font(.system(size: 18, design: .monospaced))
                                    .foregroundStyle(EchoTVTheme.textMuted)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(EchoTVTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 40)
        }
        .background(EchoTVTheme.canvas)
    }
}

// MARK: - Navidrome Detail Views

struct TVNavidromeAlbumDetailView: View {
    @Environment(TVEchoStore.self) private var store
    let album: TVNavidromeAlbum
    @State private var songs: [TVNavidromeSong] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                HStack(alignment: .top, spacing: 36) {
                    TVArtworkView(url: store.navidromeArtworkURL(for: album.coverArt), cornerRadius: 18)
                        .frame(width: 340, height: 340)
                    VStack(alignment: .leading, spacing: 14) {
                        Text("NAVIDROME ALBUM")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundStyle(EchoTVTheme.neoCyan)
                        Text(album.name)
                            .font(.system(size: 44, weight: .black, design: .rounded))
                            .foregroundStyle(EchoTVTheme.textPrimary)
                        Text(album.artist)
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(EchoTVTheme.textSecondary)

                        Button {
                            store.playNavidromeSongs(songs, startingAt: 0)
                        } label: {
                            Label("Play Album", systemImage: "play.fill")
                                .font(.system(size: 22, weight: .bold))
                                .padding(.horizontal, 28)
                                .padding(.vertical, 14)
                                .background(EchoTVTheme.neoCyan)
                                .foregroundStyle(Color.black)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .disabled(songs.isEmpty)
                    }
                    Spacer()
                }

                if isLoading {
                    ProgressView("Loading tracks from Navidrome...")
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(songs.enumerated()), id: \.element.id) { idx, song in
                            Button {
                                store.playNavidromeSongs(songs, startingAt: idx)
                            } label: {
                                HStack(spacing: 18) {
                                    Text(song.track.map { String(format: "%02d", $0) } ?? String(format: "%02d", idx + 1))
                                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                                        .foregroundStyle(EchoTVTheme.textMuted)
                                        .frame(width: 44, alignment: .trailing)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(song.title)
                                            .font(.system(size: 22, weight: .bold))
                                            .foregroundStyle(EchoTVTheme.textPrimary)
                                        Text(song.artist)
                                            .font(.system(size: 17))
                                            .foregroundStyle(EchoTVTheme.textSecondary)
                                    }
                                    Spacer()
                                    if let suffix = song.suffix {
                                        Text(suffix.uppercased())
                                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                                            .foregroundStyle(EchoTVTheme.neoCyan)
                                    }
                                    Text(TVFormatters.duration(TimeInterval(song.duration)))
                                        .font(.system(size: 18, design: .monospaced))
                                        .foregroundStyle(EchoTVTheme.textSecondary)
                                }
                                .padding(.horizontal, 22)
                                .padding(.vertical, 16)
                                .background(EchoTVTheme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 40)
        }
        .background(EchoTVTheme.canvas)
        .task {
            isLoading = true
            songs = (try? await store.navidromeClient.fetchAlbumSongs(albumID: album.id, config: store.navidromeConfig)) ?? []
            isLoading = false
        }
    }
}

struct TVNavidromeArtistDetailView: View {
    @Environment(TVEchoStore.self) private var store
    let artist: TVNavidromeArtist
    @State private var albums: [TVNavidromeAlbum] = []
    @State private var selectedAlbum: TVNavidromeAlbum?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                TVSectionHeader(eyebrow: "Navidrome Artist", title: artist.name, trailing: "\(albums.count) Albums")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 270, maximum: 300), spacing: 36)], spacing: 36) {
                    ForEach(albums) { alb in
                        TVAlbumCardTile(
                            title: alb.name,
                            subtitle: alb.artist,
                            year: alb.year,
                            artworkURL: store.navidromeArtworkURL(for: alb.coverArt)
                        ) {
                            selectedAlbum = alb
                        }
                    }
                }
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 40)
        }
        .background(EchoTVTheme.canvas)
        .navigationDestination(item: $selectedAlbum) { TVNavidromeAlbumDetailView(album: $0) }
        .task {
            albums = (try? await store.navidromeClient.fetchArtistAlbums(artistID: artist.id, config: store.navidromeConfig)) ?? []
        }
    }
}

struct TVNavidromePlaylistDetailView: View {
    @Environment(TVEchoStore.self) private var store
    let playlist: TVNavidromePlaylist
    @State private var songs: [TVNavidromeSong] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                TVSectionHeader(eyebrow: "Navidrome Playlist", title: playlist.name, trailing: "\(songs.count) Songs")
                Button {
                    store.playNavidromeSongs(songs, startingAt: 0)
                } label: {
                    Label("Play Playlist", systemImage: "play.fill")
                        .font(.system(size: 22, weight: .bold))
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(EchoTVTheme.neoCyan)
                        .foregroundStyle(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(songs.isEmpty)

                LazyVStack(spacing: 12) {
                    ForEach(Array(songs.enumerated()), id: \.element.id) { idx, song in
                        Button {
                            store.playNavidromeSongs(songs, startingAt: idx)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(song.title)
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundStyle(EchoTVTheme.textPrimary)
                                    Text("\(song.artist) · \(song.album)")
                                        .font(.system(size: 17))
                                        .foregroundStyle(EchoTVTheme.textSecondary)
                                }
                                Spacer()
                                Text(TVFormatters.duration(TimeInterval(song.duration)))
                                    .font(.system(size: 18, design: .monospaced))
                                    .foregroundStyle(EchoTVTheme.textMuted)
                            }
                            .padding(.horizontal, 22)
                            .padding(.vertical, 16)
                            .background(EchoTVTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 40)
        }
        .background(EchoTVTheme.canvas)
        .task {
            songs = (try? await store.navidromeClient.fetchPlaylistSongs(playlistID: playlist.id, config: store.navidromeConfig)) ?? []
        }
    }
}

// MARK: - Unified Search View

struct TVSearchView: View {
    @Environment(TVEchoStore.self) private var store
    @State private var selectedMacAlbum: TVAlbumGroup?
    @State private var selectedNavAlbum: TVNavidromeAlbum?

    var body: some View {
        @Bindable var bindableStore = store
        let macAlbums = store.filteredMacAlbums(query: store.searchQuery)
        let macTracks = store.filteredMacTracks(query: store.searchQuery)

        ScrollView {
            VStack(alignment: .leading, spacing: 36) {
                if store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Search Your Entire Hi-Fi Collection")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundStyle(EchoTVTheme.textPrimary)
                        Text("Use Siri dictation or the keyboard to search albums and tracks across My Echo on Mac and Navidrome simultaneously.")
                            .font(.system(size: 22))
                            .foregroundStyle(EchoTVTheme.textSecondary)
                    }
                    .padding(40)
                } else {
                    if !macAlbums.isEmpty {
                        VStack(alignment: .leading, spacing: 18) {
                            TVSectionHeader(eyebrow: "My Echo Mac", title: "Albums", trailing: "\(macAlbums.count)")
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 32) {
                                    ForEach(macAlbums.prefix(20)) { alb in
                                        TVAlbumCardTile(
                                            title: alb.title,
                                            subtitle: alb.artist,
                                            year: alb.year,
                                            artworkURL: store.macArtworkURL(for: alb.artworkHash)
                                        ) {
                                            selectedMacAlbum = alb
                                        }
                                    }
                                }
                                .padding(.vertical, 20)
                            }
                        }
                    }

                    if !macTracks.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            TVSectionHeader(eyebrow: "My Echo Mac", title: "Tracks", trailing: "\(macTracks.count)")
                            LazyVStack(spacing: 10) {
                                ForEach(Array(macTracks.enumerated()), id: \.element.id) { idx, track in
                                    Button {
                                        store.playMacTracks(macTracks, startingAt: idx)
                                    } label: {
                                        HStack(spacing: 18) {
                                            TVArtworkView(url: store.macArtworkURL(for: track.artworkHash), cornerRadius: 8)
                                                .frame(width: 60, height: 60)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(track.title)
                                                    .font(.system(size: 22, weight: .bold))
                                                    .foregroundStyle(EchoTVTheme.textPrimary)
                                                Text("\(track.artist) · \(track.effectiveAlbum)")
                                                    .font(.system(size: 17))
                                                    .foregroundStyle(EchoTVTheme.textSecondary)
                                            }
                                            Spacer()
                                            Text(TVFormatters.duration(track.duration))
                                                .font(.system(size: 18, design: .monospaced))
                                                .foregroundStyle(EchoTVTheme.textMuted)
                                        }
                                        .padding(16)
                                        .background(EchoTVTheme.surface)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    if !store.navidromeSearchAlbums.isEmpty {
                        VStack(alignment: .leading, spacing: 18) {
                            TVSectionHeader(eyebrow: "Navidrome", title: "Albums", trailing: "\(store.navidromeSearchAlbums.count)")
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 32) {
                                    ForEach(store.navidromeSearchAlbums) { alb in
                                        TVAlbumCardTile(
                                            title: alb.name,
                                            subtitle: alb.artist,
                                            year: alb.year,
                                            artworkURL: store.navidromeArtworkURL(for: alb.coverArt)
                                        ) {
                                            selectedNavAlbum = alb
                                        }
                                    }
                                }
                                .padding(.vertical, 20)
                            }
                        }
                    }

                    if !store.navidromeSearchSongs.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            TVSectionHeader(eyebrow: "Navidrome", title: "Songs", trailing: "\(store.navidromeSearchSongs.count)")
                            LazyVStack(spacing: 10) {
                                ForEach(Array(store.navidromeSearchSongs.enumerated()), id: \.element.id) { idx, song in
                                    Button {
                                        store.playNavidromeSongs(store.navidromeSearchSongs, startingAt: idx)
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(song.title)
                                                    .font(.system(size: 22, weight: .bold))
                                                    .foregroundStyle(EchoTVTheme.textPrimary)
                                                Text("\(song.artist) · \(song.album)")
                                                    .font(.system(size: 17))
                                                    .foregroundStyle(EchoTVTheme.textSecondary)
                                            }
                                            Spacer()
                                            Text(TVFormatters.duration(TimeInterval(song.duration)))
                                                .font(.system(size: 18, design: .monospaced))
                                                .foregroundStyle(EchoTVTheme.neoCyan)
                                        }
                                        .padding(16)
                                        .background(EchoTVTheme.surface)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 30)
        }
        .background(EchoTVTheme.canvas)
        .searchable(text: $bindableStore.searchQuery, prompt: "Search artists, albums, or songs")
        .onChange(of: store.searchQuery) { _, newValue in
            store.triggerNavidromeSearch(query: newValue)
        }
        .navigationDestination(item: $selectedMacAlbum) { TVMacAlbumDetailView(album: $0) }
        .navigationDestination(item: $selectedNavAlbum) { TVNavidromeAlbumDetailView(album: $0) }
    }
}

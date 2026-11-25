import Foundation
import Observation

enum TVLibrarySource: String, CaseIterable, Identifiable {
    case mac = "My Echo Mac"
    case navidrome = "Navidrome"
    var id: String { rawValue }
}

enum TVTab: Hashable {
    case home
    case library
    case nowPlaying
    case partyTV
    case podcasts
    case macRemote
    case search
    case servers
}

@MainActor
@Observable
final class TVEchoStore {
    static let presetMacTailscaleURL = "http://100.86.21.27:48721"
    static let presetUnraidTailscaleNavidromeURL = "http://100.92.217.88:4533"

    let macClient = MacCatalogClient()
    let navidromeClient = TVNavidromeClient()
    let podcastService = TVPodcastService()
    let bonjourBrowser = TVBonjourMacBrowser()
    let player = TVAudioPlayer()

    // Navigation
    var selectedTab: TVTab = .home
    var activeSource: TVLibrarySource = .mac

    // Mac Connection & Full Library Catalog
    var macServerURL: String = ""
    var macTailscaleURL: String = presetMacTailscaleURL
    var pairingPIN: String = ""
    var discoveredMacs: [TVDiscoveredMacServer] = []
    var macServerName: String = ""
    var isConnectedToMac: Bool = false
    var isLoadingMacCatalog: Bool = false
    var macStatusText: String = "Searching for My Echo on Mac..."
    var macError: String?

    var tracks: [TVTrack] = []
    var tracksByID: [String: TVTrack] = [:]
    var albums: [TVAlbumGroup] = []
    var recentAlbums: [TVAlbumGroup] = []
    var artists: [TVArtistGroup] = []
    var playlists: [TVPlaylist] = []
    var albumEditorialByKey: [String: TVAlbumEditorial] = [:]
    var artistEditorialByKey: [String: TVArtistEditorial] = [:]

    // Podcasts
    var podcastFeeds: [TVPodcastFeed] = []
    var episodesByShowID: [String: [TVPodcastEpisode]] = [:]
    var isRefreshingPodcasts: Bool = false
    var podcastStatusMessage: String?

    // Navidrome
    var navidromeConfig: TVNavidromeConfig = TVNavidromeConfig()
    var navidromeStatusText: String?
    var navidromeError: String?
    var isLoadingNavidrome: Bool = false
    var navidromeAlbumListType: String = "newest"
    var navidromeAlbums: [TVNavidromeAlbum] = []
    var navidromeArtists: [TVNavidromeArtist] = []
    var navidromePlaylists: [TVNavidromePlaylist] = []

    // Search (Unified across Mac + Navidrome)
    var searchQuery: String = ""
    var navidromeSearchArtists: [TVNavidromeArtist] = []
    var navidromeSearchAlbums: [TVNavidromeAlbum] = []
    var navidromeSearchSongs: [TVNavidromeSong] = []
    var isSearchingNavidrome: Bool = false

    // Mac Remote Control
    var remoteState: TVRemotePlaybackState?
    var remoteError: String?
    var isSendingRemoteCommand: Bool = false

    // Party Mode TV Display
    var partyStatus: TVPartyStatus = TVPartyStatus()
    var partyState: TVPartyPlaylistState?
    var standalonePartyURL: String = ""
    var partyError: String?

    // Toast feedback
    var toastMessage: String?

    private let defaults = UserDefaults.standard
    private var remotePollTask: Task<Void, Never>?
    private var partyPollTask: Task<Void, Never>?
    private var navSearchTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?

    init() {
        loadSettings()
        player.onNavidromeStreamPlayed = { [weak self] songID in
            guard let self, self.navidromeConfig.isConfigured else { return }
            let cfg = self.navidromeConfig
            Task { await self.navidromeClient.scrobble(songID: songID, config: cfg) }
        }
        setupBonjour()

        Task {
            if !macServerURL.isEmpty && !pairingPIN.isEmpty {
                await refreshMacCatalog(silent: true)
            }
            if navidromeConfig.isEnabled && navidromeConfig.isConfigured {
                await refreshNavidromeHome()
            }
            if !isConnectedToMac && navidromeConfig.isEnabled && navidromeConfig.isConfigured {
                activeSource = .navidrome
            }
        }
    }

    // MARK: - Persistence

    private func loadSettings() {
        macServerURL = defaults.string(forKey: "tv.macServerURL") ?? ""
        macTailscaleURL = defaults.string(forKey: "tv.macTailscaleURL") ?? Self.presetMacTailscaleURL
        pairingPIN = defaults.string(forKey: "tv.pairingPIN") ?? ""
        standalonePartyURL = defaults.string(forKey: "tv.standalonePartyURL") ?? ""

        if let data = defaults.data(forKey: "tv.navidromeConfig"),
           let decoded = try? JSONDecoder().decode(TVNavidromeConfig.self, from: data) {
            navidromeConfig = decoded
        } else {
            navidromeConfig = TVNavidromeConfig(
                isEnabled: false,
                serverURL: Self.presetUnraidTailscaleNavidromeURL,
                savedAddresses: [
                    TVNavidromeServerAddress(label: "Tailscale", url: Self.presetUnraidTailscaleNavidromeURL)
                ],
                username: "",
                password: "",
                streamQuality: .original
            )
        }
    }

    func saveMacSettings() {
        defaults.set(macServerURL, forKey: "tv.macServerURL")
        defaults.set(macTailscaleURL, forKey: "tv.macTailscaleURL")
        defaults.set(pairingPIN, forKey: "tv.pairingPIN")
        defaults.set(standalonePartyURL, forKey: "tv.standalonePartyURL")
    }

    func saveNavidromeSettings() {
        if let data = try? JSONEncoder().encode(navidromeConfig) {
            defaults.set(data, forKey: "tv.navidromeConfig")
        }
    }

    func showToast(_ message: String) {
        toastMessage = message
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(for: .seconds(3.0))
            guard !Task.isCancelled else { return }
            toastMessage = nil
        }
    }

    // MARK: - Bonjour Discovery

    private func setupBonjour() {
        bonjourBrowser.onServersUpdated = { [weak self] servers in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.discoveredMacs = servers
                if let first = servers.first {
                    if self.macServerURL.isEmpty {
                        self.macServerURL = first.baseURLString
                        self.saveMacSettings()
                    }
                    if !self.isConnectedToMac && !self.pairingPIN.isEmpty {
                        await self.refreshMacCatalog(silent: true)
                    } else if !self.isConnectedToMac {
                        self.macStatusText = "Found \(first.name) — enter 6-digit PIN in Servers"
                    }
                }
            }
        }
        bonjourBrowser.start()
    }

    func selectDiscoveredMac(_ server: TVDiscoveredMacServer) {
        macServerURL = server.baseURLString
        saveMacSettings()
        showToast("Selected \(server.name) (\(server.host))")
        if !pairingPIN.isEmpty {
            Task { await refreshMacCatalog() }
        }
    }

    // MARK: - Mac Full Catalog Loading

    var effectiveMacURL: String {
        let primary = macServerURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !primary.isEmpty { return primary }
        if let first = discoveredMacs.first { return first.baseURLString }
        return macTailscaleURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func macArtworkURL(for hash: String?) -> URL? {
        guard !effectiveMacURL.isEmpty, !pairingPIN.isEmpty else { return nil }
        return MacCatalogClient.artworkURL(serverURL: effectiveMacURL, pin: pairingPIN, hash: hash)
    }

    func refreshMacCatalog(silent: Bool = false) async {
        let url = effectiveMacURL
        let pin = pairingPIN.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else {
            if !silent { macError = "Select a discovered Mac or enter your Mac's LAN/Tailscale URL." }
            return
        }
        guard !pin.isEmpty else {
            if !silent { macError = "Enter your 6-digit Pairing PIN from My Echo Settings on Mac." }
            return
        }

        isLoadingMacCatalog = true
        macError = nil
        defer { isLoadingMacCatalog = false }

        do {
            let catalog = try await macClient.fetchFullCatalog(serverURL: url, pin: pin)
            applyMacCatalog(catalog)
            isConnectedToMac = true
            macStatusText = "Connected to \(catalog.serverName) · \(catalog.tracks.count) tracks"
            if !silent {
                showToast("Connected to \(catalog.serverName)")
            }
        } catch {
            // Fallback to Tailscale URL if LAN failed and Tailscale URL is different
            let tsURL = macTailscaleURL.trimmingCharacters(in: .whitespacesAndNewlines)
            if !tsURL.isEmpty && tsURL != url {
                if let catalog = try? await macClient.fetchFullCatalog(serverURL: tsURL, pin: pin) {
                    macServerURL = tsURL
                    saveMacSettings()
                    applyMacCatalog(catalog)
                    isConnectedToMac = true
                    macStatusText = "Connected via Tailscale to \(catalog.serverName)"
                    return
                }
            }
            isConnectedToMac = false
            macError = error.localizedDescription
            macStatusText = "Disconnected"
        }
    }

    private func applyMacCatalog(_ catalog: TVFullCatalogPayload) {
        macServerName = catalog.serverName
        tracks = catalog.tracks
        tracksByID = Dictionary(uniqueKeysWithValues: catalog.tracks.map { ($0.id, $0) })
        playlists = catalog.playlists
        podcastFeeds = catalog.podcastFeeds
        partyStatus = catalog.partyStatus

        var albumEd: [String: TVAlbumEditorial] = [:]
        for item in catalog.albumEditorial { albumEd[item.albumKey.lowercased()] = item }
        albumEditorialByKey = albumEd

        var artistEd: [String: TVArtistEditorial] = [:]
        for item in catalog.artistEditorial { artistEd[item.artistKey.lowercased()] = item }
        artistEditorialByKey = artistEd

        // Group tracks into albums
        let grouped = Dictionary(grouping: catalog.tracks, by: \.albumKey)
        var builtAlbums: [TVAlbumGroup] = []
        builtAlbums.reserveCapacity(grouped.count)
        for (key, albumTracks) in grouped {
            let sortedTracks = albumTracks.sorted {
                ($0.discNumber ?? 1, $0.trackNumber ?? 999, $0.title.lowercased())
                < ($1.discNumber ?? 1, $1.trackNumber ?? 999, $1.title.lowercased())
            }
            let first = sortedTracks[0]
            let artistName = first.effectiveArtist
            let art = sortedTracks.compactMap(\.artworkHash).first
            let year = sortedTracks.compactMap(\.year).first
            builtAlbums.append(TVAlbumGroup(
                id: key,
                title: first.effectiveAlbum,
                artist: artistName,
                year: year,
                artworkHash: art,
                tracks: sortedTracks
            ))
        }
        albums = builtAlbums.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        recentAlbums = builtAlbums.sorted {
            let aDate = $0.tracks.map(\.modifiedAt).max() ?? .distantPast
            let bDate = $1.tracks.map(\.modifiedAt).max() ?? .distantPast
            return aDate > bDate
        }

        // Group albums into artists
        let byArtist = Dictionary(grouping: builtAlbums) { $0.artist.lowercased() }
        artists = byArtist.values.map { list -> TVArtistGroup in
            let sorted = list.sorted { ($0.year ?? 0) > ($1.year ?? 0) }
            let name = sorted.first?.artist ?? "Unknown Artist"
            let count = sorted.reduce(0) { $0 + $1.tracks.count }
            return TVArtistGroup(
                id: name.lowercased(),
                name: name,
                albums: sorted,
                trackCount: count,
                artworkHash: sorted.compactMap(\.artworkHash).first
            )
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        // Group podcast episodes
        var epMap: [String: [TVPodcastEpisode]] = [:]
        for ep in catalog.episodes {
            epMap[ep.showID, default: []].append(ep)
        }
        for key in epMap.keys {
            epMap[key]?.sort { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }
        }
        episodesByShowID = epMap
    }

    func tracks(for playlist: TVPlaylist) -> [TVTrack] {
        playlist.trackIDs.compactMap { tracksByID[$0] }
    }

    // MARK: - Playback on Apple TV (Mac LAN Streams)

    func playableItem(from track: TVTrack) -> TVPlayableItem? {
        guard let streamURL = MacCatalogClient.catalogTrackStreamURL(
            serverURL: effectiveMacURL,
            pin: pairingPIN,
            trackID: track.id
        ) else { return nil }
        return TVPlayableItem(
            id: "mac-\(track.id)",
            title: track.title,
            artist: track.artist.isEmpty ? track.effectiveArtist : track.artist,
            album: track.effectiveAlbum,
            albumKey: track.albumKey,
            duration: track.duration,
            formatPrimary: track.formatPrimaryLabel,
            formatDetail: track.formatDetailLabel,
            isHiRes: track.isHiRes,
            isLossless: track.isLossless,
            artworkURL: macArtworkURL(for: track.artworkHash),
            source: .macStream(trackID: track.id, url: streamURL),
            sourceBadge: "MAC LAN"
        )
    }

    func playMacTracks(_ trackList: [TVTrack], startingAt index: Int = 0, openNowPlaying: Bool = true) {
        let items = trackList.compactMap(playableItem(from:))
        guard !items.isEmpty else { return }
        player.play(items: items, startingAt: min(index, items.count - 1))
        if openNowPlaying {
            selectedTab = .nowPlaying
        }
    }

    func playMacAlbum(_ album: TVAlbumGroup, startingAt index: Int = 0) {
        playMacTracks(album.tracks, startingAt: index)
    }

    func playMacPlaylist(_ playlist: TVPlaylist, startingAt index: Int = 0) {
        playMacTracks(tracks(for: playlist), startingAt: index)
    }

    // MARK: - Podcasts (Refresh RSS & Stream on TV)

    func refreshPodcastShow(_ feed: TVPodcastFeed) async {
        guard !feed.feedURL.isEmpty else { return }
        isRefreshingPodcasts = true
        defer { isRefreshingPodcasts = false }
        do {
            let fresh = try await podcastService.fetchEpisodes(for: feed)
            if !fresh.isEmpty {
                var existing = episodesByShowID[feed.id] ?? []
                let existingIDs = Set(existing.map(\.id))
                for ep in fresh where !existingIDs.contains(ep.id) {
                    existing.append(ep)
                }
                existing.sort { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }
                episodesByShowID[feed.id] = existing
                podcastStatusMessage = "Updated \(feed.title) (\(existing.count) episodes)"
            }
        } catch {
            podcastStatusMessage = "RSS refresh failed: \(error.localizedDescription)"
        }
    }

    func playPodcastEpisode(_ episode: TVPodcastEpisode, show: TVPodcastFeed) {
        let streamURL: URL?
        if let raw = episode.audioURL, let direct = URL(string: raw), !raw.isEmpty {
            streamURL = direct
        } else {
            streamURL = MacCatalogClient.catalogEpisodeStreamURL(
                serverURL: effectiveMacURL,
                pin: pairingPIN,
                episodeID: episode.id
            )
        }
        guard let streamURL else {
            showToast("No audio stream URL available for this episode")
            return
        }

        let artURL: URL? = {
            if let hash = episode.artworkHash ?? show.artworkHash, let u = macArtworkURL(for: hash) {
                return u
            }
            if let raw = show.artworkURL { return URL(string: raw) }
            return nil
        }()

        let item = TVPlayableItem(
            id: "pod-\(episode.id)",
            title: episode.title,
            artist: show.title,
            album: show.author.isEmpty ? "Podcast" : show.author,
            albumKey: nil,
            duration: episode.duration,
            formatPrimary: episode.fileExtension.uppercased(),
            formatDetail: "PODCAST",
            isHiRes: false,
            isLossless: false,
            artworkURL: artURL,
            source: .podcastStream(episodeID: episode.id, url: streamURL),
            sourceBadge: "PODCAST"
        )
        player.play(items: [item], startingAt: 0)
        selectedTab = .nowPlaying
    }

    // MARK: - Navidrome Streaming

    func navidromeArtworkURL(for coverArtID: String?) -> URL? {
        TVNavidromeClient.coverArtURL(coverArtID: coverArtID, size: 600, config: navidromeConfig)
    }

    func testNavidromeConnection() async {
        navidromeError = nil
        navidromeStatusText = "Testing..."
        do {
            let banner = try await navidromeClient.ping(config: navidromeConfig)
            navidromeConfig.isEnabled = true
            saveNavidromeSettings()
            navidromeStatusText = "Connected · \(banner)"
            showToast("Connected to \(banner)")
            await refreshNavidromeHome()
        } catch {
            navidromeError = error.localizedDescription
            navidromeStatusText = "Failed"
        }
    }

    func refreshNavidromeHome() async {
        guard navidromeConfig.isConfigured else { return }
        isLoadingNavidrome = true
        navidromeError = nil
        defer { isLoadingNavidrome = false }
        let cfg = navidromeConfig
        let listType = navidromeAlbumListType
        do {
            async let albs = navidromeClient.fetchAlbums(type: listType, size: 60, config: cfg)
            async let arts = navidromeClient.fetchArtists(config: cfg)
            async let pls = navidromeClient.fetchPlaylists(config: cfg)
            let (a, r, p) = try await (albs, arts, pls)
            navidromeAlbums = a
            navidromeArtists = r
            navidromePlaylists = p
            navidromeStatusText = "\(a.count) albums · \(r.count) artists"
        } catch {
            navidromeError = error.localizedDescription
        }
    }

    func playableItem(from song: TVNavidromeSong) -> TVPlayableItem? {
        guard let url = TVNavidromeClient.streamURL(songID: song.id, config: navidromeConfig) else { return nil }
        let suffix = (song.suffix ?? "mp3").uppercased()
        let isLossless = navidromeConfig.streamQuality == .original && ["FLAC", "ALAC", "WAV", "AIFF"].contains(suffix)
        let detail: String? = {
            if navidromeConfig.streamQuality != .original { return "\(navidromeConfig.streamQuality.rawValue)k" }
            if let br = song.bitRate, br > 0 { return "\(br)k" }
            return nil
        }()
        return TVPlayableItem(
            id: "nd-\(song.id)",
            title: song.title,
            artist: song.artist,
            album: song.album,
            albumKey: song.album.lowercased(),
            duration: TimeInterval(song.duration),
            formatPrimary: navidromeConfig.streamQuality == .original ? suffix : "MP3",
            formatDetail: detail,
            isHiRes: false,
            isLossless: isLossless,
            artworkURL: navidromeArtworkURL(for: song.coverArt),
            source: .navidromeStream(songID: song.id, url: url),
            sourceBadge: "NAVIDROME"
        )
    }

    func playNavidromeSongs(_ songs: [TVNavidromeSong], startingAt index: Int = 0) {
        let items = songs.compactMap(playableItem(from:))
        guard !items.isEmpty else { return }
        player.play(items: items, startingAt: min(index, items.count - 1))
        selectedTab = .nowPlaying
    }

    func playNavidromeAlbum(_ album: TVNavidromeAlbum) async {
        do {
            let songs = try await navidromeClient.fetchAlbumSongs(albumID: album.id, config: navidromeConfig)
            playNavidromeSongs(songs, startingAt: 0)
        } catch {
            showToast("Failed to load album: \(error.localizedDescription)")
        }
    }

    func playNavidromePlaylist(_ playlist: TVNavidromePlaylist) async {
        do {
            let songs = try await navidromeClient.fetchPlaylistSongs(playlistID: playlist.id, config: navidromeConfig)
            playNavidromeSongs(songs, startingAt: 0)
        } catch {
            showToast("Failed to load playlist: \(error.localizedDescription)")
        }
    }

    // MARK: - Unified Search

    func filteredMacAlbums(query: String) -> [TVAlbumGroup] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }
        return albums.filter {
            $0.title.lowercased().contains(q) || $0.artist.lowercased().contains(q)
        }
    }

    func filteredMacTracks(query: String) -> [TVTrack] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }
        return Array(tracks.filter {
            $0.title.lowercased().contains(q)
                || $0.artist.lowercased().contains(q)
                || $0.album.lowercased().contains(q)
        }.prefix(40))
    }

    func triggerNavidromeSearch(query: String) {
        navSearchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, navidromeConfig.isEnabled, navidromeConfig.isConfigured else {
            navidromeSearchArtists = []
            navidromeSearchAlbums = []
            navidromeSearchSongs = []
            return
        }
        let cfg = navidromeConfig
        navSearchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            isSearchingNavidrome = true
            defer { isSearchingNavidrome = false }
            if let res = try? await navidromeClient.search(query: trimmed, config: cfg) {
                navidromeSearchArtists = res.artists
                navidromeSearchAlbums = res.albums
                navidromeSearchSongs = res.songs
            }
        }
    }

    // MARK: - Mac Remote Control

    func startRemotePolling() {
        stopRemotePolling()
        remotePollTask = Task {
            while !Task.isCancelled {
                await refreshRemoteStateOnce()
                try? await Task.sleep(for: .milliseconds(1200))
            }
        }
    }

    func stopRemotePolling() {
        remotePollTask?.cancel()
        remotePollTask = nil
    }

    func refreshRemoteStateOnce() async {
        let url = effectiveMacURL
        let pin = pairingPIN.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty, !pin.isEmpty else { return }
        do {
            let state = try await macClient.fetchRemoteState(serverURL: url, pin: pin)
            remoteState = state
            partyStatus = state.partyStatus
            remoteError = nil
        } catch {
            remoteError = error.localizedDescription
        }
    }

    func sendRemoteCommand(
        _ action: String,
        seconds: Double? = nil,
        volume: Double? = nil,
        queueIndex: Int? = nil,
        trackID: String? = nil,
        albumKey: String? = nil,
        playlistID: String? = nil
    ) async {
        let url = effectiveMacURL
        let pin = pairingPIN.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty, !pin.isEmpty else {
            showToast("Pair with My Echo on Mac first")
            return
        }
        isSendingRemoteCommand = true
        defer { isSendingRemoteCommand = false }
        let req = TVRemoteCommandRequest(
            action: action,
            seconds: seconds,
            volume: volume,
            queueIndex: queueIndex,
            trackID: trackID,
            albumKey: albumKey,
            playlistID: playlistID
        )
        do {
            let resp = try await macClient.sendRemoteCommand(serverURL: url, pin: pin, command: req)
            if let st = resp.state {
                remoteState = st
                partyStatus = st.partyStatus
            }
            if let msg = resp.message, !msg.isEmpty {
                showToast(msg)
            }
            remoteError = nil
        } catch {
            remoteError = error.localizedDescription
            showToast("Mac remote error: \(error.localizedDescription)")
        }
    }

    // MARK: - Party Mode Big-Screen Polling

    func startPartyPolling() {
        stopPartyPolling()
        partyPollTask = Task {
            while !Task.isCancelled {
                await refreshPartyStateOnce()
                try? await Task.sleep(for: .milliseconds(1500))
            }
        }
    }

    func stopPartyPolling() {
        partyPollTask?.cancel()
        partyPollTask = nil
    }

    func refreshPartyStateOnce() async {
        // 1. Prefer authenticated Mac Companion endpoint when paired
        let url = effectiveMacURL
        let pin = pairingPIN.trimmingCharacters(in: .whitespacesAndNewlines)
        if !url.isEmpty && !pin.isEmpty {
            do {
                let env = try await macClient.fetchPartyEnvelope(serverURL: url, pin: pin)
                partyStatus = env.status
                partyState = env.state
                partyError = nil
                return
            } catch {
                partyError = error.localizedDescription
            }
        }

        // 2. Fallback: Standalone direct Party Mode URL (no PIN required)
        let direct = standalonePartyURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !direct.isEmpty {
            do {
                let st = try await macClient.fetchDirectPartyState(partyURL: direct)
                partyState = st
                partyStatus = TVPartyStatus(isLive: true, port: nil, lanIP: nil, joinURL: MacCatalogClient.normalizeBase(direct), playlistName: st.playlistName)
                partyError = nil
            } catch {
                partyError = error.localizedDescription
            }
        }
    }

    func partyArtworkURL(for hash: String?) -> URL? {
        if let u = macArtworkURL(for: hash) {
            return u
        }
        if let join = partyStatus.joinURL ?? (standalonePartyURL.isEmpty ? nil : standalonePartyURL) {
            return MacCatalogClient.partyArtworkURL(partyBaseURL: join, hash: hash)
        }
        return nil
    }
}

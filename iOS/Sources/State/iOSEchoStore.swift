import Foundation
import UIKit
import Observation

@MainActor
@Observable
final class iOSEchoStore {
    // Preloaded Tailscale Presets (Editable in Sync & Servers)
    static let presetMacTailscaleURL = "http://100.86.21.27:48721"
    static let presetUnraidTailscaleNavidromeURL = "http://100.92.217.88:4533"

    let syncEngine = WiFiSyncEngine()
    let podcastManager = iOSPodcastManager()
    let navidromeClient = NavidromeClient()
    let bonjourBrowser = BonjourMacBrowser()
    let player = iOSAudioPlayer()

    // Offline Synced Library State
    var localManifest: SyncManifestPayload?
    var tracks: [SyncedTrack] = []
    var albums: [SyncedAlbumGroup] = []
    var playlists: [SyncedPlaylist] = []
    var episodes: [SyncedEpisode] = []
    var albumEditorialByKey: [String: SyncedAlbumEditorial] = [:]
    var artistEditorialByKey: [String: SyncedArtistEditorial] = [:]
    var fetchingEditorialKeys: Set<String> = []
    var localStorageBytes: Int64 = 0

    // Standalone Podcasts State (Synced Feeds + Mac-Synced Episodes + Device RSS Downloads)
    var podcastShows: [iOSPodcastShow] = []
    var isRefreshingPodcasts: Bool = false
    var downloadingEpisodeIDs: Set<String> = []
    var podcastStatusText: String?
    var podcastError: String?
    var autoDownloadNewPodcasts: Bool = false

    // Podcasts Search + Offline/Online Directory Discovery & Mac Sync-Back
    var podcastSearchQuery: String = ""
    var podcastSearchIsOnline: Bool = false
    var podcastDirectory: iOSPodcastDirectory = .all
    var podcastCategory: iOSPodcastCategory? = .featured
    var podcastDirectoryResults: [iOSPodcastSearchResult] = iOSPodcastManager.curatedFeaturedShows
    var isSearchingPodcastDirectory: Bool = false
    var subscribingPodcastFeedURLs: Set<String> = []
    var pendingMacPodcastSubscriptions: [PendingMacPodcastSubscription] = []

    // Mac Wi-Fi / Tailscale Auto-Sync Config & Live Status
    var macServerURL: String = ""
    var macTailscaleURL: String = presetMacTailscaleURL
    var pairingPIN: String = ""
    var autoSyncEnabled: Bool = true
    var discoveredMacs: [DiscoveredMacServer] = []
    var isSyncing: Bool = false
    var syncStatusText: String = "Ready"
    var syncProgressFraction: Double = 0
    var syncCurrentItem: String = ""
    var lastSyncedAt: Date?
    var syncError: String?

    // Navidrome / Tailscale On-The-Go Streaming State
    var navidromeConfig: NavidromeConfig = NavidromeConfig()
    var navidromeStatusText: String?
    var navidromeError: String?
    var isTestingNavidrome: Bool = false
    var navidromeAlbums: [NavidromeAlbum] = []
    var navidromeArtists: [NavidromeArtist] = []
    var navidromePlaylists: [NavidromePlaylist] = []
    var navidromeAlbumListType: String = "newest"
    var navidromeSearchQuery: String = ""
    var navidromeSearchArtists: [NavidromeArtist] = []
    var navidromeSearchAlbums: [NavidromeAlbum] = []
    var navidromeSearchSongs: [NavidromeSong] = []
    var isSearchingNavidrome: Bool = false
    var isLoadingNavidrome: Bool = false
    var navidromeOfflineTracks: [NavidromeOfflineTrack] = []
    var downloadingNavidromeIDs: Set<String> = []

    // Mac Full Library Remote Search & Add-to-Sync State
    var macSearchAlbums: [MacLibrarySearchAlbum] = []
    var macSearchTracks: [MacLibrarySearchTrack] = []
    var isSearchingMacLibrary: Bool = false
    var macSearchError: String?
    var togglingMacSyncIDs: Set<String> = []

    // Lidarr Search & Order (Relayed via Mac)
    var lidarrConfiguredOnMac: Bool = true
    var lidarrSearchAlbums: [MacLidarrAlbumItem] = []
    var lidarrSearchTracks: [MacLidarrTrackItem] = []
    var isSearchingLidarr: Bool = false
    var lidarrError: String?
    var orderingLidarrIDs: Set<String> = []
    var orderedLidarrIDs: Set<String> = []
    var lidarrFeedbackMessage: String?

    private var navidromeSearchTask: Task<Void, Never>?
    private var macLibrarySearchTask: Task<Void, Never>?
    private var lidarrSearchTask: Task<Void, Never>?
    private var podcastDirectorySearchTask: Task<Void, Never>?
    private var autoSyncLoopTask: Task<Void, Never>?
    private let defaults = UserDefaults.standard

    init() {
        loadSavedSettings()
        player.onNavidromeStreamPlayed = { [weak self] songID in
            guard let self, self.navidromeConfig.isConfigured else { return }
            let cfg = self.navidromeConfig
            Task { await self.navidromeClient.scrobble(songID: songID, config: cfg) }
        }
        setupBonjour()
        Task {
            await reloadLocalLibrary()
            startAutoSyncPolling()
            if navidromeConfig.isEnabled && navidromeConfig.isConfigured {
                await refreshNavidromeHome()
            }
        }
    }

    // MARK: - Settings Persistence

    private func loadSavedSettings() {
        var savedURL = defaults.string(forKey: "macServerURL") ?? ""
        // Auto-clear any broken link-local IPv6 URL saved by an earlier build
        if savedURL.lowercased().contains("[fe80:") {
            savedURL = ""
            defaults.set("", forKey: "macServerURL")
        }
        macServerURL = savedURL
        let savedMacTS = defaults.string(forKey: "macTailscaleURL") ?? ""
        macTailscaleURL = savedMacTS.isEmpty ? Self.presetMacTailscaleURL : savedMacTS
        pairingPIN = defaults.string(forKey: "pairingPIN") ?? ""
        if defaults.object(forKey: "autoSyncEnabled") != nil {
            autoSyncEnabled = defaults.bool(forKey: "autoSyncEnabled")
        }
        if defaults.object(forKey: "autoDownloadNewPodcasts") != nil {
            autoDownloadNewPodcasts = defaults.bool(forKey: "autoDownloadNewPodcasts")
        }
        if defaults.object(forKey: "iosCrossfadeEnabled") != nil {
            player.crossfadeEnabled = defaults.bool(forKey: "iosCrossfadeEnabled")
        }
        let savedFade = defaults.double(forKey: "iosCrossfadeDuration")
        if savedFade >= 1.0 {
            player.crossfadeDuration = savedFade
        }
        if let ndData = defaults.data(forKey: "navidromeConfig"),
           let decoded = try? JSONDecoder().decode(NavidromeConfig.self, from: ndData) {
            navidromeConfig = decoded
        }
        if navidromeConfig.serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            navidromeConfig.serverURL = Self.presetUnraidTailscaleNavidromeURL
        }
        ensureDefaultNavidromeAddresses()
        if let pendingData = defaults.data(forKey: "pendingMacPodcastSubscriptions"),
           let decoded = try? JSONDecoder().decode([PendingMacPodcastSubscription].self, from: pendingData) {
            pendingMacPodcastSubscriptions = decoded
        }
    }

    private func savePendingMacPodcastSubscriptions() {
        if let data = try? JSONEncoder().encode(pendingMacPodcastSubscriptions) {
            defaults.set(data, forKey: "pendingMacPodcastSubscriptions")
        }
    }

    private func ensureDefaultNavidromeAddresses() {
        var list = navidromeConfig.savedAddresses
        let activeNorm = Self.normalizedURLString(navidromeConfig.serverURL)
        if !activeNorm.isEmpty && !list.contains(where: { Self.normalizedURLString($0.url) == activeNorm }) {
            let inferredLabel = activeNorm.contains("100.") || activeNorm.contains(".ts.net") ? "Tailscale" : "Home LAN"
            list.insert(NavidromeServerAddress(label: inferredLabel, url: activeNorm), at: 0)
        }
        let tsPreset = Self.normalizedURLString(Self.presetUnraidTailscaleNavidromeURL)
        if !list.contains(where: { Self.normalizedURLString($0.url) == tsPreset }) {
            list.append(NavidromeServerAddress(label: "Unraid Tailscale", url: tsPreset))
        }
        navidromeConfig.savedAddresses = list
    }

    private static func normalizedURLString(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return "" }
        if !s.lowercased().hasPrefix("http://") && !s.lowercased().hasPrefix("https://") {
            s = "http://" + s
        }
        while s.hasSuffix("/") { s.removeLast() }
        return s
    }

    func saveWiFiSyncSettings() {
        defaults.set(macServerURL.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "macServerURL")
        defaults.set(macTailscaleURL.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "macTailscaleURL")
        defaults.set(pairingPIN.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "pairingPIN")
        defaults.set(autoSyncEnabled, forKey: "autoSyncEnabled")
        defaults.set(autoDownloadNewPodcasts, forKey: "autoDownloadNewPodcasts")
    }

    func saveCrossfadeSettings() {
        defaults.set(player.crossfadeEnabled, forKey: "iosCrossfadeEnabled")
        defaults.set(player.crossfadeDuration, forKey: "iosCrossfadeDuration")
    }

    func saveNavidromeConfig(_ cfg: NavidromeConfig) {
        var updated = cfg
        let activeNorm = Self.normalizedURLString(updated.serverURL)
        if !activeNorm.isEmpty {
            updated.serverURL = activeNorm
            if !updated.savedAddresses.contains(where: { Self.normalizedURLString($0.url) == activeNorm }) {
                let label = activeNorm.contains("100.") || activeNorm.contains(".ts.net") ? "Tailscale" : "Home LAN"
                updated.savedAddresses.append(NavidromeServerAddress(label: label, url: activeNorm))
            }
        }
        navidromeConfig = updated
        if let data = try? JSONEncoder().encode(updated) {
            defaults.set(data, forKey: "navidromeConfig")
        }
    }

    func switchNavidromeAddress(_ address: NavidromeServerAddress) {
        var cfg = navidromeConfig
        cfg.serverURL = Self.normalizedURLString(address.url)
        cfg.isEnabled = true
        saveNavidromeConfig(cfg)
        navidromeAlbums = []
        navidromeSearchAlbums = []
        navidromeSearchSongs = []
        navidromeError = nil
        if cfg.isConfigured {
            Task { await refreshNavidromeHome() }
        }
    }

    func addNavidromeAddress(label: String, url: String, selectImmediately: Bool = true) {
        let normURL = Self.normalizedURLString(url)
        guard !normURL.isEmpty else { return }
        let cleanLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalLabel = cleanLabel.isEmpty
            ? (normURL.contains("100.") || normURL.contains(".ts.net") ? "Tailscale" : "Home LAN")
            : cleanLabel

        var cfg = navidromeConfig
        if let idx = cfg.savedAddresses.firstIndex(where: { Self.normalizedURLString($0.url) == normURL }) {
            cfg.savedAddresses[idx].label = finalLabel
        } else {
            cfg.savedAddresses.append(NavidromeServerAddress(label: finalLabel, url: normURL))
        }
        if selectImmediately {
            cfg.serverURL = normURL
            cfg.isEnabled = true
        }
        saveNavidromeConfig(cfg)
        if selectImmediately && cfg.isConfigured {
            Task { await refreshNavidromeHome() }
        }
    }

    func removeNavidromeAddress(id: UUID) {
        var cfg = navidromeConfig
        cfg.savedAddresses.removeAll { $0.id == id }
        if !cfg.savedAddresses.contains(where: { Self.normalizedURLString($0.url) == Self.normalizedURLString(cfg.serverURL) }),
           let first = cfg.savedAddresses.first {
            cfg.serverURL = first.url
        }
        saveNavidromeConfig(cfg)
    }

    // MARK: - Bonjour Discovery & Automatic Wi-Fi Sync

    private func setupBonjour() {
        bonjourBrowser.onServersUpdated = { [weak self] servers in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.discoveredMacs = servers
                if let first = servers.first,
                   self.macServerURL.isEmpty || self.macServerURL.lowercased().contains("[fe80:") {
                    self.macServerURL = first.baseURLString
                    self.saveWiFiSyncSettings()
                }
                if self.autoSyncEnabled && !self.pairingPIN.isEmpty && !self.isSyncing {
                    await self.checkAndAutoSyncIfNeeded()
                }
            }
        }
        bonjourBrowser.start()
    }

    func startAutoSyncPolling() {
        autoSyncLoopTask?.cancel()
        autoSyncLoopTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { break }
                if self.autoSyncEnabled && !self.macServerURL.isEmpty && !self.pairingPIN.isEmpty && !self.isSyncing {
                    await self.checkAndAutoSyncIfNeeded()
                }
                try? await Task.sleep(for: .seconds(18))
            }
        }
    }

    func handleAppBecameActive() {
        bonjourBrowser.start()
        Task {
            if autoSyncEnabled && !macServerURL.isEmpty && !pairingPIN.isEmpty && !isSyncing {
                await checkAndAutoSyncIfNeeded()
            }
        }
    }

    func selectDiscoveredMac(_ server: DiscoveredMacServer) {
        macServerURL = server.baseURLString
        saveWiFiSyncSettings()
        if !pairingPIN.isEmpty {
            Task { await syncNow() }
        }
    }

    func checkAndAutoSyncIfNeeded() async {
        guard !macServerURL.isEmpty, !pairingPIN.isEmpty, !isSyncing else { return }
        do {
            let ping = try await syncEngine.ping(serverURL: macServerURL, pin: pairingPIN)
            if localManifest?.manifestVersion != ping.manifestVersion || !pendingMacPodcastSubscriptions.isEmpty {
                await syncNow()
            }
        } catch {
            // Silent when off home Wi-Fi (e.g. away on Tailscale cellular)
        }
    }

    func syncNow() async {
        var url = macServerURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if (url.isEmpty || url.lowercased().contains("[fe80:")), let discovered = discoveredMacs.first {
            url = discovered.baseURLString
            macServerURL = url
            saveWiFiSyncSettings()
        }
        if url.isEmpty {
            url = macTailscaleURL.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let pin = pairingPIN.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty, !pin.isEmpty else {
            syncError = "Select your Mac (or enter its Wi-Fi / Tailscale URL) and 6-digit Pairing PIN first."
            return
        }
        guard !isSyncing else { return }

        saveWiFiSyncSettings()
        isSyncing = true
        syncError = nil
        syncProgressFraction = 0
        syncStatusText = "Connecting to \(url)..."
        let deviceName = UIDevice.current.name
        let localPodcastIndex = await podcastManager.downloadIndex()

        func runAttempt(targetURL: String) async throws -> SyncManifestPayload {
            try await syncEngine.performSync(
                serverURL: targetURL,
                pin: pin,
                clientName: deviceName,
                localPodcastIndex: localPodcastIndex
            ) { [weak self] update in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.syncStatusText = update.phase
                    self.syncCurrentItem = update.currentTitle
                    self.syncProgressFraction = Double(update.completed) / Double(max(1, update.total))
                }
            }
        }

        do {
            var candidates: [String] = [url]
            if let bonjourURL = discoveredMacs.first?.baseURLString, !candidates.contains(bonjourURL) {
                candidates.append(bonjourURL)
            }
            let tsURL = macTailscaleURL.trimmingCharacters(in: .whitespacesAndNewlines)
            if !tsURL.isEmpty && !candidates.contains(tsURL) {
                candidates.append(tsURL)
            }

            var updatedManifest: SyncManifestPayload?
            var lastError: Error?
            for (idx, candidate) in candidates.enumerated() {
                do {
                    if idx > 0 {
                        syncStatusText = "Retrying via \(candidate)..."
                    }
                    if !pendingMacPodcastSubscriptions.isEmpty {
                        syncStatusText = "Syncing \(pendingMacPodcastSubscriptions.count) new podcast(s) to Mac..."
                        await flushPendingMacPodcastSubscriptions(using: candidate, pin: pin)
                    }
                    let result = try await runAttempt(targetURL: candidate)
                    updatedManifest = result
                    if idx == 1 && discoveredMacs.first?.baseURLString == candidate {
                        macServerURL = candidate
                        saveWiFiSyncSettings()
                    }
                    break
                } catch {
                    lastError = error
                }
            }

            guard let updated = updatedManifest else {
                throw lastError ?? URLError(.cannotConnectToHost)
            }
            localManifest = updated
            lastSyncedAt = Date()
            await reloadLocalLibrary()
            syncStatusText = "Synced · \(tracks.count) tracks, \(podcastShows.count) feeds"
            isSyncing = false
        } catch {
            if let urlErr = error as? URLError, urlErr.code == .notConnectedToInternet {
                syncError = "Could not reach \(macServerURL) (\(error.localizedDescription)). On iPhone, enable Settings → Privacy & Security → Local Network → My Echo."
            } else {
                syncError = "Could not reach \(macServerURL): \(error.localizedDescription)"
            }
            syncStatusText = "Sync failed"
            isSyncing = false
        }
    }

    // MARK: - Local Offline Library Hydration

    func reloadLocalLibrary() async {
        let manifest = await syncEngine.loadLocalManifest()
        let syncBytes = await syncEngine.localStorageBytes()
        let ndOffline = await navidromeClient.loadOfflineTracks()
        let ndBytes = await navidromeClient.offlineStorageBytes()
        localManifest = manifest
        navidromeOfflineTracks = ndOffline
        localStorageBytes = syncBytes + ndBytes
        let macTracks = manifest?.tracks ?? []
        let macKeys = Set(macTracks.map { "\($0.title.lowercased())::\($0.artist.lowercased())" })
        let extraND = ndOffline
            .map { $0.asSyncedTrack() }
            .filter { !macKeys.contains("\($0.title.lowercased())::\($0.artist.lowercased())") }
        tracks = macTracks + extraND
        playlists = manifest?.playlists ?? []
        episodes = manifest?.episodes ?? []

        // Hydrate synced album & artist editorial info from Mac manifest (preserving any locally cached device entries)
        loadDeviceEditorialCacheIfNeeded()
        if let manifest {
            for item in manifest.albumEditorial {
                albumEditorialByKey[item.albumKey.lowercased()] = item
            }
            for item in manifest.artistEditorial {
                artistEditorialByKey[item.artistKey.lowercased()] = item
            }
            saveDeviceEditorialCache()
        }

        if let manifest {
            let pendingFeeds = Set(pendingMacPodcastSubscriptions.map { Self.normalizedFeedURL($0.feedURL) })
            podcastShows = await podcastManager.mergeFromMacManifest(
                feeds: manifest.podcastFeeds,
                syncedEpisodes: manifest.episodes,
                pendingFeedURLs: pendingFeeds
            )
        } else {
            podcastShows = await podcastManager.loadShows()
        }

        let grouped = Dictionary(grouping: tracks, by: \.albumKey)
        albums = grouped.compactMap { key, list in
            let sorted = list.sorted {
                ($0.discNumber ?? 1, $0.trackNumber ?? 999, $0.title) < ($1.discNumber ?? 1, $1.trackNumber ?? 999, $1.title)
            }
            guard let first = sorted.first else { return nil }
            return SyncedAlbumGroup(
                id: key,
                title: first.effectiveAlbum,
                artist: SyncedAlbumGroup.resolveDisplayArtist(for: sorted),
                year: sorted.compactMap(\.year).first,
                artworkHash: sorted.first(where: { $0.artworkHash != nil })?.artworkHash,
                tracks: sorted
            )
        }
        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    // MARK: - Album & Artist Editorial Info (Synced from Mac + Local Cache + Online Fallback)

    private static var editorialCacheFileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("MyEchoiOS", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("editorial-cache.json")
    }

    private struct EditorialCacheFile: Codable {
        var albums: [String: SyncedAlbumEditorial]
        var artists: [String: SyncedArtistEditorial]
    }

    private var loadedEditorialCacheOnce = false

    private func loadDeviceEditorialCacheIfNeeded() {
        guard !loadedEditorialCacheOnce else { return }
        loadedEditorialCacheOnce = true
        guard let data = try? Data(contentsOf: Self.editorialCacheFileURL) else { return }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .secondsSince1970
        if let decoded = try? dec.decode(EditorialCacheFile.self, from: data) {
            albumEditorialByKey = decoded.albums
            artistEditorialByKey = decoded.artists
        }
    }

    private func saveDeviceEditorialCache() {
        let payload = EditorialCacheFile(albums: albumEditorialByKey, artists: artistEditorialByKey)
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .secondsSince1970
        if let data = try? enc.encode(payload) {
            try? data.write(to: Self.editorialCacheFileURL, options: .atomic)
        }
    }

    func albumEditorial(for albumTitle: String) -> SyncedAlbumEditorial? {
        let key = albumTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return albumEditorialByKey[key]
    }

    func artistEditorial(for artistName: String) -> SyncedArtistEditorial? {
        let key = artistName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return artistEditorialByKey[key]
    }

    func ensureEditorialLoaded(albumTitle: String, artist: String, force: Bool = false) async {
        let albumKey = albumTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !albumKey.isEmpty else { return }
        if !force, let cached = albumEditorialByKey[albumKey], cached.hasDisplayableContent,
           Date().timeIntervalSince(cached.fetchedAt) < 14 * 24 * 60 * 60 {
            return
        }
        guard !fetchingEditorialKeys.contains(albumKey) else { return }
        fetchingEditorialKeys.insert(albumKey)
        defer { fetchingEditorialKeys.remove(albumKey) }

        let primaryArtist = artist
            .components(separatedBy: CharacterSet(charactersIn: ",;&"))
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? artist
        let isVarious = primaryArtist.lowercased() == "various artists" || primaryArtist.lowercased() == "unknown artist"

        async let dz = fetchDeezerEditorial(artist: isVarious ? "" : primaryArtist, album: albumTitle)
        async let albumWiki = fetchWikipediaExtract(
            candidates: ["\(albumTitle) (\(primaryArtist) album)", "\(albumTitle) (album)", albumTitle],
            artistHint: isVarious ? nil : primaryArtist
        )
        async let artistWiki: String? = isVarious
            ? nil
            : fetchWikipediaExtract(
                candidates: ["\(primaryArtist) (band)", "\(primaryArtist) (musician)", "\(primaryArtist) (singer)", primaryArtist],
                artistHint: nil
            )

        let dzInfo = await dz
        let aSum = await albumWiki
        let arSum = await artistWiki
        let now = Date()

        let info = SyncedAlbumEditorial(
            albumKey: albumKey,
            releaseDate: dzInfo.releaseDate,
            label: dzInfo.label,
            genres: dzInfo.genres,
            albumFans: dzInfo.albumFans,
            artistFans: dzInfo.artistFans,
            artistAlbumCount: dzInfo.artistAlbumCount,
            albumSummary: aSum,
            artistSummary: arSum,
            artistImageURL: dzInfo.artistImageURL,
            fetchedAt: now
        )
        albumEditorialByKey[albumKey] = info
        if !isVarious {
            let arKey = primaryArtist.lowercased()
            artistEditorialByKey[arKey] = SyncedArtistEditorial(
                artistKey: arKey,
                summary: arSum,
                fans: dzInfo.artistFans,
                albumCount: dzInfo.artistAlbumCount,
                imageURL: dzInfo.artistImageURL,
                fetchedAt: now
            )
        }
        saveDeviceEditorialCache()
    }

    private struct DeezerFetchedInfo {
        var releaseDate: String?
        var label: String?
        var genres: [String] = []
        var albumFans: Int?
        var artistFans: Int?
        var artistAlbumCount: Int?
        var artistImageURL: String?
    }

    private func fetchDeezerEditorial(artist: String, album: String) async -> DeezerFetchedInfo {
        var out = DeezerFetchedInfo()
        let q = artist.isEmpty ? album : "\(artist) \(album)"
        guard let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.deezer.com/search/album?q=\(encoded)&limit=5") else { return out }
        var req = URLRequest(url: url, timeoutInterval: 8)
        req.setValue("MyEchoiOS/1.3", forHTTPHeaderField: "User-Agent")
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = json["data"] as? [[String: Any]],
              let match = list.first,
              let albumID = match["id"] as? Int,
              let detailURL = URL(string: "https://api.deezer.com/album/\(albumID)") else { return out }

        var dReq = URLRequest(url: detailURL, timeoutInterval: 8)
        dReq.setValue("MyEchoiOS/1.3", forHTTPHeaderField: "User-Agent")
        if let (dData, dResp) = try? await URLSession.shared.data(for: dReq),
           (dResp as? HTTPURLResponse)?.statusCode == 200,
           let detail = try? JSONSerialization.jsonObject(with: dData) as? [String: Any] {
            if let rd = detail["release_date"] as? String, !rd.isEmpty, rd != "0000-00-00" { out.releaseDate = rd }
            if let lbl = detail["label"] as? String, !lbl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { out.label = lbl }
            if let fans = detail["fans"] as? Int, fans > 0 { out.albumFans = fans }
            if let gObj = detail["genres"] as? [String: Any], let gArr = gObj["data"] as? [[String: Any]] {
                out.genres = gArr.compactMap { $0["name"] as? String }.filter { !$0.isEmpty }
            }
            if let aObj = detail["artist"] as? [String: Any], let aID = aObj["id"] as? Int {
                out.artistImageURL = aObj["picture_medium"] as? String
                if let aURL = URL(string: "https://api.deezer.com/artist/\(aID)") {
                    var aReq = URLRequest(url: aURL, timeoutInterval: 8)
                    aReq.setValue("MyEchoiOS/1.3", forHTTPHeaderField: "User-Agent")
                    if let (aData, aResp) = try? await URLSession.shared.data(for: aReq),
                       (aResp as? HTTPURLResponse)?.statusCode == 200,
                       let aDetail = try? JSONSerialization.jsonObject(with: aData) as? [String: Any] {
                        if let f = aDetail["nb_fan"] as? Int, f > 0 { out.artistFans = f }
                        if let c = aDetail["nb_album"] as? Int, c > 0 { out.artistAlbumCount = c }
                    }
                }
            }
        }
        return out
    }

    private func fetchWikipediaExtract(candidates: [String], artistHint: String?) async -> String? {
        let keywords = ["album", "band", "singer", "musician", "music", "song", "record", "electronic", "rock", "pop", "hip hop", "jazz", "composer", "dj", "duo", "group", "rapper", "producer", "studio"]
        let normArtist = artistHint?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        for raw in candidates {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let slug = trimmed.replacingOccurrences(of: " ", with: "_")
            guard let enc = slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                  let url = URL(string: "https://en.wikipedia.org/api/rest_v1/page/summary/\(enc)") else { continue }
            var req = URLRequest(url: url, timeoutInterval: 6)
            req.setValue("MyEchoiOS/1.3", forHTTPHeaderField: "User-Agent")
            guard let (data, resp) = try? await URLSession.shared.data(for: req),
                  (resp as? HTTPURLResponse)?.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  (json["type"] as? String) != "disambiguation",
                  let extract = json["extract"] as? String else { continue }
            let clean = extract.trimmingCharacters(in: .whitespacesAndNewlines)
            guard clean.count >= 40 else { continue }
            let lower = clean.lowercased()
            guard keywords.contains(where: { lower.contains($0) }) else { continue }
            if let normArtist, !normArtist.isEmpty,
               !trimmed.lowercased().contains(normArtist) && !lower.contains(normArtist) {
                continue
            }
            return clean
        }
        return nil
    }

    // MARK: - Standalone Podcast RSS Refresh & Deduplicated Direct Downloads

    func refreshAllPodcastFeeds(downloadNew: Bool = false) async {
        guard !isRefreshingPodcasts else { return }
        isRefreshingPodcasts = true
        podcastError = nil
        podcastStatusText = "Refreshing \(podcastShows.count) podcast feeds..."
        var updatedShows = podcastShows
        var newDownloads = 0

        for show in updatedShows where !show.feedURL.isEmpty {
            do {
                updatedShows = try await podcastManager.refreshFeed(showID: show.id)
                podcastShows = updatedShows
                if downloadNew || autoDownloadNewPodcasts,
                   let freshShow = updatedShows.first(where: { $0.id == show.id }) {
                    let limit = freshShow.episodesToKeep > 0 ? freshShow.episodesToKeep : 3
                    let missing = freshShow.episodes.prefix(limit).filter { $0.downloadOrigin == .none && !$0.audioURL.isEmpty }
                    for ep in missing {
                        downloadingEpisodeIDs.insert(ep.id)
                        if let after = try? await podcastManager.downloadEpisode(showID: freshShow.id, episodeID: ep.id) {
                            updatedShows = after
                            podcastShows = after
                            newDownloads += 1
                        }
                        downloadingEpisodeIDs.remove(ep.id)
                    }
                }
            } catch {
                podcastError = "\(show.title): \(error.localizedDescription)"
            }
        }

        localStorageBytes = await syncEngine.localStorageBytes()
        podcastStatusText = newDownloads > 0
            ? "Updated feeds · downloaded \(newDownloads) new episode\(newDownloads == 1 ? "" : "s")"
            : "Feeds up to date"
        isRefreshingPodcasts = false
    }

    func refreshPodcastShow(_ show: iOSPodcastShow, downloadNew: Bool = false) async {
        isRefreshingPodcasts = true
        podcastError = nil
        do {
            var updated = try await podcastManager.refreshFeed(showID: show.id)
            podcastShows = updated
            if downloadNew, let freshShow = updated.first(where: { $0.id == show.id }) {
                let limit = freshShow.episodesToKeep > 0 ? freshShow.episodesToKeep : 3
                let missing = freshShow.episodes.prefix(limit).filter { $0.downloadOrigin == .none && !$0.audioURL.isEmpty }
                for ep in missing {
                    downloadingEpisodeIDs.insert(ep.id)
                    if let after = try? await podcastManager.downloadEpisode(showID: freshShow.id, episodeID: ep.id) {
                        updated = after
                        podcastShows = after
                    }
                    downloadingEpisodeIDs.remove(ep.id)
                }
            }
            localStorageBytes = await syncEngine.localStorageBytes()
            podcastStatusText = "Refreshed \(show.title)"
        } catch {
            podcastError = error.localizedDescription
        }
        isRefreshingPodcasts = false
    }

    func downloadPodcastEpisode(_ episode: iOSPodcastEpisode) async {
        guard !downloadingEpisodeIDs.contains(episode.id) else { return }
        downloadingEpisodeIDs.insert(episode.id)
        podcastError = nil
        do {
            podcastShows = try await podcastManager.downloadEpisode(showID: episode.showID, episodeID: episode.id)
            localStorageBytes = await syncEngine.localStorageBytes()
        } catch {
            podcastError = error.localizedDescription
        }
        downloadingEpisodeIDs.remove(episode.id)
    }

    func deletePodcastEpisodeDownload(_ episode: iOSPodcastEpisode) async {
        podcastShows = await podcastManager.deleteDownloadedEpisode(showID: episode.showID, episodeID: episode.id)
        localStorageBytes = await syncEngine.localStorageBytes()
    }

    // MARK: - Online Podcast Directory Search & Subscribe (Synced Back to Mac)

    static func normalizedFeedURL(_ raw: String) -> String {
        raw.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
    }

    func isPodcastSubscribed(feedURL: String) -> Bool {
        let target = Self.normalizedFeedURL(feedURL)
        guard !target.isEmpty else { return false }
        return podcastShows.contains { Self.normalizedFeedURL($0.feedURL) == target }
    }

    func selectPodcastCategory(_ category: iOSPodcastCategory) {
        if podcastCategory == category && category != .featured {
            podcastCategory = nil
        } else {
            podcastCategory = category
        }
        schedulePodcastDirectorySearch(immediate: true)
    }

    func schedulePodcastDirectorySearch(immediate: Bool = false) {
        podcastDirectorySearchTask?.cancel()
        let q = podcastSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard podcastSearchIsOnline else {
            isSearchingPodcastDirectory = false
            return
        }
        let activeCategory = podcastCategory
        if q.isEmpty && (activeCategory == nil || activeCategory == .featured) {
            podcastDirectoryResults = iOSPodcastManager.curatedFeaturedShows
            isSearchingPodcastDirectory = false
            return
        }
        isSearchingPodcastDirectory = true
        podcastError = nil
        let directory = podcastDirectory
        podcastDirectorySearchTask = Task { [weak self] in
            if !immediate {
                try? await Task.sleep(for: .milliseconds(280))
            }
            guard !Task.isCancelled, let self else { return }
            await self.searchPodcastDirectories(query: q, directory: directory, category: activeCategory)
        }
    }

    func searchPodcastDirectories(query: String, directory: iOSPodcastDirectory, category: iOSPodcastCategory?) async {
        isSearchingPodcastDirectory = true
        podcastError = nil
        do {
            let results = try await podcastManager.searchDirectories(query: query, directory: directory, category: category)
            guard !Task.isCancelled else { return }
            podcastDirectoryResults = results
            isSearchingPodcastDirectory = false
        } catch {
            guard !Task.isCancelled else { return }
            podcastError = error.localizedDescription
            isSearchingPodcastDirectory = false
        }
    }

    func subscribeToPodcastFromiOS(_ result: iOSPodcastSearchResult) async {
        let norm = Self.normalizedFeedURL(result.feedURL)
        guard !norm.isEmpty, !subscribingPodcastFeedURLs.contains(norm) else { return }
        if isPodcastSubscribed(feedURL: result.feedURL) {
            podcastStatusText = "Already subscribed to \(result.title)"
            return
        }

        subscribingPodcastFeedURLs.insert(norm)
        podcastError = nil
        podcastStatusText = "Subscribing to \(result.title)..."

        let pin = pairingPIN.trimmingCharacters(in: .whitespacesAndNewlines)
        let urls = macCandidateURLs()
        var macShowID: String?
        var syncedToMac = false

        if !pin.isEmpty && !urls.isEmpty {
            let req = MacPodcastSubscribeRequest(
                feedURL: result.feedURL,
                fallbackArtworkURL: result.artworkURL,
                selectForSync: true
            )
            for url in urls {
                if let res = try? await syncEngine.subscribePodcastOnMac(serverURL: url, pin: pin, request: req), res.ok {
                    macShowID = res.showID
                    syncedToMac = true
                    break
                }
            }
        }

        do {
            podcastShows = try await podcastManager.subscribeLocally(result: result, preferredShowID: macShowID)
            if syncedToMac {
                pendingMacPodcastSubscriptions.removeAll { Self.normalizedFeedURL($0.feedURL) == norm }
                savePendingMacPodcastSubscriptions()
                podcastStatusText = "Subscribed & added to Mac: \(result.title)"
                Task { [weak self] in
                    await self?.syncNow()
                }
            } else {
                if !pendingMacPodcastSubscriptions.contains(where: { Self.normalizedFeedURL($0.feedURL) == norm }) {
                    pendingMacPodcastSubscriptions.append(
                        PendingMacPodcastSubscription(feedURL: result.feedURL, fallbackArtworkURL: result.artworkURL)
                    )
                    savePendingMacPodcastSubscriptions()
                }
                podcastStatusText = "Subscribed on device · will add to Mac on next sync"
            }
        } catch {
            podcastError = "Failed to subscribe to \(result.title): \(error.localizedDescription)"
        }

        subscribingPodcastFeedURLs.remove(norm)
    }

    private func flushPendingMacPodcastSubscriptions(using url: String, pin: String) async {
        guard !pendingMacPodcastSubscriptions.isEmpty else { return }
        var remaining: [PendingMacPodcastSubscription] = []
        var pushedCount = 0

        for item in pendingMacPodcastSubscriptions {
            let req = MacPodcastSubscribeRequest(
                feedURL: item.feedURL,
                fallbackArtworkURL: item.fallbackArtworkURL,
                selectForSync: true
            )
            if let res = try? await syncEngine.subscribePodcastOnMac(serverURL: url, pin: pin, request: req), res.ok {
                pushedCount += 1
            } else {
                remaining.append(item)
            }
        }

        if pushedCount > 0 {
            pendingMacPodcastSubscriptions = remaining
            savePendingMacPodcastSubscriptions()
            podcastStatusText = "Added \(pushedCount) queued podcast\(pushedCount == 1 ? "" : "s") to Mac"
        }
    }

    func playPodcastEpisode(_ episode: iOSPodcastEpisode, in show: iOSPodcastShow) async {
        let localArt = artworkFileURL(for: episode.artworkHash ?? show.artworkHash)
        let remoteArt = show.artworkURL.flatMap(URL.init(string:))

        if let localURL = await podcastManager.localFileURL(for: episode) {
            let badge = episode.downloadOrigin == .downloadedOnDevice ? "DOWNLOADED" : "SYNCED"
            let item = PlayableItem(
                id: episode.id,
                title: episode.title,
                artist: show.title,
                album: show.author.isEmpty ? "Podcast" : show.author,
                duration: episode.duration,
                formatPrimary: episode.fileExtension.uppercased(),
                formatDetail: badge,
                isHiRes: false,
                isLossless: false,
                localArtworkURL: localArt,
                remoteArtworkURL: remoteArt,
                source: .localFile(localURL)
            )
            player.play(items: [item], startingAt: 0)
        } else if let streamURL = URL(string: episode.audioURL), !episode.audioURL.isEmpty {
            let item = PlayableItem(
                id: episode.id,
                title: episode.title,
                artist: show.title,
                album: show.author.isEmpty ? "Podcast" : show.author,
                duration: episode.duration,
                formatPrimary: episode.fileExtension.uppercased(),
                formatDetail: "STREAM",
                isHiRes: false,
                isLossless: false,
                localArtworkURL: localArt,
                remoteArtworkURL: remoteArt,
                source: .podcastStream(streamURL)
            )
            player.play(items: [item], startingAt: 0)
        }
    }

    func artworkFileURL(for hash: String?) -> URL? {
        guard let hash, !hash.isEmpty else { return nil }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        if hash.hasPrefix("ndart-") {
            let safe = String(hash.dropFirst("ndart-".count)).replacingOccurrences(of: "/", with: "_")
            let url = docs.appendingPathComponent("MyEchoLibrary/NavidromeOffline/Artwork/\(safe).jpg")
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
        let url = docs.appendingPathComponent("MyEchoLibrary/Artwork/\(hash).jpg")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func playLocalTracks(_ list: [SyncedTrack], startingAt index: Int = 0) {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let items: [PlayableItem] = list.map { t in
            let fileURL: URL
            if t.id.hasPrefix("ndoff-") {
                let songID = String(t.id.dropFirst("ndoff-".count))
                fileURL = docs.appendingPathComponent("MyEchoLibrary/NavidromeOffline/Tracks/\(songID).\(t.fileExtension)")
            } else {
                fileURL = docs.appendingPathComponent("MyEchoLibrary/Tracks/\(t.id).\(t.fileExtension)")
            }
            return PlayableItem(
                id: t.id,
                title: t.title,
                artist: t.artist,
                album: t.effectiveAlbum,
                duration: t.duration,
                formatPrimary: t.formatPrimaryLabel,
                formatDetail: t.formatDetailLabel,
                isHiRes: t.isHiRes,
                isLossless: t.isLossless,
                localArtworkURL: artworkFileURL(for: t.artworkHash),
                remoteArtworkURL: nil,
                source: .localFile(fileURL)
            )
        }
        player.play(items: items, startingAt: index)
    }

    func playLocalEpisode(_ ep: SyncedEpisode) {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = docs.appendingPathComponent("MyEchoLibrary/Episodes/\(ep.id).\(ep.fileExtension)")
        let item = PlayableItem(
            id: ep.id,
            title: ep.title,
            artist: ep.showTitle,
            album: "Podcast",
            duration: ep.duration,
            formatPrimary: ep.fileExtension.uppercased(),
            formatDetail: "PODCAST",
            isHiRes: false,
            isLossless: false,
            localArtworkURL: artworkFileURL(for: ep.artworkHash),
            remoteArtworkURL: nil,
            source: .localFile(fileURL)
        )
        player.play(items: [item], startingAt: 0)
    }

    // MARK: - Navidrome (Tailscale) On-The-Go Streaming

    func testNavidromeConnection() async {
        isTestingNavidrome = true
        navidromeError = nil
        do {
            let version = try await navidromeClient.ping(config: navidromeConfig)
            navidromeStatusText = "Connected · \(version)"
            isTestingNavidrome = false
            await refreshNavidromeHome()
        } catch {
            navidromeStatusText = nil
            navidromeError = error.localizedDescription
            isTestingNavidrome = false
        }
    }

    func refreshNavidromeHome() async {
        guard navidromeConfig.isConfigured else { return }
        isLoadingNavidrome = true
        navidromeError = nil
        let cfg = navidromeConfig
        let listType = navidromeAlbumListType
        do {
            async let albumsTask = navidromeClient.fetchAlbums(type: listType, size: 36, config: cfg)
            async let playlistsTask = navidromeClient.fetchPlaylists(config: cfg)
            navidromeAlbums = try await albumsTask
            navidromePlaylists = (try? await playlistsTask) ?? []
            isLoadingNavidrome = false
        } catch {
            navidromeError = error.localizedDescription
            isLoadingNavidrome = false
        }
    }

    func scheduleNavidromeSearch(immediate: Bool = false) {
        navidromeSearchTask?.cancel()
        let q = navidromeSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else {
            navidromeSearchArtists = []
            navidromeSearchAlbums = []
            navidromeSearchSongs = []
            isSearchingNavidrome = false
            return
        }
        guard navidromeConfig.isConfigured else { return }

        isSearchingNavidrome = true
        navidromeSearchTask = Task { [weak self] in
            if !immediate {
                try? await Task.sleep(for: .milliseconds(280))
            }
            guard !Task.isCancelled, let self else { return }
            await self.searchNavidrome()
        }
    }

    func searchNavidrome() async {
        let q = navidromeSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, navidromeConfig.isConfigured else {
            navidromeSearchArtists = []
            navidromeSearchAlbums = []
            navidromeSearchSongs = []
            isSearchingNavidrome = false
            return
        }
        isSearchingNavidrome = true
        navidromeError = nil
        let cfg = navidromeConfig
        do {
            let res = try await navidromeClient.search(query: q, config: cfg)
            guard !Task.isCancelled, navidromeSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == q else {
                return
            }
            navidromeSearchArtists = res.artists
            navidromeSearchAlbums = res.albums
            navidromeSearchSongs = res.songs
            isSearchingNavidrome = false
        } catch {
            guard !Task.isCancelled else { return }
            navidromeError = error.localizedDescription
            isSearchingNavidrome = false
        }
    }

    var matchingNavidromePlaylists: [NavidromePlaylist] {
        let q = navidromeSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return navidromePlaylists }
        return navidromePlaylists.filter { $0.name.lowercased().contains(q) }
    }

    func isNavidromeSongOffline(_ songID: String) -> Bool {
        navidromeOfflineTracks.contains(where: { $0.id == songID })
    }

    func downloadNavidromeSongOffline(_ song: NavidromeSong) async {
        guard navidromeConfig.isConfigured, !downloadingNavidromeIDs.contains(song.id) else { return }
        downloadingNavidromeIDs.insert(song.id)
        navidromeError = nil
        do {
            _ = try await navidromeClient.downloadSongOffline(song, config: navidromeConfig)
            await reloadLocalLibrary()
        } catch {
            navidromeError = error.localizedDescription
        }
        downloadingNavidromeIDs.remove(song.id)
    }

    func downloadNavidromeAlbumOffline(songs: [NavidromeSong]) async {
        guard navidromeConfig.isConfigured else { return }
        for song in songs where !isNavidromeSongOffline(song.id) {
            await downloadNavidromeSongOffline(song)
        }
    }

    func removeNavidromeOfflineSong(_ songID: String) async {
        _ = await navidromeClient.removeOfflineSong(songID: songID)
        await reloadLocalLibrary()
    }

    func playNavidromeSongs(_ songs: [NavidromeSong], startingAt index: Int = 0) {
        let cfg = navidromeConfig
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let offlineByID = Dictionary(uniqueKeysWithValues: navidromeOfflineTracks.map { ($0.id, $0) })

        let items: [PlayableItem] = songs.compactMap { s in
            let primary = (s.suffix ?? "STREAM").uppercased()
            let detail = cfg.streamQuality == .original
                ? (s.bitRate.map { "\($0)k" } ?? "TAILSCALE")
                : "\(cfg.streamQuality.rawValue)k"

            // If already downloaded offline, play directly from local storage!
            if let offline = offlineByID[s.id] {
                let localURL = docs.appendingPathComponent("MyEchoLibrary/NavidromeOffline/Tracks/\(offline.localFileName)")
                if FileManager.default.fileExists(atPath: localURL.path) {
                    return PlayableItem(
                        id: "nd-\(s.id)",
                        title: s.title,
                        artist: s.artist,
                        album: s.album,
                        duration: TimeInterval(s.duration),
                        formatPrimary: offline.format.uppercased(),
                        formatDetail: offline.bitrate.map { "\($0)k" } ?? "OFFLINE",
                        isHiRes: false,
                        isLossless: ["FLAC", "ALAC", "WAV"].contains(offline.format.uppercased()),
                        localArtworkURL: artworkFileURL(for: offline.coverArtID.map { "ndart-\($0)" }),
                        remoteArtworkURL: NavidromeClient.coverArtURL(coverArtID: s.coverArt, size: 600, config: cfg),
                        source: .localFile(localURL)
                    )
                }
            }

            guard let url = NavidromeClient.streamURL(songID: s.id, config: cfg) else { return nil }
            return PlayableItem(
                id: "nd-\(s.id)",
                title: s.title,
                artist: s.artist,
                album: s.album,
                duration: TimeInterval(s.duration),
                formatPrimary: primary,
                formatDetail: detail,
                isHiRes: false,
                isLossless: primary == "FLAC" || primary == "ALAC" || primary == "WAV",
                localArtworkURL: nil,
                remoteArtworkURL: NavidromeClient.coverArtURL(coverArtID: s.coverArt, size: 600, config: cfg),
                source: .navidromeStream(songID: s.id, url: url)
            )
        }
        player.play(items: items, startingAt: index)
    }

    // MARK: - Mac Full Library Search & Remote Add-to-Sync + Lidarr Relay

    private func macCandidateURLs() -> [String] {
        var candidates: [String] = []
        let primary = macServerURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !primary.isEmpty && !primary.lowercased().contains("[fe80:") {
            candidates.append(primary)
        }
        if let bonjour = discoveredMacs.first?.baseURLString, !candidates.contains(bonjour) {
            candidates.append(bonjour)
        }
        let ts = macTailscaleURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !ts.isEmpty && !candidates.contains(ts) {
            candidates.append(ts)
        }
        return candidates
    }

    func macArtworkURL(for hash: String?) -> URL? {
        guard let hash, !hash.isEmpty, let base = macCandidateURLs().first else { return nil }
        var trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.lowercased().hasPrefix("http://") && !trimmed.lowercased().hasPrefix("https://") {
            trimmed = "http://" + trimmed
        }
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        let pin = pairingPIN.trimmingCharacters(in: .whitespacesAndNewlines)
        return URL(string: "\(trimmed)/api/v1/artwork/\(hash)?token=\(pin)")
    }

    func scheduleMacLibrarySearch(query: String, immediate: Bool = false) {
        macLibrarySearchTask?.cancel()
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else {
            macSearchAlbums = []
            macSearchTracks = []
            macSearchError = nil
            isSearchingMacLibrary = false
            return
        }
        isSearchingMacLibrary = true
        macLibrarySearchTask = Task { [weak self] in
            if !immediate { try? await Task.sleep(for: .milliseconds(280)) }
            guard !Task.isCancelled, let self else { return }
            await self.searchMacLibrary(query: q)
        }
    }

    func searchMacLibrary(query: String) async {
        let pin = pairingPIN.trimmingCharacters(in: .whitespacesAndNewlines)
        let urls = macCandidateURLs()
        guard !pin.isEmpty, !urls.isEmpty else {
            macSearchError = "Pair with your Mac (enter 6-digit PIN in Sync tab) to search your full Mac library."
            isSearchingMacLibrary = false
            return
        }
        isSearchingMacLibrary = true
        macSearchError = nil
        var lastErr: Error?
        for url in urls {
            do {
                let res = try await syncEngine.searchMacLibrary(serverURL: url, pin: pin, query: query)
                guard !Task.isCancelled else { return }
                macSearchAlbums = res.albums
                macSearchTracks = res.tracks
                isSearchingMacLibrary = false
                return
            } catch {
                lastErr = error
            }
        }
        macSearchError = lastErr?.localizedDescription ?? "Could not reach My Echo on Mac."
        isSearchingMacLibrary = false
    }

    func toggleMacSyncTrack(_ track: MacLibrarySearchTrack) async {
        let pin = pairingPIN.trimmingCharacters(in: .whitespacesAndNewlines)
        let urls = macCandidateURLs()
        guard !pin.isEmpty, !urls.isEmpty, !togglingMacSyncIDs.contains(track.id) else { return }
        togglingMacSyncIDs.insert(track.id)
        let newSelected = !track.isSelectedForSync
        let req = MacRemoteSyncSelectRequest(deviceID: localManifest?.deviceID, trackID: track.id, albumKey: nil, selected: newSelected)
        for url in urls {
            if let res = try? await syncEngine.setMacSyncSelection(serverURL: url, pin: pin, request: req), res.ok {
                if let idx = macSearchTracks.firstIndex(where: { $0.id == track.id }) {
                    macSearchTracks[idx].isSelectedForSync = newSelected
                }
                togglingMacSyncIDs.remove(track.id)
                await syncNow()
                return
            }
        }
        macSearchError = "Could not update sync selection on Mac."
        togglingMacSyncIDs.remove(track.id)
    }

    func toggleMacSyncAlbum(_ album: MacLibrarySearchAlbum) async {
        let pin = pairingPIN.trimmingCharacters(in: .whitespacesAndNewlines)
        let urls = macCandidateURLs()
        guard !pin.isEmpty, !urls.isEmpty, !togglingMacSyncIDs.contains(album.albumKey) else { return }
        togglingMacSyncIDs.insert(album.albumKey)
        let newSelected = !album.isSelectedForSync
        let req = MacRemoteSyncSelectRequest(deviceID: localManifest?.deviceID, trackID: nil, albumKey: album.albumKey, selected: newSelected)
        for url in urls {
            if let res = try? await syncEngine.setMacSyncSelection(serverURL: url, pin: pin, request: req), res.ok {
                if let idx = macSearchAlbums.firstIndex(where: { $0.albumKey == album.albumKey }) {
                    macSearchAlbums[idx].isSelectedForSync = newSelected
                }
                for i in macSearchTracks.indices where macSearchTracks[i].albumKey == album.albumKey {
                    macSearchTracks[i].isSelectedForSync = newSelected
                }
                togglingMacSyncIDs.remove(album.albumKey)
                await syncNow()
                return
            }
        }
        macSearchError = "Could not update album sync selection on Mac."
        togglingMacSyncIDs.remove(album.albumKey)
    }

    func scheduleLidarrSearch(query: String, immediate: Bool = false) {
        lidarrSearchTask?.cancel()
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else {
            lidarrSearchAlbums = []
            lidarrSearchTracks = []
            lidarrError = nil
            isSearchingLidarr = false
            return
        }
        isSearchingLidarr = true
        lidarrSearchTask = Task { [weak self] in
            if !immediate { try? await Task.sleep(for: .milliseconds(320)) }
            guard !Task.isCancelled, let self else { return }
            await self.searchLidarr(query: q)
        }
    }

    func searchLidarr(query: String) async {
        let pin = pairingPIN.trimmingCharacters(in: .whitespacesAndNewlines)
        let urls = macCandidateURLs()
        guard !pin.isEmpty, !urls.isEmpty else {
            lidarrError = "Pair with your Mac (enter 6-digit PIN in Sync tab) to search & order via Lidarr."
            isSearchingLidarr = false
            return
        }
        isSearchingLidarr = true
        lidarrError = nil
        var lastErr: Error?
        for url in urls {
            do {
                let res = try await syncEngine.searchLidarrViaMac(serverURL: url, pin: pin, query: query)
                guard !Task.isCancelled else { return }
                lidarrConfiguredOnMac = res.configured
                lidarrSearchAlbums = res.albums
                lidarrSearchTracks = res.tracks
                if !res.configured {
                    lidarrError = res.message ?? "Configure Lidarr in My Echo on Mac first."
                }
                isSearchingLidarr = false
                return
            } catch {
                lastErr = error
            }
        }
        lidarrError = lastErr?.localizedDescription ?? "Could not reach Lidarr relay on Mac."
        isSearchingLidarr = false
    }

    func orderLidarrAlbum(_ album: MacLidarrAlbumItem) async {
        let pin = pairingPIN.trimmingCharacters(in: .whitespacesAndNewlines)
        let urls = macCandidateURLs()
        guard !pin.isEmpty, !urls.isEmpty, !orderingLidarrIDs.contains(album.id) else { return }
        orderingLidarrIDs.insert(album.id)
        lidarrError = nil
        let req = MacLidarrOrderRequest(foreignAlbumId: album.foreignAlbumId, title: album.title, artistName: album.artistName, albumTitle: album.title)
        for url in urls {
            do {
                let res = try await syncEngine.orderLidarrViaMac(serverURL: url, pin: pin, request: req)
                if res.ok {
                    orderedLidarrIDs.insert(album.id)
                    lidarrFeedbackMessage = res.message
                } else {
                    lidarrError = res.message
                }
                orderingLidarrIDs.remove(album.id)
                return
            } catch {
                lidarrError = error.localizedDescription
            }
        }
        orderingLidarrIDs.remove(album.id)
    }

    func orderLidarrTrack(_ track: MacLidarrTrackItem) async {
        let pin = pairingPIN.trimmingCharacters(in: .whitespacesAndNewlines)
        let urls = macCandidateURLs()
        guard !pin.isEmpty, !urls.isEmpty, !orderingLidarrIDs.contains(track.id) else { return }
        orderingLidarrIDs.insert(track.id)
        lidarrError = nil
        let req = MacLidarrOrderRequest(foreignAlbumId: nil, title: track.title, artistName: track.artistName, albumTitle: track.albumTitle)
        for url in urls {
            do {
                let res = try await syncEngine.orderLidarrViaMac(serverURL: url, pin: pin, request: req)
                if res.ok {
                    orderedLidarrIDs.insert(track.id)
                    lidarrFeedbackMessage = res.message
                } else {
                    lidarrError = res.message
                }
                orderingLidarrIDs.remove(track.id)
                return
            } catch {
                lidarrError = error.localizedDescription
            }
        }
        orderingLidarrIDs.remove(track.id)
    }
}

import Foundation
import SwiftUI
import AppKit
import Observation
import EchoCore

enum EchoDragPayload {
    case tracks([String])
    case album(String)
    case artist(String)
    case playlist(UUID)
    case podcastShow(UUID)
    case podcastEpisode(String)
    case reorder(playlistID: UUID, sourceIndex: Int)

    func encode() -> String {
        switch self {
        case .tracks(let ids):
            return "echo-tracks:" + ids.joined(separator: ",")
        case .album(let key):
            return "echo-album:" + key
        case .artist(let key):
            return "echo-artist:" + key
        case .playlist(let id):
            return "echo-playlist:" + id.uuidString
        case .podcastShow(let id):
            return "echo-podcast-show:" + id.uuidString
        case .podcastEpisode(let id):
            return "echo-podcast-ep:" + id
        case .reorder(let playlistID, let sourceIndex):
            return "echo-reorder:\(playlistID.uuidString):\(sourceIndex)"
        }
    }

    static func decode(_ raw: String) -> EchoDragPayload? {
        if raw.hasPrefix("echo-tracks:") {
            let body = String(raw.dropFirst("echo-tracks:".count))
            let ids = body.split(separator: ",").map(String.init).filter { !$0.isEmpty }
            return ids.isEmpty ? nil : .tracks(ids)
        }
        if raw.hasPrefix("echo-album:") {
            let key = String(raw.dropFirst("echo-album:".count))
            return key.isEmpty ? nil : .album(key)
        }
        if raw.hasPrefix("echo-artist:") {
            let key = String(raw.dropFirst("echo-artist:".count))
            return key.isEmpty ? nil : .artist(key)
        }
        if raw.hasPrefix("echo-playlist:") {
            let idStr = String(raw.dropFirst("echo-playlist:".count))
            return UUID(uuidString: idStr).map { .playlist($0) }
        }
        if raw.hasPrefix("echo-podcast-show:") {
            let idStr = String(raw.dropFirst("echo-podcast-show:".count))
            return UUID(uuidString: idStr).map { .podcastShow($0) }
        }
        if raw.hasPrefix("echo-podcast-ep:") {
            let idStr = String(raw.dropFirst("echo-podcast-ep:".count))
            return idStr.isEmpty ? nil : .podcastEpisode(idStr)
        }
        if raw.hasPrefix("echo-reorder:") {
            let parts = String(raw.dropFirst("echo-reorder:".count)).split(separator: ":")
            if parts.count == 2, let uuid = UUID(uuidString: String(parts[0])), let idx = Int(parts[1]) {
                return .reorder(playlistID: uuid, sourceIndex: idx)
            }
        }
        return nil
    }
}

struct DestinationBadgeInfo: Identifiable, Hashable {
    let deviceID: UUID
    let name: String
    let accent: DeviceAccentColor
    let isSynced: Bool      // Confirmed synced to this destination
    let isAssigned: Bool    // Currently selected/queued for this destination
    var id: UUID { deviceID }
}

enum NavDestination: Hashable {
    case home
    case artists
    case artistDetail(String) // artistKey
    case albums
    case albumDetail(String)  // albumKey
    case tracks
    case podcasts
    case podcastDetail(UUID)
    case playlist(UUID)
    case sources
    case deviceSync(UUID)
    case settings
}

@MainActor
@Observable
final class EchoStore {
    let database: EchoDatabase
    let artworkCache: ArtworkCache
    let indexer: LibraryIndexer
    let podcastService: PodcastService
    let syncEngine: SyncEngine
    let player: AudioPlayerEngine

    // Navigation & Search
    var currentDestination: NavDestination = .home
    var navHistory: [NavDestination] = [.home]
    var navHistoryIndex: Int = 0
    var searchQuery: String = ""

    // Settings
    var destinationMode: DestinationMode = .single
    var selectedTheme: AppThemeKind = .neonCassette

    // Library State
    var sources: [LibrarySource] = []
    var selectedSourceID: UUID? // nil = All Libraries; UUID = stay scoped inside that specific library source
    var tracks: [Track] = []
    var playlists: [Playlist] = []
    var focusedPlaylistID: UUID?

    // Podcasts State
    var podcasts: [PodcastShow] = []
    var selectedPodcastDirectory: PodcastDirectory = .all
    var activePodcastCategory: PodcastBrowseCategory? = .featured
    var podcastSearchQuery: String = ""
    var podcastSearchResults: [PodcastSearchResult] = PodcastService.curatedFeaturedShows
    var isSearchingPodcasts: Bool = false
    var podcastSearchError: String?
    var downloadingEpisodeIDs: Set<String> = []
    var refreshingPodcastIDs: Set<UUID> = []

    // Precomputed Grouped Views (scoped to selectedSourceID for browsing & global search)
    private(set) var scopedTracks: [Track] = []
    private(set) var artists: [ArtistGroup] = []
    private(set) var albums: [AlbumGroup] = []
    private(set) var tracksByID: [String: Track] = [:]
    private(set) var artistsByKey: [String: ArtistGroup] = [:]
    private(set) var albumsByKey: [String: AlbumGroup] = [:]
    private(set) var episodesByID: [String: PodcastEpisode] = [:]

    // Devices & Sync State
    var devices: [DeviceProfile] = []
    var activeDeviceID: UUID?
    var detectedVolumes: [MountedVolumeInfo] = []
    private(set) var activeSyncPlan: SyncPlan?

    // Live Activity
    var isIndexing: Bool = false
    var indexProgress: IndexProgress?
    var isSyncing: Bool = false
    var syncProgress: SyncProgress?
    var lastSyncSummary: SyncExecutionSummary?
    var toastMessage: String?
    var toastIsError: Bool = false

    private var syncTask: Task<Void, Never>?
    private var volumeObservers: [NSObjectProtocol] = []

    init() {
        self.artworkCache = ArtworkCache()
        self.database = try! EchoDatabase()
        self.indexer = LibraryIndexer(artworkCache: artworkCache)
        self.podcastService = PodcastService(artworkCache: artworkCache)
        self.syncEngine = SyncEngine(artworkCache: artworkCache, podcastService: podcastService)
        self.player = AudioPlayerEngine()

        loadPersistedState()
        setupPlayerSettingsPersistence()
        refreshMountedVolumes()
        startVolumeMonitoring()
    }

    // MARK: - Navigation

    func navigate(to destination: NavDestination) {
        guard destination != currentDestination else { return }
        if navHistoryIndex < navHistory.count - 1 {
            navHistory = Array(navHistory.prefix(navHistoryIndex + 1))
        }
        navHistory.append(destination)
        navHistoryIndex = navHistory.count - 1
        currentDestination = destination

        if case .playlist(let id) = destination {
            setFocusedPlaylist(id)
        }
    }

    var canGoBack: Bool { navHistoryIndex > 0 }
    var canGoForward: Bool { navHistoryIndex < navHistory.count - 1 }

    func goBack() {
        guard canGoBack else { return }
        navHistoryIndex -= 1
        currentDestination = navHistory[navHistoryIndex]
    }

    func goForward() {
        guard canGoForward else { return }
        navHistoryIndex += 1
        currentDestination = navHistory[navHistoryIndex]
    }

    // MARK: - Destination Mode, Theme & Explicit Target Selection

    func setTheme(_ theme: AppThemeKind) {
        selectedTheme = theme
        ThemeManager.shared.kind = theme
        database.setSetting("selectedTheme", value: theme.rawValue)
        showToast("Theme switched to \(theme.displayName)")
    }

    var selectedSource: LibrarySource? {
        guard let id = selectedSourceID else { return nil }
        return sources.first(where: { $0.id == id })
    }

    var selectedLibraryDisplayName: String {
        selectedSource?.name ?? "All Libraries"
    }

    func selectLibrarySource(_ sourceID: UUID?) {
        selectedSourceID = sourceID
        database.setSetting("selectedSourceID", value: sourceID?.uuidString ?? "")
        rebuildLibraryGroups()
        // If currently viewing an artist/album detail that doesn't exist in the newly selected library, return smoothly to Albums
        switch currentDestination {
        case .artistDetail(let key) where artistsByKey[key] == nil:
            navigate(to: .artists)
        case .albumDetail(let key) where albumsByKey[key] == nil:
            navigate(to: .albums)
        default:
            break
        }
        showToast("Library scope: \(selectedLibraryDisplayName)")
    }

    func setDestinationMode(_ mode: DestinationMode) {
        destinationMode = mode
        database.setSetting("destinationMode", value: mode.rawValue)
        if mode == .single && activeDeviceID == nil {
            activeDeviceID = devices.first?.id
            if let id = activeDeviceID {
                database.setSetting("activeDeviceID", value: id.uuidString)
            }
        }
        recomputeSyncPlan()
        showToast(mode == .multi
            ? "Multi-Destination Mode enabled — select a target player to sync"
            : "Single Destination Mode enabled")
    }

    /// In Single Destination mode, automatically falls back to the first device.
    /// In Multi-Destination mode, ONLY returns the explicitly selected destination!
    var activeDevice: DeviceProfile? {
        get {
            if let id = activeDeviceID, let d = devices.first(where: { $0.id == id }) {
                return d
            }
            if destinationMode == .single {
                return devices.first
            }
            return nil
        }
        set {
            activeDeviceID = newValue?.id
            database.setSetting("activeDeviceID", value: newValue?.id.uuidString ?? "")
            recomputeSyncPlan()
        }
    }

    var requiresDestinationSelection: Bool {
        destinationMode == .multi && activeDevice == nil
    }

    func selectActiveDevice(_ id: UUID?) {
        activeDeviceID = id
        database.setSetting("activeDeviceID", value: id?.uuidString ?? "")
        recomputeSyncPlan()
        if let id, let d = devices.first(where: { $0.id == id }) {
            showToast("Sync target set to '\(d.name)'")
        }
    }

    func volumeInfo(for device: DeviceProfile) -> MountedVolumeInfo? {
        if let uuid = device.volumeUUID,
           let vol = detectedVolumes.first(where: { $0.volumeUUID == uuid }) {
            return vol
        }
        if let vol = detectedVolumes.first(where: { $0.mountPath == device.mountPath }) {
            return vol
        }
        return VolumeMonitor.volumeInfo(atPath: device.mountPath)
    }

    // MARK: - Persistence Bootstrap

    private func loadPersistedState() {
        if let modeStr = database.getSetting("destinationMode"),
           let mode = DestinationMode(rawValue: modeStr) {
            destinationMode = mode
        }
        if let themeStr = database.getSetting("selectedTheme"),
           let theme = AppThemeKind(rawValue: themeStr) {
            selectedTheme = theme
            ThemeManager.shared.kind = theme
        }

        sources = database.loadSources()
        tracks = database.loadAllTracks()
        playlists = database.loadPlaylists()
        devices = database.loadDevices()
        podcasts = database.loadPodcasts()

        if let savedSourceStr = database.getSetting("selectedSourceID"),
           !savedSourceStr.isEmpty,
           let uuid = UUID(uuidString: savedSourceStr),
           sources.contains(where: { $0.id == uuid }) {
            selectedSourceID = uuid
        } else {
            selectedSourceID = nil
        }

        if let savedDeviceStr = database.getSetting("activeDeviceID"),
           !savedDeviceStr.isEmpty,
           let uuid = UUID(uuidString: savedDeviceStr),
           devices.contains(where: { $0.id == uuid }) {
            activeDeviceID = uuid
        } else if destinationMode == .single {
            activeDeviceID = devices.first?.id
        } else {
            activeDeviceID = nil
        }

        if let savedPlaylistStr = database.getSetting("focusedPlaylistID"),
           let uuid = UUID(uuidString: savedPlaylistStr),
           playlists.contains(where: { $0.id == uuid }) {
            focusedPlaylistID = uuid
        } else {
            focusedPlaylistID = playlists.first?.id
        }

        if let volStr = database.getSetting("playerVolume"), let v = Double(volStr) {
            player.volume = v
        }
        if let shufStr = database.getSetting("playerShuffle") {
            player.isShuffled = (shufStr == "true")
        }
        if let repStr = database.getSetting("playerRepeat"), let mode = RepeatMode(rawValue: repStr) {
            player.repeatMode = mode
        }

        rebuildLibraryGroups()
        rebuildEpisodeMap()
        recomputeSyncPlan()
    }

    private func setupPlayerSettingsPersistence() {
        player.onSettingsChanged = { [weak self] in
            guard let self else { return }
            self.database.setSetting("playerVolume", value: String(self.player.volume))
            self.database.setSetting("playerShuffle", value: self.player.isShuffled ? "true" : "false")
            self.database.setSetting("playerRepeat", value: self.player.repeatMode.rawValue)
        }
    }

    private func rebuildLibraryGroups() {
        // tracksByID always indexes ALL tracks so Sync & Playlists remain intact regardless of browsing scope
        tracksByID = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) })

        if let srcID = selectedSourceID {
            scopedTracks = tracks.filter { $0.sourceID == srcID }
        } else {
            scopedTracks = tracks
        }

        let byAlbum = Dictionary(grouping: scopedTracks, by: \.albumKey)
        var builtAlbums: [AlbumGroup] = []
        builtAlbums.reserveCapacity(byAlbum.count)

        for (key, albumTracks) in byAlbum {
            let sorted = albumTracks.sorted {
                ($0.discNumber ?? 1, $0.trackNumber ?? 999, $0.title.lowercased()) <
                ($1.discNumber ?? 1, $1.trackNumber ?? 999, $1.title.lowercased())
            }
            guard let first = sorted.first else { continue }
            let art = sorted.first(where: { $0.artworkHash != nil })?.artworkHash
            let year = sorted.compactMap(\.year).first
            builtAlbums.append(AlbumGroup(
                id: key,
                title: first.effectiveAlbum,
                artist: first.effectiveArtist,
                year: year,
                artworkHash: art,
                tracks: sorted
            ))
        }
        builtAlbums.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        albums = builtAlbums
        albumsByKey = Dictionary(uniqueKeysWithValues: builtAlbums.map { ($0.id, $0) })

        let byArtist = Dictionary(grouping: builtAlbums, by: { $0.artist.lowercased() })
        var builtArtists: [ArtistGroup] = []
        builtArtists.reserveCapacity(byArtist.count)

        for (key, artistAlbums) in byArtist {
            let sortedAlbums = artistAlbums.sorted {
                ($0.year ?? 9999, $0.title.lowercased()) < ($1.year ?? 9999, $1.title.lowercased())
            }
            let artistTracks = sortedAlbums.flatMap(\.tracks)
            let name = sortedAlbums.first?.artist ?? "Unknown Artist"
            let art = sortedAlbums.first(where: { $0.artworkHash != nil })?.artworkHash
            builtArtists.append(ArtistGroup(
                id: key,
                name: name,
                artworkHash: art,
                albums: sortedAlbums,
                tracks: artistTracks
            ))
        }
        builtArtists.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        artists = builtArtists
        artistsByKey = Dictionary(uniqueKeysWithValues: builtArtists.map { ($0.id, $0) })
    }

    private func rebuildEpisodeMap() {
        var map: [String: PodcastEpisode] = [:]
        for show in podcasts {
            for ep in show.episodes {
                map[ep.id] = ep
            }
        }
        episodesByID = map
    }

    // MARK: - Volume Auto-Detection

    private func startVolumeMonitoring() {
        let nc = NSWorkspace.shared.notificationCenter
        let mountObs = nc.addObserver(forName: NSWorkspace.didMountNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshMountedVolumes(autoSelectNewMatch: true)
            }
        }
        let unmountObs = nc.addObserver(forName: NSWorkspace.didUnmountNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshMountedVolumes(autoSelectNewMatch: false)
            }
        }
        volumeObservers = [mountObs, unmountObs]
    }

    func refreshMountedVolumes(autoSelectNewMatch: Bool = false) {
        detectedVolumes = VolumeMonitor.scanMountedExternalVolumes()

        var updated = false
        for i in devices.indices {
            let match = detectedVolumes.first(where: { vol in
                (devices[i].volumeUUID != nil && vol.volumeUUID == devices[i].volumeUUID)
                    || vol.mountPath == devices[i].mountPath
            })

            if let match {
                var devChanged = false
                if devices[i].mountPath != match.mountPath {
                    devices[i].mountPath = match.mountPath
                    devChanged = true
                }
                if let newUUID = match.volumeUUID, devices[i].volumeUUID != newUUID {
                    devices[i].volumeUUID = newUUID
                    devChanged = true
                }
                if !devices[i].hasCustomName && devices[i].name != match.name {
                    devices[i].name = match.name
                    devChanged = true
                }

                // Hydrate syncedTrackIDs/syncedEpisodeIDs from device manifest if mounted
                let manifest = DeviceSyncManifest.load(fromMountPath: devices[i].mountPath, fallbackDeviceID: devices[i].id)
                let manifestTracks = Set(manifest.tracks.keys)
                let manifestEps = Set(manifest.episodes.keys)
                if !manifestTracks.isEmpty && devices[i].syncedTrackIDs != manifestTracks {
                    devices[i].syncedTrackIDs = manifestTracks
                    devChanged = true
                }
                if !manifestEps.isEmpty && devices[i].syncedEpisodeIDs != manifestEps {
                    devices[i].syncedEpisodeIDs = manifestEps
                    devChanged = true
                }

                if devChanged {
                    database.saveDevice(devices[i])
                    updated = true
                }

                if autoSelectNewMatch && destinationMode == .single {
                    selectActiveDevice(devices[i].id)
                } else if autoSelectNewMatch {
                    showToast("Mounted: \(devices[i].name)")
                }
            } else if !devices[i].hasCustomName && devices[i].mountPath.hasPrefix("/Volumes/") {
                // Heal any previously stuck old volume label (e.g. EOS_DIGITAL when mountPath is /Volumes/ECHO SD2)
                let volumeDirName = URL(fileURLWithPath: devices[i].mountPath).lastPathComponent
                if !volumeDirName.isEmpty && volumeDirName != "Volumes" && devices[i].name != volumeDirName {
                    devices[i].name = volumeDirName
                    database.saveDevice(devices[i])
                    updated = true
                }
            }
        }
        if updated || activeDevice != nil {
            recomputeSyncPlan()
        }
    }

    func renameDevice(_ device: DeviceProfile, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let idx = devices.firstIndex(where: { $0.id == device.id }) else { return }
        devices[idx].name = trimmed
        devices[idx].hasCustomName = true
        database.saveDevice(devices[idx])
        recomputeSyncPlan()
        showToast("Renamed destination to '\(trimmed)'")
    }

    func resetDeviceNameFromVolume(_ device: DeviceProfile) {
        guard let idx = devices.firstIndex(where: { $0.id == device.id }) else { return }
        let volName = volumeInfo(for: devices[idx])?.name
            ?? URL(fileURLWithPath: devices[idx].mountPath).lastPathComponent
        guard !volName.isEmpty else { return }
        devices[idx].name = volName
        devices[idx].hasCustomName = false
        database.saveDevice(devices[idx])
        recomputeSyncPlan()
        showToast("Synced destination name to '\(volName)'")
    }

    func relinkDeviceVolumeViaPanel(_ device: DeviceProfile) {
        let panel = NSOpenPanel()
        panel.title = "Relink '\(device.name)' to Mounted Volume or Folder"
        panel.message = "Choose the current volume or folder for '\(device.name)' (useful after erasing/reformatting an SD card)."
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url,
           let idx = devices.firstIndex(where: { $0.id == device.id }) {
            let vol = VolumeMonitor.volumeInfo(atPath: url.path)
            devices[idx].mountPath = url.path
            devices[idx].volumeUUID = (vol?.mountPath == url.path) ? vol?.volumeUUID : nil
            if !devices[idx].hasCustomName {
                devices[idx].name = vol?.name ?? url.lastPathComponent
            }
            database.saveDevice(devices[idx])
            refreshMountedVolumes()
            recomputeSyncPlan()
            showToast("Relinked '\(devices[idx].name)' to \(url.path)")
        }
    }

    var unrecognizedMountedVolumes: [MountedVolumeInfo] {
        detectedVolumes.filter { vol in
            !devices.contains { d in
                (vol.volumeUUID != nil && d.volumeUUID == vol.volumeUUID) || d.mountPath == vol.mountPath
            }
        }
    }

    // MARK: - Library Sources & Indexing

    func addLibrarySourceViaPanel() {
        let panel = NSOpenPanel()
        panel.title = "Select Music Library Folder (Local or NAS)"
        panel.message = "Choose a local directory or mounted NAS share containing your audio files."
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true

        if panel.runModal() == .OK {
            var addedSources: [LibrarySource] = []
            for url in panel.urls {
                let path = url.path
                if sources.contains(where: { $0.path == path }) { continue }
                let src = LibrarySource(
                    name: url.lastPathComponent,
                    path: path,
                    isNetworkVolume: LibraryIndexer.detectIsNetworkVolume(path: path)
                )
                sources.append(src)
                database.saveSource(src)
                addedSources.append(src)
            }
            if !addedSources.isEmpty {
                Task {
                    for s in addedSources {
                        await indexSource(s)
                    }
                }
            }
        }
    }

    func removeLibrarySource(_ source: LibrarySource) {
        database.deleteSource(id: source.id)
        sources.removeAll { $0.id == source.id }
        tracks.removeAll { $0.sourceID == source.id }
        if selectedSourceID == source.id {
            selectedSourceID = nil
            database.setSetting("selectedSourceID", value: "")
        }
        rebuildLibraryGroups()
        recomputeSyncPlan()
        showToast("Removed source '\(source.name)'")
    }

    func indexAllSources() {
        Task {
            for src in sources {
                await indexSource(src)
            }
        }
    }

    func indexSource(_ source: LibrarySource) async {
        guard !isIndexing else { return }
        isIndexing = true
        indexProgress = IndexProgress(sourceName: source.name, scannedCount: 0, totalFound: 0, currentFile: "Scanning...")

        let existing = tracks.filter { $0.sourceID == source.id }
        let result = await indexer.indexSource(source, existingTracks: existing) { [weak self] progress in
            Task { @MainActor [weak self] in
                self?.indexProgress = progress
            }
        }

        database.replaceTracks(forSourceID: source.id, tracks: result.tracks)
        tracks.removeAll { $0.sourceID == source.id }
        tracks.append(contentsOf: result.tracks)

        if let idx = sources.firstIndex(where: { $0.id == source.id }) {
            sources[idx].lastIndexedAt = Date()
            sources[idx].trackCount = result.tracks.count
            database.saveSource(sources[idx])
        }

        rebuildLibraryGroups()
        recomputeSyncPlan()
        isIndexing = false
        indexProgress = nil

        if result.isSourceOffline {
            showToast("'\(source.name)' is offline — kept \(result.tracks.count) cached tracks", isError: true)
        } else {
            showToast("Indexed '\(source.name)': \(result.tracks.count) tracks (\(result.addedCount) new)")
        }
    }

    // MARK: - Podcasts (Search, Subscribe, Refresh, Download, Play, Sync)

    func searchPodcasts() {
        let q = podcastSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else {
            browsePodcastCategory(.featured)
            return
        }
        activePodcastCategory = nil
        isSearchingPodcasts = true
        podcastSearchError = nil
        let directory = selectedPodcastDirectory
        Task {
            do {
                let results = try await podcastService.searchPodcasts(query: q, directory: directory)
                await MainActor.run {
                    self.podcastSearchResults = results
                    self.isSearchingPodcasts = false
                    if results.isEmpty {
                        self.podcastSearchError = "No podcasts found for '\(q)' in \(directory.displayName)."
                    }
                }
            } catch {
                await MainActor.run {
                    self.isSearchingPodcasts = false
                    self.podcastSearchError = error.localizedDescription
                }
            }
        }
    }

    func browsePodcastCategory(_ category: PodcastBrowseCategory) {
        activePodcastCategory = category
        podcastSearchError = nil
        if category == .featured {
            podcastSearchResults = PodcastService.curatedFeaturedShows
            isSearchingPodcasts = false
            return
        }
        isSearchingPodcasts = true
        let directory = selectedPodcastDirectory
        Task {
            do {
                let results = try await podcastService.browseCategory(category, directory: directory)
                await MainActor.run {
                    self.podcastSearchResults = results
                    self.isSearchingPodcasts = false
                    if results.isEmpty {
                        self.podcastSearchError = "No shows returned for \(category.rawValue)."
                    }
                }
            } catch {
                await MainActor.run {
                    self.isSearchingPodcasts = false
                    self.podcastSearchError = error.localizedDescription
                }
            }
        }
    }

    func importOPMLViaPanel() {
        let panel = NSOpenPanel()
        panel.title = "Import Podcast Subscriptions (OPML)"
        panel.message = "Choose an .opml or .xml file exported from Apple Podcasts, Pocket Casts, Overcast, or AntennaPod."
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url, let data = try? Data(contentsOf: url) {
            let feeds = PodcastService.parseOPMLFeedURLs(data: data)
            guard !feeds.isEmpty else {
                showToast("No RSS feed URLs found in OPML file", isError: true)
                return
            }
            showToast("Importing \(feeds.count) podcasts from OPML...")
            Task {
                var added = 0
                for item in feeds {
                    if self.podcasts.contains(where: { $0.feedURL.caseInsensitiveCompare(item.feedURL) == .orderedSame }) {
                        continue
                    }
                    if let show = try? await self.podcastService.fetchFeed(feedURLString: item.feedURL) {
                        await MainActor.run {
                            self.podcasts.append(show)
                            self.database.savePodcast(show)
                            added += 1
                        }
                    }
                }
                await MainActor.run {
                    self.podcasts.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                    self.rebuildEpisodeMap()
                    self.recomputeSyncPlan()
                    self.showToast("Imported \(added) new podcast\(added == 1 ? "" : "s") from OPML")
                }
            }
        }
    }

    func subscribeToPodcast(feedURL: String, fallbackArtworkURL: String? = nil) {
        let trimmed = feedURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let existing = podcasts.first(where: { $0.feedURL.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            navigate(to: .podcastDetail(existing.id))
            showToast("Already subscribed to '\(existing.title)'")
            return
        }

        showToast("Subscribing to podcast feed...")
        Task {
            do {
                let show = try await podcastService.fetchFeed(feedURLString: trimmed, fallbackArtworkURL: fallbackArtworkURL)
                await MainActor.run {
                    self.podcasts.append(show)
                    self.podcasts.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                    self.database.savePodcast(show)
                    self.rebuildEpisodeMap()
                    self.recomputeSyncPlan()
                    self.navigate(to: .podcastDetail(show.id))
                    self.showToast("Subscribed to '\(show.title)' (\(show.episodes.count) episodes)")
                }
            } catch {
                await MainActor.run {
                    self.showToast("Subscribe failed: \(error.localizedDescription)", isError: true)
                }
            }
        }
    }

    func refreshPodcast(_ show: PodcastShow) {
        guard !refreshingPodcastIDs.contains(show.id) else { return }
        refreshingPodcastIDs.insert(show.id)
        Task {
            do {
                let updated = try await podcastService.fetchFeed(feedURLString: show.feedURL, existingShow: show)
                await MainActor.run {
                    if let idx = self.podcasts.firstIndex(where: { $0.id == show.id }) {
                        self.podcasts[idx] = updated
                    }
                    self.database.savePodcast(updated)
                    self.rebuildEpisodeMap()
                    self.recomputeSyncPlan()
                    self.refreshingPodcastIDs.remove(show.id)
                    self.showToast("Refreshed '\(updated.title)' (\(updated.episodes.count) episodes)")
                }
            } catch {
                await MainActor.run {
                    self.refreshingPodcastIDs.remove(show.id)
                    self.showToast("Refresh failed: \(error.localizedDescription)", isError: true)
                }
            }
        }
    }

    func refreshAllPodcasts() {
        for show in podcasts {
            refreshPodcast(show)
        }
    }

    func unsubscribePodcast(_ show: PodcastShow) {
        podcasts.removeAll { $0.id == show.id }
        database.deletePodcast(id: show.id)
        for i in devices.indices {
            var changed = false
            if devices[i].selectedPodcastShowIDs.remove(show.id) != nil { changed = true }
            for ep in show.episodes {
                if devices[i].selectedEpisodeIDs.remove(ep.id) != nil { changed = true }
            }
            if changed { database.saveDevice(devices[i]) }
        }
        if case .podcastDetail(let id) = currentDestination, id == show.id {
            navigate(to: .podcasts)
        }
        rebuildEpisodeMap()
        recomputeSyncPlan()
        showToast("Unsubscribed from '\(show.title)'")
    }

    func downloadEpisode(_ episode: PodcastEpisode) {
        guard !downloadingEpisodeIDs.contains(episode.id) else { return }
        downloadingEpisodeIDs.insert(episode.id)
        Task {
            do {
                let downloaded = try await podcastService.downloadEpisode(episode)
                await MainActor.run {
                    self.persistUpdatedEpisode(downloaded)
                    self.downloadingEpisodeIDs.remove(episode.id)
                    self.showToast("Downloaded '\(downloaded.title)'")
                }
            } catch {
                await MainActor.run {
                    self.downloadingEpisodeIDs.remove(episode.id)
                    self.showToast("Download failed: \(error.localizedDescription)", isError: true)
                }
            }
        }
    }

    func deleteDownloadedEpisode(_ episode: PodcastEpisode) {
        Task {
            let cleared = await podcastService.deleteDownloadedEpisode(episode)
            await MainActor.run {
                self.persistUpdatedEpisode(cleared)
                self.showToast("Removed local download for '\(episode.title)'")
            }
        }
    }

    func playEpisode(_ episode: PodcastEpisode) {
        if let track = episode.asPlayableTrack() {
            player.playSingle(track)
        } else {
            showToast("Downloading '\(episode.title)' to play...")
            guard !downloadingEpisodeIDs.contains(episode.id) else { return }
            downloadingEpisodeIDs.insert(episode.id)
            Task {
                do {
                    let downloaded = try await podcastService.downloadEpisode(episode)
                    await MainActor.run {
                        self.persistUpdatedEpisode(downloaded)
                        self.downloadingEpisodeIDs.remove(episode.id)
                        if let track = downloaded.asPlayableTrack() {
                            self.player.playSingle(track)
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.downloadingEpisodeIDs.remove(episode.id)
                        self.showToast("Could not download episode: \(error.localizedDescription)", isError: true)
                    }
                }
            }
        }
    }

    private func persistUpdatedEpisode(_ episode: PodcastEpisode) {
        guard let sIdx = podcasts.firstIndex(where: { $0.id == episode.showID }),
              let eIdx = podcasts[sIdx].episodes.firstIndex(where: { $0.id == episode.id }) else { return }
        podcasts[sIdx].episodes[eIdx] = episode
        database.savePodcast(podcasts[sIdx])
        rebuildEpisodeMap()
        recomputeSyncPlan()
    }

    // Podcast Sync Selection (Single & Multi-Destination)

    func isPodcastShowSelected(_ show: PodcastShow, on device: DeviceProfile? = nil) -> Bool {
        guard let dev = device ?? activeDevice else { return false }
        return dev.selectedPodcastShowIDs.contains(show.id)
    }

    func setPodcastEpisodesToKeep(_ show: PodcastShow, count: Int) {
        guard let idx = podcasts.firstIndex(where: { $0.id == show.id }) else { return }
        podcasts[idx].episodesToKeep = max(0, count)
        database.savePodcast(podcasts[idx])
        recomputeSyncPlan()
        let label = count == 0 ? "all episodes" : "latest \(count) episode\(count == 1 ? "" : "s")"
        showToast("'\(show.title)' will keep \(label) on sync")
    }

    func episodeSyncReason(_ episode: PodcastEpisode, on device: DeviceProfile? = nil) -> String? {
        guard let dev = device ?? activeDevice else { return nil }
        if dev.selectedEpisodeIDs.contains(episode.id) { return "Episode" }
        if dev.selectedPodcastShowIDs.contains(episode.showID) {
            if let show = podcasts.first(where: { $0.id == episode.showID }) {
                let newestFirst = show.episodes.sorted {
                    ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast)
                }
                let slice: ArraySlice<PodcastEpisode> = show.episodesToKeep > 0
                    ? newestFirst.prefix(show.episodesToKeep)
                    : newestFirst[...]
                if slice.contains(where: { $0.id == episode.id }) {
                    return "Show"
                }
            }
        }
        return nil
    }

    func togglePodcastShowSync(_ show: PodcastShow, onDeviceID targetDeviceID: UUID? = nil) {
        mutateDevice(id: targetDeviceID) { d in
            if d.selectedPodcastShowIDs.contains(show.id) {
                d.selectedPodcastShowIDs.remove(show.id)
            } else {
                d.selectedPodcastShowIDs.insert(show.id)
            }
        }
    }

    func toggleEpisodeSync(_ episode: PodcastEpisode, onDeviceID targetDeviceID: UUID? = nil) {
        mutateDevice(id: targetDeviceID) { d in
            if d.selectedEpisodeIDs.contains(episode.id) {
                d.selectedEpisodeIDs.remove(episode.id)
            } else {
                d.selectedEpisodeIDs.insert(episode.id)
            }
        }
    }

    // MARK: - Multi-Destination Memory Queries (Tracks & Episodes Remember Their Destinations!)

    func destinations(forTrack track: Track) -> [DestinationBadgeInfo] {
        var result: [DestinationBadgeInfo] = []
        for dev in devices {
            let isAssigned = isTrackAssigned(track, to: dev)
            let isSynced = dev.syncedTrackIDs.contains(track.id)
            if isAssigned || isSynced {
                result.append(DestinationBadgeInfo(
                    deviceID: dev.id,
                    name: dev.name,
                    accent: dev.accentColor,
                    isSynced: isSynced,
                    isAssigned: isAssigned
                ))
            }
        }
        return result
    }

    func destinations(forEpisode episode: PodcastEpisode) -> [DestinationBadgeInfo] {
        var result: [DestinationBadgeInfo] = []
        for dev in devices {
            let isAssigned = episodeSyncReason(episode, on: dev) != nil
            let isSynced = dev.syncedEpisodeIDs.contains(episode.id)
            if isAssigned || isSynced {
                result.append(DestinationBadgeInfo(
                    deviceID: dev.id,
                    name: dev.name,
                    accent: dev.accentColor,
                    isSynced: isSynced,
                    isAssigned: isAssigned
                ))
            }
        }
        return result
    }

    func destinations(forPodcastShow show: PodcastShow) -> [DestinationBadgeInfo] {
        var result: [DestinationBadgeInfo] = []
        for dev in devices {
            let isAssigned = dev.selectedPodcastShowIDs.contains(show.id)
            let epIDs = Set(show.episodes.map(\.id))
            let isSynced = !dev.syncedEpisodeIDs.isDisjoint(with: epIDs)
            if isAssigned || isSynced {
                result.append(DestinationBadgeInfo(
                    deviceID: dev.id,
                    name: dev.name,
                    accent: dev.accentColor,
                    isSynced: isSynced,
                    isAssigned: isAssigned
                ))
            }
        }
        return result
    }

    func isTrackAssigned(_ track: Track, to device: DeviceProfile) -> Bool {
        if device.selectedTrackIDs.contains(track.id) { return true }
        if device.selectedAlbumKeys.contains(track.albumKey) { return true }
        if device.selectedArtistKeys.contains(track.artistKey) { return true }
        for pl in playlists where device.selectedPlaylistIDs.contains(pl.id) {
            if pl.trackIDs.contains(track.id) { return true }
        }
        return false
    }

    // MARK: - Playlists & Drag-and-Drop

    var focusedPlaylist: Playlist? {
        if let id = focusedPlaylistID, let pl = playlists.first(where: { $0.id == id }) {
            return pl
        }
        return playlists.first
    }

    func setFocusedPlaylist(_ id: UUID?) {
        focusedPlaylistID = id
        if let id {
            database.setSetting("focusedPlaylistID", value: id.uuidString)
        }
    }

    func isTrackInFocusedPlaylist(_ track: Track) -> Bool {
        guard let pl = focusedPlaylist else { return false }
        return pl.trackIDs.contains(track.id)
    }

    func toggleTrackInFocusedPlaylist(_ track: Track) {
        if let pl = focusedPlaylist {
            if let existingIdx = pl.trackIDs.firstIndex(of: track.id) {
                removeTrack(at: existingIdx, fromPlaylistID: pl.id)
                showToast("Removed '\(track.title)' from '\(pl.name)'")
            } else {
                addTracks([track], toPlaylistID: pl.id)
            }
        } else {
            let created = createPlaylist(name: "My Playlist", initialTrackIDs: [track.id])
            setFocusedPlaylist(created.id)
            showToast("Created '\(created.name)' and added '\(track.title)'")
        }
    }

    func resolveTracks(fromDragStrings items: [String]) -> (tracks: [Track], suggestedName: String?) {
        var resolved: [Track] = []
        var seen: Set<String> = []
        var suggested: String?

        for raw in items {
            guard let payload = EchoDragPayload.decode(raw) else { continue }
            switch payload {
            case .tracks(let ids):
                for id in ids {
                    if let t = tracksByID[id], seen.insert(t.id).inserted {
                        resolved.append(t)
                        if suggested == nil { suggested = t.title }
                    }
                }
            case .album(let key):
                if let alb = albumsByKey[key] {
                    if suggested == nil { suggested = alb.title }
                    for t in alb.tracks where seen.insert(t.id).inserted {
                        resolved.append(t)
                    }
                }
            case .artist(let key):
                if let art = artistsByKey[key] {
                    if suggested == nil { suggested = art.name }
                    for t in art.tracks where seen.insert(t.id).inserted {
                        resolved.append(t)
                    }
                }
            case .playlist(let id):
                if let pl = playlists.first(where: { $0.id == id }) {
                    if suggested == nil { suggested = "\(pl.name) Copy" }
                    for tid in pl.trackIDs {
                        if let t = tracksByID[tid], seen.insert(t.id).inserted {
                            resolved.append(t)
                        }
                    }
                }
            case .reorder(let playlistID, let sourceIndex):
                if let pl = playlists.first(where: { $0.id == playlistID }),
                   sourceIndex >= 0 && sourceIndex < pl.trackIDs.count,
                   let t = tracksByID[pl.trackIDs[sourceIndex]],
                   seen.insert(t.id).inserted {
                    resolved.append(t)
                    if suggested == nil { suggested = t.title }
                }
            case .podcastShow, .podcastEpisode:
                break
            }
        }
        return (resolved, suggested)
    }

    @discardableResult
    func handleDropOntoPlaylist(items: [String], playlistID: UUID) -> Bool {
        let (droppedTracks, _) = resolveTracks(fromDragStrings: items)
        guard !droppedTracks.isEmpty else { return false }
        addTracks(droppedTracks, toPlaylistID: playlistID)
        setFocusedPlaylist(playlistID)
        return true
    }

    @discardableResult
    func handleDropToCreateNewPlaylist(items: [String]) -> Bool {
        let (droppedTracks, suggestedName) = resolveTracks(fromDragStrings: items)
        guard !droppedTracks.isEmpty else { return false }
        let name = suggestedName ?? "New Playlist"
        let pl = createPlaylist(name: name, initialTrackIDs: droppedTracks.map(\.id))
        setFocusedPlaylist(pl.id)
        navigate(to: .playlist(pl.id))
        return true
    }

    @discardableResult
    func handleDropOntoDevice(items: [String], deviceID: UUID) -> Bool {
        guard let idx = devices.firstIndex(where: { $0.id == deviceID }) else { return false }
        var changed = false
        var label = ""

        for raw in items {
            guard let payload = EchoDragPayload.decode(raw) else { continue }
            switch payload {
            case .artist(let key):
                devices[idx].selectedArtistKeys.insert(key)
                label = artistsByKey[key]?.name ?? "artist"
                changed = true
            case .album(let key):
                devices[idx].selectedAlbumKeys.insert(key)
                label = albumsByKey[key]?.title ?? "album"
                changed = true
            case .playlist(let plID):
                devices[idx].selectedPlaylistIDs.insert(plID)
                label = playlists.first(where: { $0.id == plID })?.name ?? "playlist"
                changed = true
            case .podcastShow(let showID):
                devices[idx].selectedPodcastShowIDs.insert(showID)
                label = podcasts.first(where: { $0.id == showID })?.title ?? "podcast"
                changed = true
            case .podcastEpisode(let epID):
                devices[idx].selectedEpisodeIDs.insert(epID)
                label = episodesByID[epID]?.title ?? "episode"
                changed = true
            case .tracks(let ids):
                for id in ids { devices[idx].selectedTrackIDs.insert(id) }
                label = ids.count == 1 ? (tracksByID[ids[0]]?.title ?? "track") : "\(ids.count) tracks"
                changed = true
            case .reorder(let plID, let srcIdx):
                if let pl = playlists.first(where: { $0.id == plID }),
                   srcIdx >= 0 && srcIdx < pl.trackIDs.count {
                    let tid = pl.trackIDs[srcIdx]
                    devices[idx].selectedTrackIDs.insert(tid)
                    label = tracksByID[tid]?.title ?? "track"
                    changed = true
                }
            }
        }

        if changed {
            database.saveDevice(devices[idx])
            if destinationMode == .single || activeDeviceID == nil {
                activeDeviceID = deviceID
                database.setSetting("activeDeviceID", value: deviceID.uuidString)
            }
            recomputeSyncPlan()
            showToast("Assigned '\(label)' to \(devices[idx].name)")
        }
        return changed
    }

    @discardableResult
    func handlePlaylistReorderDrop(items: [String], playlistID: UUID, targetIndex: Int) -> Bool {
        guard let plIdx = playlists.firstIndex(where: { $0.id == playlistID }) else { return false }
        for raw in items {
            if case .reorder(let srcPlID, let srcIndex) = EchoDragPayload.decode(raw), srcPlID == playlistID {
                guard srcIndex != targetIndex,
                      srcIndex >= 0 && srcIndex < playlists[plIdx].trackIDs.count else { return false }
                let moved = playlists[plIdx].trackIDs.remove(at: srcIndex)
                let clampedTarget = max(0, min(targetIndex, playlists[plIdx].trackIDs.count))
                playlists[plIdx].trackIDs.insert(moved, at: clampedTarget)
                playlists[plIdx].updatedAt = Date()
                database.savePlaylist(playlists[plIdx])
                recomputeSyncPlan()
                return true
            }
        }
        let (droppedTracks, _) = resolveTracks(fromDragStrings: items)
        guard !droppedTracks.isEmpty else { return false }
        let existing = Set(playlists[plIdx].trackIDs)
        let toInsert = droppedTracks.map(\.id).filter { !existing.contains($0) }
        guard !toInsert.isEmpty else {
            showToast("Tracks already in '\(playlists[plIdx].name)'")
            return true
        }
        let clampedTarget = max(0, min(targetIndex, playlists[plIdx].trackIDs.count))
        playlists[plIdx].trackIDs.insert(contentsOf: toInsert, at: clampedTarget)
        playlists[plIdx].updatedAt = Date()
        database.savePlaylist(playlists[plIdx])
        recomputeSyncPlan()
        showToast("Added \(toInsert.count) track\(toInsert.count == 1 ? "" : "s") to '\(playlists[plIdx].name)'")
        return true
    }

    @discardableResult
    func createPlaylist(name: String, description: String = "", initialTrackIDs: [String] = []) -> Playlist {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let pl = Playlist(
            name: trimmed.isEmpty ? "New Playlist" : trimmed,
            description: description,
            trackIDs: initialTrackIDs
        )
        playlists.append(pl)
        database.savePlaylist(pl)
        setFocusedPlaylist(pl.id)
        recomputeSyncPlan()
        showToast("Created playlist '\(pl.name)'")
        return pl
    }

    func updatePlaylist(_ playlist: Playlist) {
        var updated = playlist
        updated.updatedAt = Date()
        if let idx = playlists.firstIndex(where: { $0.id == updated.id }) {
            playlists[idx] = updated
            database.savePlaylist(updated)
            recomputeSyncPlan()
        }
    }

    func deletePlaylist(_ playlist: Playlist) {
        playlists.removeAll { $0.id == playlist.id }
        database.deletePlaylist(id: playlist.id)
        for i in devices.indices {
            if devices[i].selectedPlaylistIDs.remove(playlist.id) != nil {
                database.saveDevice(devices[i])
            }
        }
        if case .playlist(let id) = currentDestination, id == playlist.id {
            navigate(to: .home)
        }
        if focusedPlaylistID == playlist.id {
            setFocusedPlaylist(playlists.first?.id)
        }
        recomputeSyncPlan()
        showToast("Deleted playlist '\(playlist.name)'")
    }

    func addTracks(_ newTracks: [Track], toPlaylistID playlistID: UUID) {
        guard let idx = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        let existing = Set(playlists[idx].trackIDs)
        let toAdd = newTracks.map(\.id).filter { !existing.contains($0) }
        guard !toAdd.isEmpty else {
            showToast("Tracks already in '\(playlists[idx].name)'")
            return
        }
        playlists[idx].trackIDs.append(contentsOf: toAdd)
        playlists[idx].updatedAt = Date()
        database.savePlaylist(playlists[idx])
        recomputeSyncPlan()
        showToast("Added \(toAdd.count) track\(toAdd.count == 1 ? "" : "s") to '\(playlists[idx].name)'")
    }

    func removeTrack(at index: Int, fromPlaylistID playlistID: UUID) {
        guard let idx = playlists.firstIndex(where: { $0.id == playlistID }),
              index >= 0 && index < playlists[idx].trackIDs.count else { return }
        playlists[idx].trackIDs.remove(at: index)
        playlists[idx].updatedAt = Date()
        database.savePlaylist(playlists[idx])
        recomputeSyncPlan()
    }

    func moveTracksInPlaylist(playlistID: UUID, from source: IndexSet, to destination: Int) {
        guard let idx = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        playlists[idx].trackIDs.move(fromOffsets: source, toOffset: destination)
        playlists[idx].updatedAt = Date()
        database.savePlaylist(playlists[idx])
        recomputeSyncPlan()
    }

    func tracks(for playlist: Playlist) -> [Track] {
        playlist.trackIDs.compactMap { tracksByID[$0] }
    }

    // MARK: - Devices Management

    private func nextAccentColor() -> DeviceAccentColor {
        let all = DeviceAccentColor.allCases
        return all[devices.count % all.count]
    }

    @discardableResult
    func addDevice(from volume: MountedVolumeInfo, preset: DevicePresetKind = .fiioEchoMini) -> DeviceProfile {
        let isEchoInternal = volume.name.uppercased() == "ECHO" && volume.totalBytes < 16_000_000_000
        let profile = DeviceProfile(
            name: volume.name,
            accentColor: nextAccentColor(),
            volumeUUID: volume.volumeUUID,
            mountPath: volume.mountPath,
            preset: preset,
            playlistPathStyle: (preset == .fiioEchoMini && isEchoInternal) ? .echoMiniInternal : nil
        )
        devices.append(profile)
        database.saveDevice(profile)
        selectActiveDevice(profile.id)
        navigate(to: .deviceSync(profile.id))
        showToast("Added \(profile.name) (\(preset.displayName))")
        return profile
    }

    func addCustomDeviceFolderViaPanel(preset: DevicePresetKind = .fiioEchoMini) {
        let panel = NSOpenPanel()
        panel.title = "Select Audio Player, SD Card, or Target Folder"
        panel.message = "Choose the root of your FiiO player, SD card, or any local destination folder."
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            let vol = VolumeMonitor.volumeInfo(atPath: url.path)
            let profile = DeviceProfile(
                name: url.lastPathComponent,
                accentColor: nextAccentColor(),
                volumeUUID: vol?.mountPath == url.path ? vol?.volumeUUID : nil,
                mountPath: url.path,
                preset: preset
            )
            devices.append(profile)
            database.saveDevice(profile)
            selectActiveDevice(profile.id)
            navigate(to: .deviceSync(profile.id))
            showToast("Added target '\(profile.name)'")
        }
    }

    func updateDevice(_ profile: DeviceProfile) {
        guard let idx = devices.firstIndex(where: { $0.id == profile.id }) else { return }
        devices[idx] = profile
        database.saveDevice(profile)
        recomputeSyncPlan()
    }

    func deleteDevice(_ profile: DeviceProfile) {
        devices.removeAll { $0.id == profile.id }
        database.deleteDevice(id: profile.id)
        if activeDeviceID == profile.id {
            activeDeviceID = (destinationMode == .single) ? devices.first?.id : nil
            database.setSetting("activeDeviceID", value: activeDeviceID?.uuidString ?? "")
        }
        if case .deviceSync(let id) = currentDestination, id == profile.id {
            navigate(to: .home)
        }
        recomputeSyncPlan()
    }

    // MARK: - Tri-State Sync Selections (Artist / Album / Track / Playlist)

    private func mutateDevice(id targetDeviceID: UUID? = nil, _ mutate: (inout DeviceProfile) -> Void) {
        let resolvedID = targetDeviceID ?? activeDevice?.id
        guard let id = resolvedID,
              let idx = devices.firstIndex(where: { $0.id == id }) else {
            if destinationMode == .multi && !devices.isEmpty {
                showToast("Select a sync destination first (top bar or sidebar TARGET pill)", isError: true)
            } else {
                showToast("Add or select an audio player / SD card first", isError: true)
            }
            return
        }
        mutate(&devices[idx])
        database.saveDevice(devices[idx])
        recomputeSyncPlan()
    }

    func selectionState(forArtist artist: ArtistGroup, on device: DeviceProfile? = nil) -> SyncSelectionState {
        guard let dev = device ?? activeDevice else { return .none }
        if dev.selectedArtistKeys.contains(artist.id) { return .full }
        let effectiveIDs = effectiveSelectedTrackIDs(for: dev)
        let selectedCount = artist.tracks.filter { effectiveIDs.contains($0.id) }.count
        if selectedCount == 0 { return .none }
        if selectedCount == artist.tracks.count { return .full }
        return .partial
    }

    func selectionState(forAlbum album: AlbumGroup, on device: DeviceProfile? = nil) -> SyncSelectionState {
        guard let dev = device ?? activeDevice else { return .none }
        if dev.selectedAlbumKeys.contains(album.id) || dev.selectedArtistKeys.contains(album.artist.lowercased()) {
            return .full
        }
        let effectiveIDs = effectiveSelectedTrackIDs(for: dev)
        let selectedCount = album.tracks.filter { effectiveIDs.contains($0.id) }.count
        if selectedCount == 0 { return .none }
        if selectedCount == album.tracks.count { return .full }
        return .partial
    }

    func isPlaylistSelected(_ playlist: Playlist, on device: DeviceProfile? = nil) -> Bool {
        (device ?? activeDevice)?.selectedPlaylistIDs.contains(playlist.id) ?? false
    }

    func trackSyncReason(_ track: Track, on device: DeviceProfile? = nil) -> String? {
        guard let dev = device ?? activeDevice else { return nil }
        if dev.selectedTrackIDs.contains(track.id) { return "Track" }
        if dev.selectedAlbumKeys.contains(track.albumKey) { return "Album" }
        if dev.selectedArtistKeys.contains(track.artistKey) { return "Artist" }
        for pl in playlists where dev.selectedPlaylistIDs.contains(pl.id) {
            if pl.trackIDs.contains(track.id) { return "Playlist" }
        }
        return nil
    }

    func toggleArtistSync(_ artist: ArtistGroup, onDeviceID targetDeviceID: UUID? = nil) {
        let dev = targetDeviceID.flatMap { id in devices.first(where: { $0.id == id }) } ?? activeDevice
        let state = selectionState(forArtist: artist, on: dev)
        mutateDevice(id: targetDeviceID) { d in
            if state == .full {
                d.selectedArtistKeys.remove(artist.id)
                for alb in artist.albums { d.selectedAlbumKeys.remove(alb.id) }
                for t in artist.tracks { d.selectedTrackIDs.remove(t.id) }
            } else {
                d.selectedArtistKeys.insert(artist.id)
                for alb in artist.albums { d.selectedAlbumKeys.remove(alb.id) }
                for t in artist.tracks { d.selectedTrackIDs.remove(t.id) }
            }
        }
    }

    func toggleAlbumSync(_ album: AlbumGroup, onDeviceID targetDeviceID: UUID? = nil) {
        let dev = targetDeviceID.flatMap { id in devices.first(where: { $0.id == id }) } ?? activeDevice
        let state = selectionState(forAlbum: album, on: dev)
        mutateDevice(id: targetDeviceID) { d in
            if state == .full {
                let artistKey = album.artist.lowercased()
                if d.selectedArtistKeys.remove(artistKey) != nil,
                   let artistGroup = self.artistsByKey[artistKey] {
                    for otherAlb in artistGroup.albums where otherAlb.id != album.id {
                        d.selectedAlbumKeys.insert(otherAlb.id)
                    }
                }
                d.selectedAlbumKeys.remove(album.id)
                for t in album.tracks { d.selectedTrackIDs.remove(t.id) }
            } else {
                d.selectedAlbumKeys.insert(album.id)
                for t in album.tracks { d.selectedTrackIDs.remove(t.id) }
            }
        }
    }

    func toggleTrackSync(_ track: Track, onDeviceID targetDeviceID: UUID? = nil) {
        mutateDevice(id: targetDeviceID) { d in
            if d.selectedTrackIDs.contains(track.id) {
                d.selectedTrackIDs.remove(track.id)
            } else if d.selectedAlbumKeys.contains(track.albumKey) || d.selectedArtistKeys.contains(track.artistKey) {
                if d.selectedArtistKeys.remove(track.artistKey) != nil,
                   let artistGroup = self.artistsByKey[track.artistKey] {
                    for otherAlb in artistGroup.albums where otherAlb.id != track.albumKey {
                        d.selectedAlbumKeys.insert(otherAlb.id)
                    }
                }
                d.selectedAlbumKeys.remove(track.albumKey)
                if let albGroup = self.albumsByKey[track.albumKey] {
                    for other in albGroup.tracks where other.id != track.id {
                        d.selectedTrackIDs.insert(other.id)
                    }
                }
            } else {
                d.selectedTrackIDs.insert(track.id)
            }
        }
    }

    func togglePlaylistSync(_ playlist: Playlist, onDeviceID targetDeviceID: UUID? = nil) {
        mutateDevice(id: targetDeviceID) { d in
            if d.selectedPlaylistIDs.contains(playlist.id) {
                d.selectedPlaylistIDs.remove(playlist.id)
            } else {
                d.selectedPlaylistIDs.insert(playlist.id)
            }
        }
    }

    private func effectiveSelectedTrackIDs(for device: DeviceProfile) -> Set<String> {
        SyncPlanner.resolveSelectedTrackIDs(profile: device, allTracks: tracks, playlists: playlists)
    }

    // MARK: - Sync Execution

    func recomputeSyncPlan() {
        guard let device = activeDevice else {
            activeSyncPlan = nil
            return
        }
        activeSyncPlan = SyncPlanner.buildPlan(profile: device, allTracks: tracks, playlists: playlists, podcasts: podcasts)
    }

    func startSync(for targetDevice: DeviceProfile? = nil) {
        guard !isSyncing else { return }
        guard let device = targetDevice ?? activeDevice else {
            showToast("Select a sync destination first before syncing", isError: true)
            return
        }
        guard device.isConnected else {
            showToast("'\(device.name)' is not connected at \(device.mountPath)", isError: true)
            return
        }

        let plan = SyncPlanner.buildPlan(profile: device, allTracks: tracks, playlists: playlists, podcasts: podcasts)
        if activeDevice?.id == device.id {
            activeSyncPlan = plan
        }

        isSyncing = true
        lastSyncSummary = nil
        syncProgress = SyncProgress(
            phase: "Preparing sync for \(device.name)...",
            completedSteps: 0,
            totalSteps: max(1, plan.totalPendingCopies + plan.totalPendingRemovals + plan.playlistsToWrite.count),
            currentItem: "",
            bytesCopied: 0,
            totalBytes: plan.estimatedBytesToWrite,
            isFinished: false
        )

        syncTask = Task { [weak self] in
            guard let self else { return }
            do {
                let summary = try await self.syncEngine.execute(plan: plan, profile: device) { [weak self] progress in
                    Task { @MainActor [weak self] in
                        self?.syncProgress = progress
                    }
                }
                await MainActor.run {
                    self.isSyncing = false
                    self.lastSyncSummary = summary

                    // Persist any episodes auto-downloaded during sync
                    for ep in summary.downloadedEpisodes {
                        self.persistUpdatedEpisode(ep)
                    }

                    // Persist which tracks & podcast episodes are now synced on this destination!
                    if let idx = self.devices.firstIndex(where: { $0.id == device.id }) {
                        self.devices[idx].lastSyncedAt = summary.completedAt
                        self.devices[idx].syncedTrackIDs = summary.finalSyncedTrackIDs
                        self.devices[idx].syncedEpisodeIDs = summary.finalSyncedEpisodeIDs
                        self.database.saveDevice(self.devices[idx])
                    }
                    self.refreshMountedVolumes()
                    self.recomputeSyncPlan()
                    let podPart = summary.episodesCopied > 0 ? ", \(summary.episodesCopied) podcasts" : ""
                    let errSuffix = summary.errors.isEmpty ? "" : " (\(summary.errors.count) errors)"
                    self.showToast("Synced \(summary.tracksCopied) tracks\(podPart), \(summary.playlistsWritten) playlists to \(device.name) · cleaned \(summary.dotFilesCleaned) ._* files\(errSuffix)", isError: !summary.errors.isEmpty)
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.isSyncing = false
                    self.syncProgress = nil
                    self.recomputeSyncPlan()
                    self.showToast("Sync cancelled")
                }
            } catch {
                await MainActor.run {
                    self.isSyncing = false
                    self.syncProgress = nil
                    self.showToast("Sync failed: \(error.localizedDescription)", isError: true)
                }
            }
        }
    }

    func cancelSync() {
        syncTask?.cancel()
    }

    func cleanAndEjectDevice(_ device: DeviceProfile, force: Bool = false) {
        // Release any audio playback handle pointing at the volume being ejected
        if let currentPath = player.currentTrack?.filePath, currentPath.hasPrefix(device.mountPath) {
            player.stop()
        }
        showToast(force ? "Force ejecting '\(device.name)'..." : "Cleaning ._* files & ejecting '\(device.name)'...")
        Task {
            do {
                let cleaned = try await VolumeMonitor.cleanAndEject(mountPath: device.mountPath, force: force)
                await MainActor.run {
                    self.refreshMountedVolumes()
                    self.showToast("Cleaned \(cleaned) macOS junk files & safely ejected '\(device.name)'")
                }
            } catch {
                await MainActor.run {
                    self.refreshMountedVolumes()
                    self.showToast("Eject failed: \(error.localizedDescription)", isError: true)
                }
            }
        }
    }

    // MARK: - Search Filtering (Scoped to Selected Library!)

    var isGlobalSearchActive: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isViewingPodcasts: Bool {
        switch currentDestination {
        case .podcasts, .podcastDetail: return true
        default: return false
        }
    }

    var filteredArtists: [ArtistGroup] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return artists }
        return artists.filter {
            $0.name.lowercased().contains(q) || $0.albums.contains { $0.title.lowercased().contains(q) }
        }
    }

    var filteredAlbums: [AlbumGroup] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return albums }
        return albums.filter {
            $0.title.lowercased().contains(q) || $0.artist.lowercased().contains(q)
        }
    }

    var filteredTracks: [Track] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return scopedTracks }
        return scopedTracks.filter {
            $0.title.lowercased().contains(q)
                || $0.artist.lowercased().contains(q)
                || $0.album.lowercased().contains(q)
                || $0.format.displayBadge.lowercased().contains(q)
        }
    }

    var filteredPlaylists: [Playlist] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return playlists }
        return playlists.filter { pl in
            if pl.name.lowercased().contains(q) || pl.description.lowercased().contains(q) {
                return true
            }
            return pl.trackIDs.compactMap { tracksByID[$0] }.contains { t in
                (selectedSourceID == nil || t.sourceID == selectedSourceID)
                    && (t.title.lowercased().contains(q) || t.artist.lowercased().contains(q))
            }
        }
    }

    var filteredPodcastShows: [PodcastShow] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return podcasts }
        return podcasts.filter {
            $0.title.lowercased().contains(q) || $0.author.lowercased().contains(q) || $0.description.lowercased().contains(q)
        }
    }

    var filteredPodcastEpisodes: [PodcastEpisode] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }
        var out: [PodcastEpisode] = []
        for show in podcasts {
            for ep in show.episodes {
                if ep.title.lowercased().contains(q) || ep.showTitle.lowercased().contains(q) || ep.summary.lowercased().contains(q) {
                    out.append(ep)
                }
            }
        }
        return out
    }

    // MARK: - Toast Notification

    func showToast(_ message: String, isError: Bool = false) {
        toastMessage = message
        toastIsError = isError
        Task {
            try? await Task.sleep(for: .seconds(4))
            if self.toastMessage == message {
                self.toastMessage = nil
            }
        }
    }
}

import Foundation
import SwiftUI
import AppKit
import AVFoundation
import UniformTypeIdentifiers
import Observation
import EchoCore

enum PlaylistExportFormat: String, CaseIterable {
    case pls
    case m3u8

    var fileExtension: String { rawValue }

    var displayName: String {
        switch self {
        case .pls: return "PLS (Winamp)"
        case .m3u8: return "M3U8 (Extended M3U)"
        }
    }
}

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

enum TrackTableSortColumn: String, Equatable {
    case index
    case title
    case album
    case plays
    case popularity
    case rating
    case format
    case sync
    case duration

    var defaultAscending: Bool {
        switch self {
        case .index, .title, .album: return true
        case .plays, .popularity, .rating, .format, .sync, .duration: return false
        }
    }
}

struct TrackTableSortState: Equatable {
    var column: TrackTableSortColumn = .index
    var ascending: Bool = true

    mutating func toggle(_ tapped: TrackTableSortColumn) {
        if column == tapped {
            ascending.toggle()
        } else {
            column = tapped
            ascending = tapped.defaultAscending
        }
    }
}

enum TrackSortOrder: String, CaseIterable, Identifiable {
    case library = "Default"
    case newArrivals = "New Arrivals"
    case highestRated = "Highest Rated"
    case mostPlayed = "Most Played"
    case onlinePopularity = "Online Popularity"
    case recentlyPlayed = "Recently Played"
    case title = "Title A–Z"
    case artist = "Artist A–Z"
    var id: String { rawValue }
}

enum AlbumSortOrder: String, CaseIterable, Identifiable {
    case title = "A–Z"
    case newArrivals = "New Arrivals"
    case newReleases = "New Releases"
    case highestRated = "Highest Rated"
    case mostPlayed = "Most Played"
    case onlinePopularity = "Online Popularity"
    var id: String { rawValue }
}

enum AutoIndexInterval: String, CaseIterable, Identifiable {
    case off
    case every5Min
    case every15Min
    case every30Min
    case everyHour
    case every6Hours
    case daily
    case weekly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .off: return "Off"
        case .every5Min: return "Every 5 min"
        case .every15Min: return "Every 15 min"
        case .every30Min: return "Every 30 min"
        case .everyHour: return "Every hour"
        case .every6Hours: return "Every 6 hours"
        case .daily: return "Daily"
        case .weekly: return "Every week"
        }
    }

    var seconds: TimeInterval? {
        switch self {
        case .off: return nil
        case .every5Min: return 5 * 60
        case .every15Min: return 15 * 60
        case .every30Min: return 30 * 60
        case .everyHour: return 60 * 60
        case .every6Hours: return 6 * 60 * 60
        case .daily: return 24 * 60 * 60
        case .weekly: return 7 * 24 * 60 * 60
        }
    }
}

enum LidarrSearchMode: String, CaseIterable, Identifiable {
    case albums = "Albums"
    case tracks = "Tracks"
    case artists = "Artists"
    var id: String { rawValue }
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
    case partyMode
    case lidarr
    case sources
    case deviceSync(UUID)
    case settings
}

struct PartyGuestActivityItem: Identifiable, Hashable {
    let id = UUID()
    let trackID: String
    let trackTitle: String
    let artist: String
    let guestID: String?
    var guestName: String
    let addedAt: Date
}

struct PartyVoiceIntroRecord: Identifiable, Hashable {
    var id: String { trackID }
    let trackID: String
    let fileURL: URL
    let duration: TimeInterval
    let guestID: String?
    var guestName: String
    let recordedAt: Date
}

@MainActor
@Observable
final class EchoStore {
    static let partyPlaylistName = "Partymode"

    let database: EchoDatabase
    let artworkCache: ArtworkCache
    let indexer: LibraryIndexer
    let podcastService: PodcastService
    let popularityService: OnlinePopularityService
    let lidarrClient: LidarrClient
    let wirelessSyncServer: WirelessSyncServer
    let partyModeServer: PartyModeServer
    let syncEngine: SyncEngine
    let player: AudioPlayerEngine

    // Navigation & Search
    var currentDestination: NavDestination = .home
    var navHistory: [NavDestination] = [.home]
    var navHistoryIndex: Int = 0
    var searchQuery: String = ""
    /// Minimum star filter for global search (0 = off, 1...5 = at least X stars)
    var minStarRating: Int = 0
    var trackSortOrder: TrackSortOrder = .library
    var trackSortAscending: Bool = true
    var trackTableColumn: TrackTableSortColumn? = nil
    var albumSortOrder: AlbumSortOrder = .title

    // Settings
    var destinationMode: DestinationMode = .single
    var selectedTheme: AppThemeKind = .neonCassette
    var onlinePopularityEnabled: Bool = true
    var lastFMAPIKey: String = ""

    // Play Counts, Star Ratings & Online Popularity
    var trackStats: [String: TrackStats] = [:]
    var albumRatings: [String: AlbumUserRating] = [:]
    var artistStats: [String: ArtistOnlineStats] = [:]
    var fetchingPopularityKeys: Set<String> = []
    var isBatchFetchingPopularity: Bool = false
    var popularityBatchProgress: (done: Int, total: Int)? = nil
    private var popularityBatchTask: Task<Void, Never>?

    // Optional Lidarr Integration State
    var lidarrConfig: LidarrConfig = LidarrConfig()
    var lidarrStatus: LidarrSystemStatus? = nil
    var lidarrConnectionError: String? = nil
    var isTestingLidarrConnection: Bool = false
    var lidarrRootFolders: [LidarrRootFolder] = []
    var lidarrQualityProfiles: [LidarrQualityProfile] = []
    var lidarrMetadataProfiles: [LidarrMetadataProfile] = []
    var lidarrSearchQuery: String = ""
    var lidarrSearchMode: LidarrSearchMode = .albums
    var lidarrAlbumResults: [LidarrAlbumSearchResult] = []
    var lidarrArtistResults: [LidarrArtistSearchResult] = []
    var lidarrTrackResults: [LidarrTrackMatch] = []
    var isSearchingLidarr: Bool = false
    var lidarrSearchError: String? = nil
    var lidarrOrderingIDs: Set<String> = []
    var lidarrOrderedIDs: Set<String> = []
    var lidarrMarkedAlbums: [String: LidarrAlbumSearchResult] = [:]
    var lidarrMarkedTracks: [String: LidarrTrackMatch] = [:]
    var isOrderingMarkedLidarr: Bool = false
    var lidarrLastUnifiedQuery: String = ""
    private var lidarrDebounceTask: Task<Void, Never>?
    var lidarrQueue: [LidarrQueueItem] = []
    var lidarrHistory: [LidarrHistoryItem] = []
    var lidarrTrackedOrders: [LidarrTrackedOrder] = []
    var lidarrWantedMissing: [LidarrAlbumSearchResult] = []
    var lidarrQueueLastUpdatedAt: Date? = nil
    var lidarrAutoPollEnabled: Bool = true
    var isLoadingLidarrQueue: Bool = false
    private var lidarrPollTask: Task<Void, Never>?
    private var lastKnownLidarrQueueIDs: Set<Int> = []

    // Library State
    var sources: [LibrarySource] = []
    var selectedSourceID: UUID? // nil = All Libraries; UUID = stay scoped inside that specific library source
    var isLidarrLibraryScope: Bool = false
    var tracks: [Track] = []
    var playlists: [Playlist] = []
    var focusedPlaylistID: UUID?

    // Podcasts State
    var podcasts: [PodcastShow] = []
    var selectedPodcastDirectory: PodcastDirectory = .all
    var activePodcastCategory: PodcastBrowseCategory? = .featured
    var previewingPodcastResult: PodcastSearchResult? = nil
    var previewingPodcastShow: PodcastShow? = nil
    var isLoadingPodcastPreview: Bool = false
    var podcastPreviewError: String? = nil
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
    private(set) var newArrivalAlbums: [AlbumGroup] = []
    private(set) var newReleaseAlbums: [AlbumGroup] = []
    private(set) var tracksByID: [String: Track] = [:]
    private(set) var artistsByKey: [String: ArtistGroup] = [:]
    private(set) var featuredTracksByArtistKey: [String: [Track]] = [:]
    private(set) var featuredDisplayNameByArtistKey: [String: String] = [:]
    private(set) var albumsByKey: [String: AlbumGroup] = [:]
    private(set) var albumByTrackID: [String: AlbumGroup] = [:]
    /// Unscoped trackID -> AlbumGroup across the entire library (used by SyncPlanner & O(1) device selection caches)
    private(set) var allTrackAlbumByID: [String: AlbumGroup] = [:]
    /// O(1) cache of effective selected track IDs per device — eliminates O(N²) recomputation in card/row SwiftUI views!
    private(set) var selectedTrackIDsByDeviceID: [UUID: Set<String>] = [:]
    private(set) var episodesByID: [String: PodcastEpisode] = [:]

    // Devices & Sync State
    var devices: [DeviceProfile] = []
    var activeDeviceID: UUID?
    var detectedVolumes: [MountedVolumeInfo] = []
    private(set) var activeSyncPlan: SyncPlan?
    private(set) var syncPlansByDeviceID: [UUID: SyncPlan] = [:]
    private var syncPlanTask: Task<Void, Never>?

    // Virtual iPhone Wireless Sync Server & Apple TV Companion State
    var isWirelessServerRunning: Bool = false
    var wirelessServerPort: UInt16 = 0
    var wirelessServerLANIP: String? = WirelessSyncServer.localLANIPAddress()
    var wirelessServerLastError: String? = nil
    var lastWirelessClientName: String? = nil
    var wirelessManifestVersions: [UUID: String] = [:]
    var appleTVCompanionEnabled: Bool = true
    var appleTVPairingPIN: String = ""

    // Party Mode (Locked Dynamic "Partymode" Playlist + Stable/Custom-Port Guest Web Server)
    static let defaultPartyPort: UInt16 = 53_333
    var isPartyModeEnabled: Bool = false
    var partyPlaylistID: UUID? = nil
    var isPartyServerRunning: Bool = false
    var partyServerPort: UInt16 = 0
    var partyPreferredPort: UInt16? = EchoStore.defaultPartyPort
    var partyServerLANIP: String? = WirelessSyncServer.localLANIPAddress()
    var partyServerLastError: String? = nil
    var partyAutoPlayOnRequest: Bool = true
    var partyAllowReRequestPlayed: Bool = true
    var partyChatEnabled: Bool = true
    var partyStreamingEnabled: Bool = true
    var partyMaxIntroSeconds: Int = 15
    var partyVoiceIntrosByTrackID: [String: PartyVoiceIntroRecord] = [:]
    var partyGuests: [PartyGuestPresence] = []
    var partyChatMessages: [PartyChatMessage] = []
    var partyGuestActivity: [PartyGuestActivityItem] = []
    private var partyRequesterByTrackID: [String: (guestID: String?, guestName: String, addedAt: Date)] = [:]
    private var partyStateRevision: Int = 0
    private var partyPresenceTask: Task<Void, Never>?

    // Live Activity
    var isIndexing: Bool = false
    var indexProgress: IndexProgress?
    var autoIndexInterval: AutoIndexInterval = .off
    var isSyncing: Bool = false
    var syncProgress: SyncProgress?
    var lastSyncSummary: SyncExecutionSummary?
    var toastMessage: String?
    var toastIsError: Bool = false
    var isMiniPlayerOpen: Bool = false
    var lightboxAlbum: AlbumGroup? = nil
    var albumEditorialByKey: [String: AlbumEditorialInfo] = [:]
    var artistEditorialByKey: [String: ArtistEditorialInfo] = [:]
    var fetchingEditorialKeys: Set<String> = []

    private var syncTask: Task<Void, Never>?
    private var autoIndexTask: Task<Void, Never>?
    private var editorialSyncTask: Task<Void, Never>?
    private var volumeObservers: [NSObjectProtocol] = []
    private var terminationObserver: NSObjectProtocol?

    init() {
        self.artworkCache = ArtworkCache()
        self.database = try! EchoDatabase()
        self.indexer = LibraryIndexer(artworkCache: artworkCache)
        self.podcastService = PodcastService(artworkCache: artworkCache)
        self.popularityService = OnlinePopularityService()
        self.lidarrClient = LidarrClient()
        self.wirelessSyncServer = WirelessSyncServer(artworkCache: artworkCache)
        self.partyModeServer = PartyModeServer(artworkCache: artworkCache)
        self.syncEngine = SyncEngine(artworkCache: artworkCache, podcastService: podcastService)
        self.player = AudioPlayerEngine()

        setupWirelessSyncServerCallbacks()
        setupPartyModeCallbacks()
        loadPersistedState()
        setupPlayerSettingsPersistence()
        refreshMountedVolumes()
        startVolumeMonitoring()
        refreshWirelessSyncServer()
        restartAutoIndexScheduler()
        startOccasionalEditorialSync()
        if lidarrConfig.isEnabled && lidarrConfig.isConfigured {
            testLidarrConnection(silent: true)
            startLidarrQueuePolling()
        }
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

    /// Navigate cleanly to an Artist detail page from anywhere (clears active search, supports featured/split artists, widens library scope if needed)
    func openArtist(key: String) {
        let normalizedKey = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedKey.isEmpty else { return }
        clearGlobalSearch()
        isLidarrLibraryScope = false
        if resolveArtist(forKey: normalizedKey) == nil && selectedSourceID != nil {
            selectedSourceID = nil
            database.setSetting("selectedSourceID", value: "")
            rebuildLibraryGroups()
        }
        guard resolveArtist(forKey: normalizedKey) != nil else { return }
        navigate(to: .artistDetail(normalizedKey))
    }

    func openArtist(name: String) {
        openArtist(key: name)
    }

    func openAlbumLightbox(_ album: AlbumGroup) {
        lightboxAlbum = album
    }

    func openAlbumLightbox(forTrack track: Track) {
        if let album = allTrackAlbumByID[track.id] ?? albumByTrackID[track.id] {
            lightboxAlbum = album
        } else {
            let synthetic = AlbumGroup(
                id: track.albumKey,
                title: track.effectiveAlbum,
                artist: track.effectiveArtist,
                year: track.year,
                artworkHash: track.artworkHash,
                tracks: [track]
            )
            lightboxAlbum = synthetic
        }
    }

    func closeAlbumLightbox() {
        lightboxAlbum = nil
    }

    // MARK: - Local Editorial Metadata Cache & Occasional Online Sync

    func ensureEditorialLoaded(forAlbum album: AlbumGroup, force: Bool = false) {
        if !force, let cached = albumEditorialByKey[album.id], !cached.isStale {
            return
        }
        let fetchKey = "album:\(album.id)"
        guard !fetchingEditorialKeys.contains(fetchKey) else { return }
        fetchingEditorialKeys.insert(fetchKey)

        let albumID = album.id
        let artistName = album.artist
        let albumTitle = album.title

        Task {
            let result = await EditorialInfoFetcher.fetchAlbumEditorial(
                albumKey: albumID,
                artist: artistName,
                albumTitle: albumTitle
            )
            await MainActor.run {
                self.albumEditorialByKey[albumID] = result.album
                self.database.saveAlbumEditorial(result.album)
                if let artistInfo = result.artist {
                    self.artistEditorialByKey[artistInfo.artistKey] = artistInfo
                    self.database.saveArtistEditorial(artistInfo)
                }
                self.fetchingEditorialKeys.remove(fetchKey)
                self.refreshWirelessSyncServer()
            }
        }
    }

    func ensureEditorialLoaded(forArtist artist: ArtistGroup, force: Bool = false) {
        if !force, let cached = artistEditorialByKey[artist.id], !cached.isStale {
            return
        }
        let fetchKey = "artist:\(artist.id)"
        guard !fetchingEditorialKeys.contains(fetchKey) else { return }
        fetchingEditorialKeys.insert(fetchKey)

        let artistID = artist.id
        let artistName = artist.name

        Task {
            let result = await EditorialInfoFetcher.fetchArtistEditorial(
                artistKey: artistID,
                artistName: artistName
            )
            await MainActor.run {
                self.artistEditorialByKey[artistID] = result
                self.database.saveArtistEditorial(result)
                self.fetchingEditorialKeys.remove(fetchKey)
            }
        }
    }

    /// Politely syncs a small batch of uncached or >14-day-stale album & artist editorial records
    /// in the background every 6 hours so local SQLite stays rich & fresh without hammering online APIs.
    private func startOccasionalEditorialSync() {
        editorialSyncTask?.cancel()
        editorialSyncTask = Task { @MainActor [weak self] in
            // Initial gentle delay so app startup remains instant
            try? await Task.sleep(for: .seconds(12))
            while !Task.isCancelled {
                guard let self else { return }
                let wirelessTrackIDs: Set<String> = Set(
                    self.devices.filter(\.isVirtualWireless).flatMap { self.effectiveSelectedTrackIDs(for: $0) }
                )
                let prioritizedAlbums = self.albums.sorted { a, b in
                    let aSynced = a.tracks.contains { wirelessTrackIDs.contains($0.id) }
                    let bSynced = b.tracks.contains { wirelessTrackIDs.contains($0.id) }
                    if aSynced != bSynced { return aSynced }
                    return a.latestArrivalDate > b.latestArrivalDate
                }
                let staleAlbums = prioritizedAlbums.filter { album in
                    guard let existing = self.albumEditorialByKey[album.id] else { return true }
                    return existing.isStale
                }.prefix(10)

                var fetchedAny = false
                for album in staleAlbums {
                    guard !Task.isCancelled else { return }
                    let fetchKey = "album:\(album.id)"
                    if self.fetchingEditorialKeys.contains(fetchKey) { continue }
                    self.fetchingEditorialKeys.insert(fetchKey)
                    let result = await EditorialInfoFetcher.fetchAlbumEditorial(
                        albumKey: album.id,
                        artist: album.artist,
                        albumTitle: album.title
                    )
                    self.albumEditorialByKey[album.id] = result.album
                    self.database.saveAlbumEditorial(result.album)
                    if let artistInfo = result.artist {
                        self.artistEditorialByKey[artistInfo.artistKey] = artistInfo
                        self.database.saveArtistEditorial(artistInfo)
                    }
                    self.fetchingEditorialKeys.remove(fetchKey)
                    fetchedAny = true
                    try? await Task.sleep(for: .milliseconds(1200))
                }
                if fetchedAny {
                    self.refreshWirelessSyncServer()
                }

                // Sleep 6 hours between occasional background sync batches
                try? await Task.sleep(for: .seconds(6 * 60 * 60))
            }
        }
    }

    /// Resolves either a primary AlbumArtist or a featured/collaboration artist parsed from multi-artist track credits.
    func resolveArtist(forKey key: String) -> (artist: ArtistGroup, appearsOnTracks: [Track])? {
        let k = key.lowercased()
        if let primary = artistsByKey[k] {
            let ownIDs = Set(primary.tracks.map(\.id))
            let extra = (featuredTracksByArtistKey[k] ?? []).filter { !ownIDs.contains($0.id) }
            return (primary, extra)
        }
        guard let featured = featuredTracksByArtistKey[k], !featured.isEmpty else {
            return nil
        }
        let displayName = featuredDisplayNameByArtistKey[k] ?? key
        let uniqueAlbumKeys = Array(NSOrderedSet(array: featured.map(\.albumKey))) as? [String] ?? []
        let relatedAlbums = uniqueAlbumKeys.compactMap { albumsByKey[$0] }
        let artwork = featured.first(where: { $0.artworkHash != nil })?.artworkHash
        let synthesized = ArtistGroup(
            id: k,
            name: displayName,
            artworkHash: artwork,
            albums: relatedAlbums,
            tracks: featured
        )
        return (synthesized, [])
    }

    /// Navigate cleanly to an Album detail page from anywhere (clears active search & widens library scope if needed)
    func openAlbum(key: String) {
        let normalizedKey = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedKey.isEmpty else { return }
        clearGlobalSearch()
        isLidarrLibraryScope = false
        if albumsByKey[normalizedKey] == nil && selectedSourceID != nil {
            selectedSourceID = nil
            database.setSetting("selectedSourceID", value: "")
            rebuildLibraryGroups()
        }
        guard albumsByKey[normalizedKey] != nil else { return }
        navigate(to: .albumDetail(normalizedKey))
    }

    func openArtist(forTrack track: Track) {
        openArtist(key: track.artistKey)
    }

    func openAlbum(forTrack track: Track) {
        openAlbum(key: albumByTrackID[track.id]?.id ?? track.albumKey)
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
        if isLidarrLibraryScope { return "Lidarr" }
        return selectedSource?.name ?? "All Libraries"
    }

    func selectLidarrLibraryScope() {
        guard lidarrConfig.isEnabled else { return }
        isLidarrLibraryScope = true
        selectedSourceID = nil
        database.setSetting("selectedSourceID", value: "")
        if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            searchLidarrUnified(query: searchQuery, immediate: true)
        } else {
            navigate(to: .lidarr)
        }
        showToast("Library scope: Lidarr — search & mark albums/tracks for download")
    }

    func selectLibrarySource(_ sourceID: UUID?) {
        isLidarrLibraryScope = false
        selectedSourceID = sourceID
        database.setSetting("selectedSourceID", value: sourceID?.uuidString ?? "")
        rebuildLibraryGroups()
        // If currently viewing Lidarr or an artist/album detail that doesn't exist in the newly selected library, return smoothly
        switch currentDestination {
        case .lidarr:
            navigate(to: .home)
        case .artistDetail(let key) where resolveArtist(forKey: key) == nil:
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
        trackStats = database.loadAllTrackStats()
        albumRatings = database.loadAllAlbumRatings()
        artistStats = database.loadAllArtistStats()
        albumEditorialByKey = database.loadAllAlbumEditorial()
        artistEditorialByKey = database.loadAllArtistEditorial()

        if let popEnabledStr = database.getSetting("onlinePopularityEnabled") {
            onlinePopularityEnabled = (popEnabledStr != "false")
        }
        if let autoIndexStr = database.getSetting("autoIndexInterval"),
           let parsedInterval = AutoIndexInterval(rawValue: autoIndexStr) {
            autoIndexInterval = parsedInterval
        }
        if let savedLastFMKey = database.getSetting("lastFMAPIKey") {
            lastFMAPIKey = savedLastFMKey
        }
        if let lidarrJSON = database.getSetting("lidarrConfig"),
           let data = lidarrJSON.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(LidarrConfig.self, from: data) {
            lidarrConfig = decoded
        }
        if let trackedJSON = database.getSetting("lidarrTrackedOrders"),
           let data = trackedJSON.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([LidarrTrackedOrder].self, from: data) {
            lidarrTrackedOrders = decoded
        }
        if let autoPollStr = database.getSetting("lidarrAutoPollEnabled") {
            lidarrAutoPollEnabled = (autoPollStr != "false")
        }

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
        if let xfStr = database.getSetting("playerCrossfadeEnabled") {
            player.crossfadeEnabled = (xfStr == "true")
        }
        if let xfDurStr = database.getSetting("playerCrossfadeDuration"), let d = Double(xfDurStr) {
            player.crossfadeDuration = d
        }
        if let savedOutputUID = database.getSetting("audioOutputDeviceUID"), !savedOutputUID.isEmpty {
            player.selectedOutputDeviceUID = savedOutputUID
        }
        if let pauseCallStr = database.getSetting("playerAutoPauseOnCall") {
            player.autoPauseOnCall = (pauseCallStr != "false")
        }
        if let resumeCallStr = database.getSetting("playerAutoResumeAfterCall") {
            player.autoResumeAfterCall = (resumeCallStr != "false")
        }
        if let savedPartyPortStr = database.getSetting("partyPreferredPort"),
           let parsedPort = UInt16(savedPartyPortStr),
           parsedPort >= 1024 {
            partyPreferredPort = parsedPort
        }
        if let partyChatStr = database.getSetting("partyChatEnabled") {
            partyChatEnabled = (partyChatStr != "false")
        }
        if let partyStreamStr = database.getSetting("partyStreamingEnabled") {
            partyStreamingEnabled = (partyStreamStr != "false")
        }
        if let maxIntroStr = database.getSetting("partyMaxIntroSeconds"),
           let parsedSecs = Int(maxIntroStr) {
            partyMaxIntroSeconds = max(5, min(60, parsedSecs))
        }
        if let tvEnabledStr = database.getSetting("appleTVCompanionEnabled") {
            appleTVCompanionEnabled = (tvEnabledStr != "false")
        }
        if let savedTVPIN = database.getSetting("appleTVPairingPIN"), !savedTVPIN.isEmpty {
            appleTVPairingPIN = savedTVPIN
        } else {
            let generated = DeviceProfile.generatePairingPIN()
            appleTVPairingPIN = generated
            database.setSetting("appleTVPairingPIN", value: generated)
        }

        rebuildLibraryGroups()
        rebuildEpisodeMap()
        recomputeSyncPlan()
        restorePersistedPlaybackQueue()
    }

    private struct PersistedPlaybackQueue: Codable {
        var trackIDs: [String]
        var nonLibraryTracks: [Track]
        var currentIndex: Int
        var currentTime: TimeInterval
    }

    private func persistPlaybackQueue() {
        let queueTracks = player.queue
        guard !queueTracks.isEmpty else {
            database.setSetting("persistedPlaybackQueue", value: "")
            return
        }
        let ids = queueTracks.map(\.id)
        let extras = queueTracks.filter { tracksByID[$0.id] == nil }
        let payload = PersistedPlaybackQueue(
            trackIDs: ids,
            nonLibraryTracks: extras,
            currentIndex: player.currentIndex,
            currentTime: player.currentTime
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        if let data = try? encoder.encode(payload),
           let json = String(data: data, encoding: .utf8) {
            database.setSetting("persistedPlaybackQueue", value: json)
        }
    }

    private func restorePersistedPlaybackQueue() {
        guard let json = database.getSetting("persistedPlaybackQueue"),
              !json.isEmpty,
              let data = json.data(using: .utf8) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        guard let saved = try? decoder.decode(PersistedPlaybackQueue.self, from: data),
              !saved.trackIDs.isEmpty else { return }

        let extrasByID = Dictionary(uniqueKeysWithValues: saved.nonLibraryTracks.map { ($0.id, $0) })
        var resolved: [Track] = []
        var remappedIndex = 0
        for (idx, tid) in saved.trackIDs.enumerated() {
            if let track = tracksByID[tid] ?? extrasByID[tid] {
                if idx == saved.currentIndex {
                    remappedIndex = resolved.count
                }
                resolved.append(track)
            }
        }
        guard !resolved.isEmpty else { return }
        player.restoreQueue(tracks: resolved, currentIndex: remappedIndex, resumeTime: saved.currentTime)
    }

    private func setupPlayerSettingsPersistence() {
        player.onSettingsChanged = { [weak self] in
            guard let self else { return }
            self.database.setSetting("playerVolume", value: String(self.player.volume))
            self.database.setSetting("playerShuffle", value: self.player.isShuffled ? "true" : "false")
            self.database.setSetting("playerRepeat", value: self.player.repeatMode.rawValue)
            self.database.setSetting("playerCrossfadeEnabled", value: self.player.crossfadeEnabled ? "true" : "false")
            self.database.setSetting("playerCrossfadeDuration", value: String(self.player.crossfadeDuration))
            self.database.setSetting("audioOutputDeviceUID", value: self.player.selectedOutputDeviceUID ?? "")
            self.database.setSetting("playerAutoPauseOnCall", value: self.player.autoPauseOnCall ? "true" : "false")
            self.database.setSetting("playerAutoResumeAfterCall", value: self.player.autoResumeAfterCall ? "true" : "false")
        }
        player.onQueueChanged = { [weak self] in
            self?.persistPlaybackQueue()
            self?.pushPartyModeStateToServer()
        }
        player.onTrackPlayed = { [weak self] track in
            guard let self else { return }
            self.recordUserPlay(for: track)
        }
        player.onArtworkDataForNowPlaying = { [weak self] hash in
            guard let self, let hash else { return nil }
            return self.artworkCache.loadThumbnailData(for: hash)
        }
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.persistPlaybackQueue()
                self?.partyModeServer.stop()
            }
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

        let albumResult = AlbumGroup.buildGroupsWithTrackLookup(from: scopedTracks)
        let builtAlbums = albumResult.albums
        albums = builtAlbums
        albumsByKey = Dictionary(uniqueKeysWithValues: builtAlbums.map { ($0.id, $0) })
        albumByTrackID = albumResult.albumByTrackID
        if selectedSourceID == nil {
            allTrackAlbumByID = albumResult.albumByTrackID
        } else {
            allTrackAlbumByID = AlbumGroup.buildGroupsWithTrackLookup(from: tracks).albumByTrackID
        }
        rebuildSelectedTrackIDCache()

        // New Arrivals: newly downloaded / added albums sorted by latest arrival timestamp
        newArrivalAlbums = builtAlbums.sorted { a, b in
            let da = a.latestArrivalDate
            let db = b.latestArrivalDate
            if abs(da.timeIntervalSince(db)) > 1.0 { return da > db }
            return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
        }

        // New Releases: newly released albums sorted by valid release year descending, then newest arrival
        let maxValidYear = Calendar.current.component(.year, from: Date()) + 1
        newReleaseAlbums = builtAlbums
            .filter { album in
                guard let y = album.year else { return false }
                return y >= 1900 && y <= maxValidYear
            }
            .sorted { a, b in
                let ya = a.year ?? 0
                let yb = b.year ?? 0
                if ya != yb { return ya > yb }
                let da = a.latestArrivalDate
                let db = b.latestArrivalDate
                if abs(da.timeIntervalSince(db)) > 1.0 { return da > db }
                return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            }

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

        // Index individual artist names from multi-artist track credits (e.g. "Alan Walker, Noah Cyrus, ...")
        var featuredMap: [String: [Track]] = [:]
        var displayNameMap: [String: String] = [:]
        for track in scopedTracks {
            var trackArtistKeys: Set<String> = []
            for rawCredit in [track.artist, track.albumArtist] where !rawCredit.isEmpty {
                for name in ArtistNameParser.artistNames(rawCredit) {
                    let k = name.lowercased()
                    if trackArtistKeys.insert(k).inserted {
                        featuredMap[k, default: []].append(track)
                        if displayNameMap[k] == nil {
                            displayNameMap[k] = name
                        }
                    }
                }
            }
        }
        featuredTracksByArtistKey = featuredMap
        featuredDisplayNameByArtistKey = displayNameMap

        if isPartyModeEnabled {
            partyModeServer.updateLibrary(tracks: tracks)
            pushPartyModeStateToServer()
        }
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

        // Read optional .echo-sync-manifest.json deviceID on each mounted volume so SD cards
        // moving between a player and a generic card reader always match their saved destination profile!
        var manifestDeviceIDByPath: [String: UUID] = [:]
        for vol in detectedVolumes {
            let manifestURL = URL(fileURLWithPath: vol.mountPath).appendingPathComponent(".echo-sync-manifest.json")
            if let data = try? Data(contentsOf: manifestURL),
               let m = try? JSONDecoder().decode(DeviceSyncManifest.self, from: data) {
                manifestDeviceIDByPath[vol.mountPath] = m.deviceID
            }
        }

        var updated = false
        for i in devices.indices {
            // Heal any legacy bogus all-zero FAT32 UUID stored previously
            if let existingUUID = devices[i].volumeUUID, VolumeMonitor.sanitizedVolumeUUID(existingUUID) == nil {
                devices[i].volumeUUID = nil
                database.saveDevice(devices[i])
                updated = true
            }

            let match = detectedVolumes.first(where: { vol in
                if let mID = manifestDeviceIDByPath[vol.mountPath], mID == devices[i].id {
                    return true
                }
                if let devUUID = VolumeMonitor.sanitizedVolumeUUID(devices[i].volumeUUID),
                   let volUUID = VolumeMonitor.sanitizedVolumeUUID(vol.volumeUUID),
                   devUUID == volUUID {
                    return true
                }
                return vol.mountPath == devices[i].mountPath
            })

            if let match {
                var devChanged = false
                if devices[i].mountPath != match.mountPath {
                    devices[i].mountPath = match.mountPath
                    devChanged = true
                }
                if let newUUID = VolumeMonitor.sanitizedVolumeUUID(match.volumeUUID), devices[i].volumeUUID != newUUID {
                    devices[i].volumeUUID = newUUID
                    devChanged = true
                }
                if !devices[i].hasCustomName && devices[i].name != match.name {
                    devices[i].name = match.name
                    devChanged = true
                }
                if devices[i].lastConnectionKind != match.connectionKind {
                    devices[i].lastConnectionKind = match.connectionKind
                    devChanged = true
                }
                let summary = match.connectionSummary
                if devices[i].lastConnectionDetail != summary {
                    devices[i].lastConnectionDetail = summary
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
                    showToast("Mounted: \(devices[i].name) (\(match.connectionKind.shortBadge))")
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
                let sameUUID: Bool = {
                    guard let du = VolumeMonitor.sanitizedVolumeUUID(d.volumeUUID),
                          let vu = VolumeMonitor.sanitizedVolumeUUID(vol.volumeUUID) else { return false }
                    return du == vu
                }()
                return sameUUID || d.mountPath == vol.mountPath
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

    func setAutoIndexInterval(_ interval: AutoIndexInterval) {
        autoIndexInterval = interval
        database.setSetting("autoIndexInterval", value: interval.rawValue)
        restartAutoIndexScheduler()
        if interval == .off {
            showToast("Auto-scan turned off (manual Re-Index only)")
        } else {
            showToast("Auto-scan schedule: \(interval.displayName)")
        }
    }

    private func restartAutoIndexScheduler() {
        autoIndexTask?.cancel()
        autoIndexTask = nil
        guard let intervalSeconds = autoIndexInterval.seconds else { return }

        autoIndexTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let now = Date()
                // Find the soonest next-due time across all online sources
                var nextWait: TimeInterval = intervalSeconds
                var dueSources: [LibrarySource] = []

                for src in self.sources where src.isAvailable {
                    if let last = src.lastIndexedAt {
                        let elapsed = now.timeIntervalSince(last)
                        if elapsed >= intervalSeconds {
                            dueSources.append(src)
                        } else {
                            nextWait = min(nextWait, intervalSeconds - elapsed)
                        }
                    } else {
                        dueSources.append(src)
                    }
                }

                if !dueSources.isEmpty && !self.isIndexing && !self.isSyncing {
                    for src in dueSources {
                        guard !Task.isCancelled else { return }
                        if src.isAvailable {
                            await self.indexSource(src)
                        }
                    }
                    // After scanning due sources, sleep for the next check window
                    let postSleep = min(max(intervalSeconds, 30), 600)
                    try? await Task.sleep(for: .seconds(postSleep))
                } else {
                    // Check at most every 10 min so Mac wake-from-sleep catches overdue scans quickly
                    let clampedSleep = min(max(nextWait, 15), 600)
                    try? await Task.sleep(for: .seconds(clampedSleep))
                }
            }
        }
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

        let hasChanges = result.addedCount > 0
            || result.updatedCount > 0
            || result.tracks.count != existing.count
            || result.isSourceOffline

        if hasChanges {
            database.replaceTracks(forSourceID: source.id, tracks: result.tracks)
            tracks.removeAll { $0.sourceID == source.id }
            tracks.append(contentsOf: result.tracks)
        }

        if let idx = sources.firstIndex(where: { $0.id == source.id }) {
            sources[idx].lastIndexedAt = Date()
            sources[idx].trackCount = result.tracks.count
            database.saveSource(sources[idx])
        }

        if hasChanges {
            rebuildLibraryGroups()
            recomputeSyncPlan()
        }
        isIndexing = false
        indexProgress = nil

        if result.isSourceOffline {
            showToast("'\(source.name)' is offline — kept \(result.tracks.count) cached tracks", isError: true)
        } else if result.addedCount > 0 {
            showToast("Indexed '\(source.name)': \(result.addedCount) new track\(result.addedCount == 1 ? "" : "s") (\(result.tracks.count) total)")
        }
    }

    // MARK: - Podcasts (Search, Subscribe, Refresh, Download, Play, Sync)

    func searchPodcasts() {
        let q = podcastSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else {
            browsePodcastCategory(activePodcastCategory ?? .featured)
            return
        }
        // Keep an explicit genre filter (not Featured/Top Charts) active so users can search WITHIN a genre!
        let genreFilter: PodcastBrowseCategory? = {
            if let active = activePodcastCategory, active != .featured && active != .topCharts {
                return active
            }
            return nil
        }()
        if genreFilter == nil {
            activePodcastCategory = PodcastBrowseCategory.matchingGenre(for: q)
        }
        isSearchingPodcasts = true
        podcastSearchError = nil
        let directory = selectedPodcastDirectory
        Task {
            do {
                let results = try await podcastService.searchPodcasts(query: q, directory: directory, category: genreFilter)
                await MainActor.run {
                    self.podcastSearchResults = results
                    self.isSearchingPodcasts = false
                    if results.isEmpty {
                        let scopeLabel = genreFilter.map { " in \($0.rawValue)" } ?? ""
                        self.podcastSearchError = "No podcasts found for '\(q)'\(scopeLabel) in \(directory.displayName)."
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
        // Clicking an already-selected genre chip clears the genre filter back to All
        if activePodcastCategory == category && category != .featured {
            activePodcastCategory = nil
            if !podcastSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                searchPodcasts()
            } else {
                podcastSearchResults = PodcastService.curatedFeaturedShows
            }
            return
        }

        activePodcastCategory = category
        podcastSearchError = nil
        let q = podcastSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty && category != .featured && category != .topCharts {
            searchPodcasts()
            return
        }
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

    var subscribedPodcasts: [PodcastShow] {
        podcasts.filter { !$0.isSingleEpisodesBucket }
    }

    var singleEpisodesShow: PodcastShow? {
        podcasts.first(where: \.isSingleEpisodesBucket)
    }

    var singleEpisodes: [PodcastEpisode] {
        singleEpisodesShow?.episodes ?? []
    }

    func openPodcastSearchPreview(_ result: PodcastSearchResult) {
        if let existing = subscribedPodcasts.first(where: { $0.feedURL.caseInsensitiveCompare(result.feedURL) == .orderedSame }) {
            navigate(to: .podcastDetail(existing.id))
            return
        }
        previewingPodcastResult = result
        previewingPodcastShow = nil
        podcastPreviewError = nil
        isLoadingPodcastPreview = true

        Task {
            do {
                let fetched = try await podcastService.fetchFeed(
                    feedURLString: result.feedURL,
                    fallbackArtworkURL: result.artworkURL
                )
                await MainActor.run {
                    guard self.previewingPodcastResult?.feedURL == result.feedURL else { return }
                    self.previewingPodcastShow = fetched
                    self.isLoadingPodcastPreview = false
                }
            } catch {
                await MainActor.run {
                    guard self.previewingPodcastResult?.feedURL == result.feedURL else { return }
                    self.podcastPreviewError = error.localizedDescription
                    self.isLoadingPodcastPreview = false
                }
            }
        }
    }

    func closePodcastSearchPreview() {
        previewingPodcastResult = nil
        previewingPodcastShow = nil
        podcastPreviewError = nil
        isLoadingPodcastPreview = false
    }

    func isSavedAsSingleEpisode(_ episode: PodcastEpisode) -> Bool {
        singleEpisodes.contains {
            $0.id == episode.id
                || (!$0.guid.isEmpty && $0.guid == episode.guid)
                || (!$0.audioURL.isEmpty && $0.audioURL == episode.audioURL)
        }
    }

    /// Downloads a single podcast episode without subscribing to its show and stores it in "EnkeltEpisoder".
    func downloadSingleEpisode(_ episode: PodcastEpisode, autoPlay: Bool = false, pinToActiveDevice: Bool = false) {
        if let existing = singleEpisodes.first(where: {
            $0.id == episode.id || (!$0.guid.isEmpty && $0.guid == episode.guid) || (!$0.audioURL.isEmpty && $0.audioURL == episode.audioURL)
        }), existing.isDownloaded {
            if pinToActiveDevice, let dev = activeDevice, !dev.selectedEpisodeIDs.contains(existing.id) {
                toggleEpisodeSync(existing)
            }
            if autoPlay {
                playEpisode(existing)
            } else {
                showToast("'\(existing.title)' er allerede i EnkeltEpisoder")
            }
            return
        }

        guard !downloadingEpisodeIDs.contains(episode.id) else { return }
        downloadingEpisodeIDs.insert(episode.id)
        showToast("Laster ned '\(episode.title)' til EnkeltEpisoder...")

        Task {
            do {
                var downloaded = try await podcastService.downloadEpisode(episode)
                downloaded.showID = PodcastShow.singleEpisodesShowID
                await MainActor.run {
                    if let idx = self.podcasts.firstIndex(where: \.isSingleEpisodesBucket) {
                        if let eIdx = self.podcasts[idx].episodes.firstIndex(where: {
                            $0.id == downloaded.id || (!$0.guid.isEmpty && $0.guid == downloaded.guid)
                        }) {
                            self.podcasts[idx].episodes[eIdx] = downloaded
                        } else {
                            self.podcasts[idx].episodes.insert(downloaded, at: 0)
                        }
                        if self.podcasts[idx].artworkHash == nil {
                            self.podcasts[idx].artworkHash = downloaded.artworkHash
                        }
                        self.database.savePodcast(self.podcasts[idx])
                    } else {
                        let bucket = PodcastShow(
                            id: PodcastShow.singleEpisodesShowID,
                            title: "EnkeltEpisoder",
                            author: "Enkeltstående nedlastinger",
                            description: "Episoder lastet ned uten å abonnere på podcasten.",
                            feedURL: PodcastShow.singleEpisodesFeedURL,
                            artworkHash: downloaded.artworkHash,
                            lastRefreshedAt: Date(),
                            episodesToKeep: 0,
                            episodes: [downloaded]
                        )
                        self.podcasts.append(bucket)
                        self.database.savePodcast(bucket)
                    }
                    self.rebuildEpisodeMap()
                    if pinToActiveDevice, let dev = self.activeDevice, !dev.selectedEpisodeIDs.contains(downloaded.id) {
                        self.toggleEpisodeSync(downloaded)
                    } else {
                        self.recomputeSyncPlan()
                    }
                    self.downloadingEpisodeIDs.remove(episode.id)
                    if autoPlay, let track = downloaded.asPlayableTrack() {
                        self.player.playSingle(track)
                    } else {
                        self.showToast("Lagret '\(downloaded.title)' i EnkeltEpisoder")
                    }
                }
            } catch {
                await MainActor.run {
                    self.downloadingEpisodeIDs.remove(episode.id)
                    self.showToast("Nedlasting feilet: \(error.localizedDescription)", isError: true)
                }
            }
        }
    }

    func removeSingleEpisode(_ episode: PodcastEpisode) {
        Task {
            _ = await podcastService.deleteDownloadedEpisode(episode)
            await MainActor.run {
                if let idx = self.podcasts.firstIndex(where: \.isSingleEpisodesBucket) {
                    self.podcasts[idx].episodes.removeAll { $0.id == episode.id }
                    if self.podcasts[idx].episodes.isEmpty {
                        let bucketID = self.podcasts[idx].id
                        self.podcasts.remove(at: idx)
                        self.database.deletePodcast(id: bucketID)
                    } else {
                        self.database.savePodcast(self.podcasts[idx])
                    }
                }
                for i in self.devices.indices {
                    if self.devices[i].selectedEpisodeIDs.remove(episode.id) != nil {
                        self.database.saveDevice(self.devices[i])
                    }
                }
                self.rebuildEpisodeMap()
                self.recomputeSyncPlan()
                self.showToast("Fjernet '\(episode.title)' fra EnkeltEpisoder")
            }
        }
    }

    func refreshAllPodcasts() {
        for show in subscribedPodcasts {
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
        let resolvedAlb = albumByTrackID[track.id]
        if let resolvedID = resolvedAlb?.id, device.selectedAlbumKeys.contains(resolvedID) { return true }
        if device.selectedAlbumKeys.contains(track.albumKey) || device.selectedAlbumKeys.contains(track.legacyAlbumKey) { return true }
        if device.selectedArtistKeys.contains(track.artistKey) { return true }
        if let albumArtistKey = (resolvedAlb ?? albumsByKey[track.albumKey])?.artist.lowercased(),
           device.selectedArtistKeys.contains(albumArtistKey) {
            return true
        }
        for pl in syncablePlaylists where device.selectedPlaylistIDs.contains(pl.id) {
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

    func focusedPlaylistState(for targetTracks: [Track]) -> SyncSelectionState {
        guard let pl = focusedPlaylist, !targetTracks.isEmpty else { return .none }
        let set = Set(pl.trackIDs)
        let count = targetTracks.filter { set.contains($0.id) }.count
        if count == 0 { return .none }
        if count == targetTracks.count { return .full }
        return .partial
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

    func toggleTracksInFocusedPlaylist(_ targetTracks: [Track], label: String) {
        guard !targetTracks.isEmpty else { return }
        if let pl = focusedPlaylist,
           let idx = playlists.firstIndex(where: { $0.id == pl.id }) {
            let state = focusedPlaylistState(for: targetTracks)
            if state == .full {
                let removeIDs = Set(targetTracks.map(\.id))
                playlists[idx].trackIDs.removeAll { removeIDs.contains($0) }
                playlists[idx].updatedAt = Date()
                database.savePlaylist(playlists[idx])
                recomputeSyncPlan()
                showToast("Removed '\(label)' from '\(pl.name)'")
            } else {
                addTracks(targetTracks, toPlaylistID: pl.id)
            }
        } else {
            let created = createPlaylist(name: "My Playlist", initialTrackIDs: targetTracks.map(\.id))
            setFocusedPlaylist(created.id)
            showToast("Created '\(created.name)' and added '\(label)'")
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
                if let pl = playlists.first(where: { $0.id == plID }), isPartyPlaylist(pl) {
                    showToast("Partymode playlist is not synced to devices")
                    continue
                }
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
                if isPartyModeEnabled && playlistID == partyPlaylistID {
                    syncPartyPlaylistToPlayerAndServer(autoStartIfIdle: false)
                }
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
        if isPartyModeEnabled && playlistID == partyPlaylistID {
            syncPartyPlaylistToPlayerAndServer(autoStartIfIdle: partyAutoPlayOnRequest)
        }
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
        if isPartyLockedPlaylist(playlist) {
            showToast("Exit Party Mode before deleting '\(playlist.name)'", isError: true)
            return
        }
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
        if partyPlaylistID == playlist.id {
            partyPlaylistID = nil
        }
        recomputeSyncPlan()
        showToast("Deleted playlist '\(playlist.name)'")
    }

    @discardableResult
    func duplicatePlaylist(_ playlist: Playlist) -> Playlist {
        let existingNames = Set(playlists.map { $0.name.lowercased() })
        let baseName = "\(playlist.name) Copy"
        var candidate = baseName
        var counter = 2
        while existingNames.contains(candidate.lowercased()) {
            candidate = "\(baseName) \(counter)"
            counter += 1
        }
        let copy = Playlist(
            name: candidate,
            description: playlist.description,
            trackIDs: playlist.trackIDs
        )
        playlists.append(copy)
        database.savePlaylist(copy)
        setFocusedPlaylist(copy.id)
        navigate(to: .playlist(copy.id))
        recomputeSyncPlan()
        showToast("Duplicated '\(playlist.name)' → '\(copy.name)'")
        return copy
    }

    func exportPlaylist(_ playlist: Playlist, format: PlaylistExportFormat = .pls) {
        let playlistTracks = tracks(for: playlist)
        let content: String
        switch format {
        case .pls:
            var lines: [String] = ["[playlist]"]
            for (i, track) in playlistTracks.enumerated() {
                let n = i + 1
                let artist = track.artist.isEmpty ? track.effectiveArtist : track.artist
                let title = artist.isEmpty ? track.title : "\(artist) - \(track.title)"
                let length = track.duration > 0 ? Int(track.duration.rounded()) : -1
                lines.append("File\(n)=\(track.filePath)")
                lines.append("Title\(n)=\(title)")
                lines.append("Length\(n)=\(length)")
            }
            lines.append("NumberOfEntries=\(playlistTracks.count)")
            lines.append("Version=2")
            content = lines.joined(separator: "\n") + "\n"

        case .m3u8:
            var lines: [String] = ["#EXTM3U", "#PLAYLIST:\(playlist.name)"]
            for track in playlistTracks {
                let artist = track.artist.isEmpty ? track.effectiveArtist : track.artist
                let title = artist.isEmpty ? track.title : "\(artist) - \(track.title)"
                let length = track.duration > 0 ? Int(track.duration.rounded()) : -1
                lines.append("#EXTINF:\(length),\(title)")
                lines.append(track.filePath)
            }
            content = lines.joined(separator: "\n") + "\n"
        }

        let safeBase = playlist.name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let defaultName = (safeBase.isEmpty ? "Playlist" : safeBase) + ".\(format.fileExtension)"

        let panel = NSSavePanel()
        panel.title = "Export Playlist (\(format.displayName))"
        panel.nameFieldStringValue = defaultName
        panel.canCreateDirectories = true
        if let utType = UTType(filenameExtension: format.fileExtension) {
            panel.allowedContentTypes = [utType]
        }
        panel.allowsOtherFileTypes = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            showToast("Exported '\(playlist.name)' (\(playlistTracks.count) tracks) to \(url.lastPathComponent)")
        } catch {
            showToast("Failed to export playlist: \(error.localizedDescription)", isError: true)
        }
    }

    func addTracks(_ newTracks: [Track], toPlaylistID playlistID: UUID) {
        guard let idx = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        let isLockedParty = isPartyModeEnabled && playlistID == partyPlaylistID
        let existing = Set(playlists[idx].trackIDs)
        let toAdd: [String]
        if isLockedParty && partyAllowReRequestPlayed {
            let curIdx = player.currentTrack != nil ? player.currentIndex : 0
            let upcoming = Set(playlists[idx].trackIDs.dropFirst(max(0, min(curIdx, playlists[idx].trackIDs.count))))
            toAdd = newTracks.map(\.id).filter { !upcoming.contains($0) }
        } else {
            toAdd = newTracks.map(\.id).filter { !existing.contains($0) }
        }
        guard !toAdd.isEmpty else {
            showToast("Tracks already in '\(playlists[idx].name)'")
            return
        }
        playlists[idx].trackIDs.append(contentsOf: toAdd)
        playlists[idx].updatedAt = Date()
        database.savePlaylist(playlists[idx])
        recomputeSyncPlan()
        if isLockedParty {
            syncPartyPlaylistToPlayerAndServer(autoStartIfIdle: partyAutoPlayOnRequest)
        }
        showToast("Added \(toAdd.count) track\(toAdd.count == 1 ? "" : "s") to '\(playlists[idx].name)'")
    }

    func removeTrack(at index: Int, fromPlaylistID playlistID: UUID) {
        guard let idx = playlists.firstIndex(where: { $0.id == playlistID }),
              index >= 0 && index < playlists[idx].trackIDs.count else { return }
        playlists[idx].trackIDs.remove(at: index)
        playlists[idx].updatedAt = Date()
        database.savePlaylist(playlists[idx])
        recomputeSyncPlan()
        if isPartyModeEnabled && playlistID == partyPlaylistID {
            syncPartyPlaylistToPlayerAndServer(autoStartIfIdle: false)
        }
    }

    func moveTracksInPlaylist(playlistID: UUID, from source: IndexSet, to destination: Int) {
        guard let idx = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        playlists[idx].trackIDs.move(fromOffsets: source, toOffset: destination)
        playlists[idx].updatedAt = Date()
        database.savePlaylist(playlists[idx])
        recomputeSyncPlan()
        if isPartyModeEnabled && playlistID == partyPlaylistID {
            syncPartyPlaylistToPlayerAndServer(autoStartIfIdle: false)
        }
    }

    func tracks(for playlist: Playlist) -> [Track] {
        playlist.trackIDs.compactMap { tracksByID[$0] }
    }

    // MARK: - Party Mode (Dynamic "Partymode" Playlist & Random-Port Guest Web Server)

    var partyPlaylist: Playlist? {
        if let id = partyPlaylistID, let pl = playlists.first(where: { $0.id == id }) {
            return pl
        }
        return playlists.first(where: { $0.name.caseInsensitiveCompare(Self.partyPlaylistName) == .orderedSame })
    }

    var partyServerURLString: String? {
        guard isPartyModeEnabled, partyServerPort > 0 else { return nil }
        let host = partyServerLANIP ?? "localhost"
        return "http://\(host):\(partyServerPort)"
    }

    var partyLocalURLString: String? {
        guard isPartyModeEnabled, partyServerPort > 0 else { return nil }
        return "http://localhost:\(partyServerPort)"
    }

    func isPartyPlaylist(_ playlist: Playlist) -> Bool {
        if let id = partyPlaylistID, playlist.id == id {
            return true
        }
        return playlist.name.caseInsensitiveCompare(Self.partyPlaylistName) == .orderedSame
    }

    var syncablePlaylists: [Playlist] {
        playlists.filter { !isPartyPlaylist($0) }
    }

    func isPartyLockedPlaylist(_ playlist: Playlist) -> Bool {
        isPartyModeEnabled && playlist.id == partyPlaylistID
    }

    func partyRequesterName(for trackID: String) -> String? {
        partyRequesterByTrackID[trackID]?.guestName
    }

    private func setupPartyModeCallbacks() {
        partyModeServer.onStatusChanged = { [weak self] running, port, lanIP, errorMessage in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isPartyServerRunning = running
                self.partyServerPort = port
                if running {
                    self.partyServerLANIP = lanIP ?? WirelessSyncServer.localLANIPAddress()
                    self.partyServerLastError = nil
                    if port > 0 && self.partyPreferredPort != port {
                        self.partyPreferredPort = port
                        self.database.setSetting("partyPreferredPort", value: String(port))
                    }
                } else {
                    self.partyServerLastError = errorMessage
                }
            }
        }

        partyModeServer.onAddTrack = { [weak self] trackID, guestName, guestID in
            guard let self else {
                return PartyAddTrackResponse(ok: false, message: "Host app unavailable")
            }
            return await MainActor.run {
                self.addTrackToPartyMode(trackID: trackID, guestName: guestName, guestID: guestID, fromHost: false)
            }
        }

        partyModeServer.onRenameGuest = { [weak self] guestID, newName in
            guard let self else {
                return PartyRenameGuestResponse(ok: false, guestName: "Guest")
            }
            return await MainActor.run {
                self.renamePartyGuest(guestID: guestID, newName: newName)
            }
        }

        partyModeServer.onSendChatMessage = { [weak self] guestID, guestName, text in
            guard let self else {
                return PartyChatSendResponse(ok: false, message: "Host app unavailable")
            }
            return await MainActor.run {
                self.sendPartyChatMessage(text: text, guestID: guestID, guestName: guestName, isHost: false)
            }
        }

        partyModeServer.onUploadVoiceIntro = { [weak self] trackID, guestID, guestName, audioData, ext in
            guard let self else {
                return PartyIntroUploadResponse(ok: false, message: "Host app unavailable")
            }
            return await MainActor.run {
                self.savePartyVoiceIntro(
                    trackID: trackID,
                    guestID: guestID,
                    guestName: guestName,
                    audioData: audioData,
                    fileExtension: ext
                )
            }
        }

        partyModeServer.onDeleteVoiceIntro = { [weak self] trackID, guestID in
            guard let self else {
                return PartyIntroUploadResponse(ok: false, message: "Host app unavailable")
            }
            return await MainActor.run {
                self.deletePartyVoiceIntro(trackID: trackID, guestID: guestID, fromHost: false)
            }
        }

        partyModeServer.onFetchTrackInfo = { [weak self] trackID in
            guard let self else { return nil }
            return await self.fetchPartyTrackInfo(trackID: trackID)
        }

        partyModeServer.onGuestsChanged = { [weak self] guests in
            Task { @MainActor [weak self] in
                self?.partyGuests = guests
            }
        }
    }

    @discardableResult
    func ensurePartyPlaylist() -> Playlist {
        if let existing = partyPlaylist {
            partyPlaylistID = existing.id
            return existing
        }
        let created = Playlist(
            name: Self.partyPlaylistName,
            description: "Dynamic Party Mode queue — guests can search & add tracks from the web jukebox."
        )
        playlists.append(created)
        database.savePlaylist(created)
        partyPlaylistID = created.id
        recomputeSyncPlan()
        return created
    }

    func startPartyMode(navigateToView: Bool = true) {
        let pl = ensurePartyPlaylist()
        isPartyModeEnabled = true
        partyPlaylistID = pl.id
        partyServerLastError = nil
        setFocusedPlaylist(pl.id)

        // Lock playback queue onto dynamic "Partymode" playlist in strict FIFO order
        if player.isShuffled {
            player.isShuffled = false
        }
        player.isQueueLocked = true
        player.ignoreMicInputAutoPause = true
        player.onLockedQueuePlayRequest = { [weak self] tracks, startingAt in
            guard let self, startingAt >= 0, startingAt < tracks.count else { return }
            let chosen = tracks[startingAt]
            let response = self.addTrackToPartyMode(trackID: chosen.id, guestName: "Host", fromHost: true)
            self.showToast(response.message, isError: !response.ok)
        }
        player.onLockedQueueAppendRequest = { [weak self] track, playNext in
            guard let self else { return }
            self.insertTrackIntoPartyMode(track, playNext: playNext, guestName: "Host")
        }
        player.onLockedQueueRemoveRequest = { [weak self] index in
            guard let self, let plID = self.partyPlaylistID else { return }
            self.removeTrack(at: index, fromPlaylistID: plID)
        }
        player.onVoiceIntroURLForTrack = { [weak self] trackID in
            self?.partyVoiceIntrosByTrackID[trackID]?.fileURL
        }
        player.onVoiceIntroStarted = { [weak self] trackID in
            guard let self else { return }
            if let rec = self.partyVoiceIntrosByTrackID.removeValue(forKey: trackID) {
                let title = self.tracksByID[trackID]?.title ?? "next track"
                self.showToast("🎙 Playing \(Int(rec.duration.rounded()))s intro by \(rec.guestName) for '\(title)'")
                // Keep file briefly while AVAudioPlayer finishes playing, then clean up
                let urlToClean = rec.fileURL
                Task {
                    try? await Task.sleep(for: .seconds(max(20, rec.duration + 10)))
                    try? FileManager.default.removeItem(at: urlToClean)
                }
                self.pushPartyModeStateToServer()
            }
        }

        let plTracks = tracks(for: pl)
        if plTracks.isEmpty {
            player.syncLockedQueue(tracks: [], autoStartIfIdle: false)
        } else if let cur = player.currentTrack, plTracks.contains(where: { $0.id == cur.id }) {
            player.syncLockedQueue(tracks: plTracks, autoStartIfIdle: false)
        } else {
            player.playLockedQueue(tracks: plTracks, startingAt: 0)
        }

        partyModeServer.updateLibrary(tracks: tracks)
        pushPartyModeStateToServer()
        partyModeServer.start(preferredPort: partyPreferredPort, fallbackToRandomIfBusy: true)
        startPartyPresenceTicker()

        if navigateToView {
            searchQuery = ""
            isLidarrLibraryScope = false
            navigate(to: .partyMode)
        }
        showToast("Party Mode started — locked to '\(pl.name)'")
    }

    func stopPartyMode() {
        isPartyModeEnabled = false
        partyPresenceTask?.cancel()
        partyPresenceTask = nil
        player.isQueueLocked = false
        player.ignoreMicInputAutoPause = false
        player.onLockedQueuePlayRequest = nil
        player.onLockedQueueAppendRequest = nil
        player.onLockedQueueRemoveRequest = nil
        player.onVoiceIntroURLForTrack = nil
        player.onVoiceIntroStarted = nil
        partyModeServer.stop()
        partyModeServer.clearGuestPresence()
        partyGuests = []
        isPartyServerRunning = false
        partyServerPort = 0
        partyServerLastError = nil
        showToast("Party Mode stopped — web server closed")
    }

    private func startPartyPresenceTicker() {
        partyPresenceTask?.cancel()
        partyPresenceTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled, let self, self.isPartyModeEnabled else { return }
                self.partyGuests = self.partyModeServer.snapshotGuests()
                self.pushPartyModeStateToServer()
            }
        }
    }

    func setPartyChatEnabled(_ enabled: Bool) {
        partyChatEnabled = enabled
        database.setSetting("partyChatEnabled", value: enabled ? "true" : "false")
        pushPartyModeStateToServer()
        showToast(enabled ? "Party Chat enabled" : "Party Chat disabled")
    }

    func setPartyStreamingEnabled(_ enabled: Bool) {
        partyStreamingEnabled = enabled
        database.setSetting("partyStreamingEnabled", value: enabled ? "true" : "false")
        pushPartyModeStateToServer()
        showToast(enabled
            ? "Remote Listen-Along streaming enabled — guests can tap Listen to stream live"
            : "Remote Listen-Along streaming disabled")
    }

    func setPartyMaxIntroSeconds(_ seconds: Int) {
        let clamped = max(5, min(60, seconds))
        partyMaxIntroSeconds = clamped
        database.setSetting("partyMaxIntroSeconds", value: String(clamped))
        pushPartyModeStateToServer()
        showToast("Max guest voice intro set to \(clamped)s")
    }

    private var partyIntrosDirectoryURL: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = caches.appendingPathComponent("Echo/PartyIntros", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @discardableResult
    func savePartyVoiceIntro(
        trackID: String,
        guestID: String?,
        guestName: String?,
        audioData: Data,
        fileExtension: String
    ) -> PartyIntroUploadResponse {
        guard let pl = partyPlaylist, pl.trackIDs.contains(trackID), let track = tracksByID[trackID] else {
            return PartyIntroUploadResponse(ok: false, message: "Track is not in the Partymode queue")
        }

        // Verify requestor ownership when guestID is tracked
        if let ownerID = partyRequesterByTrackID[trackID]?.guestID,
           let incomingID = guestID,
           ownerID != incomingID {
            return PartyIntroUploadResponse(ok: false, message: "Only the guest who requested this track can record its intro")
        }

        let safeExt = ["wav", "m4a", "mp3", "aac", "caf"].contains(fileExtension.lowercased()) ? fileExtension.lowercased() : "wav"
        let baseID = UUID().uuidString
        let rawURL = partyIntrosDirectoryURL.appendingPathComponent("\(baseID)-raw.\(safeExt)")
        let normalizedURL = partyIntrosDirectoryURL.appendingPathComponent("\(baseID).wav")

        do {
            try audioData.write(to: rawURL, options: .atomic)
            let validator = try AVAudioPlayer(contentsOf: rawURL)
            var duration = validator.duration
            guard duration >= 0.25 else {
                try? FileManager.default.removeItem(at: rawURL)
                return PartyIntroUploadResponse(ok: false, message: "Recording was too short — hold/record for at least 1 second")
            }
            let maxAllowed = Double(partyMaxIntroSeconds) + 1.5
            guard duration <= maxAllowed else {
                try? FileManager.default.removeItem(at: rawURL)
                return PartyIntroUploadResponse(ok: false, message: "Intro exceeds host limit of \(partyMaxIntroSeconds)s")
            }

            // Normalize voice loudness (-13.2 dBFS active speech + -1.0 dBFS soft-knee limiter)
            let finalURL: URL
            if let normalizedDuration = try? VoiceIntroAudioNormalizer.normalizeAudioFile(inputURL: rawURL, outputURL: normalizedURL),
               normalizedDuration >= 0.25 {
                try? FileManager.default.removeItem(at: rawURL)
                finalURL = normalizedURL
                duration = normalizedDuration
            } else {
                try? FileManager.default.removeItem(at: normalizedURL)
                finalURL = rawURL
            }

            if let old = partyVoiceIntrosByTrackID[trackID] {
                try? FileManager.default.removeItem(at: old.fileURL)
            }
            let displayGuest = PartyModeServer.sanitizeGuestName(guestName)
                ?? partyRequesterByTrackID[trackID]?.guestName
                ?? "Guest"
            let record = PartyVoiceIntroRecord(
                trackID: trackID,
                fileURL: finalURL,
                duration: duration,
                guestID: guestID ?? partyRequesterByTrackID[trackID]?.guestID,
                guestName: displayGuest,
                recordedAt: Date()
            )
            partyVoiceIntrosByTrackID[trackID] = record
            pushPartyModeStateToServer()
            showToast("🎙 \(displayGuest) added a \(Int(duration.rounded()))s intro for '\(track.title)'")
            return PartyIntroUploadResponse(
                ok: true,
                message: "Saved \(Int(duration.rounded()))s intro for '\(track.title)'!",
                duration: duration,
                state: buildPartyPlaylistState()
            )
        } catch {
            try? FileManager.default.removeItem(at: rawURL)
            try? FileManager.default.removeItem(at: normalizedURL)
            return PartyIntroUploadResponse(ok: false, message: "Unsupported or unreadable intro audio format")
        }
    }

    @discardableResult
    func deletePartyVoiceIntro(trackID: String, guestID: String? = nil, fromHost: Bool = false) -> PartyIntroUploadResponse {
        guard let existing = partyVoiceIntrosByTrackID[trackID] else {
            return PartyIntroUploadResponse(ok: true, message: "No intro found", state: buildPartyPlaylistState())
        }
        if !fromHost, let ownerID = existing.guestID, let incomingID = guestID, ownerID != incomingID {
            return PartyIntroUploadResponse(ok: false, message: "Only the requestor or host can remove this intro")
        }
        partyVoiceIntrosByTrackID.removeValue(forKey: trackID)
        try? FileManager.default.removeItem(at: existing.fileURL)
        pushPartyModeStateToServer()
        return PartyIntroUploadResponse(ok: true, message: "Removed voice intro", state: buildPartyPlaylistState())
    }

    func fetchPartyTrackInfo(trackID: String) async -> PartyTrackInfoResponse? {
        guard let track = tracksByID[trackID] else { return nil }

        let displayArtist = track.artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? track.effectiveArtist
            : track.artist
        let albumGroup = albums.first(where: { $0.tracks.contains(where: { $0.id == trackID }) })
        let resolvedAlbumTitle = albumGroup?.title ?? track.effectiveAlbum
        let resolvedAlbumArtist = albumGroup?.artist ?? track.effectiveArtist
        let albumKey = albumGroup?.id ?? track.albumKey
        let artistKey = resolvedAlbumArtist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let matchingArtistGroup = artists.first(where: {
            $0.name.caseInsensitiveCompare(displayArtist) == .orderedSame
                || $0.name.caseInsensitiveCompare(resolvedAlbumArtist) == .orderedSame
        })
        let localArtistAlbumCount = matchingArtistGroup?.albums.count ?? (albumGroup != nil ? 1 : 0)
        let localArtistTrackCount = matchingArtistGroup?.albums.reduce(0) { $0 + $1.tracks.count } ?? (albumGroup?.tracks.count ?? 1)
        let albumTrackCount = albumGroup?.tracks.count ?? 1
        let addedBy = partyRequesterByTrackID[trackID]?.guestName

        var albumInfo = albumEditorialByKey[albumKey]
        var artistInfo = artistEditorialByKey[artistKey]

        // Fetch on-demand if missing or stale so guests get rich album + artist info in the lightbox
        if albumInfo == nil || albumInfo?.isStale == true {
            let fetched = await EditorialInfoFetcher.fetchAlbumEditorial(
                albumKey: albumKey,
                artist: resolvedAlbumArtist,
                albumTitle: resolvedAlbumTitle
            )
            albumEditorialByKey[albumKey] = fetched.album
            database.saveAlbumEditorial(fetched.album)
            albumInfo = fetched.album
            if let fetchedArtist = fetched.artist {
                artistEditorialByKey[fetchedArtist.artistKey] = fetchedArtist
                database.saveArtistEditorial(fetchedArtist)
                artistInfo = fetchedArtist
            }
        }

        if (artistInfo?.summary == nil || artistInfo?.summary?.isEmpty == true)
            && (albumInfo?.artistSummary == nil || albumInfo?.artistSummary?.isEmpty == true)
            && (artistInfo == nil || artistInfo?.isStale == true) {
            let fetchedArtist = await EditorialInfoFetcher.fetchArtistEditorial(
                artistKey: artistKey,
                artistName: displayArtist
            )
            artistEditorialByKey[artistKey] = fetchedArtist
            database.saveArtistEditorial(fetchedArtist)
            artistInfo = fetchedArtist
        }

        let resolvedArtistSummary = (artistInfo?.summary?.isEmpty == false ? artistInfo?.summary : nil)
            ?? (albumInfo?.artistSummary?.isEmpty == false ? albumInfo?.artistSummary : nil)
        let resolvedArtistFans = artistInfo?.fans ?? albumInfo?.artistFans
        let resolvedArtistAlbums = artistInfo?.albumCount ?? albumInfo?.artistAlbumCount
        let resolvedArtistImage = artistInfo?.imageURL ?? albumInfo?.artistImageURL

        return PartyTrackInfoResponse(
            ok: true,
            trackId: track.id,
            title: track.title,
            artist: displayArtist,
            album: resolvedAlbumTitle,
            year: track.year,
            duration: track.duration,
            format: track.format.displayBadge,
            artworkHash: track.artworkHash,
            addedBy: addedBy,
            releaseDate: albumInfo?.releaseDate,
            label: albumInfo?.label,
            genres: albumInfo?.genres ?? [],
            albumFans: albumInfo?.albumFans,
            albumSummary: albumInfo?.albumSummary,
            albumTrackCount: albumTrackCount,
            artistSummary: resolvedArtistSummary,
            artistFans: resolvedArtistFans,
            artistAlbumCount: resolvedArtistAlbums,
            artistImageURL: resolvedArtistImage,
            localArtistAlbumCount: localArtistAlbumCount,
            localArtistTrackCount: localArtistTrackCount
        )
    }

    @discardableResult
    func sendPartyChatMessage(text: String, guestID: String? = nil, guestName: String? = nil, isHost: Bool = false) -> PartyChatSendResponse {
        guard partyChatEnabled else {
            return PartyChatSendResponse(ok: false, message: "Party chat is currently disabled by the host")
        }
        guard let cleanText = PartyModeServer.sanitizeChatText(text) else {
            return PartyChatSendResponse(ok: false, message: "Message cannot be empty")
        }
        let sender = isHost
            ? "Host"
            : (PartyModeServer.sanitizeGuestName(guestName) ?? "Guest")
        let normalizedGuestID = isHost ? nil : PartyModeServer.sanitizeGuestID(guestID)
        let msg = PartyChatMessage(
            guestID: normalizedGuestID,
            senderName: sender,
            isHost: isHost,
            text: cleanText,
            sentAt: Date()
        )
        partyChatMessages.append(msg)
        if partyChatMessages.count > 120 {
            partyChatMessages = Array(partyChatMessages.suffix(120))
        }
        pushPartyModeStateToServer()
        return PartyChatSendResponse(ok: true, chatMessage: msg, state: buildPartyPlaylistState())
    }

    func clearPartyChat() {
        partyChatMessages.removeAll()
        pushPartyModeStateToServer()
        showToast("Cleared Party Chat messages")
    }

    func togglePartyMode() {
        if isPartyModeEnabled {
            stopPartyMode()
        } else {
            startPartyMode(navigateToView: true)
        }
    }

    func restartPartyServerOnNewPort() {
        partyPreferredPort = nil
        database.setSetting("partyPreferredPort", value: "")
        guard isPartyModeEnabled else {
            showToast("Party Mode port reset to Random")
            return
        }
        partyServerLastError = nil
        partyModeServer.restart(preferredPort: nil)
        showToast("Restarting Party Mode server on a new random port...")
    }

    /// Sets a custom unprivileged port (1024–65535) or resets to default `53333` when blank, restarting live if Party Mode is active.
    @discardableResult
    func setPartyPort(_ rawInput: String) -> Bool {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            let fallback = Self.defaultPartyPort
            partyPreferredPort = fallback
            database.setSetting("partyPreferredPort", value: String(fallback))
            partyServerLastError = nil
            if isPartyModeEnabled {
                partyModeServer.restart(preferredPort: fallback, fallbackToRandomIfBusy: true)
                showToast("Party Mode reset to default port \(fallback)")
            } else {
                showToast("Party Mode port reset to \(fallback)")
            }
            return true
        }

        guard let parsed = Int(trimmed), parsed >= 1024 && parsed <= 65535 else {
            showToast("Enter a valid port between 1024 and 65535 (or leave blank for default 53333)", isError: true)
            return false
        }

        let port = UInt16(parsed)
        partyPreferredPort = port
        database.setSetting("partyPreferredPort", value: String(port))
        partyServerLastError = nil

        if isPartyModeEnabled {
            partyModeServer.restart(preferredPort: port)
            showToast("Restarting Party Mode server on port \(port)...")
        } else {
            showToast("Party Mode port set to \(port)")
        }
        return true
    }

    func playPartyModeTrack(at index: Int) {
        let pl = ensurePartyPlaylist()
        let plTracks = tracks(for: pl)
        guard index >= 0 && index < plTracks.count else { return }
        if isPartyModeEnabled {
            player.playLockedQueue(tracks: plTracks, startingAt: index)
            pushPartyModeStateToServer()
        } else {
            player.play(tracks: plTracks, startingAt: index)
        }
    }

    @discardableResult
    func addTrackToPartyMode(trackID: String, guestName: String?, guestID: String? = nil, fromHost: Bool = false) -> PartyAddTrackResponse {
        guard let track = tracksByID[trackID], track.isAvailable else {
            return PartyAddTrackResponse(ok: false, message: "Track is unavailable in library")
        }

        let pl = ensurePartyPlaylist()
        guard let plIdx = playlists.firstIndex(where: { $0.id == pl.id }) else {
            return PartyAddTrackResponse(ok: false, message: "Partymode playlist not found")
        }

        let currentIDs = playlists[plIdx].trackIDs
        let activeIdx = (player.currentTrack != nil) ? max(0, min(player.currentIndex, currentIDs.count)) : 0
        let upNextSlice = currentIDs.dropFirst(activeIdx)

        // Prevent duplicate in currently-playing or upcoming queue
        if upNextSlice.contains(track.id) {
            let state = buildPartyPlaylistState()
            return PartyAddTrackResponse(
                ok: true,
                alreadyQueued: true,
                message: "'\(track.title)' is already up next in Partymode",
                position: currentIDs.lastIndex(of: track.id),
                track: PartyTrackItem(from: track, inPlaylist: true, inUpNext: true),
                state: state
            )
        }

        // If already played earlier and re-requesting is disabled, block duplicate
        if !partyAllowReRequestPlayed && currentIDs.contains(track.id) {
            let state = buildPartyPlaylistState()
            return PartyAddTrackResponse(
                ok: true,
                alreadyQueued: true,
                message: "'\(track.title)' was already played in Partymode",
                position: currentIDs.firstIndex(of: track.id),
                track: PartyTrackItem(from: track, inPlaylist: true, inUpNext: false),
                state: state
            )
        }

        let now = Date()
        let displayGuest = PartyModeServer.sanitizeGuestName(guestName) ?? (fromHost ? "Host" : "Guest")
        let normalizedGuestID = fromHost ? nil : PartyModeServer.sanitizeGuestID(guestID)
        playlists[plIdx].trackIDs.append(track.id)
        playlists[plIdx].updatedAt = now
        database.savePlaylist(playlists[plIdx])
        recomputeSyncPlan()

        partyRequesterByTrackID[track.id] = (normalizedGuestID, displayGuest, now)
        let activity = PartyGuestActivityItem(
            trackID: track.id,
            trackTitle: track.title,
            artist: track.artist.isEmpty ? track.effectiveArtist : track.artist,
            guestID: normalizedGuestID,
            guestName: displayGuest,
            addedAt: now
        )
        partyGuestActivity.insert(activity, at: 0)
        if partyGuestActivity.count > 100 {
            partyGuestActivity = Array(partyGuestActivity.prefix(100))
        }

        let newPosition = playlists[plIdx].trackIDs.count - 1
        if isPartyModeEnabled {
            syncPartyPlaylistToPlayerAndServer(autoStartIfIdle: partyAutoPlayOnRequest)
        }

        let updatedState = buildPartyPlaylistState()
        if !fromHost {
            showToast("Party Mode: \(displayGuest) added '\(track.title)'")
        }
        return PartyAddTrackResponse(
            ok: true,
            alreadyQueued: false,
            message: "Added '\(track.title)' to Partymode (#\(newPosition + 1))",
            position: newPosition,
            track: PartyTrackItem(from: track, inPlaylist: true, inUpNext: true),
            state: updatedState
        )
    }

    @discardableResult
    func renamePartyGuest(guestID: String, newName: String?) -> PartyRenameGuestResponse {
        let displayGuest = PartyModeServer.sanitizeGuestName(newName) ?? "Guest"
        var updatedTracks = 0

        for (trackID, info) in partyRequesterByTrackID where info.guestID == guestID {
            partyRequesterByTrackID[trackID] = (info.guestID, displayGuest, info.addedAt)
            updatedTracks += 1
        }

        var updatedActivity = 0
        for idx in partyGuestActivity.indices where partyGuestActivity[idx].guestID == guestID {
            partyGuestActivity[idx].guestName = displayGuest
            updatedActivity += 1
        }

        var updatedChat = 0
        for idx in partyChatMessages.indices where partyChatMessages[idx].guestID == guestID {
            partyChatMessages[idx].senderName = displayGuest
            updatedChat += 1
        }

        for (tid, rec) in partyVoiceIntrosByTrackID where rec.guestID == guestID {
            var copy = rec
            copy.guestName = displayGuest
            partyVoiceIntrosByTrackID[tid] = copy
        }

        partyModeServer.renameGuestPresence(guestID: guestID, newName: displayGuest)
        partyGuests = partyModeServer.snapshotGuests()

        let updatedCount = max(updatedTracks, updatedActivity)
        if updatedCount > 0 || updatedChat > 0 {
            pushPartyModeStateToServer()
        }
        let latestState = buildPartyPlaylistState()
        return PartyRenameGuestResponse(
            ok: true,
            updatedCount: updatedCount,
            guestName: displayGuest,
            state: latestState
        )
    }

    private func insertTrackIntoPartyMode(_ track: Track, playNext: Bool, guestName: String) {
        if !playNext {
            let resp = addTrackToPartyMode(trackID: track.id, guestName: guestName, fromHost: true)
            showToast(resp.message, isError: !resp.ok)
            return
        }
        let pl = ensurePartyPlaylist()
        guard let plIdx = playlists.firstIndex(where: { $0.id == pl.id }) else { return }
        let insertIdx: Int
        if player.currentTrack != nil {
            insertIdx = min(player.currentIndex + 1, playlists[plIdx].trackIDs.count)
        } else {
            insertIdx = 0
        }
        playlists[plIdx].trackIDs.insert(track.id, at: insertIdx)
        playlists[plIdx].updatedAt = Date()
        database.savePlaylist(playlists[plIdx])
        recomputeSyncPlan()
        partyRequesterByTrackID[track.id] = (nil, guestName, Date())
        if isPartyModeEnabled {
            syncPartyPlaylistToPlayerAndServer(autoStartIfIdle: partyAutoPlayOnRequest)
        }
        showToast("Party Mode: '\(track.title)' queued next in Partymode")
    }

    func clearPlayedPartyTracks() {
        guard let pl = partyPlaylist,
              let plIdx = playlists.firstIndex(where: { $0.id == pl.id }) else { return }
        guard player.currentTrack != nil, player.currentIndex > 0 else {
            showToast("No played tracks to clear")
            return
        }
        let removeCount = min(player.currentIndex, playlists[plIdx].trackIDs.count)
        guard removeCount > 0 else { return }
        playlists[plIdx].trackIDs.removeFirst(removeCount)
        playlists[plIdx].updatedAt = Date()
        database.savePlaylist(playlists[plIdx])
        recomputeSyncPlan()
        if isPartyModeEnabled {
            syncPartyPlaylistToPlayerAndServer(autoStartIfIdle: false)
        }
        showToast("Cleared \(removeCount) played track\(removeCount == 1 ? "" : "s") from Partymode")
    }

    func clearAllPartyTracks() {
        guard let pl = partyPlaylist,
              let plIdx = playlists.firstIndex(where: { $0.id == pl.id }) else { return }
        playlists[plIdx].trackIDs.removeAll()
        playlists[plIdx].updatedAt = Date()
        database.savePlaylist(playlists[plIdx])
        partyRequesterByTrackID.removeAll()
        for rec in partyVoiceIntrosByTrackID.values {
            try? FileManager.default.removeItem(at: rec.fileURL)
        }
        partyVoiceIntrosByTrackID.removeAll()
        recomputeSyncPlan()
        if isPartyModeEnabled {
            syncPartyPlaylistToPlayerAndServer(autoStartIfIdle: false)
        }
        showToast("Cleared all tracks from Partymode")
    }

    func seedPartyModeWithCurrentQueue() {
        guard !player.queue.isEmpty else { return }
        let pl = ensurePartyPlaylist()
        addTracks(player.queue, toPlaylistID: pl.id)
    }

    private func syncPartyPlaylistToPlayerAndServer(autoStartIfIdle: Bool) {
        guard isPartyModeEnabled, let pl = partyPlaylist else { return }
        let plTracks = tracks(for: pl)
        player.syncLockedQueue(tracks: plTracks, autoStartIfIdle: autoStartIfIdle)
        pushPartyModeStateToServer()
    }

    func pushPartyModeStateToServer() {
        guard isPartyModeEnabled else { return }
        partyStateRevision += 1
        partyModeServer.updatePlaylistState(buildPartyPlaylistState())
    }

    /// Computes planned wall-clock start times (`Date`) for upcoming tracks in "Partymode".
    func plannedPlayTimesForPartymode(now: Date = Date()) -> [Int: Date] {
        guard let pl = partyPlaylist else { return [:] }
        let plTracks = tracks(for: pl)
        guard !plTracks.isEmpty else { return [:] }

        let curIdx: Int? = {
            guard player.currentTrack != nil else { return nil }
            if player.currentIndex >= 0 && player.currentIndex < plTracks.count && plTracks[player.currentIndex].id == player.currentTrack?.id {
                return player.currentIndex
            }
            return plTracks.firstIndex(where: { $0.id == player.currentTrack?.id })
        }()

        var result: [Int: Date] = [:]
        var cursor = now

        if let cur = curIdx {
            let activeDuration = player.duration > 0 ? player.duration : plTracks[cur].duration
            let remaining = max(0, activeDuration - player.currentTime)
            cursor = cursor.addingTimeInterval(remaining)
            if cur + 1 < plTracks.count {
                for idx in (cur + 1)..<plTracks.count {
                    result[idx] = cursor
                    cursor = cursor.addingTimeInterval(max(0, plTracks[idx].duration))
                }
            }
        } else {
            for idx in plTracks.indices {
                result[idx] = cursor
                cursor = cursor.addingTimeInterval(max(0, plTracks[idx].duration))
            }
        }
        return result
    }

    private func buildPartyPlaylistState() -> PartyPlaylistState {
        let now = Date()
        let pl = partyPlaylist
        let plTracks = pl.map { tracks(for: $0) } ?? []
        let curIdx: Int? = {
            guard player.currentTrack != nil, !plTracks.isEmpty else { return nil }
            if player.currentIndex >= 0 && player.currentIndex < plTracks.count && plTracks[player.currentIndex].id == player.currentTrack?.id {
                return player.currentIndex
            }
            return plTracks.firstIndex(where: { $0.id == player.currentTrack?.id })
        }()
        let plannedByIndex = plannedPlayTimesForPartymode(now: now)

        var entries: [PartyQueueEntry] = []
        entries.reserveCapacity(plTracks.count)
        var upNextCount = 0

        for (idx, t) in plTracks.enumerated() {
            let isCurrent = (curIdx == idx)
            let isPlayed = curIdx.map { idx < $0 } ?? false
            let isUpNext = !isPlayed
            if !isCurrent && !isPlayed {
                upNextCount += 1
            }
            let req = partyRequesterByTrackID[t.id]
            let intro = partyVoiceIntrosByTrackID[t.id]
            let item = PartyTrackItem(
                from: t,
                resolvedAlbumTitle: allTrackAlbumByID[t.id]?.title ?? t.effectiveAlbum,
                inPlaylist: true,
                inUpNext: isUpNext
            )
            entries.append(PartyQueueEntry(
                position: idx,
                track: item,
                isCurrent: isCurrent,
                isPlayed: isPlayed,
                addedBy: req?.guestName,
                addedByGuestID: req?.guestID,
                addedAt: req?.addedAt,
                plannedPlayAt: isCurrent ? nil : plannedByIndex[idx],
                hasVoiceIntro: intro != nil,
                voiceIntroDuration: intro?.duration
            ))
        }

        let hostName = Host.current().localizedName ?? "My Echo"
        return PartyPlaylistState(
            playlistName: pl?.name ?? Self.partyPlaylistName,
            serverName: hostName,
            isPlaying: player.isPlaying,
            isPlayingVoiceIntro: player.isPlayingVoiceIntro,
            currentTrackID: player.currentTrack?.id,
            currentIndex: curIdx,
            currentTime: player.currentTime,
            duration: player.duration,
            libraryTotalCount: tracks.filter(\.isAvailable).count,
            upNextCount: upNextCount,
            allowReRequestPlayed: partyAllowReRequestPlayed,
            chatEnabled: partyChatEnabled,
            streamingEnabled: partyStreamingEnabled,
            maxIntroSeconds: partyMaxIntroSeconds,
            stateUpdatedAt: now,
            revision: partyStateRevision,
            tracks: entries,
            guests: partyModeServer.snapshotGuests(now: now),
            chatMessages: partyChatMessages
        )
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

    func addVirtualIPhoneDestination(name: String = "iPhone") {
        let existingCount = devices.filter(\.isVirtualWireless).count
        let finalName = existingCount == 0 ? name : "\(name) \(existingCount + 1)"
        let nextAccent = DeviceAccentColor.allCases[(devices.count + 1) % DeviceAccentColor.allCases.count]
        let profile = DeviceProfile(
            name: finalName,
            hasCustomName: true,
            accentColor: nextAccent,
            volumeUUID: nil,
            mountPath: "echo-wireless://\(finalName.lowercased().replacingOccurrences(of: " ", with: "-"))",
            preset: .iphoneWireless,
            syncMode: .mirror
        )
        devices.append(profile)
        database.saveDevice(profile)
        selectActiveDevice(profile.id)
        refreshWirelessSyncServer()
        navigate(to: .deviceSync(profile.id))
        showToast("Created virtual '\(finalName)' Wi-Fi Auto-Sync destination (PIN: \(profile.wirelessSyncToken ?? ""))")
    }

    func regenerateWirelessPIN(for device: DeviceProfile) {
        guard let idx = devices.firstIndex(where: { $0.id == device.id }) else { return }
        let newPIN = DeviceProfile.generatePairingPIN()
        devices[idx].wirelessSyncToken = newPIN
        database.saveDevice(devices[idx])
        refreshWirelessSyncServer()
        showToast("Generated new pairing PIN for '\(devices[idx].name)': \(newPIN)")
    }

    private func setupWirelessSyncServerCallbacks() {
        wirelessSyncServer.onStatusChanged = { [weak self] running, port, info in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isWirelessServerRunning = running
                self.wirelessServerPort = port
                if running {
                    self.wirelessServerLANIP = info ?? WirelessSyncServer.localLANIPAddress()
                    self.wirelessServerLastError = nil
                } else {
                    self.wirelessServerLastError = info
                }
            }
        }
        wirelessSyncServer.onSyncReportReceived = { [weak self] report in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard let uuid = UUID(uuidString: report.deviceID),
                      let idx = self.devices.firstIndex(where: { $0.id == uuid }) else { return }
                self.devices[idx].syncedTrackIDs = Set(report.syncedTrackIDs)
                self.devices[idx].syncedEpisodeIDs = Set(report.syncedEpisodeIDs)
                self.devices[idx].lastSyncedAt = report.completedAt ?? Date()
                self.database.saveDevice(self.devices[idx])
                self.lastWirelessClientName = report.clientName ?? self.devices[idx].name
                self.recomputeSyncPlan()
                let who = report.clientName ?? self.devices[idx].name
                self.showToast("\(who) auto-synced: \(report.syncedTrackIDs.count) tracks, \(report.syncedEpisodeIDs.count) podcasts")
            }
        }

        // Remote add/remove single track or album from iPhone/iPad
        wirelessSyncServer.onRemoteSyncSelect = { [weak self] deviceID, req in
            guard let self else {
                return WirelessRemoteSyncSelectResponse(ok: false, manifestVersion: "", message: "Mac store unavailable")
            }
            return await MainActor.run {
                guard let idx = self.devices.firstIndex(where: { $0.id == deviceID }) else {
                    return WirelessRemoteSyncSelectResponse(ok: false, manifestVersion: "", message: "Device profile not found")
                }
                var label = "selection"
                if let trackID = req.trackID, !trackID.isEmpty {
                    if req.selected {
                        self.devices[idx].selectedTrackIDs.insert(trackID)
                    } else {
                        self.devices[idx].selectedTrackIDs.remove(trackID)
                    }
                    label = self.tracksByID[trackID]?.title ?? "track"
                } else if let albumKey = req.albumKey, !albumKey.isEmpty {
                    if req.selected {
                        self.devices[idx].selectedAlbumKeys.insert(albumKey)
                    } else {
                        self.devices[idx].selectedAlbumKeys.remove(albumKey)
                        if let alb = self.albumsByKey[albumKey] {
                            for t in alb.tracks {
                                self.devices[idx].selectedTrackIDs.remove(t.id)
                                self.devices[idx].selectedAlbumKeys.remove(t.legacyAlbumKey)
                            }
                        }
                    }
                    label = self.albumsByKey[albumKey]?.title ?? "album"
                } else {
                    return WirelessRemoteSyncSelectResponse(ok: false, manifestVersion: "", message: "Missing trackID or albumKey")
                }
                self.database.saveDevice(self.devices[idx])
                self.recomputeSyncPlan()
                let newVersion = self.wirelessManifestVersions[deviceID] ?? ""
                let verb = req.selected ? "Added" : "Removed"
                self.showToast("\(verb) '\(label)' on '\(self.devices[idx].name)' from iOS")
                return WirelessRemoteSyncSelectResponse(ok: true, manifestVersion: newVersion, message: "\(verb) '\(label)'")
            }
        }

        // Lidarr search relay from iPhone/iPad (reuses Mac's configured Lidarr API key & profiles)
        wirelessSyncServer.onLidarrSearch = { [weak self] query in
            guard let self else {
                return WirelessLidarrSearchResponse(configured: false, albums: [], tracks: [], message: "Mac unavailable")
            }
            let (cfg, client) = await MainActor.run { (self.lidarrConfig, self.lidarrClient) }
            guard cfg.isEnabled && cfg.isConfigured else {
                return WirelessLidarrSearchResponse(configured: false, albums: [], tracks: [], message: "Configure Lidarr in My Echo Settings on Mac first.")
            }
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return WirelessLidarrSearchResponse(configured: true, albums: [], tracks: [])
            }
            async let albumsTask: [LidarrAlbumSearchResult] = (try? await client.searchAlbums(term: trimmed, config: cfg)) ?? []
            async let tracksTask: [LidarrTrackMatch] = (try? await client.searchTracksForAlbumOrder(term: trimmed)) ?? []
            let albums = await albumsTask
            let tracks = await tracksTask
            let wireAlbums = albums.prefix(24).map { a in
                WirelessLidarrAlbumItem(
                    id: a.id,
                    foreignAlbumId: a.foreignAlbumId,
                    title: a.title,
                    artistName: a.artistName,
                    releaseYear: a.releaseYear,
                    coverURL: a.coverURL,
                    monitored: a.monitored,
                    inLibrary: a.isDownloaded
                )
            }
            let wireTracks = tracks.prefix(24).map { t in
                WirelessLidarrTrackItem(
                    id: t.id,
                    title: t.title,
                    artistName: t.artistName,
                    albumTitle: t.albumTitle,
                    duration: TimeInterval(t.duration),
                    coverURL: t.coverURL
                )
            }
            return WirelessLidarrSearchResponse(configured: true, albums: Array(wireAlbums), tracks: Array(wireTracks))
        }

        // Lidarr order relay from iPhone/iPad
        wirelessSyncServer.onLidarrOrder = { [weak self] req in
            guard let self else {
                return WirelessLidarrOrderResponse(ok: false, message: "Mac unavailable")
            }
            let (cfg, client) = await MainActor.run { (self.lidarrConfig, self.lidarrClient) }
            guard cfg.isEnabled && cfg.isConfigured else {
                return WirelessLidarrOrderResponse(ok: false, message: "Configure Lidarr in My Echo Settings on Mac first.")
            }
            do {
                let searchTerm = "\(req.artistName) \(req.albumTitle ?? req.title)".trimmingCharacters(in: .whitespacesAndNewlines)
                let candidates = try await client.searchAlbums(term: searchTerm, config: cfg)
                let chosen: LidarrAlbumSearchResult?
                if let fid = req.foreignAlbumId, !fid.isEmpty {
                    chosen = candidates.first(where: { $0.foreignAlbumId == fid }) ?? candidates.first
                } else {
                    let targetAlb = OnlinePopularityService.normalizeTitleForMatching(req.albumTitle ?? req.title)
                    let targetArt = OnlinePopularityService.normalizeTitleForMatching(req.artistName)
                    chosen = candidates.first(where: {
                        let a = OnlinePopularityService.normalizeTitleForMatching($0.title)
                        let ar = OnlinePopularityService.normalizeTitleForMatching($0.artistName)
                        return (a == targetAlb || a.contains(targetAlb) || targetAlb.contains(a))
                            && (ar.contains(targetArt) || targetArt.contains(ar))
                    }) ?? candidates.first
                }
                guard let albumToOrder = chosen else {
                    return WirelessLidarrOrderResponse(ok: false, message: "No matching album found in Lidarr for '\(req.title)'")
                }
                let res = try await client.orderAlbum(albumToOrder, config: cfg)
                await MainActor.run {
                    self.recordLidarrTrackedOrder(albumTitle: res.albumTitle, artistName: res.artistName, lidarrAlbumID: res.lidarrAlbumID)
                    self.showToast("iOS ordered '\(res.albumTitle)' (\(res.artistName)) in Lidarr")
                    self.refreshLidarrQueueAndWanted(silent: true)
                }
                return WirelessLidarrOrderResponse(ok: true, message: "Ordered '\(res.albumTitle)' in Lidarr", albumTitle: res.albumTitle, artistName: res.artistName)
            } catch {
                return WirelessLidarrOrderResponse(ok: false, message: error.localizedDescription)
            }
        }

        // Podcast subscription pushed back from iPhone/iPad
        wirelessSyncServer.onPodcastSubscribe = { [weak self] deviceID, req in
            guard let self else {
                return WirelessPodcastSubscribeResponse(ok: false, message: "Mac unavailable")
            }
            let feedURL = req.feedURL.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !feedURL.isEmpty else {
                return WirelessPodcastSubscribeResponse(ok: false, message: "Missing podcast feed URL")
            }

            let existing = await MainActor.run {
                self.subscribedPodcasts.first { $0.feedURL.caseInsensitiveCompare(feedURL) == .orderedSame }
            }
            if let existing {
                let ver = await MainActor.run { () -> String in
                    if req.selectForSync ?? true,
                       let devIdx = self.devices.firstIndex(where: { $0.id == deviceID }) {
                        self.devices[devIdx].selectedPodcastShowIDs.insert(existing.id)
                        self.database.saveDevice(self.devices[devIdx])
                        self.recomputeSyncPlan()
                    }
                    return self.wirelessManifestVersions[deviceID] ?? ""
                }
                return WirelessPodcastSubscribeResponse(
                    ok: true,
                    showID: existing.id.uuidString,
                    title: existing.title,
                    manifestVersion: ver,
                    message: "Already subscribed to '\(existing.title)' on Mac"
                )
            }

            do {
                let service = await MainActor.run { self.podcastService }
                let fetched = try await service.fetchFeed(feedURLString: feedURL, fallbackArtworkURL: req.fallbackArtworkURL)
                let ver = await MainActor.run { () -> String in
                    self.podcasts.append(fetched)
                    self.podcasts.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                    self.database.savePodcast(fetched)
                    if req.selectForSync ?? true,
                       let devIdx = self.devices.firstIndex(where: { $0.id == deviceID }) {
                        self.devices[devIdx].selectedPodcastShowIDs.insert(fetched.id)
                        self.database.saveDevice(self.devices[devIdx])
                    }
                    self.rebuildEpisodeMap()
                    self.recomputeSyncPlan()
                    self.showToast("iOS subscribed to '\(fetched.title)' — added to Mac")
                    return self.wirelessManifestVersions[deviceID] ?? ""
                }
                    return WirelessPodcastSubscribeResponse(
                    ok: true,
                    showID: fetched.id.uuidString,
                    title: fetched.title,
                    manifestVersion: ver,
                    message: "Subscribed to '\(fetched.title)' on Mac"
                )
            } catch {
                return WirelessPodcastSubscribeResponse(ok: false, message: "Subscribe failed: \(error.localizedDescription)")
            }
        }

        // Apple TV / LAN Companion: Live Mac Remote Playback State
        wirelessSyncServer.onFetchRemoteState = { [weak self] in
            guard let self else {
                return WirelessRemotePlaybackState(serverName: Host.current().localizedName ?? "My Echo Mac")
            }
            return await MainActor.run {
                self.buildRemotePlaybackState()
            }
        }

        // Apple TV / LAN Companion: Remote Control Commands for Mac Playback
        wirelessSyncServer.onRemoteCommand = { [weak self] req in
            guard let self else {
                return WirelessRemoteCommandResponse(ok: false, message: "Mac store unavailable")
            }
            return await MainActor.run {
                self.handleRemoteCommand(req)
            }
        }

        // Apple TV / LAN Companion: Live Party Mode Status & Queue Envelope
        wirelessSyncServer.onFetchPartyState = { [weak self] in
            guard let self else {
                return WirelessPartyEnvelope(status: WirelessPartyStatus(), state: nil)
            }
            return await MainActor.run {
                let status = self.buildCurrentPartyStatus()
                let state = self.isPartyModeEnabled ? self.buildPartyPlaylistState() : nil
                return WirelessPartyEnvelope(status: status, state: state)
            }
        }
    }

    func setAppleTVCompanionEnabled(_ enabled: Bool) {
        appleTVCompanionEnabled = enabled
        database.setSetting("appleTVCompanionEnabled", value: enabled ? "true" : "false")
        refreshWirelessSyncServer()
    }

    func regenerateAppleTVPairingPIN() {
        let newPIN = DeviceProfile.generatePairingPIN()
        appleTVPairingPIN = newPIN
        database.setSetting("appleTVPairingPIN", value: newPIN)
        refreshWirelessSyncServer()
        showToast("Generated new Apple TV pairing PIN: \(newPIN)")
    }

    private func buildCurrentPartyStatus() -> WirelessPartyStatus {
        let host = partyServerLANIP ?? WirelessSyncServer.localLANIPAddress()
        let port = partyServerPort > 0 ? Int(partyServerPort) : nil
        let joinURL: String? = (isPartyModeEnabled && partyServerPort > 0)
            ? "http://\(host ?? "localhost"):\(partyServerPort)"
            : nil
        return WirelessPartyStatus(
            isLive: isPartyModeEnabled && partyServerPort > 0,
            port: port,
            lanIP: host,
            joinURL: joinURL,
            playlistName: partyPlaylist?.name ?? Self.partyPlaylistName
        )
    }

    private func buildRemotePlaybackState() -> WirelessRemotePlaybackState {
        let serverName = Host.current().localizedName ?? "My Echo Mac"
        let currentWireTrack = player.currentTrack.map {
            WirelessSyncTrack(from: $0, resolvedAlbumArtist: allTrackAlbumByID[$0.id]?.artist)
        }
        let allQueue = player.queue
        let curIdx = max(0, min(player.currentIndex, max(0, allQueue.count - 1)))
        // Send up to 120 tracks centered around the active index for responsive TV rendering
        let sliceStart = max(0, curIdx - 10)
        let sliceEnd = min(allQueue.count, sliceStart + 120)
        let wireQueue: [WirelessSyncTrack] = (sliceStart < sliceEnd)
            ? allQueue[sliceStart..<sliceEnd].map { WirelessSyncTrack(from: $0, resolvedAlbumArtist: allTrackAlbumByID[$0.id]?.artist) }
            : []
        let adjustedIndex = max(0, curIdx - sliceStart)
        let outputName = player.activeOutputDevice?.name ?? "System Default"

        return WirelessRemotePlaybackState(
            serverName: serverName,
            isPlaying: player.isPlaying,
            currentTrack: currentWireTrack,
            currentTime: player.currentTime,
            duration: player.duration,
            volume: player.volume,
            isMuted: player.isMuted,
            isShuffled: player.isShuffled,
            repeatMode: player.repeatMode.rawValue,
            currentIndex: adjustedIndex,
            queue: wireQueue,
            outputDeviceName: outputName,
            partyStatus: buildCurrentPartyStatus()
        )
    }

    private func handleRemoteCommand(_ req: WirelessRemoteCommandRequest) -> WirelessRemoteCommandResponse {
        var message: String?
        switch req.action {
        case "togglePlayPause":
            player.togglePlayPause()
        case "play":
            player.resumeOrPlay()
        case "pause":
            player.pause()
        case "next":
            player.nextTrack()
        case "previous":
            player.previousTrack()
        case "seek":
            if let secs = req.seconds {
                player.seek(to: secs)
            }
        case "setVolume":
            if let vol = req.volume {
                player.volume = max(0.0, min(1.0, vol))
                if player.isMuted && vol > 0 { player.isMuted = false }
            }
        case "toggleMute":
            player.isMuted.toggle()
        case "toggleShuffle":
            player.isShuffled.toggle()
        case "cycleRepeat":
            player.cycleRepeatMode()
        case "jumpToQueueIndex":
            if let idx = req.queueIndex {
                let allQueue = player.queue
                let curIdx = max(0, min(player.currentIndex, max(0, allQueue.count - 1)))
                let sliceStart = max(0, curIdx - 10)
                let absoluteIdx = sliceStart + idx
                if absoluteIdx >= 0 && absoluteIdx < allQueue.count {
                    player.jumpToQueueIndex(absoluteIdx)
                }
            }
        case "playTrack":
            if let trackID = req.trackID, let track = tracksByID[trackID] {
                if let alb = allTrackAlbumByID[track.id],
                   let idx = alb.tracks.firstIndex(where: { $0.id == track.id }) {
                    player.play(tracks: alb.tracks, startingAt: idx)
                } else {
                    player.playSingle(track)
                }
                message = "Playing \(track.title) on Mac"
            } else {
                return WirelessRemoteCommandResponse(ok: false, message: "Track not found on Mac", state: buildRemotePlaybackState())
            }
        case "playAlbum":
            if let key = req.albumKey {
                let matched = albumsByKey[key] ?? albums.first(where: { $0.title.lowercased() == key.lowercased() || $0.id.lowercased() == key.lowercased() })
                if let alb = matched, !alb.tracks.isEmpty {
                    player.play(tracks: alb.tracks, startingAt: 0)
                    message = "Playing \(alb.title) on Mac"
                } else {
                    return WirelessRemoteCommandResponse(ok: false, message: "Album not found on Mac", state: buildRemotePlaybackState())
                }
            }
        case "playPlaylist":
            if let plIDStr = req.playlistID, let plUUID = UUID(uuidString: plIDStr),
               let pl = playlists.first(where: { $0.id == plUUID }) {
                let plTracks = tracks(for: pl)
                if !plTracks.isEmpty {
                    player.play(tracks: plTracks, startingAt: 0)
                    message = "Playing playlist \(pl.name) on Mac"
                } else {
                    return WirelessRemoteCommandResponse(ok: false, message: "Playlist is empty", state: buildRemotePlaybackState())
                }
            }
        case "startPartyMode":
            if !isPartyModeEnabled {
                startPartyMode(navigateToView: false)
            }
            message = "Party Mode started on Mac"
        case "stopPartyMode":
            if isPartyModeEnabled {
                stopPartyMode()
            }
            message = "Party Mode stopped"
        default:
            return WirelessRemoteCommandResponse(ok: false, message: "Unknown remote action: \(req.action)", state: buildRemotePlaybackState())
        }
        return WirelessRemoteCommandResponse(ok: true, message: message, state: buildRemotePlaybackState())
    }

    func refreshWirelessSyncServer() {
        let serverName = Host.current().localizedName ?? "My Echo Mac"
        wirelessSyncServer.setCompanionToken(appleTVCompanionEnabled ? appleTVPairingPIN : nil)
        wirelessSyncServer.updateLibraryCatalog(
            tracks: tracks,
            albums: albums,
            playlists: syncablePlaylists,
            podcasts: podcasts,
            albumEditorial: Array(albumEditorialByKey.values),
            artistEditorial: Array(artistEditorialByKey.values),
            serverName: serverName
        )
        let wirelessDevices = devices.filter(\.isVirtualWireless)
        guard !wirelessDevices.isEmpty || appleTVCompanionEnabled else {
            wirelessSyncServer.updateSnapshots([])
            wirelessSyncServer.stop()
            wirelessManifestVersions = [:]
            return
        }
        let snapshotTracks = tracks
        let snapshotPlaylists = syncablePlaylists
        let snapshotPodcasts = podcasts
        let albumMap = allTrackAlbumByID
        let albumEditorial = albumEditorialByKey
        let artistEditorial = artistEditorialByKey
        Task.detached(priority: .userInitiated) { [weak self] in
            let snapshots = wirelessDevices.map { dev in
                WirelessDeviceSnapshot(
                    device: dev,
                    allTracks: snapshotTracks,
                    playlists: snapshotPlaylists,
                    podcasts: snapshotPodcasts,
                    serverName: serverName,
                    precomputedAlbumByTrackID: albumMap,
                    albumEditorialByKey: albumEditorial,
                    artistEditorialByKey: artistEditorial
                )
            }
            var versions: [UUID: String] = [:]
            for s in snapshots { versions[s.deviceID] = s.manifest.manifestVersion }
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.wirelessManifestVersions = versions
                self.wirelessSyncServer.updateSnapshots(snapshots)
                self.wirelessSyncServer.start()
            }
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
        if isPartyPlaylist(playlist) { return false }
        return (device ?? activeDevice)?.selectedPlaylistIDs.contains(playlist.id) ?? false
    }

    func trackSyncReason(_ track: Track, on device: DeviceProfile? = nil) -> String? {
        guard let dev = device ?? activeDevice else { return nil }
        if dev.selectedTrackIDs.contains(track.id) { return "Track" }
        let resolvedAlb = albumByTrackID[track.id]
        if let resolvedID = resolvedAlb?.id, dev.selectedAlbumKeys.contains(resolvedID) { return "Album" }
        if dev.selectedAlbumKeys.contains(track.albumKey) || dev.selectedAlbumKeys.contains(track.legacyAlbumKey) { return "Album" }
        if dev.selectedArtistKeys.contains(track.artistKey) { return "Artist" }
        if let albumArtistKey = (resolvedAlb ?? albumsByKey[track.albumKey])?.artist.lowercased(),
           dev.selectedArtistKeys.contains(albumArtistKey) {
            return "Artist"
        }
        for pl in syncablePlaylists where dev.selectedPlaylistIDs.contains(pl.id) {
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
                for t in album.tracks {
                    d.selectedAlbumKeys.remove(t.legacyAlbumKey)
                    d.selectedTrackIDs.remove(t.id)
                }
            } else {
                d.selectedAlbumKeys.insert(album.id)
                for t in album.tracks { d.selectedTrackIDs.remove(t.id) }
            }
        }
    }

    func toggleTrackSync(_ track: Track, onDeviceID targetDeviceID: UUID? = nil) {
        mutateDevice(id: targetDeviceID) { d in
            let resolvedAlb = self.albumByTrackID[track.id] ?? self.albumsByKey[track.albumKey]
            let resolvedAlbID = resolvedAlb?.id ?? track.albumKey
            let resolvedArtistKey = resolvedAlb?.artist.lowercased()
            let viaAlbum = d.selectedAlbumKeys.contains(resolvedAlbID)
                || d.selectedAlbumKeys.contains(track.albumKey)
                || d.selectedAlbumKeys.contains(track.legacyAlbumKey)
            let viaArtist = d.selectedArtistKeys.contains(track.artistKey)
                || (resolvedArtistKey.map { d.selectedArtistKeys.contains($0) } ?? false)
            if d.selectedTrackIDs.contains(track.id) {
                d.selectedTrackIDs.remove(track.id)
            } else if viaAlbum || viaArtist {
                for artistK in Set([track.artistKey, resolvedArtistKey].compactMap { $0 }) {
                    if d.selectedArtistKeys.remove(artistK) != nil,
                       let artistGroup = self.artistsByKey[artistK] {
                        for otherAlb in artistGroup.albums where otherAlb.id != resolvedAlbID {
                            d.selectedAlbumKeys.insert(otherAlb.id)
                        }
                    }
                }
                d.selectedAlbumKeys.remove(resolvedAlbID)
                d.selectedAlbumKeys.remove(track.albumKey)
                d.selectedAlbumKeys.remove(track.legacyAlbumKey)
                if let albGroup = resolvedAlb {
                    for other in albGroup.tracks where other.id != track.id {
                        d.selectedAlbumKeys.remove(other.legacyAlbumKey)
                        d.selectedTrackIDs.insert(other.id)
                    }
                }
            } else {
                d.selectedTrackIDs.insert(track.id)
            }
        }
    }

    func togglePlaylistSync(_ playlist: Playlist, onDeviceID targetDeviceID: UUID? = nil) {
        if isPartyPlaylist(playlist) {
            mutateDevice(id: targetDeviceID) { d in
                d.selectedPlaylistIDs.remove(playlist.id)
            }
            return
        }
        mutateDevice(id: targetDeviceID) { d in
            if d.selectedPlaylistIDs.contains(playlist.id) {
                d.selectedPlaylistIDs.remove(playlist.id)
            } else {
                d.selectedPlaylistIDs.insert(playlist.id)
            }
        }
    }

    private func rebuildSelectedTrackIDCache() {
        var map: [UUID: Set<String>] = [:]
        map.reserveCapacity(devices.count)
        let allowedPlaylists = syncablePlaylists
        for dev in devices {
            map[dev.id] = SyncPlanner.resolveSelectedTrackIDs(
                profile: dev,
                allTracks: tracks,
                playlists: allowedPlaylists,
                precomputedAlbumByTrackID: allTrackAlbumByID
            )
        }
        selectedTrackIDsByDeviceID = map
    }

    func assignedTrackCount(for device: DeviceProfile) -> Int {
        selectedTrackIDsByDeviceID[device.id]?.count ?? 0
    }

    private func effectiveSelectedTrackIDs(for device: DeviceProfile) -> Set<String> {
        selectedTrackIDsByDeviceID[device.id] ?? []
    }

    func cachedSyncPlan(for device: DeviceProfile) -> SyncPlan? {
        if activeDevice?.id == device.id, let activeSyncPlan {
            return activeSyncPlan
        }
        return syncPlansByDeviceID[device.id]
    }

    func ensureSyncPlanLoaded(for deviceID: UUID) {
        guard let dev = devices.first(where: { $0.id == deviceID }) else { return }
        if syncPlansByDeviceID[deviceID] != nil { return }
        let snapshotTracks = tracks
        let snapshotPlaylists = syncablePlaylists
        let snapshotPodcasts = podcasts
        let albumMap = allTrackAlbumByID
        Task.detached(priority: .userInitiated) { [weak self] in
            let plan = SyncPlanner.buildPlan(
                profile: dev,
                allTracks: snapshotTracks,
                playlists: snapshotPlaylists,
                podcasts: snapshotPodcasts,
                precomputedAlbumByTrackID: albumMap
            )
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.syncPlansByDeviceID[deviceID] = plan
                if self.activeDevice?.id == deviceID {
                    self.activeSyncPlan = plan
                }
            }
        }
    }

    // MARK: - Sync Execution

    func recomputeSyncPlan() {
        // 1. Update O(1) in-memory selection cache synchronously (< 1ms) so badges/toggles respond instantaneously
        rebuildSelectedTrackIDCache()
        refreshWirelessSyncServer()

        var targetDevices: [DeviceProfile] = []
        if let active = activeDevice {
            targetDevices.append(active)
        } else {
            activeSyncPlan = nil
        }
        if case .deviceSync(let viewedID) = currentDestination,
           let viewed = devices.first(where: { $0.id == viewedID }),
           !targetDevices.contains(where: { $0.id == viewed.id }) {
            targetDevices.append(viewed)
        }
        // Also compute pending-bytes plans for all connected physical storage devices shown in the sidebar
        for dev in devices where !dev.isVirtualWireless && dev.isConnected {
            if !targetDevices.contains(where: { $0.id == dev.id }) {
                targetDevices.append(dev)
            }
        }
        guard !targetDevices.isEmpty else { return }

        // 2. Compute I/O-heavy SyncPlan (NAS/USB fileExists + manifest read) off the main thread!
        syncPlanTask?.cancel()
        let snapshotTracks = tracks
        let snapshotPlaylists = syncablePlaylists
        let snapshotPodcasts = podcasts
        let albumMap = allTrackAlbumByID
        let activeID = activeDevice?.id

        syncPlanTask = Task.detached(priority: .userInitiated) { [weak self] in
            var computed: [UUID: SyncPlan] = [:]
            for dev in targetDevices {
                if Task.isCancelled { return }
                computed[dev.id] = SyncPlanner.buildPlan(
                    profile: dev,
                    allTracks: snapshotTracks,
                    playlists: snapshotPlaylists,
                    podcasts: snapshotPodcasts,
                    precomputedAlbumByTrackID: albumMap
                )
            }
            if Task.isCancelled { return }
            await MainActor.run { [weak self] in
                guard let self else { return }
                for (id, plan) in computed {
                    self.syncPlansByDeviceID[id] = plan
                }
                if let activeID, let plan = computed[activeID] {
                    self.activeSyncPlan = plan
                }
            }
        }
    }

    func startSync(for targetDevice: DeviceProfile? = nil) {
        guard !isSyncing else { return }
        guard let device = targetDevice ?? activeDevice else {
            showToast("Select a sync destination first before syncing", isError: true)
            return
        }
        if device.isVirtualWireless {
            refreshWirelessSyncServer()
            let plan = cachedSyncPlan(for: device) ?? SyncPlanner.buildPlan(profile: device, allTracks: tracks, playlists: playlists, podcasts: podcasts, precomputedAlbumByTrackID: allTrackAlbumByID)
            if activeDevice?.id == device.id { activeSyncPlan = plan }
            let ip = wirelessServerLANIP ?? "your Mac's Wi-Fi"
            let pinHint = device.wirelessSyncToken.map { " · PIN \($0)" } ?? ""
            showToast("Published \(plan.projectedTotalTracks) tracks to '\(device.name)' (\(ip):\(wirelessServerPort)\(pinHint)) — open My Echo on iPhone/iPad & enter PIN in Sync tab")
            return
        }
        guard device.isConnected else {
            showToast("'\(device.name)' is not connected at \(device.mountPath)", isError: true)
            return
        }

        let plan = SyncPlanner.buildPlan(profile: device, allTracks: tracks, playlists: playlists, podcasts: podcasts, precomputedAlbumByTrackID: allTrackAlbumByID)
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

    // MARK: - Play Counters & Online Popularity

    func setOnlinePopularityEnabled(_ enabled: Bool) {
        onlinePopularityEnabled = enabled
        database.setSetting("onlinePopularityEnabled", value: enabled ? "true" : "false")
        showToast(enabled ? "Online popularity lookup enabled" : "Online popularity lookup paused")
    }

    func setLastFMAPIKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        lastFMAPIKey = trimmed
        database.setSetting("lastFMAPIKey", value: trimmed)
        showToast(trimmed.isEmpty ? "Cleared Last.fm API key (using built-in Deezer popularity)" : "Saved Last.fm API key for global play counts")
    }

    func stats(for track: Track) -> TrackStats {
        trackStats[track.id] ?? TrackStats(trackID: track.id)
    }

    func userPlayCount(for track: Track) -> Int {
        trackStats[track.id]?.userPlayCount ?? 0
    }

    func totalUserPlays(for album: AlbumGroup) -> Int {
        album.tracks.reduce(0) { $0 + (trackStats[$1.id]?.userPlayCount ?? 0) }
    }

    func totalUserPlays(for artist: ArtistGroup) -> Int {
        artist.tracks.reduce(0) { $0 + (trackStats[$1.id]?.userPlayCount ?? 0) }
    }

    func averageOnlinePopularity(for album: AlbumGroup) -> Int? {
        let scores = album.tracks.compactMap { trackStats[$0.id]?.onlinePopularity }
        guard !scores.isEmpty else { return nil }
        return Int((Double(scores.reduce(0, +)) / Double(scores.count)).rounded())
    }

    func averageOnlinePopularity(for artist: ArtistGroup) -> Int? {
        let scores = artist.tracks.compactMap { trackStats[$0.id]?.onlinePopularity }
        guard !scores.isEmpty else { return nil }
        return Int((Double(scores.reduce(0, +)) / Double(scores.count)).rounded())
    }

    var totalLibraryUserPlays: Int {
        scopedTracks.reduce(0) { $0 + (trackStats[$1.id]?.userPlayCount ?? 0) }
    }

    var tracksWithOnlinePopularityCount: Int {
        scopedTracks.filter { trackStats[$0.id]?.onlinePopularity != nil }.count
    }

    func mostPlayedTracks(limit: Int = 10) -> [Track] {
        scopedTracks
            .filter { (trackStats[$0.id]?.userPlayCount ?? 0) > 0 }
            .sorted { a, b in
                let pa = trackStats[a.id]?.userPlayCount ?? 0
                let pb = trackStats[b.id]?.userPlayCount ?? 0
                if pa != pb { return pa > pb }
                let da = trackStats[a.id]?.lastPlayedAt ?? .distantPast
                let db = trackStats[b.id]?.lastPlayedAt ?? .distantPast
                return da > db
            }
            .prefix(limit)
            .map { $0 }
    }

    func mostPopularOnlineTracks(limit: Int = 10) -> [Track] {
        scopedTracks
            .filter { (trackStats[$0.id]?.onlinePopularity ?? 0) > 0 }
            .sorted { a, b in
                let pa = trackStats[a.id]?.onlinePopularity ?? 0
                let pb = trackStats[b.id]?.onlinePopularity ?? 0
                if pa != pb { return pa > pb }
                return (trackStats[a.id]?.onlinePlayCount ?? 0) > (trackStats[b.id]?.onlinePlayCount ?? 0)
            }
            .prefix(limit)
            .map { $0 }
    }

    func recordUserPlay(for track: Track) {
        var current = trackStats[track.id] ?? TrackStats(trackID: track.id)
        current.userPlayCount += 1
        current.lastPlayedAt = Date()
        trackStats[track.id] = current
        database.saveTrackStats(current)

        // Opportunistically enrich this track's online popularity if not fetched yet
        if onlinePopularityEnabled && current.onlinePopularity == nil {
            fetchPopularity(forTrack: track, silent: true)
        }
    }

    func resetUserPlayCount(for track: Track) {
        guard var current = trackStats[track.id] else { return }
        current.userPlayCount = 0
        current.lastPlayedAt = nil
        trackStats[track.id] = current
        database.saveTrackStats(current)
        showToast("Reset play count for '\(track.title)'")
    }

    func resetAllUserPlayCounts() {
        var updated: [TrackStats] = []
        for (id, var st) in trackStats where st.userPlayCount > 0 || st.lastPlayedAt != nil {
            st.userPlayCount = 0
            st.lastPlayedAt = nil
            trackStats[id] = st
            updated.append(st)
        }
        database.saveTrackStatsBatch(updated)
        showToast("Reset all personal play counters")
    }

    // MARK: - 1–5 Star Track & Album Ratings

    func userRating(for track: Track) -> Int {
        trackStats[track.id]?.userRating ?? 0
    }

    func setUserRating(_ rating: Int?, for track: Track) {
        let clamped: Int? = rating.flatMap { $0 >= 1 ? min(5, $0) : nil }
        var current = trackStats[track.id] ?? TrackStats(trackID: track.id)
        if current.userRating == clamped { return }
        current.userRating = clamped
        trackStats[track.id] = current
        database.saveTrackStats(current)
    }

    func explicitAlbumRating(for album: AlbumGroup) -> Int? {
        albumRatings[album.id]?.rating
    }

    func averageTrackRating(for album: AlbumGroup) -> Double? {
        let rated = album.tracks.compactMap { trackStats[$0.id]?.userRating }.filter { $0 > 0 }
        guard !rated.isEmpty else { return nil }
        return Double(rated.reduce(0, +)) / Double(rated.count)
    }

    /// Explicit 1–5 album rating if set, otherwise the average rating of rated tracks on the album (0 if unrated).
    func effectiveAlbumRating(for album: AlbumGroup) -> Double {
        if let explicit = albumRatings[album.id]?.rating {
            return Double(explicit)
        }
        return averageTrackRating(for: album) ?? 0
    }

    func setAlbumRating(_ rating: Int?, for album: AlbumGroup) {
        let clamped: Int? = rating.flatMap { $0 >= 1 ? min(5, $0) : nil }
        if let clamped {
            let entry = AlbumUserRating(albumKey: album.id, rating: clamped, updatedAt: Date())
            albumRatings[album.id] = entry
            database.saveAlbumRating(entry)
        } else {
            albumRatings.removeValue(forKey: album.id)
            database.deleteAlbumRating(albumKey: album.id)
        }
    }

    func clearGlobalSearch() {
        searchQuery = ""
        minStarRating = 0
    }

    func ensurePopularityLoaded(forAlbum album: AlbumGroup, force: Bool = false) {
        guard onlinePopularityEnabled || force else { return }
        let fetchKey = "album:\(album.id)"
        guard !fetchingPopularityKeys.contains(fetchKey) else { return }

        if !force {
            let missingCount = album.tracks.filter { trackStats[$0.id]?.onlinePopularity == nil }.count
            // Skip if most tracks on this album already have cached online popularity
            if missingCount == 0 || (Double(missingCount) / Double(max(1, album.tracks.count)) < 0.25) {
                return
            }
        }

        fetchingPopularityKeys.insert(fetchKey)
        let apiKey = lastFMAPIKey.isEmpty ? nil : lastFMAPIKey
        Task {
            let batch = await popularityService.fetchAlbumPopularity(
                artist: album.artist,
                album: album.title,
                tracks: album.tracks,
                lastFMAPIKey: apiKey
            )
            await MainActor.run {
                self.applyPopularityBatch(batch)
                self.fetchingPopularityKeys.remove(fetchKey)
                if force {
                    self.showToast("Updated online popularity for \(batch.trackResults.count)/\(album.tracks.count) tracks in '\(album.title)'")
                }
            }
        }
    }

    func ensurePopularityLoaded(forArtist artist: ArtistGroup, force: Bool = false) {
        guard onlinePopularityEnabled || force else { return }
        let fetchKey = "artist:\(artist.id)"
        guard !fetchingPopularityKeys.contains(fetchKey) else { return }

        if !force {
            let hasArtistStats = artistStats[artist.id] != nil
            let populatedTracks = artist.tracks.filter { trackStats[$0.id]?.onlinePopularity != nil }.count
            if hasArtistStats && populatedTracks >= min(5, artist.tracks.count) {
                return
            }
        }

        fetchingPopularityKeys.insert(fetchKey)
        let apiKey = lastFMAPIKey.isEmpty ? nil : lastFMAPIKey
        Task {
            let batch = await popularityService.fetchArtistPopularity(
                artistName: artist.name,
                artistKey: artist.id,
                tracks: artist.tracks,
                lastFMAPIKey: apiKey
            )
            await MainActor.run {
                self.applyPopularityBatch(batch)
                self.fetchingPopularityKeys.remove(fetchKey)
                if force {
                    self.showToast("Updated online popularity for '\(artist.name)' (\(batch.trackResults.count) tracks)")
                }
            }
        }
    }

    func fetchPopularity(forTrack track: Track, silent: Bool = false) {
        let fetchKey = "track:\(track.id)"
        guard !fetchingPopularityKeys.contains(fetchKey) else { return }
        fetchingPopularityKeys.insert(fetchKey)
        let apiKey = lastFMAPIKey.isEmpty ? nil : lastFMAPIKey
        Task {
            let result = await popularityService.fetchTrackPopularity(track: track, lastFMAPIKey: apiKey)
            await MainActor.run {
                if let result {
                    self.applyPopularityBatch(AlbumPopularityBatch(trackResults: [result]))
                    if !silent {
                        self.showToast("Online popularity for '\(track.title)': \(result.popularity)/100")
                    }
                } else if !silent {
                    self.showToast("No online popularity match found for '\(track.title)'", isError: true)
                }
                self.fetchingPopularityKeys.remove(fetchKey)
            }
        }
    }

    func batchFetchPopularityForLibrary(maxAlbums: Int = 80) {
        guard !isBatchFetchingPopularity else { return }
        let targets = albums.filter { album in
            let missing = album.tracks.filter { trackStats[$0.id]?.onlinePopularity == nil }.count
            return missing > 0 && Double(missing) / Double(max(1, album.tracks.count)) >= 0.4
        }
        let slice = Array(targets.prefix(maxAlbums))
        guard !slice.isEmpty else {
            showToast("All albums in \(selectedLibraryDisplayName) already have online popularity data!")
            return
        }

        isBatchFetchingPopularity = true
        popularityBatchProgress = (0, slice.count)
        let apiKey = lastFMAPIKey.isEmpty ? nil : lastFMAPIKey

        popularityBatchTask = Task { [weak self] in
            guard let self else { return }
            var totalMatched = 0
            for (idx, album) in slice.enumerated() {
                if Task.isCancelled { break }
                let batch = await self.popularityService.fetchAlbumPopularity(
                    artist: album.artist,
                    album: album.title,
                    tracks: album.tracks,
                    lastFMAPIKey: apiKey
                )
                totalMatched += batch.trackResults.count
                await MainActor.run {
                    self.applyPopularityBatch(batch)
                    self.popularityBatchProgress = (idx + 1, slice.count)
                }
                try? await Task.sleep(for: .milliseconds(160))
            }
            await MainActor.run {
                self.isBatchFetchingPopularity = false
                self.popularityBatchProgress = nil
                self.showToast("Online popularity synced for \(totalMatched) tracks across \(slice.count) albums")
            }
        }
    }

    func cancelPopularityBatchFetch() {
        popularityBatchTask?.cancel()
        popularityBatchTask = nil
        isBatchFetchingPopularity = false
        popularityBatchProgress = nil
        showToast("Stopped online popularity scan")
    }

    private func applyPopularityBatch(_ batch: AlbumPopularityBatch) {
        let now = Date()
        var toSave: [TrackStats] = []
        toSave.reserveCapacity(batch.trackResults.count)

        for res in batch.trackResults {
            var current = trackStats[res.trackID] ?? TrackStats(trackID: res.trackID)
            current.onlinePopularity = res.popularity
            current.onlinePlayCount = res.playCount
            current.onlineListeners = res.listeners
            current.onlineSource = res.source
            current.onlineFetchedAt = now
            trackStats[res.trackID] = current
            toSave.append(current)
        }
        if !toSave.isEmpty {
            database.saveTrackStatsBatch(toSave)
        }
        if let aStats = batch.artistStats {
            artistStats[aStats.artistKey] = aStats
            database.saveArtistStats(aStats)
        }
    }

    // MARK: - Optional Lidarr Integration (Search, Order, Queue)

    func saveLidarrConfig(_ config: LidarrConfig) {
        lidarrConfig = config
        if let data = try? JSONEncoder().encode(config),
           let str = String(data: data, encoding: .utf8) {
            database.setSetting("lidarrConfig", value: str)
        }
        if !config.isEnabled {
            isLidarrLibraryScope = false
            stopLidarrQueuePolling()
            if currentDestination == .lidarr {
                navigate(to: .home)
            }
        } else if config.isConfigured {
            startLidarrQueuePolling()
        }
    }

    func setLidarrAutoPollEnabled(_ enabled: Bool) {
        lidarrAutoPollEnabled = enabled
        database.setSetting("lidarrAutoPollEnabled", value: enabled ? "true" : "false")
        if enabled && lidarrConfig.isEnabled && lidarrConfig.isConfigured {
            startLidarrQueuePolling()
        } else {
            stopLidarrQueuePolling()
        }
    }

    private func persistLidarrTrackedOrders() {
        // Cap history to most recent 40 tracked orders
        if lidarrTrackedOrders.count > 40 {
            lidarrTrackedOrders = Array(lidarrTrackedOrders.prefix(40))
        }
        if let data = try? JSONEncoder().encode(lidarrTrackedOrders),
           let str = String(data: data, encoding: .utf8) {
            database.setSetting("lidarrTrackedOrders", value: str)
        }
    }

    private func recordLidarrTrackedOrder(albumTitle: String, artistName: String, lidarrAlbumID: Int?) {
        let normAlbum = OnlinePopularityService.normalizeTitleForMatching(albumTitle)
        let normArtist = OnlinePopularityService.normalizeTitleForMatching(artistName)
        if let idx = lidarrTrackedOrders.firstIndex(where: {
            (lidarrAlbumID != nil && $0.lidarrAlbumID == lidarrAlbumID)
            || (OnlinePopularityService.normalizeTitleForMatching($0.albumTitle) == normAlbum
                && OnlinePopularityService.normalizeTitleForMatching($0.artistName) == normArtist)
        }) {
            lidarrTrackedOrders[idx].phase = .searching
            lidarrTrackedOrders[idx].progress = 0
            lidarrTrackedOrders[idx].orderedAt = Date()
            lidarrTrackedOrders[idx].lastUpdatedAt = Date()
            lidarrTrackedOrders[idx].statusDetail = "Searching Lidarr indexers..."
            if let lidarrAlbumID { lidarrTrackedOrders[idx].lidarrAlbumID = lidarrAlbumID }
        } else {
            let order = LidarrTrackedOrder(
                albumTitle: albumTitle,
                artistName: artistName,
                lidarrAlbumID: lidarrAlbumID,
                orderedAt: Date(),
                phase: .searching,
                progress: 0,
                statusDetail: "Searching Lidarr indexers...",
                lastUpdatedAt: Date()
            )
            lidarrTrackedOrders.insert(order, at: 0)
        }
        persistLidarrTrackedOrders()
    }

    func dismissLidarrTrackedOrder(id: String) {
        lidarrTrackedOrders.removeAll { $0.id == id }
        persistLidarrTrackedOrders()
    }

    func clearCompletedLidarrOrders() {
        lidarrTrackedOrders.removeAll { $0.phase == .completed || $0.phase == .failed }
        persistLidarrTrackedOrders()
    }

    var lidarrWarningCount: Int {
        lidarrQueue.filter { $0.phase == .warning || $0.phase == .failed }.count
    }

    var lidarrAverageQueueProgress: Double? {
        let downloading = lidarrQueue.filter { $0.phase == .downloading || $0.phase == .importing }
        guard !downloading.isEmpty else { return nil }
        let totalSize = downloading.reduce(0.0) { $0 + max(0, $1.size) }
        if totalSize > 0 {
            let remaining = downloading.reduce(0.0) { $0 + max(0, $1.sizeleft) }
            return max(0, min(1, 1.0 - (remaining / totalSize)))
        }
        return downloading.reduce(0.0) { $0 + $1.progress } / Double(downloading.count)
    }

    /// Deduplicated recent album imports from Lidarr history
    var lidarrRecentImports: [LidarrHistoryItem] {
        var seen: Set<String> = []
        var out: [LidarrHistoryItem] = []
        for item in lidarrHistory where item.isImported {
            let key = item.albumId.map(String.init) ?? "\(item.artistName ?? "")::\(item.albumTitle ?? item.sourceTitle)".lowercased()
            if seen.insert(key).inserted {
                out.append(item)
            }
        }
        return out
    }

    func startLidarrQueuePolling() {
        guard lidarrAutoPollEnabled && lidarrConfig.isEnabled && lidarrConfig.isConfigured else { return }
        guard lidarrPollTask == nil else { return }

        lidarrPollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { break }
                let shouldPoll = await MainActor.run {
                    self.lidarrAutoPollEnabled && self.lidarrConfig.isEnabled && self.lidarrConfig.isConfigured
                }
                if !shouldPoll { break }

                await self.syncLidarrQueueSnapshot(silent: true, includeWanted: false)

                let intervalSeconds: Int = await MainActor.run {
                    let viewingLidarr = self.currentDestination == .lidarr || self.isLidarrLibraryScope
                    let hasActiveWork = !self.lidarrQueue.isEmpty || self.lidarrTrackedOrders.contains(where: { $0.phase.isActive })
                    if viewingLidarr || hasActiveWork { return 5 }
                    return 20
                }
                try? await Task.sleep(for: .seconds(intervalSeconds))
            }
        }
    }

    func stopLidarrQueuePolling() {
        lidarrPollTask?.cancel()
        lidarrPollTask = nil
    }

    var lidarrMarkedCount: Int {
        lidarrMarkedAlbums.count + lidarrMarkedTracks.count
    }

    func isAlbumMarkedForLidarr(_ album: LidarrAlbumSearchResult) -> Bool {
        lidarrMarkedAlbums[album.id] != nil
    }

    func isTrackMarkedForLidarr(_ track: LidarrTrackMatch) -> Bool {
        lidarrMarkedTracks[track.id] != nil
    }

    func toggleMarkForLidarrDownload(_ album: LidarrAlbumSearchResult) {
        if lidarrMarkedAlbums[album.id] != nil {
            lidarrMarkedAlbums.removeValue(forKey: album.id)
        } else {
            lidarrMarkedAlbums[album.id] = album
        }
    }

    func toggleMarkForLidarrDownload(_ track: LidarrTrackMatch) {
        if lidarrMarkedTracks[track.id] != nil {
            lidarrMarkedTracks.removeValue(forKey: track.id)
        } else {
            lidarrMarkedTracks[track.id] = track
        }
    }

    func clearLidarrMarks() {
        lidarrMarkedAlbums.removeAll()
        lidarrMarkedTracks.removeAll()
    }

    func orderAllMarkedLidarrItems() {
        guard lidarrConfig.isConfigured else {
            showToast("Configure Lidarr URL & API Key in Settings first.", isError: true)
            return
        }
        guard lidarrMarkedCount > 0, !isOrderingMarkedLidarr else { return }

        let albumsToOrder = Array(lidarrMarkedAlbums.values)
        let tracksToOrder = Array(lidarrMarkedTracks.values)
        isOrderingMarkedLidarr = true
        let cfg = lidarrConfig

        Task {
            var succeeded = 0
            var failed = 0

            for album in albumsToOrder {
                await MainActor.run { _ = self.lidarrOrderingIDs.insert(album.id) }
                do {
                    let res = try await lidarrClient.orderAlbum(album, config: cfg)
                    succeeded += 1
                    await MainActor.run {
                        self.lidarrOrderingIDs.remove(album.id)
                        self.lidarrOrderedIDs.insert(album.id)
                        self.lidarrMarkedAlbums.removeValue(forKey: album.id)
                        self.recordLidarrTrackedOrder(albumTitle: res.albumTitle, artistName: res.artistName, lidarrAlbumID: res.lidarrAlbumID)
                        if let idx = self.lidarrAlbumResults.firstIndex(where: { $0.id == album.id }) {
                            self.lidarrAlbumResults[idx].monitored = true
                            if let newID = res.lidarrAlbumID {
                                self.lidarrAlbumResults[idx].lidarrID = newID
                            }
                        }
                    }
                } catch {
                    failed += 1
                    await MainActor.run { _ = self.lidarrOrderingIDs.remove(album.id) }
                }
            }

            for track in tracksToOrder {
                await MainActor.run { _ = self.lidarrOrderingIDs.insert(track.id) }
                do {
                    let query = "\(track.artistName) \(track.albumTitle)"
                    let candidates = try await lidarrClient.searchAlbums(term: query, config: cfg)
                    let targetAlbum = OnlinePopularityService.normalizeTitleForMatching(track.albumTitle)
                    let targetArtist = OnlinePopularityService.normalizeTitleForMatching(track.artistName)
                    let best = candidates.first(where: { c in
                        let aNorm = OnlinePopularityService.normalizeTitleForMatching(c.title)
                        let arNorm = OnlinePopularityService.normalizeTitleForMatching(c.artistName)
                        return (aNorm == targetAlbum || aNorm.contains(targetAlbum) || targetAlbum.contains(aNorm))
                            && (arNorm.contains(targetArtist) || targetArtist.contains(arNorm))
                    }) ?? candidates.first

                    if let best {
                        let res = try await lidarrClient.orderAlbum(best, config: cfg)
                        succeeded += 1
                        await MainActor.run {
                            self.lidarrOrderingIDs.remove(track.id)
                            self.lidarrOrderedIDs.insert(track.id)
                            self.lidarrOrderedIDs.insert(best.id)
                            self.lidarrMarkedTracks.removeValue(forKey: track.id)
                            self.recordLidarrTrackedOrder(albumTitle: res.albumTitle, artistName: res.artistName, lidarrAlbumID: res.lidarrAlbumID)
                        }
                    } else {
                        failed += 1
                        await MainActor.run { _ = self.lidarrOrderingIDs.remove(track.id) }
                    }
                } catch {
                    failed += 1
                    await MainActor.run { _ = self.lidarrOrderingIDs.remove(track.id) }
                }
            }

            await MainActor.run {
                self.isOrderingMarkedLidarr = false
                let errPart = failed > 0 ? " (\(failed) failed)" : ""
                self.showToast("Ordered \(succeeded) marked download\(succeeded == 1 ? "" : "s") in Lidarr\(errPart)", isError: failed > 0 && succeeded == 0)
            }
            try? await Task.sleep(for: .seconds(1.2))
            self.refreshLidarrQueueAndWanted(silent: true)
        }
    }

    /// Unified Lidarr search driven by the Top Global Search Bar when scoped to the Lidarr library
    func searchLidarrUnified(query: String, immediate: Bool = false) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        lidarrDebounceTask?.cancel()
        guard !q.isEmpty else {
            lidarrLastUnifiedQuery = ""
            isSearchingLidarr = false
            lidarrSearchError = nil
            return
        }
        guard lidarrConfig.isConfigured else {
            lidarrSearchError = "Configure your Lidarr Server URL and API Key in Settings first."
            return
        }
        if !immediate && q == lidarrLastUnifiedQuery && (!lidarrAlbumResults.isEmpty || !lidarrArtistResults.isEmpty || !lidarrTrackResults.isEmpty) {
            return
        }

        let cfg = lidarrConfig
        lidarrDebounceTask = Task { [weak self] in
            guard let self else { return }
            if !immediate {
                try? await Task.sleep(for: .milliseconds(420))
            }
            if Task.isCancelled { return }

            await MainActor.run {
                self.isSearchingLidarr = true
                self.lidarrSearchError = nil
                self.lidarrLastUnifiedQuery = q
            }

            do {
                async let albumsTask = self.lidarrClient.searchAlbums(term: q, config: cfg)
                async let artistsTask = self.lidarrClient.searchArtists(term: q, config: cfg)
                async let tracksTask = self.lidarrClient.searchTracksForAlbumOrder(term: q)

                let albums = (try? await albumsTask) ?? []
                let artists = (try? await artistsTask) ?? []
                let tracks = (try? await tracksTask) ?? []

                if Task.isCancelled { return }
                await MainActor.run {
                    self.lidarrAlbumResults = albums
                    self.lidarrArtistResults = artists
                    self.lidarrTrackResults = tracks
                    self.isSearchingLidarr = false
                    if albums.isEmpty && artists.isEmpty && tracks.isEmpty {
                        self.lidarrSearchError = "No Lidarr albums, artists, or tracks matched '\(q)'."
                    }
                }
            }
        }
    }

    func testLidarrConnection(silent: Bool = false) {
        guard lidarrConfig.isConfigured else {
            if !silent {
                lidarrConnectionError = "Enter both Server URL and API Key first."
            }
            return
        }
        isTestingLidarrConnection = true
        lidarrConnectionError = nil
        let cfg = lidarrConfig
        Task {
            do {
                let bundle = try await lidarrClient.testConnection(config: cfg)
                await MainActor.run {
                    self.lidarrStatus = bundle.status
                    self.lidarrRootFolders = bundle.rootFolders
                    self.lidarrQualityProfiles = bundle.qualityProfiles
                    self.lidarrMetadataProfiles = bundle.metadataProfiles
                    self.isTestingLidarrConnection = false

                    // Auto-pick defaults if user hasn't chosen profiles/root folder yet
                    var updated = self.lidarrConfig
                    var changed = false
                    if updated.rootFolderPath.isEmpty, let firstRF = bundle.rootFolders.first {
                        updated.rootFolderPath = firstRF.path
                        changed = true
                    }
                    if updated.qualityProfileId == nil, let firstQP = bundle.qualityProfiles.first {
                        updated.qualityProfileId = firstQP.id
                        changed = true
                    }
                    if updated.metadataProfileId == nil, let firstMP = bundle.metadataProfiles.first {
                        updated.metadataProfileId = firstMP.id
                        changed = true
                    }
                    if changed {
                        self.saveLidarrConfig(updated)
                    }
                    if !silent {
                        self.showToast("Connected to \(bundle.status.appName) v\(bundle.status.version)")
                    }
                }
                self.refreshLidarrQueueAndWanted(silent: true)
            } catch {
                await MainActor.run {
                    self.lidarrStatus = nil
                    self.isTestingLidarrConnection = false
                    self.lidarrConnectionError = error.localizedDescription
                    if !silent {
                        self.showToast("Lidarr connection failed: \(error.localizedDescription)", isError: true)
                    }
                }
            }
        }
    }

    func openLidarrSearch(query: String, mode: LidarrSearchMode = .albums) {
        guard lidarrConfig.isEnabled else { return }
        searchQuery = ""
        lidarrSearchQuery = query
        lidarrSearchMode = mode
        navigate(to: .lidarr)
        searchLidarr()
    }

    func searchLidarr() {
        let q = lidarrSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        if lidarrSearchMode != .tracks && !lidarrConfig.isConfigured {
            lidarrSearchError = "Configure your Lidarr Server URL and API Key in Settings first."
            return
        }
        isSearchingLidarr = true
        lidarrSearchError = nil
        let mode = lidarrSearchMode
        let cfg = lidarrConfig

        Task {
            do {
                switch mode {
                case .albums:
                    let results = try await lidarrClient.searchAlbums(term: q, config: cfg)
                    await MainActor.run {
                        self.lidarrAlbumResults = results
                        self.isSearchingLidarr = false
                        if results.isEmpty {
                            self.lidarrSearchError = "No albums matched '\(q)' in Lidarr."
                        }
                    }
                case .artists:
                    let results = try await lidarrClient.searchArtists(term: q, config: cfg)
                    await MainActor.run {
                        self.lidarrArtistResults = results
                        self.isSearchingLidarr = false
                        if results.isEmpty {
                            self.lidarrSearchError = "No artists matched '\(q)' in Lidarr."
                        }
                    }
                case .tracks:
                    let results = try await lidarrClient.searchTracksForAlbumOrder(term: q)
                    await MainActor.run {
                        self.lidarrTrackResults = results
                        self.isSearchingLidarr = false
                        if results.isEmpty {
                            self.lidarrSearchError = "No tracks matched '\(q)'."
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.isSearchingLidarr = false
                    self.lidarrSearchError = error.localizedDescription
                }
            }
        }
    }

    func orderLidarrAlbum(_ album: LidarrAlbumSearchResult) {
        guard !lidarrOrderingIDs.contains(album.id) else { return }
        lidarrOrderingIDs.insert(album.id)
        let cfg = lidarrConfig
        Task {
            do {
                let res = try await lidarrClient.orderAlbum(album, config: cfg)
                await MainActor.run {
                    self.lidarrOrderingIDs.remove(album.id)
                    self.lidarrOrderedIDs.insert(album.id)
                    self.recordLidarrTrackedOrder(albumTitle: res.albumTitle, artistName: res.artistName, lidarrAlbumID: res.lidarrAlbumID)
                    if let idx = self.lidarrAlbumResults.firstIndex(where: { $0.id == album.id }) {
                        self.lidarrAlbumResults[idx].monitored = true
                        if let newID = res.lidarrAlbumID {
                            self.lidarrAlbumResults[idx].lidarrID = newID
                        }
                    }
                    let verb = res.alreadyExisted ? "Triggered Lidarr search for" : "Ordered in Lidarr:"
                    self.showToast("\(verb) '\(res.albumTitle)' — \(res.artistName)")
                }
                try? await Task.sleep(for: .seconds(1.2))
                self.refreshLidarrQueueAndWanted(silent: true)
            } catch {
                await MainActor.run {
                    self.lidarrOrderingIDs.remove(album.id)
                    self.showToast("Lidarr order failed: \(error.localizedDescription)", isError: true)
                }
            }
        }
    }

    /// Resolves a matched track's parent album in Lidarr and orders it in one click
    func orderLidarrAlbumForTrack(_ track: LidarrTrackMatch) {
        guard lidarrConfig.isConfigured else {
            showToast("Configure Lidarr URL & API Key in Settings first.", isError: true)
            return
        }
        guard !lidarrOrderingIDs.contains(track.id) else { return }
        lidarrOrderingIDs.insert(track.id)
        let cfg = lidarrConfig
        let query = "\(track.artistName) \(track.albumTitle)"
        Task {
            do {
                let candidates = try await lidarrClient.searchAlbums(term: query, config: cfg)
                let targetAlbum = OnlinePopularityService.normalizeTitleForMatching(track.albumTitle)
                let targetArtist = OnlinePopularityService.normalizeTitleForMatching(track.artistName)
                let best = candidates.first(where: { c in
                    let aNorm = OnlinePopularityService.normalizeTitleForMatching(c.title)
                    let arNorm = OnlinePopularityService.normalizeTitleForMatching(c.artistName)
                    return (aNorm == targetAlbum || aNorm.contains(targetAlbum) || targetAlbum.contains(aNorm))
                        && (arNorm.contains(targetArtist) || targetArtist.contains(arNorm))
                }) ?? candidates.first

                guard let best else {
                    await MainActor.run {
                        self.lidarrOrderingIDs.remove(track.id)
                        self.showToast("Could not locate album '\(track.albumTitle)' in Lidarr metadata — try Album search.", isError: true)
                    }
                    return
                }

                let res = try await lidarrClient.orderAlbum(best, config: cfg)
                await MainActor.run {
                    self.lidarrOrderingIDs.remove(track.id)
                    self.lidarrOrderedIDs.insert(track.id)
                    self.lidarrOrderedIDs.insert(best.id)
                    self.recordLidarrTrackedOrder(albumTitle: res.albumTitle, artistName: res.artistName, lidarrAlbumID: res.lidarrAlbumID)
                    self.showToast("Ordered '\(res.albumTitle)' (contains '\(track.title)') in Lidarr")
                }
                try? await Task.sleep(for: .seconds(1.2))
                self.refreshLidarrQueueAndWanted(silent: true)
            } catch {
                await MainActor.run {
                    self.lidarrOrderingIDs.remove(track.id)
                    self.showToast("Lidarr order failed: \(error.localizedDescription)", isError: true)
                }
            }
        }
    }

    func orderLidarrArtist(_ artist: LidarrArtistSearchResult, monitorMode: String = "all", searchMissing: Bool = true) {
        guard !lidarrOrderingIDs.contains(artist.id) else { return }
        lidarrOrderingIDs.insert(artist.id)
        let cfg = lidarrConfig
        Task {
            do {
                let createdID = try await lidarrClient.orderArtist(
                    artist,
                    config: cfg,
                    monitorMode: monitorMode,
                    searchMissing: searchMissing
                )
                await MainActor.run {
                    self.lidarrOrderingIDs.remove(artist.id)
                    self.lidarrOrderedIDs.insert(artist.id)
                    if let idx = self.lidarrArtistResults.firstIndex(where: { $0.id == artist.id }) {
                        self.lidarrArtistResults[idx].monitored = true
                        if let createdID { self.lidarrArtistResults[idx].lidarrID = createdID }
                    }
                    self.showToast("Added & ordered '\(artist.artistName)' in Lidarr")
                }
                try? await Task.sleep(for: .seconds(1.2))
                self.refreshLidarrQueueAndWanted(silent: true)
            } catch {
                await MainActor.run {
                    self.lidarrOrderingIDs.remove(artist.id)
                    self.showToast("Lidarr artist order failed: \(error.localizedDescription)", isError: true)
                }
            }
        }
    }

    func refreshLidarrQueueAndWanted(silent: Bool = false) {
        guard lidarrConfig.isConfigured else { return }
        Task {
            await syncLidarrQueueSnapshot(silent: silent, includeWanted: true)
        }
    }

    func syncLidarrQueueSnapshot(silent: Bool = true, includeWanted: Bool = false) async {
        guard lidarrConfig.isConfigured else { return }
        await MainActor.run {
            if !silent { self.isLoadingLidarrQueue = true }
        }
        let cfg = lidarrConfig
        do {
            async let qTask = lidarrClient.fetchQueue(config: cfg)
            async let hTask = lidarrClient.fetchRecentHistory(config: cfg, pageSize: 30)
            let queueItems = try await qTask
            let historyItems = (try? await hTask) ?? []
            let wantedItems: [LidarrAlbumSearchResult]? = includeWanted ? (try? await lidarrClient.fetchWantedMissing(config: cfg)) : nil

            await MainActor.run {
                let previousQueueIDs = self.lastKnownLidarrQueueIDs
                let currentQueueIDs = Set(queueItems.map(\.id))
                let droppedIDs = previousQueueIDs.subtracting(currentQueueIDs)
                self.lastKnownLidarrQueueIDs = currentQueueIDs

                self.lidarrQueue = queueItems
                self.lidarrHistory = historyItems
                if let wantedItems {
                    self.lidarrWantedMissing = wantedItems
                }
                self.lidarrQueueLastUpdatedAt = Date()
                self.isLoadingLidarrQueue = false

                // Reconcile My Echo's tracked orders against live Lidarr queue & history
                let (updatedOrders, newlyCompleted) = LidarrClient.reconcileTrackedOrders(
                    self.lidarrTrackedOrders,
                    queue: queueItems,
                    history: historyItems
                )
                if updatedOrders != self.lidarrTrackedOrders {
                    self.lidarrTrackedOrders = updatedOrders
                    self.persistLidarrTrackedOrders()
                }

                // Notify & optionally re-index when tracked orders finish importing (or active queue items finish)
                if !newlyCompleted.isEmpty {
                    let first = newlyCompleted[0]
                    let extra = newlyCompleted.count > 1 ? " (+\(newlyCompleted.count - 1) more)" : ""
                    self.showToast("Lidarr imported '\(first.albumTitle)'\(extra) — ready in your library!")
                    if self.lidarrConfig.autoReindexOnImport && !self.isIndexing && !self.sources.isEmpty {
                        self.indexAllSources()
                    }
                } else if !droppedIDs.isEmpty && !previousQueueIDs.isEmpty {
                    // Check if any dropped queue item just showed up as a recent import in the last 90 seconds
                    let freshImport = historyItems.first(where: { $0.isImported && Date().timeIntervalSince($0.date) < 90 })
                    if let freshImport {
                        let name = freshImport.albumTitle ?? freshImport.sourceTitle
                        self.showToast("Lidarr finished importing '\(name)'")
                        if self.lidarrConfig.autoReindexOnImport && !self.isIndexing && !self.sources.isEmpty {
                            self.indexAllSources()
                        }
                    }
                }
            }
        } catch {
            await MainActor.run {
                self.isLoadingLidarrQueue = false
                if !silent {
                    self.showToast("Could not refresh Lidarr queue: \(error.localizedDescription)", isError: true)
                }
            }
        }
    }

    func triggerLidarrWantedSearch(_ album: LidarrAlbumSearchResult) {
        guard let lidarrID = album.lidarrID else { return }
        lidarrOrderingIDs.insert(album.id)
        let cfg = lidarrConfig
        Task {
            do {
                try await lidarrClient.triggerAlbumSearch(albumID: lidarrID, config: cfg)
                await MainActor.run {
                    self.lidarrOrderingIDs.remove(album.id)
                    self.showToast("Triggered Lidarr download search for '\(album.title)'")
                }
                try? await Task.sleep(for: .seconds(1.2))
                self.refreshLidarrQueueAndWanted(silent: true)
            } catch {
                await MainActor.run {
                    self.lidarrOrderingIDs.remove(album.id)
                    self.showToast("Search trigger failed: \(error.localizedDescription)", isError: true)
                }
            }
        }
    }

    func removeLidarrQueueItem(_ item: LidarrQueueItem) {
        let cfg = lidarrConfig
        Task {
            do {
                try await lidarrClient.removeQueueItem(id: item.id, config: cfg)
                await MainActor.run {
                    self.lidarrQueue.removeAll { $0.id == item.id }
                    self.showToast("Removed '\(item.albumTitle ?? item.title)' from Lidarr queue")
                }
            } catch {
                await MainActor.run {
                    self.showToast("Failed to remove queue item: \(error.localizedDescription)", isError: true)
                }
            }
        }
    }

    // MARK: - Search Filtering & Sorting (Scoped to Selected Library!)

    var isGlobalSearchActive: Bool {
        let hasText = !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if isLidarrLibraryScope || isViewingPodcasts {
            return hasText
        }
        return hasText || minStarRating > 0
    }

    var isViewingPodcasts: Bool {
        switch currentDestination {
        case .podcasts, .podcastDetail: return true
        default: return false
        }
    }

    var filteredArtists: [ArtistGroup] {
        let terms = SearchQueryTerms.parse(searchQuery)
        let minStars = minStarRating
        guard !terms.isEmpty || minStars > 0 else { return artists }
        return artists.filter { artist in
            let maxAlbumRating = artist.albums.map { effectiveAlbumRating(for: $0) }.max() ?? 0
            let maxTrackRating = Double(artist.tracks.map { userRating(for: $0) }.max() ?? 0)
            let bestRating = max(maxAlbumRating, maxTrackRating)
            if minStars > 0 && bestRating < Double(minStars) {
                return false
            }
            if terms.isEmpty { return true }
            let values = SearchFieldValues(
                track: artist.tracks.map(\.title).joined(separator: " ").lowercased(),
                artist: artist.name.lowercased(),
                album: artist.albums.map(\.title).joined(separator: " ").lowercased(),
                rating: bestRating > 0 ? bestRating : nil
            )
            return terms.matches(values: values)
        }
    }

    var filteredAlbums: [AlbumGroup] {
        let terms = SearchQueryTerms.parse(searchQuery)
        let minStars = minStarRating
        if terms.isEmpty && minStars == 0 {
            switch albumSortOrder {
            case .title:
                return albums
            case .newArrivals:
                return newArrivalAlbums
            case .newReleases:
                return newReleaseAlbums
            case .highestRated:
                return albums.sorted { a, b in
                    let ra = effectiveAlbumRating(for: a)
                    let rb = effectiveAlbumRating(for: b)
                    if abs(ra - rb) > 0.001 { return ra > rb }
                    return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
                }
            case .mostPlayed:
                return albums.sorted { a, b in
                    let pa = totalUserPlays(for: a)
                    let pb = totalUserPlays(for: b)
                    if pa != pb { return pa > pb }
                    return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
                }
            case .onlinePopularity:
                return albums.sorted { a, b in
                    let pa = averageOnlinePopularity(for: a) ?? -1
                    let pb = averageOnlinePopularity(for: b) ?? -1
                    if pa != pb { return pa > pb }
                    return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
                }
            }
        }
        let base = albums.filter { album in
            let effRating = effectiveAlbumRating(for: album)
            if minStars > 0 && effRating < Double(minStars) {
                return false
            }
            if terms.isEmpty { return true }
            let values = SearchFieldValues(
                track: album.tracks.map(\.title).joined(separator: " ").lowercased(),
                artist: album.artist.lowercased(),
                album: album.title.lowercased(),
                year: album.year.map(String.init) ?? "",
                rating: effRating > 0 ? effRating : nil
            )
            return terms.matches(values: values)
        }
        switch albumSortOrder {
        case .title:
            return base
        case .newArrivals:
            return base.sorted { a, b in
                let da = a.latestArrivalDate
                let db = b.latestArrivalDate
                if abs(da.timeIntervalSince(db)) > 1.0 { return da > db }
                return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            }
        case .newReleases:
            let maxValidYear = Calendar.current.component(.year, from: Date()) + 1
            return base.sorted { a, b in
                let ya = (a.year ?? 0) <= maxValidYear ? (a.year ?? 0) : 0
                let yb = (b.year ?? 0) <= maxValidYear ? (b.year ?? 0) : 0
                if ya != yb { return ya > yb }
                let da = a.latestArrivalDate
                let db = b.latestArrivalDate
                if abs(da.timeIntervalSince(db)) > 1.0 { return da > db }
                return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            }
        case .highestRated:
            return base.sorted { a, b in
                let ra = effectiveAlbumRating(for: a)
                let rb = effectiveAlbumRating(for: b)
                if abs(ra - rb) > 0.001 { return ra > rb }
                return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            }
        case .mostPlayed:
            return base.sorted { a, b in
                let pa = totalUserPlays(for: a)
                let pb = totalUserPlays(for: b)
                if pa != pb { return pa > pb }
                return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            }
        case .onlinePopularity:
            return base.sorted { a, b in
                let pa = averageOnlinePopularity(for: a) ?? -1
                let pb = averageOnlinePopularity(for: b) ?? -1
                if pa != pb { return pa > pb }
                return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            }
        }
    }

    func sortTracks(_ input: [Track], by state: TrackTableSortState) -> [Track] {
        if state.column == .index {
            return state.ascending ? input : Array(input.reversed())
        }
        return input.sorted { a, b in
            let asc: Bool
            switch state.column {
            case .index:
                asc = true
            case .title:
                let cmp = a.title.localizedCaseInsensitiveCompare(b.title)
                asc = cmp == .orderedSame ? (a.artist.localizedCaseInsensitiveCompare(b.artist) == .orderedAscending) : (cmp == .orderedAscending)
            case .album:
                let cmp = a.effectiveAlbum.localizedCaseInsensitiveCompare(b.effectiveAlbum)
                if cmp == .orderedSame {
                    asc = (a.discNumber ?? 1, a.trackNumber ?? 999) < (b.discNumber ?? 1, b.trackNumber ?? 999)
                } else {
                    asc = cmp == .orderedAscending
                }
            case .plays:
                let pa = trackStats[a.id]?.userPlayCount ?? 0
                let pb = trackStats[b.id]?.userPlayCount ?? 0
                if pa == pb { return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending }
                asc = pa < pb
            case .popularity:
                let pa = trackStats[a.id]?.onlinePopularity ?? -1
                let pb = trackStats[b.id]?.onlinePopularity ?? -1
                if pa == pb {
                    let ra = trackStats[a.id]?.onlinePlayCount ?? 0
                    let rb = trackStats[b.id]?.onlinePlayCount ?? 0
                    if ra == rb { return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending }
                    asc = ra < rb
                } else {
                    asc = pa < pb
                }
            case .rating:
                let ra = trackStats[a.id]?.userRating ?? 0
                let rb = trackStats[b.id]?.userRating ?? 0
                if ra == rb { return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending }
                asc = ra < rb
            case .format:
                let qa = qualitySortScore(a)
                let qb = qualitySortScore(b)
                if qa == qb { return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending }
                asc = qa < qb
            case .sync:
                let sa = trackSyncReason(a) != nil ? 1 : 0
                let sb = trackSyncReason(b) != nil ? 1 : 0
                if sa == sb { return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending }
                asc = sa < sb
            case .duration:
                if abs(a.duration - b.duration) < 0.01 { return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending }
                asc = a.duration < b.duration
            }
            return state.ascending ? asc : !asc
        }
    }

    private func qualitySortScore(_ t: Track) -> Int {
        var score = 0
        if t.format == .dsf || t.format == .dff { score += 5_000_000 }
        else if t.isHiRes { score += 4_000_000 }
        else if t.format.isLossless { score += 3_000_000 }
        else { score += 1_000_000 }
        score += (t.bitDepth ?? 0) * 10_000
        score += (t.sampleRate ?? 0) / 100
        score += (t.bitrate ?? 0)
        return score
    }

    var tracksViewSortState: TrackTableSortState {
        get {
            if let col = trackTableColumn {
                return TrackTableSortState(column: col, ascending: trackSortAscending)
            }
            switch trackSortOrder {
            case .library, .newArrivals, .recentlyPlayed, .artist:
                return TrackTableSortState(column: .index, ascending: trackSortAscending)
            case .highestRated:
                return TrackTableSortState(column: .rating, ascending: trackSortAscending)
            case .mostPlayed:
                return TrackTableSortState(column: .plays, ascending: trackSortAscending)
            case .onlinePopularity:
                return TrackTableSortState(column: .popularity, ascending: trackSortAscending)
            case .title:
                return TrackTableSortState(column: .title, ascending: trackSortAscending)
            }
        }
        set {
            trackTableColumn = newValue.column
            trackSortAscending = newValue.ascending
            switch newValue.column {
            case .index: trackSortOrder = .library
            case .title: trackSortOrder = .title
            case .rating: trackSortOrder = .highestRated
            case .plays: trackSortOrder = .mostPlayed
            case .popularity: trackSortOrder = .onlinePopularity
            case .album, .format, .sync, .duration: break
            }
        }
    }

    var filteredTracks: [Track] {
        let terms = SearchQueryTerms.parse(searchQuery)
        let minStars = minStarRating
        let base: [Track]
        if terms.isEmpty && minStars == 0 {
            base = scopedTracks
        } else {
            base = scopedTracks.filter { t in
                let r = userRating(for: t)
                if minStars > 0 && r < minStars {
                    return false
                }
                if terms.isEmpty { return true }
                return terms.matches(track: t, rating: r > 0 ? r : nil)
            }
        }
        if let col = trackTableColumn {
            return sortTracks(base, by: TrackTableSortState(column: col, ascending: trackSortAscending))
        }
        switch trackSortOrder {
        case .library:
            return base
        case .newArrivals:
            return base.sorted { a, b in
                let da = a.arrivalDate
                let db = b.arrivalDate
                if abs(da.timeIntervalSince(db)) > 1.0 { return da > db }
                return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            }
        case .highestRated:
            return sortTracks(base, by: TrackTableSortState(column: .rating, ascending: false))
        case .mostPlayed:
            return sortTracks(base, by: TrackTableSortState(column: .plays, ascending: false))
        case .onlinePopularity:
            return sortTracks(base, by: TrackTableSortState(column: .popularity, ascending: false))
        case .recentlyPlayed:
            return base.sorted { a, b in
                let da = trackStats[a.id]?.lastPlayedAt ?? .distantPast
                let db = trackStats[b.id]?.lastPlayedAt ?? .distantPast
                if da != db { return da > db }
                return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            }
        case .title:
            return sortTracks(base, by: TrackTableSortState(column: .title, ascending: true))
        case .artist:
            return base.sorted {
                let c = $0.artist.localizedCaseInsensitiveCompare($1.artist)
                if c != .orderedSame { return c == .orderedAscending }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        }
    }

    var filteredPlaylists: [Playlist] {
        let terms = SearchQueryTerms.parse(searchQuery)
        let minStars = minStarRating
        guard !terms.isEmpty || minStars > 0 else { return playlists }
        return playlists.filter { pl in
            let tracksInPl = pl.trackIDs.compactMap { tracksByID[$0] }.filter {
                selectedSourceID == nil || $0.sourceID == selectedSourceID
            }
            if minStars > 0 {
                let hasQualifiedTrack = tracksInPl.contains { t in
                    let r = userRating(for: t)
                    guard r >= minStars else { return false }
                    return terms.isEmpty || terms.matches(track: t, rating: r)
                }
                return hasQualifiedTrack
            }
            if terms.matches(fields: [pl.name, pl.description]) {
                return true
            }
            return tracksInPl.contains { t in
                let r = userRating(for: t)
                return terms.matches(track: t, rating: r > 0 ? r : nil)
            }
        }
    }

    var filteredPodcastShows: [PodcastShow] {
        let terms = SearchQueryTerms.parse(searchQuery)
        guard !terms.isEmpty else { return podcasts }
        return podcasts.filter {
            terms.matches(fields: [$0.title, $0.author, $0.description])
        }
    }

    var filteredPodcastEpisodes: [PodcastEpisode] {
        let terms = SearchQueryTerms.parse(searchQuery)
        guard !terms.isEmpty else { return [] }
        var out: [PodcastEpisode] = []
        for show in podcasts {
            for ep in show.episodes {
                if terms.matches(fields: [ep.title, ep.showTitle, ep.summary]) {
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

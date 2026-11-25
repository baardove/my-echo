import Foundation
import Network
import CryptoKit
import Darwin

// MARK: - Wireless Sync Wire Protocol Models (Shared Contract with My Echo iOS App)

public struct WirelessSyncTrack: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var artist: String
    public var albumArtist: String
    public var album: String
    public var trackNumber: Int?
    public var discNumber: Int?
    public var year: Int?
    public var genre: String?
    public var duration: TimeInterval
    public var format: String
    public var fileExtension: String
    public var sampleRate: Int?
    public var bitDepth: Int?
    public var bitrate: Int?
    public var fileSize: Int64
    public var modifiedAt: Date
    public var artworkHash: String?

    public init(from track: Track, resolvedAlbumArtist: String? = nil) {
        self.id = track.id
        self.title = track.title
        self.artist = track.artist
        self.albumArtist = (resolvedAlbumArtist?.isEmpty == false ? resolvedAlbumArtist! : track.albumArtist)
        self.album = track.album
        self.trackNumber = track.trackNumber
        self.discNumber = track.discNumber
        self.year = track.year
        self.genre = track.genre
        self.duration = track.duration
        self.format = track.format.rawValue
        let ext = URL(fileURLWithPath: track.filePath).pathExtension.lowercased()
        self.fileExtension = ext.isEmpty ? track.format.rawValue : ext
        self.sampleRate = track.sampleRate
        self.bitDepth = track.bitDepth
        self.bitrate = track.bitrate
        self.fileSize = track.fileSize
        self.modifiedAt = track.modifiedAt
        self.artworkHash = track.artworkHash
    }
}

public struct WirelessSyncPlaylist: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var description: String
    public var trackIDs: [String]

    public init(from playlist: Playlist, allowedTrackIDs: Set<String>) {
        self.id = playlist.id.uuidString
        self.name = playlist.name
        self.description = playlist.description
        self.trackIDs = playlist.trackIDs.filter { allowedTrackIDs.contains($0) }
    }
}

public struct WirelessSyncPodcastFeed: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var author: String
    public var description: String
    public var feedURL: String
    public var artworkURL: String?
    public var artworkHash: String?
    public var episodesToKeep: Int
    public var isSelectedForAutoSync: Bool

    public init(from show: PodcastShow, isSelectedForAutoSync: Bool) {
        self.id = show.id.uuidString
        self.title = show.title
        self.author = show.author
        self.description = show.description
        self.feedURL = show.feedURL
        self.artworkURL = show.artworkURL
        self.artworkHash = show.artworkHash
        self.episodesToKeep = show.episodesToKeep
        self.isSelectedForAutoSync = isSelectedForAutoSync
    }
}

public struct WirelessSyncEpisode: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var showID: String
    public var showTitle: String
    public var title: String
    public var summary: String
    public var publishedAt: Date?
    public var duration: TimeInterval
    public var fileSize: Int64
    public var artworkHash: String?
    public var fileExtension: String
    public var guid: String?
    public var audioURL: String?

    public init(from episode: PodcastEpisode) {
        self.id = episode.id
        self.showID = episode.showID.uuidString
        self.showTitle = episode.showTitle
        self.title = episode.title
        self.summary = episode.summary
        self.publishedAt = episode.publishedAt
        self.duration = episode.duration
        self.fileSize = episode.fileSize
        self.artworkHash = episode.artworkHash
        let ext = episode.localFilePath.map { URL(fileURLWithPath: $0).pathExtension.lowercased() } ?? "mp3"
        self.fileExtension = ext.isEmpty ? "mp3" : ext
        self.guid = episode.guid.isEmpty ? nil : episode.guid
        self.audioURL = episode.audioURL.isEmpty ? nil : episode.audioURL
    }
}

public struct WirelessSyncManifest: Codable, Sendable {
    public var deviceID: String
    public var deviceName: String
    public var serverName: String
    public var manifestVersion: String
    public var syncMode: String
    public var generatedAt: Date
    public var tracks: [WirelessSyncTrack]
    public var playlists: [WirelessSyncPlaylist]
    public var episodes: [WirelessSyncEpisode]
    public var podcastFeeds: [WirelessSyncPodcastFeed]
    public var albumEditorial: [AlbumEditorialInfo]
    public var artistEditorial: [ArtistEditorialInfo]

    public init(
        deviceID: String,
        deviceName: String,
        serverName: String,
        manifestVersion: String,
        syncMode: String,
        generatedAt: Date = Date(),
        tracks: [WirelessSyncTrack],
        playlists: [WirelessSyncPlaylist],
        episodes: [WirelessSyncEpisode],
        podcastFeeds: [WirelessSyncPodcastFeed] = [],
        albumEditorial: [AlbumEditorialInfo] = [],
        artistEditorial: [ArtistEditorialInfo] = []
    ) {
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.serverName = serverName
        self.manifestVersion = manifestVersion
        self.syncMode = syncMode
        self.generatedAt = generatedAt
        self.tracks = tracks
        self.playlists = playlists
        self.episodes = episodes
        self.podcastFeeds = podcastFeeds
        self.albumEditorial = albumEditorial
        self.artistEditorial = artistEditorial
    }
}

public struct WirelessSyncPing: Codable, Sendable {
    public var app: String
    public var serverName: String
    public var deviceID: String
    public var deviceName: String
    public var manifestVersion: String
    public var syncMode: String
    public var trackCount: Int
    public var playlistCount: Int
    public var episodeCount: Int
    public var totalBytes: Int64
}

public struct WirelessSyncReport: Codable, Sendable {
    public var deviceID: String
    public var clientName: String?
    public var syncedTrackIDs: [String]
    public var syncedEpisodeIDs: [String]
    public var completedAt: Date?

    public init(
        deviceID: String,
        clientName: String? = nil,
        syncedTrackIDs: [String],
        syncedEpisodeIDs: [String],
        completedAt: Date? = Date()
    ) {
        self.deviceID = deviceID
        self.clientName = clientName
        self.syncedTrackIDs = syncedTrackIDs
        self.syncedEpisodeIDs = syncedEpisodeIDs
        self.completedAt = completedAt
    }
}

// MARK: - Remote Mac Library Search, Sync Selection & Lidarr Relay Payloads

public struct WirelessLibrarySearchAlbum: Identifiable, Codable, Hashable, Sendable {
    public var id: String { albumKey }
    public var albumKey: String
    public var title: String
    public var artist: String
    public var year: Int?
    public var trackCount: Int
    public var artworkHash: String?
    public var isSelectedForSync: Bool
}

public struct WirelessLibrarySearchTrack: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var artist: String
    public var album: String
    public var albumKey: String
    public var duration: TimeInterval
    public var format: String
    public var sampleRate: Int?
    public var bitDepth: Int?
    public var bitrate: Int?
    public var artworkHash: String?
    public var isSelectedForSync: Bool
}

public struct WirelessLibrarySearchResponse: Codable, Sendable {
    public var query: String
    public var albums: [WirelessLibrarySearchAlbum]
    public var tracks: [WirelessLibrarySearchTrack]
}

public struct WirelessRemoteSyncSelectRequest: Codable, Sendable {
    public var deviceID: String?
    public var trackID: String?
    public var albumKey: String?
    public var selected: Bool
}

public struct WirelessRemoteSyncSelectResponse: Codable, Sendable {
    public var ok: Bool
    public var manifestVersion: String
    public var message: String

    public init(ok: Bool, manifestVersion: String, message: String) {
        self.ok = ok
        self.manifestVersion = manifestVersion
        self.message = message
    }
}

public struct WirelessLidarrAlbumItem: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var foreignAlbumId: String
    public var title: String
    public var artistName: String
    public var releaseYear: Int?
    public var coverURL: String?
    public var monitored: Bool
    public var inLibrary: Bool

    public init(
        id: String,
        foreignAlbumId: String,
        title: String,
        artistName: String,
        releaseYear: Int? = nil,
        coverURL: String? = nil,
        monitored: Bool = false,
        inLibrary: Bool = false
    ) {
        self.id = id
        self.foreignAlbumId = foreignAlbumId
        self.title = title
        self.artistName = artistName
        self.releaseYear = releaseYear
        self.coverURL = coverURL
        self.monitored = monitored
        self.inLibrary = inLibrary
    }
}

public struct WirelessLidarrTrackItem: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var artistName: String
    public var albumTitle: String
    public var duration: TimeInterval
    public var coverURL: String?

    public init(
        id: String,
        title: String,
        artistName: String,
        albumTitle: String,
        duration: TimeInterval = 0,
        coverURL: String? = nil
    ) {
        self.id = id
        self.title = title
        self.artistName = artistName
        self.albumTitle = albumTitle
        self.duration = duration
        self.coverURL = coverURL
    }
}

public struct WirelessLidarrSearchResponse: Codable, Sendable {
    public var configured: Bool
    public var albums: [WirelessLidarrAlbumItem]
    public var tracks: [WirelessLidarrTrackItem]
    public var message: String?

    public init(configured: Bool, albums: [WirelessLidarrAlbumItem], tracks: [WirelessLidarrTrackItem], message: String? = nil) {
        self.configured = configured
        self.albums = albums
        self.tracks = tracks
        self.message = message
    }
}

public struct WirelessLidarrOrderRequest: Codable, Sendable {
    public var foreignAlbumId: String?
    public var title: String
    public var artistName: String
    public var albumTitle: String?
}

public struct WirelessLidarrOrderResponse: Codable, Sendable {
    public var ok: Bool
    public var message: String
    public var albumTitle: String?
    public var artistName: String?

    public init(ok: Bool, message: String, albumTitle: String? = nil, artistName: String? = nil) {
        self.ok = ok
        self.message = message
        self.albumTitle = albumTitle
        self.artistName = artistName
    }
}

public struct WirelessPodcastSubscribeRequest: Codable, Sendable {
    public var feedURL: String
    public var fallbackArtworkURL: String?
    public var selectForSync: Bool?

    public init(feedURL: String, fallbackArtworkURL: String? = nil, selectForSync: Bool? = true) {
        self.feedURL = feedURL
        self.fallbackArtworkURL = fallbackArtworkURL
        self.selectForSync = selectForSync
    }
}

public struct WirelessPodcastSubscribeResponse: Codable, Sendable {
    public var ok: Bool
    public var showID: String?
    public var title: String?
    public var manifestVersion: String
    public var message: String

    public init(ok: Bool, showID: String? = nil, title: String? = nil, manifestVersion: String = "", message: String) {
        self.ok = ok
        self.showID = showID
        self.title = title
        self.manifestVersion = manifestVersion
        self.message = message
    }
}

// MARK: - Apple TV / Full LAN Catalog & Mac Remote Control Payloads

public struct WirelessPartyStatus: Codable, Hashable, Sendable {
    public var isLive: Bool
    public var port: Int?
    public var lanIP: String?
    public var joinURL: String?
    public var playlistName: String

    public init(
        isLive: Bool = false,
        port: Int? = nil,
        lanIP: String? = nil,
        joinURL: String? = nil,
        playlistName: String = "Partymode"
    ) {
        self.isLive = isLive
        self.port = port
        self.lanIP = lanIP
        self.joinURL = joinURL
        self.playlistName = playlistName
    }
}

public struct WirelessFullCatalogPayload: Codable, Sendable {
    public var serverName: String
    public var catalogVersion: String
    public var generatedAt: Date
    public var tracks: [WirelessSyncTrack]
    public var playlists: [WirelessSyncPlaylist]
    public var podcastFeeds: [WirelessSyncPodcastFeed]
    public var episodes: [WirelessSyncEpisode]
    public var albumEditorial: [AlbumEditorialInfo]
    public var artistEditorial: [ArtistEditorialInfo]
    public var partyStatus: WirelessPartyStatus

    public init(
        serverName: String,
        catalogVersion: String,
        generatedAt: Date = Date(),
        tracks: [WirelessSyncTrack],
        playlists: [WirelessSyncPlaylist],
        podcastFeeds: [WirelessSyncPodcastFeed],
        episodes: [WirelessSyncEpisode],
        albumEditorial: [AlbumEditorialInfo] = [],
        artistEditorial: [ArtistEditorialInfo] = [],
        partyStatus: WirelessPartyStatus = WirelessPartyStatus()
    ) {
        self.serverName = serverName
        self.catalogVersion = catalogVersion
        self.generatedAt = generatedAt
        self.tracks = tracks
        self.playlists = playlists
        self.podcastFeeds = podcastFeeds
        self.episodes = episodes
        self.albumEditorial = albumEditorial
        self.artistEditorial = artistEditorial
        self.partyStatus = partyStatus
    }
}

public struct WirelessRemotePlaybackState: Codable, Sendable {
    public var serverName: String
    public var isPlaying: Bool
    public var currentTrack: WirelessSyncTrack?
    public var currentTime: TimeInterval
    public var duration: TimeInterval
    public var volume: Double
    public var isMuted: Bool
    public var isShuffled: Bool
    public var repeatMode: String
    public var currentIndex: Int
    public var queue: [WirelessSyncTrack]
    public var outputDeviceName: String
    public var partyStatus: WirelessPartyStatus

    public init(
        serverName: String,
        isPlaying: Bool = false,
        currentTrack: WirelessSyncTrack? = nil,
        currentTime: TimeInterval = 0,
        duration: TimeInterval = 0,
        volume: Double = 0.85,
        isMuted: Bool = false,
        isShuffled: Bool = false,
        repeatMode: String = "off",
        currentIndex: Int = 0,
        queue: [WirelessSyncTrack] = [],
        outputDeviceName: String = "System Default",
        partyStatus: WirelessPartyStatus = WirelessPartyStatus()
    ) {
        self.serverName = serverName
        self.isPlaying = isPlaying
        self.currentTrack = currentTrack
        self.currentTime = currentTime
        self.duration = duration
        self.volume = volume
        self.isMuted = isMuted
        self.isShuffled = isShuffled
        self.repeatMode = repeatMode
        self.currentIndex = currentIndex
        self.queue = queue
        self.outputDeviceName = outputDeviceName
        self.partyStatus = partyStatus
    }
}

public struct WirelessRemoteCommandRequest: Codable, Sendable {
    public var action: String
    public var seconds: Double?
    public var volume: Double?
    public var queueIndex: Int?
    public var trackID: String?
    public var albumKey: String?
    public var playlistID: String?

    public init(
        action: String,
        seconds: Double? = nil,
        volume: Double? = nil,
        queueIndex: Int? = nil,
        trackID: String? = nil,
        albumKey: String? = nil,
        playlistID: String? = nil
    ) {
        self.action = action
        self.seconds = seconds
        self.volume = volume
        self.queueIndex = queueIndex
        self.trackID = trackID
        self.albumKey = albumKey
        self.playlistID = playlistID
    }
}

public struct WirelessRemoteCommandResponse: Codable, Sendable {
    public var ok: Bool
    public var message: String?
    public var state: WirelessRemotePlaybackState?

    public init(ok: Bool, message: String? = nil, state: WirelessRemotePlaybackState? = nil) {
        self.ok = ok
        self.message = message
        self.state = state
    }
}

public struct WirelessPartyEnvelope: Codable, Sendable {
    public var status: WirelessPartyStatus
    public var state: PartyPlaylistState?

    public init(status: WirelessPartyStatus, state: PartyPlaylistState? = nil) {
        self.status = status
        self.state = state
    }
}

public struct WirelessLibraryCatalog: Sendable {
    public var serverName: String
    public var tracks: [Track]
    public var albums: [AlbumGroup]
    public var playlists: [Playlist]
    public var podcasts: [PodcastShow]
    public var albumEditorial: [AlbumEditorialInfo]
    public var artistEditorial: [ArtistEditorialInfo]
    public var trackFilePaths: [String: String]
    public var episodeFilePaths: [String: String]
    public var albumArtistByTrackID: [String: String]

    public init(
        tracks: [Track] = [],
        albums: [AlbumGroup] = [],
        playlists: [Playlist] = [],
        podcasts: [PodcastShow] = [],
        albumEditorial: [AlbumEditorialInfo] = [],
        artistEditorial: [ArtistEditorialInfo] = [],
        serverName: String = Host.current().localizedName ?? "My Echo Mac"
    ) {
        self.serverName = serverName
        self.tracks = tracks
        self.albums = albums
        self.playlists = playlists
        self.podcasts = podcasts
        self.albumEditorial = albumEditorial
        self.artistEditorial = artistEditorial

        var tPaths: [String: String] = [:]
        tPaths.reserveCapacity(tracks.count)
        for t in tracks where t.isAvailable {
            tPaths[t.id] = t.filePath
        }
        self.trackFilePaths = tPaths

        var ePaths: [String: String] = [:]
        for show in podcasts {
            for ep in show.episodes {
                if let p = ep.localFilePath, !p.isEmpty {
                    ePaths[ep.id] = p
                }
            }
        }
        self.episodeFilePaths = ePaths

        var aaMap: [String: String] = [:]
        for alb in albums {
            for t in alb.tracks {
                aaMap[t.id] = alb.artist
            }
        }
        self.albumArtistByTrackID = aaMap
    }

    public func buildFullCatalog(partyStatus: WirelessPartyStatus) -> WirelessFullCatalogPayload {
        let availableTracks = tracks.filter(\.isAvailable)
        let allowedIDs = Set(availableTracks.map(\.id))
        let wireTracks = availableTracks.map {
            WirelessSyncTrack(from: $0, resolvedAlbumArtist: albumArtistByTrackID[$0.id])
        }
        let wirePlaylists = playlists.map {
            WirelessSyncPlaylist(from: $0, allowedTrackIDs: allowedIDs)
        }
        let wireFeeds = podcasts
            .filter { !$0.isSingleEpisodesBucket || !$0.episodes.isEmpty }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            .map { show -> WirelessSyncPodcastFeed in
                var feed = WirelessSyncPodcastFeed(from: show, isSelectedForAutoSync: true)
                if show.isSingleEpisodesBucket {
                    feed.feedURL = ""
                }
                return feed
            }
        let wireEpisodes = podcasts
            .flatMap(\.episodes)
            .sorted { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }
            .prefix(500)
            .map { WirelessSyncEpisode(from: $0) }

        var normalizedAlbumEd: [AlbumEditorialInfo] = []
        var seenEdKeys = Set<String>()
        for info in albumEditorial where info.hasDisplayableContent {
            let key = info.albumKey.lowercased()
            if seenEdKeys.insert(key).inserted {
                var copy = info
                copy.albumKey = key
                normalizedAlbumEd.append(copy)
            }
        }

        let version = WirelessDeviceSnapshot.computeManifestVersion(
            syncMode: "catalog",
            tracks: wireTracks,
            playlists: wirePlaylists,
            episodes: Array(wireEpisodes),
            podcastFeeds: wireFeeds
        )

        return WirelessFullCatalogPayload(
            serverName: serverName,
            catalogVersion: version,
            generatedAt: Date(),
            tracks: wireTracks,
            playlists: wirePlaylists,
            podcastFeeds: wireFeeds,
            episodes: Array(wireEpisodes),
            albumEditorial: normalizedAlbumEd,
            artistEditorial: artistEditorial.filter(\.hasDisplayableContent),
            partyStatus: partyStatus
        )
    }

    public func search(query: String, syncedTrackIDs: Set<String>, limit: Int = 30) -> WirelessLibrarySearchResponse {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else {
            return WirelessLibrarySearchResponse(query: "", albums: [], tracks: [])
        }
        let matchingAlbums = albums
            .filter { $0.title.lowercased().contains(q) || $0.artist.lowercased().contains(q) }
            .prefix(limit)
            .map { alb in
                let allIn = !alb.tracks.isEmpty && alb.tracks.allSatisfy { syncedTrackIDs.contains($0.id) }
                return WirelessLibrarySearchAlbum(
                    albumKey: alb.id,
                    title: alb.title,
                    artist: alb.artist,
                    year: alb.year,
                    trackCount: alb.tracks.count,
                    artworkHash: alb.artworkHash,
                    isSelectedForSync: allIn
                )
            }
        let matchingTracks = tracks
            .filter {
                $0.title.lowercased().contains(q)
                    || $0.artist.lowercased().contains(q)
                    || $0.album.lowercased().contains(q)
            }
            .prefix(limit)
            .map { t in
                WirelessLibrarySearchTrack(
                    id: t.id,
                    title: t.title,
                    artist: t.artist,
                    album: t.effectiveAlbum,
                    albumKey: t.albumKey,
                    duration: t.duration,
                    format: t.format.rawValue,
                    sampleRate: t.sampleRate,
                    bitDepth: t.bitDepth,
                    bitrate: t.bitrate,
                    artworkHash: t.artworkHash,
                    isSelectedForSync: syncedTrackIDs.contains(t.id)
                )
            }
        return WirelessLibrarySearchResponse(
            query: query,
            albums: Array(matchingAlbums),
            tracks: Array(matchingTracks)
        )
    }
}

public struct WirelessDeviceSnapshot: Sendable {
    public var deviceID: UUID
    public var deviceName: String
    public var syncToken: String
    public var manifest: WirelessSyncManifest
    public var trackFilePaths: [String: String]
    public var episodeFilePaths: [String: String]
    public var totalBytes: Int64

    public init(
        device: DeviceProfile,
        allTracks: [Track],
        playlists: [Playlist],
        podcasts: [PodcastShow],
        serverName: String,
        precomputedAlbumByTrackID: [String: AlbumGroup]? = nil,
        albumEditorialByKey: [String: AlbumEditorialInfo] = [:],
        artistEditorialByKey: [String: ArtistEditorialInfo] = [:]
    ) {
        self.deviceID = device.id
        self.deviceName = device.name
        self.syncToken = device.wirelessSyncToken ?? "000000"

        let albumByTrackID = precomputedAlbumByTrackID ?? AlbumGroup.buildGroupsWithTrackLookup(from: allTracks).albumByTrackID
        let selectedTrackIDs = SyncPlanner.resolveSelectedTrackIDs(
            profile: device,
            allTracks: allTracks,
            playlists: playlists,
            precomputedAlbumByTrackID: albumByTrackID
        )
        let matchingTracks = allTracks
            .filter { selectedTrackIDs.contains($0.id) && device.supports($0.format) && $0.isAvailable }
            .sorted {
                ((albumByTrackID[$0.id]?.artist ?? $0.effectiveArtist).lowercased(), $0.effectiveAlbum.lowercased(), $0.discNumber ?? 1, $0.trackNumber ?? 999, $0.title.lowercased())
                < ((albumByTrackID[$1.id]?.artist ?? $1.effectiveArtist).lowercased(), $1.effectiveAlbum.lowercased(), $1.discNumber ?? 1, $1.trackNumber ?? 999, $1.title.lowercased())
            }

        let allowedIDs = Set(matchingTracks.map(\.id))
        let wireTracks = matchingTracks.map {
            WirelessSyncTrack(from: $0, resolvedAlbumArtist: albumByTrackID[$0.id]?.artist)
        }
        let wirePlaylists = playlists
            .filter { device.selectedPlaylistIDs.contains($0.id) }
            .map { WirelessSyncPlaylist(from: $0, allowedTrackIDs: allowedIDs) }

        let selectedEpisodeIDs = SyncPlanner.resolveSelectedEpisodeIDs(profile: device, podcasts: podcasts)
        let matchingEpisodes = podcasts
            .flatMap(\.episodes)
            .filter { ep in
                selectedEpisodeIDs.contains(ep.id) && ep.isDownloaded
            }
            .sorted { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }
        let wireEpisodes = matchingEpisodes.map { WirelessSyncEpisode(from: $0) }

        // Sync all subscribed Mac podcast feeds so iPhone/iPad can also pull new episodes independently over the internet.
        // Include the virtual "EnkeltEpisoder" bucket only when it has synced episodes (with empty feedURL so iOS doesn't RSS-poll it).
        let syncedShowIDs = Set(matchingEpisodes.map(\.showID))
        let wireFeeds = podcasts
            .filter { !$0.isSingleEpisodesBucket || syncedShowIDs.contains($0.id) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            .map { show -> WirelessSyncPodcastFeed in
                var feed = WirelessSyncPodcastFeed(
                    from: show,
                    isSelectedForAutoSync: device.selectedPodcastShowIDs.contains(show.id)
                )
                if show.isSingleEpisodesBucket {
                    feed.feedURL = ""
                }
                return feed
            }

        var trackPaths: [String: String] = [:]
        for t in matchingTracks { trackPaths[t.id] = t.filePath }
        var epPaths: [String: String] = [:]
        for e in matchingEpisodes {
            if let p = e.localFilePath { epPaths[e.id] = p }
        }
        self.trackFilePaths = trackPaths
        self.episodeFilePaths = epPaths
        self.totalBytes = matchingTracks.reduce(0) { $0 + $1.fileSize } + matchingEpisodes.reduce(0) { $0 + $1.fileSize }

        // Collect locally cached album & artist editorial info relevant to this device's synced tracks
        var seenAlbumEditorialKeys = Set<String>()
        var wireAlbumEditorial: [AlbumEditorialInfo] = []
        var syncedArtistKeys = Set<String>()
        for t in matchingTracks {
            let resolvedAlbum = albumByTrackID[t.id]
            let macAlbumKey = resolvedAlbum?.id ?? t.albumKey
            let iosAlbumKey = t.effectiveAlbum.lowercased()
            if let info = albumEditorialByKey[macAlbumKey] ?? albumEditorialByKey[iosAlbumKey],
               info.hasDisplayableContent,
               seenAlbumEditorialKeys.insert(iosAlbumKey).inserted {
                var copy = info
                copy.albumKey = iosAlbumKey
                wireAlbumEditorial.append(copy)
            }
            let artistCandidate = resolvedAlbum?.artist ?? t.effectiveArtist
            for name in ArtistNameParser.artistNames(artistCandidate) {
                syncedArtistKeys.insert(name.lowercased())
            }
            for name in ArtistNameParser.artistNames(t.artist) {
                syncedArtistKeys.insert(name.lowercased())
            }
        }
        wireAlbumEditorial.sort { $0.albumKey < $1.albumKey }

        let wireArtistEditorial: [ArtistEditorialInfo] = syncedArtistKeys
            .compactMap { artistEditorialByKey[$0] }
            .filter { $0.hasDisplayableContent }
            .sorted { $0.artistKey < $1.artistKey }

        let version = Self.computeManifestVersion(
            syncMode: device.syncMode.rawValue,
            tracks: wireTracks,
            playlists: wirePlaylists,
            episodes: wireEpisodes,
            podcastFeeds: wireFeeds,
            albumEditorial: wireAlbumEditorial,
            artistEditorial: wireArtistEditorial
        )

        self.manifest = WirelessSyncManifest(
            deviceID: device.id.uuidString,
            deviceName: device.name,
            serverName: serverName,
            manifestVersion: version,
            syncMode: device.syncMode.rawValue,
            generatedAt: Date(),
            tracks: wireTracks,
            playlists: wirePlaylists,
            episodes: wireEpisodes,
            podcastFeeds: wireFeeds,
            albumEditorial: wireAlbumEditorial,
            artistEditorial: wireArtistEditorial
        )
    }

    public static func computeManifestVersion(
        syncMode: String,
        tracks: [WirelessSyncTrack],
        playlists: [WirelessSyncPlaylist],
        episodes: [WirelessSyncEpisode],
        podcastFeeds: [WirelessSyncPodcastFeed] = [],
        albumEditorial: [AlbumEditorialInfo] = [],
        artistEditorial: [ArtistEditorialInfo] = []
    ) -> String {
        var parts: [String] = ["mode:\(syncMode)"]
        parts.append(contentsOf: tracks.map { "t:\($0.id):\($0.fileSize):\(Int($0.modifiedAt.timeIntervalSince1970))" })
        parts.append(contentsOf: playlists.map { "p:\($0.id):\($0.name):\($0.trackIDs.joined(separator: ","))" })
        parts.append(contentsOf: episodes.map { "e:\($0.id):\($0.fileSize)" })
        parts.append(contentsOf: podcastFeeds.map { "f:\($0.id):\($0.feedURL):\($0.episodesToKeep):\($0.isSelectedForAutoSync ? 1 : 0)" })
        parts.append(contentsOf: albumEditorial.map { "ae:\($0.albumKey):\(Int($0.fetchedAt.timeIntervalSince1970))" })
        parts.append(contentsOf: artistEditorial.map { "are:\($0.artistKey):\(Int($0.fetchedAt.timeIntervalSince1970))" })
        let joined = parts.joined(separator: "|")
        let digest = SHA256.hash(data: Data(joined.utf8))
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Built-in Bonjour + HTTP/1.1 Wi-Fi Sync Server

public final class WirelessSyncServer: @unchecked Sendable {
    public static let bonjourServiceType = "_myecho-sync._tcp"
    public static let defaultPort: UInt16 = 48721

    private let artworkCache: ArtworkCache
    private let queue = DispatchQueue(label: "com.myecho.wireless-sync-server", qos: .userInitiated)
    private var listener: NWListener?
    private var snapshotsByDeviceID: [UUID: WirelessDeviceSnapshot] = [:]
    private var primaryDeviceID: UUID?
    private var companionToken: String?
    private var libraryCatalog = WirelessLibraryCatalog()
    private let lock = NSLock()

    public private(set) var listeningPort: UInt16 = 0
    public private(set) var isRunning: Bool = false
    public var onStatusChanged: (@Sendable (Bool, UInt16, String?) -> Void)?
    public var onSyncReportReceived: (@Sendable (WirelessSyncReport) -> Void)?
    public var onRemoteSyncSelect: (@Sendable (UUID, WirelessRemoteSyncSelectRequest) async -> WirelessRemoteSyncSelectResponse)?
    public var onLidarrSearch: (@Sendable (String) async -> WirelessLidarrSearchResponse)?
    public var onLidarrOrder: (@Sendable (WirelessLidarrOrderRequest) async -> WirelessLidarrOrderResponse)?
    public var onPodcastSubscribe: (@Sendable (UUID, WirelessPodcastSubscribeRequest) async -> WirelessPodcastSubscribeResponse)?
    public var onFetchRemoteState: (@Sendable () async -> WirelessRemotePlaybackState)?
    public var onRemoteCommand: (@Sendable (WirelessRemoteCommandRequest) async -> WirelessRemoteCommandResponse)?
    public var onFetchPartyState: (@Sendable () async -> WirelessPartyEnvelope)?

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    public init(artworkCache: ArtworkCache) {
        self.artworkCache = artworkCache
    }

    public func setCompanionToken(_ token: String?) {
        lock.lock()
        companionToken = token?.trimmingCharacters(in: .whitespacesAndNewlines)
        lock.unlock()
    }

    public func updateLibraryCatalog(
        tracks: [Track],
        albums: [AlbumGroup],
        playlists: [Playlist] = [],
        podcasts: [PodcastShow] = [],
        albumEditorial: [AlbumEditorialInfo] = [],
        artistEditorial: [ArtistEditorialInfo] = [],
        serverName: String = Host.current().localizedName ?? "My Echo Mac"
    ) {
        lock.lock()
        libraryCatalog = WirelessLibraryCatalog(
            tracks: tracks,
            albums: albums,
            playlists: playlists,
            podcasts: podcasts,
            albumEditorial: albumEditorial,
            artistEditorial: artistEditorial,
            serverName: serverName
        )
        lock.unlock()
    }

    public func updateSnapshots(_ snapshots: [WirelessDeviceSnapshot]) {
        lock.lock()
        var map: [UUID: WirelessDeviceSnapshot] = [:]
        for s in snapshots { map[s.deviceID] = s }
        snapshotsByDeviceID = map
        primaryDeviceID = snapshots.first?.deviceID
        lock.unlock()
    }

    public func start(preferredPort: UInt16 = WirelessSyncServer.defaultPort) {
        queue.async { [weak self] in
            guard let self else { return }
            if self.listener != nil { return }

            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true

            do {
                let nwListener: NWListener
                if let port = NWEndpoint.Port(rawValue: preferredPort),
                   let bound = try? NWListener(using: params, on: port) {
                    nwListener = bound
                } else {
                    nwListener = try NWListener(using: params)
                }

                let hostName = Host.current().localizedName ?? "My Echo Mac"
                var txt = NWTXTRecord()
                if let lanIP = Self.localLANIPAddress() {
                    txt["lanIP"] = lanIP
                }
                txt["port"] = String(preferredPort)
                nwListener.service = NWListener.Service(name: hostName, type: Self.bonjourServiceType, txtRecord: txt)

                nwListener.stateUpdateHandler = { [weak self] state in
                    guard let self else { return }
                    switch state {
                    case .ready:
                        let port = nwListener.port?.rawValue ?? preferredPort
                        self.listeningPort = port
                        self.isRunning = true
                        self.onStatusChanged?(true, port, Self.localLANIPAddress())
                    case .failed(let err):
                        self.isRunning = false
                        self.listeningPort = 0
                        self.listener?.cancel()
                        self.listener = nil
                        self.onStatusChanged?(false, 0, err.localizedDescription)
                    case .cancelled:
                        self.isRunning = false
                        self.listeningPort = 0
                        self.onStatusChanged?(false, 0, nil)
                    default:
                        break
                    }
                }

                nwListener.newConnectionHandler = { [weak self] conn in
                    self?.handleConnection(conn)
                }

                self.listener = nwListener
                nwListener.start(queue: self.queue)
            } catch {
                self.isRunning = false
                self.onStatusChanged?(false, 0, error.localizedDescription)
            }
        }
    }

    public func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.listener?.cancel()
            self.listener = nil
            self.isRunning = false
            self.listeningPort = 0
            self.onStatusChanged?(false, 0, nil)
        }
    }

    public static func localLANIPAddress() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        var fallback: String?
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let current = ptr {
            let flags = Int32(current.pointee.ifa_flags)
            let isUp = (flags & (IFF_UP | IFF_RUNNING)) == (IFF_UP | IFF_RUNNING)
            let isLoopback = (flags & IFF_LOOPBACK) != 0
            if isUp && !isLoopback,
               let addr = current.pointee.ifa_addr,
               addr.pointee.sa_family == UInt8(AF_INET) {
                let name = String(cString: current.pointee.ifa_name)
                var hostBuf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(addr, socklen_t(addr.pointee.sa_len), &hostBuf, socklen_t(hostBuf.count), nil, 0, NI_NUMERICHOST) == 0 {
                    let ip = String(decoding: hostBuf.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
                    if name == "en0" || name == "en1" {
                        return ip
                    }
                    if fallback == nil && !ip.hasPrefix("169.254.") {
                        fallback = ip
                    }
                }
            }
            ptr = current.pointee.ifa_next
        }
        return fallback
    }

    // MARK: - HTTP Connection Handling

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveHTTPRequest(on: connection, buffer: Data())
    }

    private func receiveHTTPRequest(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if error != nil {
                connection.cancel()
                return
            }
            var accumulated = buffer
            if let data { accumulated.append(data) }

            let headerDelimiter = Data("\r\n\r\n".utf8)
            if let range = accumulated.range(of: headerDelimiter) {
                let headerData = accumulated[..<range.lowerBound]
                let bodyStart = range.upperBound
                let headerStr = String(data: headerData, encoding: .utf8) ?? ""
                let parsed = Self.parseHTTPHeaders(headerStr)
                let contentLength = Int(parsed.headers["content-length"] ?? "0") ?? 0
                let currentBodyCount = accumulated.count - bodyStart

                if currentBodyCount >= contentLength || isComplete {
                    let bodyData = accumulated.subdata(in: bodyStart..<min(accumulated.count, bodyStart + max(0, contentLength)))
                    self.routeRequest(method: parsed.method, rawTarget: parsed.target, headers: parsed.headers, body: bodyData, connection: connection)
                    return
                }
            }

            if isComplete || accumulated.count > 2_000_000 {
                self.sendJSONError(connection: connection, status: 400, message: "Malformed HTTP request")
            } else {
                self.receiveHTTPRequest(on: connection, buffer: accumulated)
            }
        }
    }

    private static func parseHTTPHeaders(_ raw: String) -> (method: String, target: String, headers: [String: String]) {
        let lines = raw.components(separatedBy: "\r\n")
        let reqParts = (lines.first ?? "").split(separator: " ")
        let method = reqParts.first.map(String.init) ?? "GET"
        let target = reqParts.count > 1 ? String(reqParts[1]) : "/"
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            if let colon = line.firstIndex(of: ":") {
                let key = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
                let val = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                headers[key] = val
            }
        }
        return (method, target, headers)
    }

    private func routeRequest(
        method: String,
        rawTarget: String,
        headers: [String: String],
        body: Data,
        connection: NWConnection
    ) {
        let comps = URLComponents(string: "http://localhost" + rawTarget)
        let path = comps?.path ?? "/"
        let queryItems = comps?.queryItems ?? []
        let queryMap = Dictionary(uniqueKeysWithValues: queryItems.compactMap { item -> (String, String)? in
            guard let v = item.value else { return nil }
            return (item.name, v)
        })

        let token = headers["x-echo-token"] ?? queryMap["token"] ?? ""
        let requestedDeviceUUID = queryMap["deviceId"].flatMap(UUID.init(uuidString:))

        guard let snapshot = resolveAuthorizedSnapshot(requestedDeviceID: requestedDeviceUUID, token: token, allowUnauthenticatedDiscovery: path == "/api/v1/info") else {
            sendJSONError(connection: connection, status: 401, message: "Invalid or missing pairing PIN (X-Echo-Token)")
            return
        }

        // 1. Ping / Manifest Version Check
        if method == "GET" && (path == "/api/v1/ping" || path == "/api/v1/info") {
            let ping = WirelessSyncPing(
                app: "My Echo",
                serverName: snapshot.manifest.serverName,
                deviceID: snapshot.manifest.deviceID,
                deviceName: snapshot.manifest.deviceName,
                manifestVersion: snapshot.manifest.manifestVersion,
                syncMode: snapshot.manifest.syncMode,
                trackCount: snapshot.manifest.tracks.count,
                playlistCount: snapshot.manifest.playlists.count,
                episodeCount: snapshot.manifest.episodes.count,
                totalBytes: snapshot.totalBytes
            )
            sendJSON(connection: connection, value: ping)
            return
        }

        // 2. Full Manifest
        if method == "GET" && path == "/api/v1/manifest" {
            sendJSON(connection: connection, value: snapshot.manifest)
            return
        }

        // 3. Track Audio Stream
        if method == "GET" && path.hasPrefix("/api/v1/track/") {
            let trackID = String(path.dropFirst("/api/v1/track/".count))
            guard let filePath = snapshot.trackFilePaths[trackID],
                  FileManager.default.fileExists(atPath: filePath) else {
                sendJSONError(connection: connection, status: 404, message: "Track not found")
                return
            }
            streamFile(atPath: filePath, rangeHeader: headers["range"], connection: connection)
            return
        }

        // 4. Podcast Episode Audio Stream
        if method == "GET" && path.hasPrefix("/api/v1/episode/") {
            let epID = String(path.dropFirst("/api/v1/episode/".count))
            guard let filePath = snapshot.episodeFilePaths[epID],
                  FileManager.default.fileExists(atPath: filePath) else {
                sendJSONError(connection: connection, status: 404, message: "Episode not found")
                return
            }
            streamFile(atPath: filePath, rangeHeader: headers["range"], connection: connection)
            return
        }

        // 5. Artwork JPEG
        if method == "GET" && path.hasPrefix("/api/v1/artwork/") {
            let hash = String(path.dropFirst("/api/v1/artwork/".count))
            guard let data = artworkCache.loadOriginalData(for: hash) ?? artworkCache.loadThumbnailData(for: hash) else {
                sendJSONError(connection: connection, status: 404, message: "Artwork not found")
                return
            }
            sendRawResponse(connection: connection, status: 200, statusText: "OK", contentType: "image/jpeg", data: data)
            return
        }

        // 6. Sync Report from iPhone (updates Mac's remembered syncedTrackIDs & lastSyncedAt)
        if method == "POST" && path == "/api/v1/sync-report" {
            if let report = try? decoder.decode(WirelessSyncReport.self, from: body) {
                onSyncReportReceived?(report)
                sendJSON(connection: connection, value: ["ok": true])
            } else {
                sendJSONError(connection: connection, status: 400, message: "Invalid sync report payload")
            }
            return
        }

        // 7. Search Mac's Full Library (so iPhone/iPad can discover & add any single track or album to sync)
        if method == "GET" && path == "/api/v1/library/search" {
            let query = queryMap["q"] ?? ""
            let limit = min(60, max(5, Int(queryMap["limit"] ?? "30") ?? 30))
            lock.lock()
            let catalog = libraryCatalog
            lock.unlock()
            let syncedIDs = Set(snapshot.manifest.tracks.map(\.id))
            let result = catalog.search(query: query, syncedTrackIDs: syncedIDs, limit: limit)
            sendJSON(connection: connection, value: result)
            return
        }

        // 8. Remote Sync Selection Toggle from iOS (add/remove a single track or album on this iPhone/iPad destination)
        if method == "POST" && path == "/api/v1/sync/select" {
            guard let req = try? decoder.decode(WirelessRemoteSyncSelectRequest.self, from: body),
                  let handler = onRemoteSyncSelect else {
                sendJSONError(connection: connection, status: 400, message: "Invalid sync selection payload")
                return
            }
            let targetDeviceID = snapshot.deviceID
            Task { [weak self] in
                let response = await handler(targetDeviceID, req)
                guard let server = self else { return }
                server.queue.async {
                    server.sendJSON(connection: connection, value: response, status: response.ok ? 200 : 400)
                }
            }
            return
        }

        // 9. Lidarr Search Relay via Mac
        if method == "GET" && path == "/api/v1/lidarr/search" {
            let query = queryMap["q"] ?? ""
            guard let handler = onLidarrSearch else {
                sendJSON(connection: connection, value: WirelessLidarrSearchResponse(configured: false, albums: [], tracks: [], message: "Lidarr relay unavailable"))
                return
            }
            Task { [weak self] in
                let response = await handler(query)
                guard let server = self else { return }
                server.queue.async {
                    server.sendJSON(connection: connection, value: response)
                }
            }
            return
        }

        // 10. Lidarr Order Relay via Mac
        if method == "POST" && path == "/api/v1/lidarr/order" {
            guard let req = try? decoder.decode(WirelessLidarrOrderRequest.self, from: body),
                  let handler = onLidarrOrder else {
                sendJSONError(connection: connection, status: 400, message: "Invalid Lidarr order payload")
                return
            }
            Task { [weak self] in
                let response = await handler(req)
                guard let server = self else { return }
                server.queue.async {
                    server.sendJSON(connection: connection, value: response, status: response.ok ? 200 : 400)
                }
            }
            return
        }

        // 11. Podcast Subscribe from iPhone/iPad (adds podcast subscription back to Mac & syncs)
        if method == "POST" && path == "/api/v1/podcasts/subscribe" {
            guard let req = try? decoder.decode(WirelessPodcastSubscribeRequest.self, from: body),
                  let handler = onPodcastSubscribe else {
                sendJSONError(connection: connection, status: 400, message: "Invalid podcast subscribe payload")
                return
            }
            let targetDeviceID = snapshot.deviceID
            Task { [weak self] in
                let response = await handler(targetDeviceID, req)
                guard let server = self else { return }
                server.queue.async {
                    server.sendJSON(connection: connection, value: response, status: response.ok ? 200 : 400)
                }
            }
            return
        }

        sendJSONError(connection: connection, status: 404, message: "Unknown endpoint: \(path)")
    }

    private func resolveAuthorizedSnapshot(requestedDeviceID: UUID?, token: String, allowUnauthenticatedDiscovery: Bool) -> WirelessDeviceSnapshot? {
        lock.lock()
        defer { lock.unlock() }

        if let id = requestedDeviceID, let snap = snapshotsByDeviceID[id] {
            if allowUnauthenticatedDiscovery || snap.syncToken == token {
                return snap
            }
            return nil
        }

        // Match by PIN if caller didn't specify deviceId
        if !token.isEmpty, let match = snapshotsByDeviceID.values.first(where: { $0.syncToken == token }) {
            return match
        }

        if allowUnauthenticatedDiscovery, let primary = primaryDeviceID, let snap = snapshotsByDeviceID[primary] {
            return snap
        }
        return nil
    }

    private func sendJSON<T: Encodable>(connection: NWConnection, value: T, status: Int = 200) {
        let data = (try? encoder.encode(value)) ?? Data("{}".utf8)
        sendRawResponse(connection: connection, status: status, statusText: status == 200 ? "OK" : "Error", contentType: "application/json", data: data)
    }

    private func sendJSONError(connection: NWConnection, status: Int, message: String) {
        let data = (try? JSONSerialization.data(withJSONObject: ["error": message])) ?? Data()
        sendRawResponse(connection: connection, status: status, statusText: "Error", contentType: "application/json", data: data)
    }

    private func sendRawResponse(connection: NWConnection, status: Int, statusText: String, contentType: String, data: Data) {
        var header = "HTTP/1.1 \(status) \(statusText)\r\n"
        header += "Content-Type: \(contentType)\r\n"
        header += "Content-Length: \(data.count)\r\n"
        header += "Connection: close\r\n\r\n"

        var payload = Data(header.utf8)
        payload.append(data)
        connection.send(content: payload, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func streamFile(atPath path: String, rangeHeader: String?, connection: NWConnection) {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let totalSize = (attrs[.size] as? NSNumber)?.int64Value,
              let handle = FileHandle(forReadingAtPath: path) else {
            sendJSONError(connection: connection, status: 404, message: "File unreadable")
            return
        }

        var startOffset: Int64 = 0
        var endOffset: Int64 = max(0, totalSize - 1)
        var isPartial = false

        if let rangeHeader, rangeHeader.lowercased().hasPrefix("bytes=") {
            let spec = rangeHeader.dropFirst("bytes=".count)
            let parts = spec.split(separator: "-", omittingEmptySubsequences: false)
            if parts.count == 2 {
                if let s = Int64(parts[0]) { startOffset = max(0, min(s, totalSize - 1)) }
                if let e = Int64(parts[1]), e >= startOffset { endOffset = min(e, totalSize - 1) }
                isPartial = true
            }
        }

        let lengthToSend = max(0, endOffset - startOffset + 1)
        let mime = Self.mimeType(forPath: path)
        var header = isPartial ? "HTTP/1.1 206 Partial Content\r\n" : "HTTP/1.1 200 OK\r\n"
        header += "Content-Type: \(mime)\r\n"
        header += "Accept-Ranges: bytes\r\n"
        header += "Content-Length: \(lengthToSend)\r\n"
        if isPartial {
            header += "Content-Range: bytes \(startOffset)-\(endOffset)/\(totalSize)\r\n"
        }
        header += "Connection: close\r\n\r\n"

        try? handle.seek(toOffset: UInt64(startOffset))

        connection.send(content: Data(header.utf8), completion: .contentProcessed { [weak self] err in
            if err != nil {
                try? handle.close()
                connection.cancel()
                return
            }
            self?.sendNextChunk(handle: handle, remaining: lengthToSend, connection: connection)
        })
    }

    private func sendNextChunk(handle: FileHandle, remaining: Int64, connection: NWConnection) {
        if remaining <= 0 {
            try? handle.close()
            connection.cancel()
            return
        }
        let chunkSize = Int(min(262_144, remaining))
        let chunk = (try? handle.read(upToCount: chunkSize)) ?? Data()
        if chunk.isEmpty {
            try? handle.close()
            connection.cancel()
            return
        }
        connection.send(content: chunk, completion: .contentProcessed { [weak self] err in
            if err != nil {
                try? handle.close()
                connection.cancel()
                return
            }
            self?.sendNextChunk(handle: handle, remaining: remaining - Int64(chunk.count), connection: connection)
        })
    }

    private static func mimeType(forPath path: String) -> String {
        switch URL(fileURLWithPath: path).pathExtension.lowercased() {
        case "flac": return "audio/flac"
        case "mp3": return "audio/mpeg"
        case "m4a", "mp4", "aac": return "audio/mp4"
        case "wav": return "audio/wav"
        case "aiff", "aif": return "audio/aiff"
        default: return "application/octet-stream"
        }
    }
}

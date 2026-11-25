import Foundation

public struct LidarrConfig: Codable, Hashable, Sendable {
    public var isEnabled: Bool
    public var baseURL: String
    public var apiKey: String
    public var rootFolderPath: String
    public var qualityProfileId: Int?
    public var metadataProfileId: Int?
    public var searchOnAdd: Bool
    public var autoReindexOnImport: Bool

    public init(
        isEnabled: Bool = false,
        baseURL: String = "",
        apiKey: String = "",
        rootFolderPath: String = "",
        qualityProfileId: Int? = nil,
        metadataProfileId: Int? = nil,
        searchOnAdd: Bool = true,
        autoReindexOnImport: Bool = false
    ) {
        self.isEnabled = isEnabled
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.rootFolderPath = rootFolderPath
        self.qualityProfileId = qualityProfileId
        self.metadataProfileId = metadataProfileId
        self.searchOnAdd = searchOnAdd
        self.autoReindexOnImport = autoReindexOnImport
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        self.baseURL = try c.decodeIfPresent(String.self, forKey: .baseURL) ?? ""
        self.apiKey = try c.decodeIfPresent(String.self, forKey: .apiKey) ?? ""
        self.rootFolderPath = try c.decodeIfPresent(String.self, forKey: .rootFolderPath) ?? ""
        self.qualityProfileId = try c.decodeIfPresent(Int.self, forKey: .qualityProfileId)
        self.metadataProfileId = try c.decodeIfPresent(Int.self, forKey: .metadataProfileId)
        self.searchOnAdd = try c.decodeIfPresent(Bool.self, forKey: .searchOnAdd) ?? true
        self.autoReindexOnImport = try c.decodeIfPresent(Bool.self, forKey: .autoReindexOnImport) ?? false
    }

    public var isConfigured: Bool {
        !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

public struct LidarrSystemStatus: Codable, Sendable, Hashable {
    public var appName: String
    public var version: String

    public init(appName: String = "Lidarr", version: String = "") {
        self.appName = appName
        self.version = version
    }
}

public struct LidarrRootFolder: Identifiable, Codable, Sendable, Hashable {
    public var id: Int
    public var path: String
    public var freeSpace: Int64?

    public init(id: Int, path: String, freeSpace: Int64? = nil) {
        self.id = id
        self.path = path
        self.freeSpace = freeSpace
    }
}

public struct LidarrQualityProfile: Identifiable, Codable, Sendable, Hashable {
    public var id: Int
    public var name: String

    public init(id: Int, name: String) {
        self.id = id
        self.name = name
    }
}

public struct LidarrMetadataProfile: Identifiable, Codable, Sendable, Hashable {
    public var id: Int
    public var name: String

    public init(id: Int, name: String) {
        self.id = id
        self.name = name
    }
}

public struct LidarrAlbumSearchResult: Identifiable, Hashable, Sendable {
    public var id: String { foreignAlbumId }
    public var lidarrID: Int?
    public var foreignAlbumId: String
    public var title: String
    public var artistName: String
    public var foreignArtistId: String?
    public var releaseYear: Int?
    public var releaseDate: String?
    public var albumType: String?
    public var coverURL: String?
    public var monitored: Bool
    public var trackFileCount: Int
    public var trackCount: Int
    public var percentOfTracks: Double
    /// Exact raw JSON object from Lidarr lookup so POST /api/v1/album preserves all required Lidarr fields
    public var rawJSONData: Data

    public init(
        lidarrID: Int? = nil,
        foreignAlbumId: String,
        title: String,
        artistName: String,
        foreignArtistId: String? = nil,
        releaseYear: Int? = nil,
        releaseDate: String? = nil,
        albumType: String? = nil,
        coverURL: String? = nil,
        monitored: Bool = false,
        trackFileCount: Int = 0,
        trackCount: Int = 0,
        percentOfTracks: Double = 0,
        rawJSONData: Data = Data()
    ) {
        self.lidarrID = lidarrID
        self.foreignAlbumId = foreignAlbumId
        self.title = title
        self.artistName = artistName
        self.foreignArtistId = foreignArtistId
        self.releaseYear = releaseYear
        self.releaseDate = releaseDate
        self.albumType = albumType
        self.coverURL = coverURL
        self.monitored = monitored
        self.trackFileCount = trackFileCount
        self.trackCount = trackCount
        self.percentOfTracks = percentOfTracks
        self.rawJSONData = rawJSONData
    }

    public var isInLidarr: Bool {
        (lidarrID ?? 0) > 0
    }

    public var isDownloaded: Bool {
        isInLidarr && (percentOfTracks >= 99.0 || (trackCount > 0 && trackFileCount >= trackCount))
    }
}

public struct LidarrArtistSearchResult: Identifiable, Hashable, Sendable {
    public var id: String { foreignArtistId }
    public var lidarrID: Int?
    public var foreignArtistId: String
    public var artistName: String
    public var overview: String?
    public var coverURL: String?
    public var monitored: Bool
    public var albumCount: Int
    public var trackFileCount: Int
    public var rawJSONData: Data

    public init(
        lidarrID: Int? = nil,
        foreignArtistId: String,
        artistName: String,
        overview: String? = nil,
        coverURL: String? = nil,
        monitored: Bool = false,
        albumCount: Int = 0,
        trackFileCount: Int = 0,
        rawJSONData: Data = Data()
    ) {
        self.lidarrID = lidarrID
        self.foreignArtistId = foreignArtistId
        self.artistName = artistName
        self.overview = overview
        self.coverURL = coverURL
        self.monitored = monitored
        self.albumCount = albumCount
        self.trackFileCount = trackFileCount
        self.rawJSONData = rawJSONData
    }

    public var isInLidarr: Bool {
        (lidarrID ?? 0) > 0
    }
}

/// Song-level search match (via Deezer catalog) so users can search a single track name and order its album in Lidarr
public struct LidarrTrackMatch: Identifiable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var artistName: String
    public var albumTitle: String
    public var duration: Int
    public var coverURL: String?
    public var popularity: Int?

    public init(
        id: String,
        title: String,
        artistName: String,
        albumTitle: String,
        duration: Int,
        coverURL: String? = nil,
        popularity: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.artistName = artistName
        self.albumTitle = albumTitle
        self.duration = duration
        self.coverURL = coverURL
        self.popularity = popularity
    }
}

public enum LidarrDownloadPhase: String, Codable, CaseIterable, Sendable, Hashable {
    case searching
    case queued
    case downloading
    case importing
    case paused
    case warning
    case failed
    case completed

    public var displayLabel: String {
        switch self {
        case .searching: return "SEARCHING"
        case .queued: return "QUEUED"
        case .downloading: return "DOWNLOADING"
        case .importing: return "IMPORTING"
        case .paused: return "PAUSED"
        case .warning: return "WARNING"
        case .failed: return "FAILED"
        case .completed: return "IMPORTED"
        }
    }

    public var isActive: Bool {
        switch self {
        case .searching, .queued, .downloading, .importing, .paused, .warning:
            return true
        case .failed, .completed:
            return false
        }
    }
}

public struct LidarrQueueItem: Identifiable, Hashable, Sendable {
    public var id: Int
    public var albumId: Int?
    public var artistId: Int?
    public var title: String
    public var artistName: String?
    public var albumTitle: String?
    public var status: String
    public var trackedDownloadStatus: String?
    public var trackedDownloadState: String?
    public var size: Double
    public var sizeleft: Double
    public var timeleft: String?
    public var downloadClient: String?
    public var protocolName: String?
    public var qualityName: String?
    public var statusMessages: [String]
    public var errorMessage: String?

    public init(
        id: Int,
        albumId: Int? = nil,
        artistId: Int? = nil,
        title: String,
        artistName: String? = nil,
        albumTitle: String? = nil,
        status: String = "queued",
        trackedDownloadStatus: String? = nil,
        trackedDownloadState: String? = nil,
        size: Double = 0,
        sizeleft: Double = 0,
        timeleft: String? = nil,
        downloadClient: String? = nil,
        protocolName: String? = nil,
        qualityName: String? = nil,
        statusMessages: [String] = [],
        errorMessage: String? = nil
    ) {
        self.id = id
        self.albumId = albumId
        self.artistId = artistId
        self.title = title
        self.artistName = artistName
        self.albumTitle = albumTitle
        self.status = status
        self.trackedDownloadStatus = trackedDownloadStatus
        self.trackedDownloadState = trackedDownloadState
        self.size = size
        self.sizeleft = sizeleft
        self.timeleft = timeleft
        self.downloadClient = downloadClient
        self.protocolName = protocolName
        self.qualityName = qualityName
        self.statusMessages = statusMessages
        self.errorMessage = errorMessage
    }

    public var progress: Double {
        guard size > 0 else { return 0 }
        return max(0, min(1, 1.0 - (sizeleft / size)))
    }

    public var downloadedBytes: Int64 {
        Int64(max(0, size - sizeleft))
    }

    public var totalBytes: Int64 {
        Int64(max(0, size))
    }

    public var phase: LidarrDownloadPhase {
        let st = status.lowercased()
        let tdStatus = (trackedDownloadStatus ?? "").lowercased()
        let tdState = (trackedDownloadState ?? "").lowercased()

        if st == "failed" || tdStatus == "error" || tdState == "failed" || tdState == "failedpending" {
            return .failed
        }
        if tdStatus == "warning" || st == "warning" || !statusMessages.isEmpty && (tdState == "importpending" || tdState == "importblocked") {
            return .warning
        }
        if tdState == "importing" || tdState == "importpending" || st == "completed" {
            return .importing
        }
        if st == "paused" {
            return .paused
        }
        if st == "downloading" || tdState == "downloading" {
            return .downloading
        }
        return .queued
    }

    public var primaryDiagnostic: String? {
        if let err = errorMessage, !err.isEmpty { return err }
        return statusMessages.first
    }
}

public struct LidarrHistoryItem: Identifiable, Hashable, Sendable {
    public var id: Int
    public var albumId: Int?
    public var albumTitle: String?
    public var artistName: String?
    public var sourceTitle: String
    public var eventType: String
    public var qualityName: String?
    public var date: Date

    public init(
        id: Int,
        albumId: Int? = nil,
        albumTitle: String? = nil,
        artistName: String? = nil,
        sourceTitle: String,
        eventType: String,
        qualityName: String? = nil,
        date: Date = Date()
    ) {
        self.id = id
        self.albumId = albumId
        self.albumTitle = albumTitle
        self.artistName = artistName
        self.sourceTitle = sourceTitle
        self.eventType = eventType
        self.qualityName = qualityName
        self.date = date
    }

    public var isImported: Bool {
        let e = eventType.lowercased()
        return e.contains("imported")
    }

    public var isFailed: Bool {
        let e = eventType.lowercased()
        return e.contains("failed")
    }
}

/// Persisted order tracked by My Echo from the moment the user orders it until Lidarr completes import
public struct LidarrTrackedOrder: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var albumTitle: String
    public var artistName: String
    public var lidarrAlbumID: Int?
    public var orderedAt: Date
    public var phase: LidarrDownloadPhase
    public var progress: Double
    public var statusDetail: String?
    public var qualityName: String?
    public var lastUpdatedAt: Date

    public init(
        id: String = UUID().uuidString,
        albumTitle: String,
        artistName: String,
        lidarrAlbumID: Int? = nil,
        orderedAt: Date = Date(),
        phase: LidarrDownloadPhase = .searching,
        progress: Double = 0,
        statusDetail: String? = nil,
        qualityName: String? = nil,
        lastUpdatedAt: Date = Date()
    ) {
        self.id = id
        self.albumTitle = albumTitle
        self.artistName = artistName
        self.lidarrAlbumID = lidarrAlbumID
        self.orderedAt = orderedAt
        self.phase = phase
        self.progress = progress
        self.statusDetail = statusDetail
        self.qualityName = qualityName
        self.lastUpdatedAt = lastUpdatedAt
    }
}

public struct LidarrOrderResult: Sendable {
    public var albumTitle: String
    public var artistName: String
    public var lidarrAlbumID: Int?
    public var alreadyExisted: Bool
    public var searchTriggered: Bool

    public init(albumTitle: String, artistName: String, lidarrAlbumID: Int?, alreadyExisted: Bool, searchTriggered: Bool) {
        self.albumTitle = albumTitle
        self.artistName = artistName
        self.lidarrAlbumID = lidarrAlbumID
        self.alreadyExisted = alreadyExisted
        self.searchTriggered = searchTriggered
    }
}

public struct LidarrConnectionBundle: Sendable {
    public var status: LidarrSystemStatus
    public var rootFolders: [LidarrRootFolder]
    public var qualityProfiles: [LidarrQualityProfile]
    public var metadataProfiles: [LidarrMetadataProfile]
}

public enum LidarrError: LocalizedError {
    case invalidURL
    case missingAPIKey
    case missingProfileSettings(String)
    case httpError(Int, String)
    case invalidResponse(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Lidarr server URL. Example: http://192.168.1.10:8686"
        case .missingAPIKey:
            return "Lidarr API key is missing. Find it in Lidarr → Settings → General → Security."
        case .missingProfileSettings(let detail):
            return detail
        case .httpError(let code, let msg):
            if code == 401 || code == 403 {
                return "Lidarr rejected the API key (HTTP \(code)). Verify your API key in Settings."
            }
            return "Lidarr error (HTTP \(code)): \(msg)"
        case .invalidResponse(let msg):
            return "Unexpected Lidarr response: \(msg)"
        }
    }
}

public actor LidarrClient {
    private let session: URLSession

    public init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 18
        cfg.timeoutIntervalForResource = 35
        cfg.httpAdditionalHeaders = [
            "User-Agent": "MyEcho/1.3 (macOS Hi-Fi Studio)"
        ]
        self.session = URLSession(configuration: cfg)
    }

    // MARK: - URL & Payload Helpers (Public for Unit Tests)

    public static func normalizeBaseURL(_ raw: String) -> URL? {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if !trimmed.lowercased().hasPrefix("http://") && !trimmed.lowercased().hasPrefix("https://") {
            trimmed = "http://" + trimmed
        }
        while trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        if trimmed.lowercased().hasSuffix("/api/v1") {
            trimmed = String(trimmed.dropLast("/api/v1".count))
        }
        return URL(string: trimmed)
    }

    public static func buildAddAlbumPayload(fromLookupData data: Data, config: LidarrConfig) throws -> Data {
        guard var obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LidarrError.invalidResponse("Album lookup JSON was not an object")
        }
        let rootPath = config.rootFolderPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rootPath.isEmpty else {
            throw LidarrError.missingProfileSettings("Select a Lidarr Root Folder in Settings first.")
        }
        guard let qID = config.qualityProfileId else {
            throw LidarrError.missingProfileSettings("Select a Lidarr Quality Profile in Settings first.")
        }
        guard let mID = config.metadataProfileId else {
            throw LidarrError.missingProfileSettings("Select a Lidarr Metadata Profile in Settings first.")
        }

        obj["monitored"] = true
        obj["addOptions"] = [
            "searchForNewAlbum": config.searchOnAdd
        ]

        // Ensure nested artist carries required profile & rootFolderPath without auto-downloading other albums
        var artist = (obj["artist"] as? [String: Any]) ?? [:]
        artist["qualityProfileId"] = qID
        artist["metadataProfileId"] = mID
        artist["rootFolderPath"] = rootPath
        artist["monitored"] = true
        artist["addOptions"] = [
            "monitor": "none",
            "searchForMissingAlbums": false
        ]
        obj["artist"] = artist

        return try JSONSerialization.data(withJSONObject: obj, options: [])
    }

    public static func buildAddArtistPayload(
        fromLookupData data: Data,
        config: LidarrConfig,
        monitorMode: String = "all",
        searchMissing: Bool = true
    ) throws -> Data {
        guard var obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LidarrError.invalidResponse("Artist lookup JSON was not an object")
        }
        let rootPath = config.rootFolderPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rootPath.isEmpty else {
            throw LidarrError.missingProfileSettings("Select a Lidarr Root Folder in Settings first.")
        }
        guard let qID = config.qualityProfileId else {
            throw LidarrError.missingProfileSettings("Select a Lidarr Quality Profile in Settings first.")
        }
        guard let mID = config.metadataProfileId else {
            throw LidarrError.missingProfileSettings("Select a Lidarr Metadata Profile in Settings first.")
        }

        obj["qualityProfileId"] = qID
        obj["metadataProfileId"] = mID
        obj["rootFolderPath"] = rootPath
        obj["monitored"] = true
        obj["addOptions"] = [
            "monitor": monitorMode,
            "searchForMissingAlbums": searchMissing
        ]
        return try JSONSerialization.data(withJSONObject: obj, options: [])
    }

    // MARK: - Connection & Metadata Lookups

    public func testConnection(config: LidarrConfig) async throws -> LidarrConnectionBundle {
        let statusData = try await request(path: "/api/v1/system/status", config: config)
        let status = try JSONDecoder().decode(LidarrSystemStatus.self, from: statusData)

        async let rfData = request(path: "/api/v1/rootfolder", config: config)
        async let qpData = request(path: "/api/v1/qualityprofile", config: config)
        async let mpData = request(path: "/api/v1/metadataprofile", config: config)

        let decoder = JSONDecoder()
        let rootFolders = (try? decoder.decode([LidarrRootFolder].self, from: await rfData)) ?? []
        let qualityProfiles = (try? decoder.decode([LidarrQualityProfile].self, from: await qpData)) ?? []
        let metadataProfiles = (try? decoder.decode([LidarrMetadataProfile].self, from: await mpData)) ?? []

        return LidarrConnectionBundle(
            status: status,
            rootFolders: rootFolders,
            qualityProfiles: qualityProfiles,
            metadataProfiles: metadataProfiles
        )
    }

    // MARK: - Search (Albums, Artists, Tracks)

    public func searchAlbums(term: String, config: LidarrConfig) async throws -> [LidarrAlbumSearchResult] {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let data = try await request(
            path: "/api/v1/album/lookup",
            queryItems: [URLQueryItem(name: "term", value: trimmed)],
            config: config
        )
        return parseAlbumLookupArray(data: data, baseURL: Self.normalizeBaseURL(config.baseURL))
    }

    public func searchArtists(term: String, config: LidarrConfig) async throws -> [LidarrArtistSearchResult] {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let data = try await request(
            path: "/api/v1/artist/lookup",
            queryItems: [URLQueryItem(name: "term", value: trimmed)],
            config: config
        )
        return parseArtistLookupArray(data: data, baseURL: Self.normalizeBaseURL(config.baseURL))
    }

    /// Resolves song/track queries to their album + artist via Deezer public catalog,
    /// allowing users to search by track title and immediately order the album in Lidarr.
    public func searchTracksForAlbumOrder(term: String) async throws -> [LidarrTrackMatch] {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.deezer.com/search?q=\(encoded)&limit=20") else {
            return []
        }
        let (data, _) = try await session.data(from: url)

        struct DZResp: Decodable {
            let data: [DZTrack]
        }
        struct DZTrack: Decodable {
            let id: Int
            let title: String
            let duration: Int
            let rank: Int?
            let artist: DZArtist
            let album: DZAlbum
        }
        struct DZArtist: Decodable { let name: String }
        struct DZAlbum: Decodable {
            let title: String
            let cover_medium: String?
            let cover_big: String?
        }

        let decoded = try JSONDecoder().decode(DZResp.self, from: data)
        return decoded.data.map { item in
            LidarrTrackMatch(
                id: String(item.id),
                title: item.title,
                artistName: item.artist.name,
                albumTitle: item.album.title,
                duration: item.duration,
                coverURL: item.album.cover_big ?? item.album.cover_medium,
                popularity: item.rank.map { OnlinePopularityService.scoreFromDeezerRank($0) }
            )
        }
    }

    // MARK: - Ordering Downloads

    public func orderAlbum(_ album: LidarrAlbumSearchResult, config: LidarrConfig) async throws -> LidarrOrderResult {
        // 1. If already tracked in Lidarr, monitor & trigger AlbumSearch directly
        if let existingID = album.lidarrID, existingID > 0 {
            try await monitorAlbum(albumID: existingID, monitored: true, config: config)
            try await triggerAlbumSearch(albumID: existingID, config: config)
            return LidarrOrderResult(
                albumTitle: album.title,
                artistName: album.artistName,
                lidarrAlbumID: existingID,
                alreadyExisted: true,
                searchTriggered: true
            )
        }

        // 2. Check if foreignAlbumId is already in Lidarr (e.g. added since lookup)
        if let existingData = try? await request(
            path: "/api/v1/album",
            queryItems: [URLQueryItem(name: "foreignAlbumId", value: album.foreignAlbumId)],
            config: config
        ),
           let existingArr = try? JSONSerialization.jsonObject(with: existingData) as? [[String: Any]],
           let first = existingArr.first,
           let existingID = first["id"] as? Int, existingID > 0 {
            try await monitorAlbum(albumID: existingID, monitored: true, config: config)
            try await triggerAlbumSearch(albumID: existingID, config: config)
            return LidarrOrderResult(
                albumTitle: album.title,
                artistName: album.artistName,
                lidarrAlbumID: existingID,
                alreadyExisted: true,
                searchTriggered: true
            )
        }

        // 3. Add brand-new album via POST /api/v1/album
        let payload = try Self.buildAddAlbumPayload(fromLookupData: album.rawJSONData, config: config)
        let responseData = try await request(path: "/api/v1/album", method: "POST", body: payload, config: config)
        let createdObj = (try? JSONSerialization.jsonObject(with: responseData) as? [String: Any])
        let createdID = createdObj?["id"] as? Int

        return LidarrOrderResult(
            albumTitle: album.title,
            artistName: album.artistName,
            lidarrAlbumID: createdID,
            alreadyExisted: false,
            searchTriggered: config.searchOnAdd
        )
    }

    public func orderArtist(
        _ artist: LidarrArtistSearchResult,
        config: LidarrConfig,
        monitorMode: String = "all",
        searchMissing: Bool = true
    ) async throws -> Int? {
        if let existingID = artist.lidarrID, existingID > 0 {
            if searchMissing {
                let cmd = try JSONSerialization.data(withJSONObject: [
                    "name": "ArtistSearch",
                    "artistId": existingID
                ])
                _ = try await request(path: "/api/v1/command", method: "POST", body: cmd, config: config)
            }
            return existingID
        }

        let payload = try Self.buildAddArtistPayload(
            fromLookupData: artist.rawJSONData,
            config: config,
            monitorMode: monitorMode,
            searchMissing: searchMissing
        )
        let responseData = try await request(path: "/api/v1/artist", method: "POST", body: payload, config: config)
        let createdObj = (try? JSONSerialization.jsonObject(with: responseData) as? [String: Any])
        return createdObj?["id"] as? Int
    }

    public func monitorAlbum(albumID: Int, monitored: Bool, config: LidarrConfig) async throws {
        let body = try JSONSerialization.data(withJSONObject: [
            "albumIds": [albumID],
            "monitored": monitored
        ])
        _ = try await request(path: "/api/v1/album/monitor", method: "PUT", body: body, config: config)
    }

    public func triggerAlbumSearch(albumID: Int, config: LidarrConfig) async throws {
        let body = try JSONSerialization.data(withJSONObject: [
            "name": "AlbumSearch",
            "albumIds": [albumID]
        ])
        _ = try await request(path: "/api/v1/command", method: "POST", body: body, config: config)
    }

    // MARK: - Queue, History & Wanted Missing

    public func fetchQueue(config: LidarrConfig) async throws -> [LidarrQueueItem] {
        let data = try await request(
            path: "/api/v1/queue",
            queryItems: [
                URLQueryItem(name: "pageSize", value: "60"),
                URLQueryItem(name: "includeUnknownArtistItems", value: "true"),
                URLQueryItem(name: "includeArtist", value: "true"),
                URLQueryItem(name: "includeAlbum", value: "true")
            ],
            config: config
        )
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let records = root["records"] as? [[String: Any]] else {
            return []
        }

        return records.compactMap { rec in
            guard let id = rec["id"] as? Int else { return nil }
            let artistObj = rec["artist"] as? [String: Any]
            let albumObj = rec["album"] as? [String: Any]
            let qualityWrap = rec["quality"] as? [String: Any]
            let qualityInner = qualityWrap?["quality"] as? [String: Any]

            var messages: [String] = []
            if let smArray = rec["statusMessages"] as? [[String: Any]] {
                for entry in smArray {
                    if let list = entry["messages"] as? [String] {
                        messages.append(contentsOf: list.filter { !$0.isEmpty })
                    } else if let title = entry["title"] as? String, !title.isEmpty {
                        messages.append(title)
                    }
                }
            }

            return LidarrQueueItem(
                id: id,
                albumId: (rec["albumId"] as? Int) ?? (albumObj?["id"] as? Int),
                artistId: (rec["artistId"] as? Int) ?? (artistObj?["id"] as? Int),
                title: (rec["title"] as? String) ?? (albumObj?["title"] as? String) ?? "Download #\(id)",
                artistName: artistObj?["artistName"] as? String,
                albumTitle: albumObj?["title"] as? String,
                status: (rec["status"] as? String) ?? "queued",
                trackedDownloadStatus: rec["trackedDownloadStatus"] as? String,
                trackedDownloadState: rec["trackedDownloadState"] as? String,
                size: (rec["size"] as? NSNumber)?.doubleValue ?? 0,
                sizeleft: (rec["sizeleft"] as? NSNumber)?.doubleValue ?? 0,
                timeleft: rec["timeleft"] as? String,
                downloadClient: rec["downloadClient"] as? String,
                protocolName: rec["protocol"] as? String,
                qualityName: qualityInner?["name"] as? String,
                statusMessages: messages,
                errorMessage: rec["errorMessage"] as? String
            )
        }
    }

    public func fetchRecentHistory(config: LidarrConfig, pageSize: Int = 30) async throws -> [LidarrHistoryItem] {
        let data = try await request(
            path: "/api/v1/history",
            queryItems: [
                URLQueryItem(name: "pageSize", value: String(pageSize)),
                URLQueryItem(name: "sortKey", value: "date"),
                URLQueryItem(name: "sortDirection", value: "descending"),
                URLQueryItem(name: "includeArtist", value: "true"),
                URLQueryItem(name: "includeAlbum", value: "true")
            ],
            config: config
        )
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let records = root["records"] as? [[String: Any]] else {
            return []
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoBasic = ISO8601DateFormatter()

        return records.compactMap { rec in
            guard let id = rec["id"] as? Int else { return nil }
            let artistObj = rec["artist"] as? [String: Any]
            let albumObj = rec["album"] as? [String: Any]
            let qualityWrap = rec["quality"] as? [String: Any]
            let qualityInner = qualityWrap?["quality"] as? [String: Any]
            let dateStr = (rec["date"] as? String) ?? ""
            let parsedDate = iso.date(from: dateStr) ?? isoBasic.date(from: dateStr) ?? Date()

            return LidarrHistoryItem(
                id: id,
                albumId: (rec["albumId"] as? Int) ?? (albumObj?["id"] as? Int),
                albumTitle: albumObj?["title"] as? String,
                artistName: artistObj?["artistName"] as? String,
                sourceTitle: (rec["sourceTitle"] as? String) ?? (albumObj?["title"] as? String) ?? "Event #\(id)",
                eventType: (rec["eventType"] as? String) ?? "unknown",
                qualityName: qualityInner?["name"] as? String,
                date: parsedDate
            )
        }
    }

    /// Pure state reconciliation: updates My Echo's tracked orders based on live Lidarr queue & history snapshots.
    /// Returns updated orders and the list of orders that just transitioned to `.completed`.
    public static func reconcileTrackedOrders(
        _ orders: [LidarrTrackedOrder],
        queue: [LidarrQueueItem],
        history: [LidarrHistoryItem],
        now: Date = Date()
    ) -> (updated: [LidarrTrackedOrder], newlyCompleted: [LidarrTrackedOrder]) {
        var result: [LidarrTrackedOrder] = []
        var newlyCompleted: [LidarrTrackedOrder] = []

        for var order in orders {
            let wasCompleted = (order.phase == .completed)
            let normAlbum = OnlinePopularityService.normalizeTitleForMatching(order.albumTitle)
            let normArtist = OnlinePopularityService.normalizeTitleForMatching(order.artistName)

            // 1. Match against live Lidarr queue
            let queueMatch = queue.first(where: { q in
                if let oID = order.lidarrAlbumID, let qID = q.albumId, oID == qID { return true }
                let qAlbum = OnlinePopularityService.normalizeTitleForMatching(q.albumTitle ?? q.title)
                let qArtist = OnlinePopularityService.normalizeTitleForMatching(q.artistName ?? "")
                let albumOk = !normAlbum.isEmpty && (qAlbum == normAlbum || qAlbum.contains(normAlbum) || normAlbum.contains(qAlbum))
                let artistOk = normArtist.isEmpty || qArtist.isEmpty || qArtist.contains(normArtist) || normArtist.contains(qArtist)
                return albumOk && artistOk
            })

            if let q = queueMatch {
                order.phase = q.phase
                order.progress = q.progress
                order.qualityName = q.qualityName ?? order.qualityName
                order.statusDetail = q.primaryDiagnostic ?? q.timeleft.map { "ETA \($0)" } ?? q.trackedDownloadState
                order.lastUpdatedAt = now
                if order.lidarrAlbumID == nil { order.lidarrAlbumID = q.albumId }
                result.append(order)
                continue
            }

            // 2. Not in active queue: check recent history for import or failure after order time
            let histMatch = history.first(where: { h in
                guard h.date >= order.orderedAt.addingTimeInterval(-60) else { return false }
                if let oID = order.lidarrAlbumID, let hID = h.albumId, oID == hID { return true }
                let hAlbum = OnlinePopularityService.normalizeTitleForMatching(h.albumTitle ?? h.sourceTitle)
                let hArtist = OnlinePopularityService.normalizeTitleForMatching(h.artistName ?? "")
                let albumOk = !normAlbum.isEmpty && (hAlbum == normAlbum || hAlbum.contains(normAlbum) || normAlbum.contains(hAlbum))
                let artistOk = normArtist.isEmpty || hArtist.isEmpty || hArtist.contains(normArtist) || normArtist.contains(hArtist)
                return albumOk && artistOk
            })

            if let h = histMatch {
                if h.isImported {
                    order.phase = .completed
                    order.progress = 1.0
                    order.qualityName = h.qualityName ?? order.qualityName
                    order.statusDetail = "Imported by Lidarr"
                    order.lastUpdatedAt = now
                    if !wasCompleted { newlyCompleted.append(order) }
                } else if h.isFailed {
                    order.phase = .failed
                    order.statusDetail = "Download failed in Lidarr"
                    order.lastUpdatedAt = now
                } else if h.eventType.lowercased().contains("grabbed") && order.phase == .searching {
                    order.phase = .queued
                    order.statusDetail = "Grabbed from indexer"
                    order.lastUpdatedAt = now
                }
            }

            result.append(order)
        }

        return (result, newlyCompleted)
    }

    public func removeQueueItem(id: Int, config: LidarrConfig, removeFromClient: Bool = false) async throws {
        _ = try await request(
            path: "/api/v1/queue/\(id)",
            method: "DELETE",
            queryItems: [
                URLQueryItem(name: "removeFromClient", value: removeFromClient ? "true" : "false"),
                URLQueryItem(name: "blocklist", value: "false")
            ],
            config: config
        )
    }

    public func fetchWantedMissing(config: LidarrConfig) async throws -> [LidarrAlbumSearchResult] {
        let data = try await request(
            path: "/api/v1/wanted/missing",
            queryItems: [
                URLQueryItem(name: "pageSize", value: "25"),
                URLQueryItem(name: "sortKey", value: "releaseDate"),
                URLQueryItem(name: "sortDirection", value: "descending"),
                URLQueryItem(name: "includeArtist", value: "true")
            ],
            config: config
        )
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let records = root["records"] as? [[String: Any]] else {
            return []
        }
        let baseURL = Self.normalizeBaseURL(config.baseURL)
        return records.compactMap { parseAlbumDict($0, baseURL: baseURL) }
    }

    // MARK: - HTTP Core & Parsing

    private func request(
        path: String,
        method: String = "GET",
        queryItems: [URLQueryItem] = [],
        body: Data? = nil,
        config: LidarrConfig
    ) async throws -> Data {
        guard let base = Self.normalizeBaseURL(config.baseURL) else {
            throw LidarrError.invalidURL
        }
        let apiKey = config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            throw LidarrError.missingAPIKey
        }

        var comps = URLComponents(url: base.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))), resolvingAgainstBaseURL: false)
        if !queryItems.isEmpty {
            comps?.queryItems = queryItems
        }
        guard let url = comps?.url else {
            throw LidarrError.invalidURL
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw LidarrError.invalidResponse("Non-HTTP response")
        }
        guard (200...299).contains(http.statusCode) else {
            let snippet = extractErrorMessage(from: data) ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw LidarrError.httpError(http.statusCode, snippet)
        }
        return data
    }

    private func extractErrorMessage(from data: Data) -> String? {
        if let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
           let msg = arr.first?["errorMessage"] as? String {
            return msg
        }
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let msg = (obj["message"] as? String) ?? (obj["errorMessage"] as? String) {
            return msg
        }
        let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let text, !text.isEmpty {
            return String(text.prefix(180))
        }
        return nil
    }

    private func parseAlbumLookupArray(data: Data, baseURL: URL?) -> [LidarrAlbumSearchResult] {
        guard let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return arr.compactMap { parseAlbumDict($0, baseURL: baseURL) }
    }

    private func parseAlbumDict(_ dict: [String: Any], baseURL: URL?) -> LidarrAlbumSearchResult? {
        guard let foreignID = dict["foreignAlbumId"] as? String, !foreignID.isEmpty,
              let title = dict["title"] as? String else {
            return nil
        }
        let lidarrID = (dict["id"] as? Int).flatMap { $0 > 0 ? $0 : nil }
        let artistObj = dict["artist"] as? [String: Any]
        let artistName = (artistObj?["artistName"] as? String) ?? "Unknown Artist"
        let foreignArtistId = artistObj?["foreignArtistId"] as? String
        let releaseDate = dict["releaseDate"] as? String
        let releaseYear = releaseDate.flatMap { str -> Int? in
            guard str.count >= 4 else { return nil }
            return Int(str.prefix(4))
        }
        let albumType = dict["albumType"] as? String
        let monitored = (dict["monitored"] as? Bool) ?? false
        let stats = dict["statistics"] as? [String: Any]
        let trackFileCount = (stats?["trackFileCount"] as? Int) ?? 0
        let trackCount = (stats?["trackCount"] as? Int) ?? 0
        let percent = (stats?["percentOfTracks"] as? NSNumber)?.doubleValue ?? 0
        let coverURL = resolveImageURL(from: dict["images"] as? [[String: Any]], baseURL: baseURL)
        let rawData = (try? JSONSerialization.data(withJSONObject: dict, options: [])) ?? Data()

        return LidarrAlbumSearchResult(
            lidarrID: lidarrID,
            foreignAlbumId: foreignID,
            title: title,
            artistName: artistName,
            foreignArtistId: foreignArtistId,
            releaseYear: releaseYear,
            releaseDate: releaseDate,
            albumType: albumType,
            coverURL: coverURL,
            monitored: monitored,
            trackFileCount: trackFileCount,
            trackCount: trackCount,
            percentOfTracks: percent,
            rawJSONData: rawData
        )
    }

    private func parseArtistLookupArray(data: Data, baseURL: URL?) -> [LidarrArtistSearchResult] {
        guard let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return arr.compactMap { dict in
            guard let foreignID = dict["foreignArtistId"] as? String, !foreignID.isEmpty,
                  let name = dict["artistName"] as? String else {
                return nil
            }
            let lidarrID = (dict["id"] as? Int).flatMap { $0 > 0 ? $0 : nil }
            let overview = dict["overview"] as? String
            let monitored = (dict["monitored"] as? Bool) ?? false
            let stats = dict["statistics"] as? [String: Any]
            let albumCount = (stats?["albumCount"] as? Int) ?? 0
            let trackFileCount = (stats?["trackFileCount"] as? Int) ?? 0
            let coverURL = resolveImageURL(from: dict["images"] as? [[String: Any]], baseURL: baseURL)
            let rawData = (try? JSONSerialization.data(withJSONObject: dict, options: [])) ?? Data()

            return LidarrArtistSearchResult(
                lidarrID: lidarrID,
                foreignArtistId: foreignID,
                artistName: name,
                overview: overview,
                coverURL: coverURL,
                monitored: monitored,
                albumCount: albumCount,
                trackFileCount: trackFileCount,
                rawJSONData: rawData
            )
        }
    }

    private func resolveImageURL(from images: [[String: Any]]?, baseURL: URL?) -> String? {
        guard let images, !images.isEmpty else { return nil }
        let preferred = images.first(where: { ($0["coverType"] as? String)?.lowercased() == "cover" })
            ?? images.first(where: { ($0["coverType"] as? String)?.lowercased() == "poster" })
            ?? images.first
        if let remote = preferred?["remoteUrl"] as? String, !remote.isEmpty {
            return remote
        }
        if let local = preferred?["url"] as? String, !local.isEmpty {
            if local.hasPrefix("http://") || local.hasPrefix("https://") { return local }
            if let baseURL {
                return baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    + "/" + local.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            }
        }
        return nil
    }
}

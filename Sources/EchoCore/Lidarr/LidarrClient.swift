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
    // Note: Albums / Tracks / Artists select the OUTPUT type, not the input field:
    // - searchAlbums accepts an album title OR an artist name (returning matching albums + artist discography)
    // - searchTracksForAlbumOrder accepts a track title, artist name, OR album title (returning matching tracks)

    public func searchAlbums(term: String, config: LidarrConfig) async throws -> [LidarrAlbumSearchResult] {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        // 1. Query Lidarr album lookup & artist lookup in parallel
        async let directAlbumsTask = lookupAlbumsRaw(term: trimmed, config: config)
        async let artistsTask = searchArtistsSafe(term: trimmed, config: config)

        let directAlbums = try await directAlbumsTask
        let artists = await artistsTask

        // 2. If the query matches one or more artists, expand their discographies into album results
        let strongArtists = Self.selectMatchingArtists(from: artists, query: trimmed)
        var artistDiscographyAlbums: [LidarrAlbumSearchResult] = []
        let matchedArtistNames = strongArtists.map(\.artistName)

        if !strongArtists.isEmpty {
            for artist in strongArtists.prefix(2) {
                // Path A: Artist is already in Lidarr -> fetch all albums directly from Lidarr DB
                if let artistID = artist.lidarrID, artistID > 0 {
                    if let localAlbums = try? await fetchAlbumsForLidarrArtist(artistID: artistID, artistName: artist.artistName, config: config),
                       !localAlbums.isEmpty {
                        artistDiscographyAlbums.append(contentsOf: localAlbums)
                        continue
                    }
                }

                // Path B: Artist not yet in Lidarr -> resolve discography via MusicBrainz (exact MBID) + Deezer (cover art & popularity)
                let remoteAlbums = await fetchRemoteDiscographyAlbums(for: artist)
                artistDiscographyAlbums.append(contentsOf: remoteAlbums)
            }
        } else if directAlbums.count < 5 {
            // Fallback: if Lidarr didn't return an artist match, still check Deezer artist discography
            let fallbackAlbums = await fetchDeezerArtistDiscography(artistName: trimmed)
            artistDiscographyAlbums.append(contentsOf: fallbackAlbums)
        }

        return Self.mergeAndRankAlbumResults(
            query: trimmed,
            directAlbums: directAlbums,
            artistAlbums: artistDiscographyAlbums,
            matchedArtistNames: matchedArtistNames
        )
    }

    private func searchArtistsSafe(term: String, config: LidarrConfig) async -> [LidarrArtistSearchResult] {
        (try? await searchArtists(term: term, config: config)) ?? []
    }

    /// Direct low-level Lidarr `/api/v1/album/lookup` (used when resolving a specific album payload for ordering).
    public func lookupAlbumsRaw(term: String, config: LidarrConfig) async throws -> [LidarrAlbumSearchResult] {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let data = try await request(
            path: "/api/v1/album/lookup",
            queryItems: [URLQueryItem(name: "term", value: trimmed)],
            config: config
        )
        return parseAlbumLookupArray(data: data, baseURL: Self.normalizeBaseURL(config.baseURL))
    }

    private func fetchAlbumsForLidarrArtist(artistID: Int, artistName: String, config: LidarrConfig) async throws -> [LidarrAlbumSearchResult] {
        let data = try await request(
            path: "/api/v1/album",
            queryItems: [
                URLQueryItem(name: "artistId", value: String(artistID)),
                URLQueryItem(name: "includeAllArtistAlbums", value: "true")
            ],
            config: config
        )
        let baseURL = Self.normalizeBaseURL(config.baseURL)
        return parseAlbumLookupArray(data: data, baseURL: baseURL).map { alb in
            var copy = alb
            if copy.artistName == "Unknown Artist" || copy.artistName.isEmpty {
                copy.artistName = artistName
            }
            return copy
        }
    }

    private func fetchRemoteDiscographyAlbums(for artist: LidarrArtistSearchResult) async -> [LidarrAlbumSearchResult] {
        async let deezerTask = fetchDeezerArtistDiscography(artistName: artist.artistName)
        async let mbTask = fetchMusicBrainzReleaseGroups(foreignArtistId: artist.foreignArtistId, artistName: artist.artistName)

        let deezerAlbums = await deezerTask
        let mbAlbums = await mbTask

        if mbAlbums.isEmpty {
            return deezerAlbums
        }

        // Enrich MusicBrainz albums (which carry exact Lidarr foreignAlbumIds) with Deezer cover art when available
        var deezerCoverByNormTitle: [String: String] = [:]
        for d in deezerAlbums {
            let key = OnlinePopularityService.normalizeTitleForMatching(d.title)
            if let cover = d.coverURL, !cover.isEmpty, deezerCoverByNormTitle[key] == nil {
                deezerCoverByNormTitle[key] = cover
            }
        }

        var enriched = mbAlbums.map { alb -> LidarrAlbumSearchResult in
            var copy = alb
            let key = OnlinePopularityService.normalizeTitleForMatching(copy.title)
            if copy.coverURL == nil, let cover = deezerCoverByNormTitle[key] {
                copy.coverURL = cover
            }
            return copy
        }

        // Append any Deezer albums not already represented in MusicBrainz results
        let seenTitles = Set(enriched.map { OnlinePopularityService.normalizeTitleForMatching($0.title) })
        for d in deezerAlbums {
            let key = OnlinePopularityService.normalizeTitleForMatching(d.title)
            if !key.isEmpty && !seenTitles.contains(key) {
                enriched.append(d)
            }
        }
        return enriched
    }

    private func fetchMusicBrainzReleaseGroups(foreignArtistId: String, artistName: String) async -> [LidarrAlbumSearchResult] {
        guard !foreignArtistId.isEmpty,
              let encoded = foreignArtistId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://musicbrainz.org/ws/2/release-group?artist=\(encoded)&type=album%7Cep&fmt=json&limit=40") else {
            return []
        }
        var req = URLRequest(url: url)
        req.timeoutInterval = 8
        req.setValue("MyEcho/1.3 (https://github.com/myecho)", forHTTPHeaderField: "User-Agent")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        guard let (data, resp) = try? await session.data(for: req),
              let http = resp as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            return []
        }

        struct MBResponse: Decodable {
            let releaseGroups: [MBReleaseGroup]
            enum CodingKeys: String, CodingKey {
                case releaseGroups = "release-groups"
            }
        }
        struct MBReleaseGroup: Decodable {
            let id: String
            let title: String
            let primaryType: String?
            let secondaryTypes: [String]?
            let firstReleaseDate: String?
            enum CodingKeys: String, CodingKey {
                case id, title
                case primaryType = "primary-type"
                case secondaryTypes = "secondary-types"
                case firstReleaseDate = "first-release-date"
            }
        }

        guard let decoded = try? JSONDecoder().decode(MBResponse.self, from: data) else { return [] }
        return decoded.releaseGroups.compactMap { rg in
            // Skip noisy unofficial/bootleg/compilation-heavy secondary types unless studio album/EP
            let secondaries = Set((rg.secondaryTypes ?? []).map { $0.lowercased() })
            if secondaries.contains("bootleg") || secondaries.contains("interview") || secondaries.contains("audiobook") {
                return nil
            }
            let year: Int? = rg.firstReleaseDate.flatMap { str in
                str.count >= 4 ? Int(str.prefix(4)) : nil
            }
            let typeLabel = secondaries.contains("compilation")
                ? "Compilation"
                : (secondaries.contains("live") ? "Live" : (rg.primaryType ?? "Album"))
            return LidarrAlbumSearchResult(
                lidarrID: nil,
                foreignAlbumId: rg.id,
                title: rg.title,
                artistName: artistName,
                foreignArtistId: foreignArtistId,
                releaseYear: year,
                releaseDate: rg.firstReleaseDate,
                albumType: typeLabel,
                coverURL: "https://coverartarchive.org/release-group/\(rg.id)/front-250",
                monitored: false,
                rawJSONData: Data()
            )
        }
    }

    private func fetchDeezerArtistDiscography(artistName: String) async -> [LidarrAlbumSearchResult] {
        guard let artist = await findMatchingDeezerArtist(term: artistName) else { return [] }
        guard let url = URL(string: "https://api.deezer.com/artist/\(artist.id)/albums?limit=35") else { return [] }
        guard let (data, _) = try? await session.data(from: url) else { return [] }

        struct DZAlbumResp: Decodable { let data: [DZArtistAlbum] }
        struct DZArtistAlbum: Decodable {
            let id: Int
            let title: String
            let cover_medium: String?
            let cover_big: String?
            let release_date: String?
            let record_type: String?
        }

        guard let decoded = try? JSONDecoder().decode(DZAlbumResp.self, from: data) else { return [] }
        return decoded.data.map { item in
            let year = item.release_date.flatMap { $0.count >= 4 ? Int($0.prefix(4)) : nil }
            let typeLabel: String
            switch item.record_type?.lowercased() {
            case "album": typeLabel = "Album"
            case "ep": typeLabel = "EP"
            case "single": typeLabel = "Single"
            case "compile": typeLabel = "Compilation"
            default: typeLabel = "Album"
            }
            return LidarrAlbumSearchResult(
                lidarrID: nil,
                foreignAlbumId: "deezer-album:\(item.id)",
                title: item.title,
                artistName: artist.name,
                foreignArtistId: nil,
                releaseYear: year,
                releaseDate: item.release_date,
                albumType: typeLabel,
                coverURL: item.cover_big ?? item.cover_medium,
                monitored: false,
                rawJSONData: Data()
            )
        }
    }

    private struct DeezerArtistHit: Decodable {
        let id: Int
        let name: String
    }

    private func findMatchingDeezerArtist(term: String) async -> DeezerArtistHit? {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.deezer.com/search/artist?q=\(encoded)&limit=5") else {
            return nil
        }
        struct DZArtistsResp: Decodable { let data: [DeezerArtistHit] }
        guard let (data, _) = try? await session.data(from: url),
              let decoded = try? JSONDecoder().decode(DZArtistsResp.self, from: data) else {
            return nil
        }
        let normQ = OnlinePopularityService.normalizeTitleForMatching(trimmed)
        guard !normQ.isEmpty else { return nil }
        return decoded.data.first(where: { hit in
            let normName = OnlinePopularityService.normalizeTitleForMatching(hit.name)
            return normName == normQ
                || normName.hasPrefix(normQ)
                || normQ.hasPrefix(normName)
                || normName.contains(normQ)
        })
    }

    public static func selectMatchingArtists(from artists: [LidarrArtistSearchResult], query: String) -> [LidarrArtistSearchResult] {
        let normQ = OnlinePopularityService.normalizeTitleForMatching(query)
        guard !normQ.isEmpty else { return [] }
        let queryTokens = normQ.split(separator: " ").map(String.init)
        return artists.filter { artist in
            let normName = OnlinePopularityService.normalizeTitleForMatching(artist.artistName)
            guard !normName.isEmpty else { return false }
            if normName == normQ || normName.hasPrefix(normQ) || normQ.hasPrefix(normName) {
                return true
            }
            if normQ.count >= 3 && normName.contains(normQ) {
                return true
            }
            if queryTokens.count >= 2 && queryTokens.allSatisfy({ normName.contains($0) }) {
                return true
            }
            return false
        }
    }

    public static func mergeAndRankAlbumResults(
        query: String,
        directAlbums: [LidarrAlbumSearchResult],
        artistAlbums: [LidarrAlbumSearchResult],
        matchedArtistNames: [String] = []
    ) -> [LidarrAlbumSearchResult] {
        let normQ = OnlinePopularityService.normalizeTitleForMatching(query)
        let normMatchedArtists = Set(matchedArtistNames.map { OnlinePopularityService.normalizeTitleForMatching($0) }.filter { !$0.isEmpty })

        // Deduplicate: prefer entries with real Lidarr metadata (isInLidarr or non-empty rawJSONData)
        var byKey: [String: LidarrAlbumSearchResult] = [:]
        var orderedKeys: [String] = []

        func ingest(_ item: LidarrAlbumSearchResult) {
            let normTitle = OnlinePopularityService.normalizeTitleForMatching(item.title)
            let normArtist = OnlinePopularityService.normalizeTitleForMatching(item.artistName)
            let key = normTitle.isEmpty ? item.foreignAlbumId.lowercased() : "\(normArtist)::\(normTitle)"

            if let existing = byKey[key] {
                let existingRichness = (existing.isInLidarr ? 4 : 0) + (!existing.rawJSONData.isEmpty ? 2 : 0) + (existing.coverURL != nil ? 1 : 0)
                let newRichness = (item.isInLidarr ? 4 : 0) + (!item.rawJSONData.isEmpty ? 2 : 0) + (item.coverURL != nil ? 1 : 0)
                if newRichness > existingRichness {
                    var merged = item
                    if merged.coverURL == nil { merged.coverURL = existing.coverURL }
                    if merged.releaseYear == nil { merged.releaseYear = existing.releaseYear }
                    byKey[key] = merged
                } else if existing.coverURL == nil, let cover = item.coverURL {
                    var updated = existing
                    updated.coverURL = cover
                    byKey[key] = updated
                }
            } else {
                byKey[key] = item
                orderedKeys.append(key)
            }
        }

        for a in directAlbums { ingest(a) }
        for a in artistAlbums { ingest(a) }

        func score(_ alb: LidarrAlbumSearchResult) -> Int {
            let normTitle = OnlinePopularityService.normalizeTitleForMatching(alb.title)
            let normArtist = OnlinePopularityService.normalizeTitleForMatching(alb.artistName)
            let typeLower = (alb.albumType ?? "").lowercased()
            let isStudioAlbum = typeLower.isEmpty || typeLower == "album"
            let isSingle = typeLower == "single"
            let isCompilation = typeLower == "compilation" || typeLower == "live"

            var s = 0
            // Exact or strong artist match (e.g. searching "Michael Jackson" -> albums by Michael Jackson)
            if normArtist == normQ || normMatchedArtists.contains(normArtist) {
                s += 900
            } else if !normQ.isEmpty && (normArtist.hasPrefix(normQ) || normArtist.contains(normQ)) {
                s += 650
            }

            // Album title match
            if normTitle == normQ {
                s += 1000
            } else if !normQ.isEmpty && normTitle.hasPrefix(normQ) {
                s += 720
            } else if !normQ.isEmpty && normTitle.contains(normQ) {
                s += 520
            }

            // Prefer full studio albums over singles & compilations
            if isStudioAlbum { s += 160 }
            else if isCompilation { s += 40 }
            else if isSingle { s -= 120 }

            if alb.isInLidarr { s += 30 }
            if !alb.rawJSONData.isEmpty { s += 15 }
            return s
        }

        let merged = orderedKeys.compactMap { byKey[$0] }
        return merged.sorted { a, b in
            let sa = score(a)
            let sb = score(b)
            if sa != sb { return sa > sb }
            // Within same tier (e.g., studio albums by the same artist), sort chronologically newest or oldest cleanly -> releaseYear ascending/descending (newest first)
            let ya = a.releaseYear ?? 0
            let yb = b.releaseYear ?? 0
            if ya != yb { return ya > yb }
            return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
        }
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

    /// Resolves track, artist, or album queries into matching tracks (output = Tracks) via Deezer public catalog,
    /// allowing users to search by artist name, album title, or song title and order the parent album in Lidarr.
    public func searchTracksForAlbumOrder(term: String) async throws -> [LidarrTrackMatch] {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let searchURL = URL(string: "https://api.deezer.com/search/track?q=\(encoded)&limit=30") else {
            return []
        }

        struct DZResp: Decodable { let data: [DZTrack] }
        struct DZTrack: Decodable {
            let id: Int
            let title: String
            let duration: Int
            let rank: Int?
            let artist: DZArtist
            let album: DZAlbum?
        }
        struct DZArtist: Decodable { let name: String }
        struct DZAlbum: Decodable {
            let title: String
            let cover_medium: String?
            let cover_big: String?
        }
        struct DZAlbumHit: Decodable {
            let id: Int
            let title: String
            let cover_medium: String?
            let cover_big: String?
            let artist: DZArtist?
        }
        struct DZAlbumSearchResp: Decodable { let data: [DZAlbumHit] }

        func mapTrack(_ item: DZTrack, fallbackAlbum: String = "", fallbackCover: String? = nil) -> LidarrTrackMatch {
            LidarrTrackMatch(
                id: String(item.id),
                title: item.title,
                artistName: item.artist.name,
                albumTitle: item.album?.title ?? fallbackAlbum,
                duration: item.duration,
                coverURL: item.album?.cover_big ?? item.album?.cover_medium ?? fallbackCover,
                popularity: item.rank.map { OnlinePopularityService.scoreFromDeezerRank($0) }
            )
        }

        // Run direct track search, artist top-tracks lookup, and album tracks lookup in parallel
        async let directTracksTask: [LidarrTrackMatch] = {
            let (data, _) = try await self.session.data(from: searchURL)
            let decoded = try JSONDecoder().decode(DZResp.self, from: data)
            return decoded.data.map { mapTrack($0) }
        }()

        async let artistTopTask: (artistName: String?, tracks: [LidarrTrackMatch]) = {
            guard let artist = await self.findMatchingDeezerArtist(term: trimmed),
                  let topURL = URL(string: "https://api.deezer.com/artist/\(artist.id)/top?limit=30"),
                  let (data, _) = try? await self.session.data(from: topURL),
                  let decoded = try? JSONDecoder().decode(DZResp.self, from: data) else {
                return (nil, [])
            }
            return (artist.name, decoded.data.map { mapTrack($0) })
        }()

        async let albumTracksTask: [LidarrTrackMatch] = {
            guard let albSearchURL = URL(string: "https://api.deezer.com/search/album?q=\(encoded)&limit=3"),
                  let (sData, _) = try? await self.session.data(from: albSearchURL),
                  let sDecoded = try? JSONDecoder().decode(DZAlbumSearchResp.self, from: sData) else {
                return []
            }
            let normQ = OnlinePopularityService.normalizeTitleForMatching(trimmed)
            guard let hit = sDecoded.data.first(where: { h in
                let nt = OnlinePopularityService.normalizeTitleForMatching(h.title)
                return nt == normQ || nt.hasPrefix(normQ)
            }) else {
                return []
            }
            guard let tracksURL = URL(string: "https://api.deezer.com/album/\(hit.id)/tracks?limit=25"),
                  let (tData, _) = try? await self.session.data(from: tracksURL),
                  let tDecoded = try? JSONDecoder().decode(DZResp.self, from: tData) else {
                return []
            }
            let fallbackCover = hit.cover_big ?? hit.cover_medium
            return tDecoded.data.map { mapTrack($0, fallbackAlbum: hit.title, fallbackCover: fallbackCover) }
        }()

        let directTracks = try await directTracksTask
        let artistRes = await artistTopTask
        let albumTracks = await albumTracksTask

        return Self.mergeAndRankTrackResults(
            query: trimmed,
            directTracks: directTracks,
            artistTopTracks: artistRes.tracks,
            albumTracks: albumTracks,
            matchedArtistName: artistRes.artistName
        )
    }

    public static func mergeAndRankTrackResults(
        query: String,
        directTracks: [LidarrTrackMatch],
        artistTopTracks: [LidarrTrackMatch],
        albumTracks: [LidarrTrackMatch],
        matchedArtistName: String? = nil
    ) -> [LidarrTrackMatch] {
        let normQ = OnlinePopularityService.normalizeTitleForMatching(query)
        let normMatchedArtist = matchedArtistName.map { OnlinePopularityService.normalizeTitleForMatching($0) } ?? ""
        let queryIsExactArtist = !normMatchedArtist.isEmpty && (normMatchedArtist == normQ || normMatchedArtist.hasPrefix(normQ))

        var seenIDs = Set<String>()
        var seenArtistTitle = Set<String>()
        var combined: [LidarrTrackMatch] = []

        func ingest(_ list: [LidarrTrackMatch]) {
            for t in list {
                let dedupKey = "\(OnlinePopularityService.normalizeTitleForMatching(t.artistName))::\(OnlinePopularityService.normalizeTitleForMatching(t.title))"
                guard seenIDs.insert(t.id).inserted else { continue }
                guard seenArtistTitle.insert(dedupKey).inserted else { continue }
                combined.append(t)
            }
        }

        // If user searched an artist name, artist top tracks are the cleanest primary results;
        // otherwise lead with direct track matches, then album tracks, then artist top tracks.
        if queryIsExactArtist {
            ingest(artistTopTracks)
            ingest(directTracks)
            ingest(albumTracks)
        } else {
            ingest(directTracks)
            ingest(albumTracks)
            ingest(artistTopTracks)
        }

        func score(_ t: LidarrTrackMatch) -> Int {
            let nt = OnlinePopularityService.normalizeTitleForMatching(t.title)
            let na = OnlinePopularityService.normalizeTitleForMatching(t.artistName)
            let nal = OnlinePopularityService.normalizeTitleForMatching(t.albumTitle)
            var s = (t.popularity ?? 0)

            if queryIsExactArtist && (na == normMatchedArtist || na.contains(normMatchedArtist)) {
                s += 900
            } else if na == normQ {
                s += 850
            } else if !normQ.isEmpty && na.contains(normQ) {
                s += 500
            }

            if nt == normQ {
                s += 950
            } else if !normQ.isEmpty && nt.hasPrefix(normQ) {
                s += 700
            } else if !normQ.isEmpty && nt.contains(normQ) {
                s += 520
            }

            if nal == normQ {
                s += 620
            } else if !normQ.isEmpty && nal.contains(normQ) {
                s += 320
            }
            return s
        }

        return Array(
            combined.sorted { a, b in
                let sa = score(a)
                let sb = score(b)
                if sa != sb { return sa > sb }
                return (a.popularity ?? 0) > (b.popularity ?? 0)
            }.prefix(40)
        )
    }

    // MARK: - Ordering Downloads

    public func orderAlbum(_ album: LidarrAlbumSearchResult, config: LidarrConfig) async throws -> LidarrOrderResult {
        // 0. If this album came from artist-discography expansion without raw Lidarr lookup JSON,
        // resolve the full Lidarr lookup object on-demand before adding!
        var resolvedAlbum = album
        if resolvedAlbum.lidarrID == nil && resolvedAlbum.rawJSONData.isEmpty {
            let isMBID = !resolvedAlbum.foreignAlbumId.hasPrefix("deezer-album:")
                && UUID(uuidString: resolvedAlbum.foreignAlbumId) != nil
            if isMBID,
               let byID = try? await lookupAlbumsRaw(term: "lidarr:\(resolvedAlbum.foreignAlbumId)", config: config),
               let exact = byID.first(where: { $0.foreignAlbumId.caseInsensitiveCompare(resolvedAlbum.foreignAlbumId) == .orderedSame }) ?? byID.first {
                resolvedAlbum = exact
            } else {
                let candidates = try await lookupAlbumsRaw(term: "\(resolvedAlbum.artistName) \(resolvedAlbum.title)", config: config)
                let targetTitle = OnlinePopularityService.normalizeTitleForMatching(resolvedAlbum.title)
                let targetArtist = OnlinePopularityService.normalizeTitleForMatching(resolvedAlbum.artistName)
                if let best = candidates.first(where: { c in
                    let ct = OnlinePopularityService.normalizeTitleForMatching(c.title)
                    let ca = OnlinePopularityService.normalizeTitleForMatching(c.artistName)
                    return (ct == targetTitle || ct.contains(targetTitle) || targetTitle.contains(ct))
                        && (ca.contains(targetArtist) || targetArtist.contains(ca))
                }) ?? candidates.first {
                    resolvedAlbum = best
                }
            }
        }

        // 1. If already tracked in Lidarr, monitor & trigger AlbumSearch directly
        if let existingID = resolvedAlbum.lidarrID, existingID > 0 {
            try await monitorAlbum(albumID: existingID, monitored: true, config: config)
            try await triggerAlbumSearch(albumID: existingID, config: config)
            return LidarrOrderResult(
                albumTitle: resolvedAlbum.title,
                artistName: resolvedAlbum.artistName,
                lidarrAlbumID: existingID,
                alreadyExisted: true,
                searchTriggered: true
            )
        }

        // 2. Check if foreignAlbumId is already in Lidarr (e.g. added since lookup)
        if !resolvedAlbum.foreignAlbumId.hasPrefix("deezer-album:"),
           let existingData = try? await request(
            path: "/api/v1/album",
            queryItems: [URLQueryItem(name: "foreignAlbumId", value: resolvedAlbum.foreignAlbumId)],
            config: config
        ),
           let existingArr = try? JSONSerialization.jsonObject(with: existingData) as? [[String: Any]],
           let first = existingArr.first,
           let existingID = first["id"] as? Int, existingID > 0 {
            try await monitorAlbum(albumID: existingID, monitored: true, config: config)
            try await triggerAlbumSearch(albumID: existingID, config: config)
            return LidarrOrderResult(
                albumTitle: resolvedAlbum.title,
                artistName: resolvedAlbum.artistName,
                lidarrAlbumID: existingID,
                alreadyExisted: true,
                searchTriggered: true
            )
        }

        // 3. Add brand-new album via POST /api/v1/album
        let payload = try Self.buildAddAlbumPayload(fromLookupData: resolvedAlbum.rawJSONData, config: config)
        let responseData = try await request(path: "/api/v1/album", method: "POST", body: payload, config: config)
        let createdObj = (try? JSONSerialization.jsonObject(with: responseData) as? [String: Any])
        let createdID = createdObj?["id"] as? Int

        return LidarrOrderResult(
            albumTitle: resolvedAlbum.title,
            artistName: resolvedAlbum.artistName,
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

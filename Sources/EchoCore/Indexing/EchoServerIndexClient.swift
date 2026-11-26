import Foundation
import CryptoKit
import Compression
import Darwin

// MARK: - Auto-Detection & Share `.myecho` Models

public struct ShareDotMyEchoBeacon: Codable, Hashable, Sendable {
    public var serverName: String
    public var serverKind: String?
    public var libraryId: String
    public var libraryName: String
    public var lanURL: String
    public var partyURL: String?
    public var apiPort: Int?
    public var partyPort: Int?
}

public struct DetectedEchoServerForSource: Hashable, Sendable {
    public var sourceID: UUID
    public var serverName: String
    public var baseURL: String
    public var libraryID: String
    public var hasDotMyEchoIndex: Bool
    public var dotMyEchoRevision: Int?
    public var dotMyEchoTrackCount: Int?
    public var detectionMethod: String // ".myecho" or "smb-probe"
}

// MARK: - Echo Server V2 Wire Models (Partitioned Compressed Shards + Delta Sync + Shared State)

public struct EchoServerInfo: Codable, Sendable {
    public var app: String
    public var serverKind: String?
    public var serverName: String
    public var trackCount: Int
    public var playlistCount: Int
    public var totalBytes: Int64
    public var capabilities: [String]?
    public var partyPort: Int?
    public var partyHTTPSPort: Int?
    public var advertiseHost: String?
}

public struct EchoServerLibraryMeta: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var rootPath: String
    public var shardCount: Int
    public var currentRevision: Int
    public var minDeltaRevision: Int
    public var trackCount: Int
    public var totalBytes: Int64
    public var lastScannedAt: Date?
}

public struct EchoServerLibrariesResponse: Codable, Sendable {
    public var serverName: String
    public var libraries: [EchoServerLibraryMeta]
}

public struct EchoServerShardMeta: Codable, Hashable, Sendable {
    public var libraryId: String
    public var shardId: Int
    public var sha256: String
    public var trackCount: Int
    public var compressedBytes: Int64
    public var uncompressedBytes: Int64
    public var updatedAtRevision: Int
}

public struct EchoServerIndexManifest: Codable, Sendable {
    public var serverName: String
    public var libraryId: String
    public var libraryName: String
    public var revision: Int
    public var minDeltaRevision: Int?
    public var shardCount: Int
    public var trackCount: Int
    public var totalAudioBytes: Int64
    public var compressedBytes: Int64
    public var uncompressedBytes: Int64
    public var lastScannedAt: Date?
    public var compression: String
    public var shards: [EchoServerShardMeta]
    public var editorialSha256: String?
    public var editorialCompressedBytes: Int64?
    public var editorialAlbumCount: Int?
    public var editorialArtistCount: Int?
}

public struct EchoServerEditorialBundle: Codable, Sendable {
    public var generatedAt: Date?
    public var albumEditorial: [AlbumEditorialInfo]
    public var artistEditorial: [ArtistEditorialInfo]
}

public struct EchoServerTrackRecord: Codable, Sendable {
    public var trackKey: String
    public var legacyId: String?
    public var libraryId: String
    public var relativePath: String
    public var fileName: String
    public var fileSize: Int64
    public var modifiedAt: Date
    public var addedAt: Date?
    public var format: String
    public var fileExtension: String
    public var title: String
    public var artist: String
    public var albumArtist: String
    public var album: String
    public var trackNumber: Int?
    public var discNumber: Int?
    public var year: Int?
    public var genre: String?
    public var duration: TimeInterval
    public var sampleRate: Int?
    public var bitDepth: Int?
    public var bitrate: Int?
    public var artworkHash: String?
    public var hasEmbeddedArtwork: Bool
    public var lyricsRelativePath: String?
    public var shardId: Int

    /// Reconstructs a macOS `Track` with deterministic legacy `Track.id = stableTrackID(forPath: localPath)`
    /// so all existing playlists, 1–5 star ratings, and FiiO/SD card sync manifests stay 100% intact.
    public func toLocalTrack(sourceID: UUID, localMountRoot: String) -> Track {
        let trimmedRoot = localMountRoot.hasSuffix("/") ? String(localMountRoot.dropLast()) : localMountRoot
        let cleanRel = relativePath.hasPrefix("/") ? String(relativePath.dropFirst()) : relativePath
        let fullPath = trimmedRoot.isEmpty ? cleanRel : "\(trimmedRoot)/\(cleanRel)"
        let fullLyricsPath: String? = lyricsRelativePath.map { rel in
            let r = rel.hasPrefix("/") ? String(rel.dropFirst()) : rel
            return trimmedRoot.isEmpty ? r : "\(trimmedRoot)/\(r)"
        }
        let localID = AudioMetadataReader.stableTrackID(forPath: fullPath)
        let audioFmt = AudioFormat(rawValue: format.lowercased()) ?? AudioFormat(fileExtension: fileExtension)
        return Track(
            id: localID,
            sourceID: sourceID,
            filePath: fullPath,
            fileName: fileName,
            fileSize: fileSize,
            modifiedAt: modifiedAt,
            addedAt: addedAt,
            format: audioFmt,
            title: title,
            artist: artist,
            albumArtist: albumArtist,
            album: album,
            trackNumber: trackNumber,
            discNumber: discNumber,
            year: year,
            genre: genre,
            duration: duration,
            sampleRate: sampleRate,
            bitDepth: bitDepth,
            bitrate: bitrate,
            artworkHash: artworkHash,
            hasEmbeddedArtwork: hasEmbeddedArtwork,
            lyricsPath: fullLyricsPath,
            isAvailable: true
        )
    }
}

public struct EchoServerDeltaResponse: Codable, Sendable {
    public var libraryId: String
    public var fromRevision: Int
    public var toRevision: Int
    public var requiresShardSync: Bool
    public var reason: String?
    public var upserted: [EchoServerTrackRecord]?
    public var removedTrackKeys: [String]?
    public var removedRelativePaths: [String]?
}

public struct EchoServerSyncOutcome: Sendable {
    public var sourceID: UUID
    public var tracks: [Track]
    public var newRevision: Int
    public var shardChecksums: [String: String]
    public var addedCount: Int
    public var updatedCount: Int
    public var removedCount: Int
    public var downloadedShards: Int
    public var usedDelta: Bool
    public var artworkPrefetched: Int
    public var albumEditorial: [AlbumEditorialInfo] = []
    public var artistEditorial: [ArtistEditorialInfo] = []
}

// MARK: - Shared Library State Sync Payloads

public struct EchoServerSharedPlaylist: Codable, Sendable {
    public var id: String
    public var name: String
    public var description: String
    public var trackIDs: [String]
    public var createdAt: Date
    public var updatedAt: Date
    public var deleted: Bool?

    public init(from pl: Playlist, deleted: Bool = false) {
        self.id = pl.id.uuidString
        self.name = pl.name
        self.description = pl.description
        self.trackIDs = pl.trackIDs
        self.createdAt = pl.createdAt
        self.updatedAt = pl.updatedAt
        self.deleted = deleted ? true : nil
    }
}

public struct EchoServerSharedTrackStats: Codable, Sendable {
    public var trackID: String
    public var userPlayCount: Int
    public var lastPlayedAt: Date?
    public var userRating: Int?
    public var onlinePopularity: Int?
    public var onlinePlayCount: Int?
    public var onlineListeners: Int?
    public var onlineSource: String?
    public var onlineFetchedAt: Date?
    public var updatedAt: Date

    public init(from s: TrackStats, updatedAt: Date = Date()) {
        self.trackID = s.trackID
        self.userPlayCount = s.userPlayCount
        self.lastPlayedAt = s.lastPlayedAt
        self.userRating = s.userRating
        self.onlinePopularity = s.onlinePopularity
        self.onlinePlayCount = s.onlinePlayCount
        self.onlineListeners = s.onlineListeners
        self.onlineSource = s.onlineSource
        self.onlineFetchedAt = s.onlineFetchedAt
        self.updatedAt = updatedAt
    }
}

public struct EchoServerSharedAlbumRating: Codable, Sendable {
    public var albumKey: String
    public var rating: Int
    public var updatedAt: Date
    public var deleted: Bool?

    public init(from r: AlbumUserRating, deleted: Bool = false) {
        self.albumKey = r.albumKey
        self.rating = r.rating
        self.updatedAt = r.updatedAt
        self.deleted = deleted ? true : nil
    }
}

public struct EchoServerSharedPodcastFeed: Codable, Sendable {
    public var id: String
    public var title: String
    public var author: String
    public var description: String
    public var feedURL: String
    public var artworkURL: String?
    public var artworkHash: String?
    public var episodesToKeep: Int
    public var isSelectedForAutoSync: Bool
    public var updatedAt: Date
    public var deleted: Bool?

    public init(from show: PodcastShow, updatedAt: Date = Date()) {
        self.id = show.id.uuidString
        self.title = show.title
        self.author = show.author
        self.description = show.description
        self.feedURL = show.feedURL
        self.artworkURL = show.artworkURL
        self.artworkHash = show.artworkHash
        self.episodesToKeep = show.episodesToKeep
        self.isSelectedForAutoSync = true
        self.updatedAt = updatedAt
        self.deleted = nil
    }
}

public struct EchoServerSharedStatePayload: Codable, Sendable {
    public var playlists: [EchoServerSharedPlaylist]?
    public var trackStats: [EchoServerSharedTrackStats]?
    public var albumRatings: [EchoServerSharedAlbumRating]?
    public var podcasts: [EchoServerSharedPodcastFeed]?
    public var albumEditorial: [AlbumEditorialInfo]?
    public var artistEditorial: [ArtistEditorialInfo]?

    public init(
        playlists: [EchoServerSharedPlaylist]? = nil,
        trackStats: [EchoServerSharedTrackStats]? = nil,
        albumRatings: [EchoServerSharedAlbumRating]? = nil,
        podcasts: [EchoServerSharedPodcastFeed]? = nil,
        albumEditorial: [AlbumEditorialInfo]? = nil,
        artistEditorial: [ArtistEditorialInfo]? = nil
    ) {
        self.playlists = playlists
        self.trackStats = trackStats
        self.albumRatings = albumRatings
        self.podcasts = podcasts
        self.albumEditorial = albumEditorial
        self.artistEditorial = artistEditorial
    }
}

// MARK: - Echo Server Client Actor

public actor EchoServerIndexClient {
    private let session: URLSession
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        let frac = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        let std = Date.ISO8601FormatStyle(includingFractionalSeconds: false)
        d.dateDecodingStrategy = .custom { dec in
            let c = try dec.singleValueContainer()
            let str = try c.decode(String.self)
            if let dt = try? frac.parse(str) { return dt }
            if let dt = try? std.parse(str) { return dt }
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Invalid ISO8601 date: \(str)")
        }
        return d
    }()
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    public init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 20
        cfg.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: cfg)
    }

    public func ping(config: EchoServerConfig) async throws -> (info: EchoServerInfo, activeBaseURL: String) {
        let (data, baseURL) = try await requestWithFailover(config: config, path: "/api/v1/ping")
        let info = try decoder.decode(EchoServerInfo.self, from: data)
        return (info, baseURL)
    }

    public func listLibraries(config: EchoServerConfig) async throws -> [EchoServerLibraryMeta] {
        let (data, _) = try await requestWithFailover(config: config, path: "/api/v2/libraries")
        let resp = try decoder.decode(EchoServerLibrariesResponse.self, from: data)
        return resp.libraries
    }

    // MARK: - Automatic Echo Server & `.myecho` Share Detection

    /// Extracts the SMB/NFS server host/IP from a mounted macOS volume path using POSIX `statfs`
    /// (e.g. `//bard@192.168.0.12/Media` -> `192.168.0.12`).
    public static func extractNetworkMountHost(forPath path: String) -> String? {
        var fs = statfs()
        guard statfs(path, &fs) == 0 else { return nil }
        let mntFrom = withUnsafePointer(to: &fs.f_mntfromname) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) {
                String(cString: $0)
            }
        }
        // SMB format: `//user@host/share` or `//host/share`
        if mntFrom.hasPrefix("//") {
            let withoutPrefix = String(mntFrom.dropFirst(2))
            let hostAndUser = withoutPrefix.components(separatedBy: "/").first ?? ""
            let hostPort = hostAndUser.components(separatedBy: "@").last ?? hostAndUser
            let host = hostPort.components(separatedBy: ":").first ?? hostPort
            let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        // NFS format: `host:/export/path`
        if let colon = mntFrom.firstIndex(of: ":") {
            let host = String(mntFrom[..<colon]).trimmingCharacters(in: .whitespacesAndNewlines)
            return host.isEmpty ? nil : host
        }
        return nil
    }

    /// Auto-detects My Echo Server for a LibrarySource by:
    /// 1) Checking `<source.path>/.myecho/server.json` + `manifest.json` directly on the mounted share
    /// 2) Probing `http://<smb-mount-host>:48721/api/v1/info` extracted via `statfs`
    public func detectServer(for source: LibrarySource) async -> DetectedEchoServerForSource? {
        let fm = FileManager.default
        let rootURL = URL(fileURLWithPath: source.path, isDirectory: true)
        let dotMyEchoDir = rootURL.appendingPathComponent(".myecho", isDirectory: true)
        let beaconURL = dotMyEchoDir.appendingPathComponent("server.json")
        let manifestURL = dotMyEchoDir.appendingPathComponent("manifest.json")

        var shareManifest: EchoServerIndexManifest? = nil
        if fm.fileExists(atPath: manifestURL.path),
           let data = try? Data(contentsOf: manifestURL),
           let decoded = try? decoder.decode(EchoServerIndexManifest.self, from: data) {
            shareManifest = decoded
        }

        if fm.fileExists(atPath: beaconURL.path),
           let data = try? Data(contentsOf: beaconURL),
           let beacon = try? decoder.decode(ShareDotMyEchoBeacon.self, from: data) {
            return DetectedEchoServerForSource(
                sourceID: source.id,
                serverName: beacon.serverName,
                baseURL: EchoServerConfig.normalizeURL(beacon.lanURL),
                libraryID: beacon.libraryId,
                hasDotMyEchoIndex: shareManifest != nil,
                dotMyEchoRevision: shareManifest?.revision,
                dotMyEchoTrackCount: shareManifest?.trackCount,
                detectionMethod: ".myecho"
            )
        }

        if let man = shareManifest {
            return DetectedEchoServerForSource(
                sourceID: source.id,
                serverName: man.serverName,
                baseURL: "",
                libraryID: man.libraryId,
                hasDotMyEchoIndex: true,
                dotMyEchoRevision: man.revision,
                dotMyEchoTrackCount: man.trackCount,
                detectionMethod: ".myecho"
            )
        }

        // Fallback: probe the SMB/NFS server host directly on default port 48721
        if let host = Self.extractNetworkMountHost(forPath: source.path),
           let infoURL = URL(string: "http://\(host):48721/api/v1/info") {
            var req = URLRequest(url: infoURL)
            req.timeoutInterval = 2.5
            if let (data, resp) = try? await session.data(for: req),
               let http = resp as? HTTPURLResponse,
               (200...299).contains(http.statusCode),
               let info = try? decoder.decode(EchoServerInfo.self, from: data),
               info.serverKind == "echo-server" {
                return DetectedEchoServerForSource(
                    sourceID: source.id,
                    serverName: info.serverName,
                    baseURL: "http://\(host):48721",
                    libraryID: "music",
                    hasDotMyEchoIndex: false,
                    dotMyEchoRevision: nil,
                    dotMyEchoTrackCount: info.trackCount,
                    detectionMethod: "smb-probe"
                )
            }
        }
        return nil
    }

    /// Reads pre-built compressed `.myecho/shards/shard-XXX.ndjson.gz` directly from the mounted share root!
    /// Only reads changed shards (by SHA-256), verifies checksums, and maps exact legacy Track IDs.
    public func syncFromShareDotMyEcho(
        source: LibrarySource,
        existingTracks: [Track],
        onProgress: @escaping @Sendable (IndexProgress) -> Void
    ) async throws -> EchoServerSyncOutcome {
        let rootURL = URL(fileURLWithPath: source.path, isDirectory: true)
        let dotDir = rootURL.appendingPathComponent(".myecho", isDirectory: true)
        let manifestURL = dotDir.appendingPathComponent("manifest.json")
        guard let manifestData = try? Data(contentsOf: manifestURL) else {
            throw NSError(domain: "EchoServer.ShareIndex", code: 404, userInfo: [NSLocalizedDescriptionKey: "No .myecho/manifest.json found in \(source.path)"])
        }
        let manifest = try decoder.decode(EchoServerIndexManifest.self, from: manifestData)
        let serverChecksums = Dictionary(uniqueKeysWithValues: manifest.shards.map { (String($0.shardId), $0.sha256) })

        if let lastRev = source.lastSyncedRevision,
           lastRev == manifest.revision,
           !existingTracks.isEmpty {
            onProgress(IndexProgress(sourceName: source.name, scannedCount: existingTracks.count, totalFound: existingTracks.count, currentFile: ".myecho up to date (rev #\(manifest.revision))", isComplete: true))
            return EchoServerSyncOutcome(
                sourceID: source.id,
                tracks: existingTracks,
                newRevision: manifest.revision,
                shardChecksums: serverChecksums,
                addedCount: 0,
                updatedCount: 0,
                removedCount: 0,
                downloadedShards: 0,
                usedDelta: true,
                artworkPrefetched: 0
            )
        }

        let localChecksums = existingTracks.isEmpty ? [:] : (source.cachedShardChecksums ?? [:])
        let shardsToRead = manifest.shards.filter { localChecksums[String($0.shardId)] != $0.sha256 }
        let unchangedShardIDs = Set(manifest.shards.map(\.shardId)).subtracting(shardsToRead.map(\.shardId))

        var tracksByShard: [Int: [Track]] = [:]
        if !unchangedShardIDs.isEmpty {
            let trimmedRoot = source.path.hasSuffix("/") ? String(source.path.dropLast()) : source.path
            let prefix = trimmedRoot.isEmpty ? "" : trimmedRoot + "/"
            for t in existingTracks {
                let rel = (!prefix.isEmpty && t.filePath.hasPrefix(prefix)) ? String(t.filePath.dropFirst(prefix.count)) : t.filePath
                let sid = Self.shardForRelativePath(rel, shardCount: manifest.shardCount)
                if unchangedShardIDs.contains(sid) {
                    tracksByShard[sid, default: []].append(t)
                }
            }
        }

        let shardsDir = dotDir.appendingPathComponent("shards", isDirectory: true)
        var readCount = 0
        for shard in shardsToRead {
            onProgress(IndexProgress(
                sourceName: source.name,
                scannedCount: readCount,
                totalFound: shardsToRead.count,
                currentFile: "Reading .myecho shard \(shard.shardId + 1)/\(manifest.shardCount)..."
            ))
            let shardFile = shardsDir.appendingPathComponent(String(format: "shard-%03d.ndjson.gz", shard.shardId))
            let rawGZ = try Data(contentsOf: shardFile)
            let digest = SHA256.hash(data: rawGZ).map { String(format: "%02x", $0) }.joined()
            guard digest == shard.sha256 else {
                throw NSError(domain: "EchoServer.ShareIndex", code: 500, userInfo: [NSLocalizedDescriptionKey: ".myecho shard \(shard.shardId) checksum mismatch"])
            }
            let ndjsonData = try Self.gunzip(rawGZ)
            var shardTracks: [Track] = []
            shardTracks.reserveCapacity(shard.trackCount)
            for line in ndjsonData.split(separator: UInt8(ascii: "\n")) where !line.isEmpty {
                if let rec = try? decoder.decode(EchoServerTrackRecord.self, from: Data(line)) {
                    shardTracks.append(rec.toLocalTrack(sourceID: source.id, localMountRoot: source.path))
                }
            }
            tracksByShard[shard.shardId] = shardTracks
            readCount += 1
        }

        var allTracks: [Track] = []
        allTracks.reserveCapacity(manifest.trackCount)
        for sid in tracksByShard.keys.sorted() {
            if let list = tracksByShard[sid] { allTracks.append(contentsOf: list) }
        }

        let oldByPath = Dictionary(uniqueKeysWithValues: existingTracks.map { ($0.filePath, $0) })
        let newByPath = Dictionary(uniqueKeysWithValues: allTracks.map { ($0.filePath, $0) })
        var added = 0
        var updated = 0
        for (p, t) in newByPath {
            if let old = oldByPath[p] {
                if old.fileSize != t.fileSize || abs(old.modifiedAt.timeIntervalSince(t.modifiedAt)) >= 1.5 || old.title != t.title {
                    updated += 1
                }
            } else {
                added += 1
            }
        }
        let removed = oldByPath.keys.filter { newByPath[$0] == nil }.count

        let edBundle = loadShareEditorialBundle(dotDir: dotDir, expectedSHA256: manifest.editorialSha256)

        onProgress(IndexProgress(sourceName: source.name, scannedCount: allTracks.count, totalFound: allTracks.count, currentFile: "Synced .myecho rev #\(manifest.revision)", isComplete: true))
        return EchoServerSyncOutcome(
            sourceID: source.id,
            tracks: allTracks,
            newRevision: manifest.revision,
            shardChecksums: serverChecksums,
            addedCount: added,
            updatedCount: updated,
            removedCount: removed,
            downloadedShards: shardsToRead.count,
            usedDelta: false,
            artworkPrefetched: 0,
            albumEditorial: edBundle?.albumEditorial ?? [],
            artistEditorial: edBundle?.artistEditorial ?? []
        )
    }

    private func loadShareEditorialBundle(dotDir: URL, expectedSHA256: String?) -> EchoServerEditorialBundle? {
        let edFile = dotDir.appendingPathComponent("editorial.json.gz")
        guard let rawGZ = try? Data(contentsOf: edFile), !rawGZ.isEmpty else { return nil }
        if let expected = expectedSHA256, !expected.isEmpty {
            let digest = SHA256.hash(data: rawGZ).map { String(format: "%02x", $0) }.joined()
            guard digest == expected else { return nil }
        }
        guard let jsonData = try? Self.gunzip(rawGZ) else { return nil }
        return try? decoder.decode(EchoServerEditorialBundle.self, from: jsonData)
    }

    private func fetchRemoteEditorialBundle(baseURL: String, pin: String, expectedSHA256: String?) async -> EchoServerEditorialBundle? {
        guard let rawGZ = try? await requestSingleBase(baseURL: baseURL, pin: pin, path: "/api/v2/index/editorial?raw=1"), !rawGZ.isEmpty else {
            return nil
        }
        if let expected = expectedSHA256, !expected.isEmpty {
            let digest = SHA256.hash(data: rawGZ).map { String(format: "%02x", $0) }.joined()
            guard digest == expected else { return nil }
        }
        guard let jsonData = try? Self.gunzip(rawGZ) else { return nil }
        return try? decoder.decode(EchoServerEditorialBundle.self, from: jsonData)
    }

    public func triggerRemoteScan(config: EchoServerConfig, libraryID: String? = nil, sync: Bool = false) async throws {
        var body: [String: Any] = ["sync": sync]
        if let libraryID { body["libraryId"] = libraryID }
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        _ = try await requestWithFailover(config: config, path: "/api/v2/admin/scan", method: "POST", body: jsonData)
    }

    /// Incrementally syncs a remote-indexed LibrarySource from My Echo Server using:
    /// 1) Fast revision check (0 bytes if unchanged)
    /// 2) Compressed delta patch if within delta retention window
    /// 3) SHA-256 verified parallel shard download (only changed shards) for cold starts or large jumps
    /// 4) Batch prefetch of missing 512px artwork thumbnails into local ArtworkCache
    public func syncLibraryIndex(
        source: LibrarySource,
        existingTracks: [Track],
        config: EchoServerConfig,
        artworkCache: ArtworkCache,
        onProgress: @escaping @Sendable (IndexProgress) -> Void
    ) async throws -> EchoServerSyncOutcome {
        let libID = source.remoteLibraryID ?? "music"
        onProgress(IndexProgress(sourceName: source.name, scannedCount: 0, totalFound: 0, currentFile: "Checking Echo Server manifest..."))

        let encodedLib = libID.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? libID
        let (manifestData, activeBaseURL) = try await requestWithFailover(
            config: config,
            path: "/api/v2/index/manifest?libraryId=\(encodedLib)"
        )
        let manifest = try decoder.decode(EchoServerIndexManifest.self, from: manifestData)

        let serverChecksums = Dictionary(uniqueKeysWithValues: manifest.shards.map { (String($0.shardId), $0.sha256) })

        // Fast path: already at latest revision (still pull editorial bundle if server has newly enriched items)
        if let lastRev = source.lastSyncedRevision,
           lastRev == manifest.revision,
           !existingTracks.isEmpty {
            let edBundle = await fetchRemoteEditorialBundle(baseURL: activeBaseURL, pin: config.pairingPIN, expectedSHA256: manifest.editorialSha256)
            onProgress(IndexProgress(sourceName: source.name, scannedCount: existingTracks.count, totalFound: existingTracks.count, currentFile: "Up to date (rev #\(manifest.revision))", isComplete: true))
            return EchoServerSyncOutcome(
                sourceID: source.id,
                tracks: existingTracks,
                newRevision: manifest.revision,
                shardChecksums: serverChecksums,
                addedCount: 0,
                updatedCount: 0,
                removedCount: 0,
                downloadedShards: 0,
                usedDelta: true,
                artworkPrefetched: 0,
                albumEditorial: edBundle?.albumEditorial ?? [],
                artistEditorial: edBundle?.artistEditorial ?? []
            )
        }

        // Incremental delta path when client is within server's changelog retention window
        let minDelta = manifest.minDeltaRevision ?? 1
        if let lastRev = source.lastSyncedRevision,
           lastRev > 0,
           !existingTracks.isEmpty,
           (minDelta <= 1 || lastRev >= minDelta - 1) {
            let deltaData = try await requestSingleBase(
                baseURL: activeBaseURL,
                pin: config.pairingPIN,
                path: "/api/v2/index/delta?libraryId=\(encodedLib)&since=\(lastRev)"
            )
            let delta = try decoder.decode(EchoServerDeltaResponse.self, from: deltaData)
            if !delta.requiresShardSync {
                let trimmedRoot = source.path.hasSuffix("/") ? String(source.path.dropLast()) : source.path
                var byPath = Dictionary(uniqueKeysWithValues: existingTracks.map { ($0.filePath, $0) })
                var removed = 0
                for rel in delta.removedRelativePaths ?? [] {
                    let cleanRel = rel.hasPrefix("/") ? String(rel.dropFirst()) : rel
                    let fullPath = trimmedRoot.isEmpty ? cleanRel : "\(trimmedRoot)/\(cleanRel)"
                    if byPath.removeValue(forKey: fullPath) != nil {
                        removed += 1
                    }
                }
                var added = 0
                var updated = 0
                var newArtworkHashes = Set<String>()
                for rec in delta.upserted ?? [] {
                    let track = rec.toLocalTrack(sourceID: source.id, localMountRoot: source.path)
                    if byPath[track.filePath] != nil {
                        updated += 1
                    } else {
                        added += 1
                    }
                    byPath[track.filePath] = track
                    if let h = track.artworkHash, !h.isEmpty {
                        newArtworkHashes.insert(h)
                    }
                }
                let merged = Array(byPath.values)
                let prefetched = await prefetchMissingArtwork(
                    hashes: newArtworkHashes,
                    artworkCache: artworkCache,
                    baseURL: activeBaseURL,
                    pin: config.pairingPIN
                )
                let edBundle = await fetchRemoteEditorialBundle(baseURL: activeBaseURL, pin: config.pairingPIN, expectedSHA256: manifest.editorialSha256)
                onProgress(IndexProgress(sourceName: source.name, scannedCount: merged.count, totalFound: merged.count, currentFile: "Delta synced rev #\(manifest.revision)", isComplete: true))
                return EchoServerSyncOutcome(
                    sourceID: source.id,
                    tracks: merged,
                    newRevision: manifest.revision,
                    shardChecksums: serverChecksums,
                    addedCount: added,
                    updatedCount: updated,
                    removedCount: removed,
                    downloadedShards: 0,
                    usedDelta: true,
                    artworkPrefetched: prefetched,
                    albumEditorial: edBundle?.albumEditorial ?? [],
                    artistEditorial: edBundle?.artistEditorial ?? []
                )
            }
        }

        // Sharded snapshot path: download only shards whose SHA-256 changed (or all shards on cold start)
        let localChecksums = existingTracks.isEmpty ? [:] : (source.cachedShardChecksums ?? [:])
        let shardsToFetch = manifest.shards.filter { localChecksums[String($0.shardId)] != $0.sha256 }
        let unchangedShardIDs = Set(manifest.shards.map(\.shardId)).subtracting(shardsToFetch.map(\.shardId))

        var tracksByShard: [Int: [Track]] = [:]
        // Preserve existing tracks that belong to unchanged shards using identical deterministic FNV-1a bucket
        if !unchangedShardIDs.isEmpty {
            let trimmedRoot = source.path.hasSuffix("/") ? String(source.path.dropLast()) : source.path
            let prefix = trimmedRoot.isEmpty ? "" : trimmedRoot + "/"
            for t in existingTracks {
                let rel = (!prefix.isEmpty && t.filePath.hasPrefix(prefix)) ? String(t.filePath.dropFirst(prefix.count)) : t.filePath
                let sid = Self.shardForRelativePath(rel, shardCount: manifest.shardCount)
                if unchangedShardIDs.contains(sid) {
                    tracksByShard[sid, default: []].append(t)
                }
            }
        }

        var fetchedCount = 0
        for shard in shardsToFetch {
            onProgress(IndexProgress(
                sourceName: source.name,
                scannedCount: fetchedCount,
                totalFound: shardsToFetch.count,
                currentFile: "Downloading shard \(shard.shardId + 1)/\(manifest.shardCount) (\(shard.compressedBytes / 1024) KB)..."
            ))
            let rawGZ = try await requestSingleBase(
                baseURL: activeBaseURL,
                pin: config.pairingPIN,
                path: "/api/v2/index/shards/\(encodedLib)/\(shard.shardId)?raw=1"
            )
            // Verify SHA-256 over compressed payload
            let digest = SHA256.hash(data: rawGZ).map { String(format: "%02x", $0) }.joined()
            guard digest == shard.sha256 else {
                throw NSError(domain: "EchoServer", code: 500, userInfo: [
                    NSLocalizedDescriptionKey: "Shard \(shard.shardId) checksum mismatch (expected \(shard.sha256.prefix(8)), got \(digest.prefix(8)))"
                ])
            }
            let ndjsonData = try Self.gunzip(rawGZ)
            var shardTracks: [Track] = []
            shardTracks.reserveCapacity(shard.trackCount)
            for line in ndjsonData.split(separator: UInt8(ascii: "\n")) where !line.isEmpty {
                if let rec = try? decoder.decode(EchoServerTrackRecord.self, from: Data(line)) {
                    shardTracks.append(rec.toLocalTrack(sourceID: source.id, localMountRoot: source.path))
                }
            }
            tracksByShard[shard.shardId] = shardTracks
            fetchedCount += 1
        }

        var allTracks: [Track] = []
        allTracks.reserveCapacity(manifest.trackCount)
        for sid in tracksByShard.keys.sorted() {
            if let list = tracksByShard[sid] {
                allTracks.append(contentsOf: list)
            }
        }

        let oldByPath = Dictionary(uniqueKeysWithValues: existingTracks.map { ($0.filePath, $0) })
        let newByPath = Dictionary(uniqueKeysWithValues: allTracks.map { ($0.filePath, $0) })
        var added = 0
        var updated = 0
        for (p, t) in newByPath {
            if let old = oldByPath[p] {
                if old.fileSize != t.fileSize || abs(old.modifiedAt.timeIntervalSince(t.modifiedAt)) >= 1.5 || old.title != t.title {
                    updated += 1
                }
            } else {
                added += 1
            }
        }
        let removed = oldByPath.keys.filter { newByPath[$0] == nil }.count

        let artHashes = Set(allTracks.compactMap(\.artworkHash))
        let prefetched = await prefetchMissingArtwork(
            hashes: artHashes,
            artworkCache: artworkCache,
            baseURL: activeBaseURL,
            pin: config.pairingPIN
        )

        let edBundle = await fetchRemoteEditorialBundle(baseURL: activeBaseURL, pin: config.pairingPIN, expectedSHA256: manifest.editorialSha256)

        onProgress(IndexProgress(sourceName: source.name, scannedCount: allTracks.count, totalFound: allTracks.count, currentFile: "Synced rev #\(manifest.revision)", isComplete: true))
        return EchoServerSyncOutcome(
            sourceID: source.id,
            tracks: allTracks,
            newRevision: manifest.revision,
            shardChecksums: serverChecksums,
            addedCount: added,
            updatedCount: updated,
            removedCount: removed,
            downloadedShards: shardsToFetch.count,
            usedDelta: false,
            artworkPrefetched: prefetched,
            albumEditorial: edBundle?.albumEditorial ?? [],
            artistEditorial: edBundle?.artistEditorial ?? []
        )
    }

    public func syncSharedState(config: EchoServerConfig, payload: EchoServerSharedStatePayload) async throws -> EchoServerSharedStatePayload {
        let body = try encoder.encode(payload)
        let (data, _) = try await requestWithFailover(config: config, path: "/api/v2/sync/state", method: "POST", body: body)
        return try decoder.decode(EchoServerSharedStatePayload.self, from: data)
    }

    public func fetchServerPartyEnvelope(config: EchoServerConfig) async throws -> WirelessPartyEnvelope {
        let (data, _) = try await requestWithFailover(config: config, path: "/api/v1/party/state")
        return try decoder.decode(WirelessPartyEnvelope.self, from: data)
    }

    public func setServerPartyActive(config: EchoServerConfig, active: Bool) async throws -> WirelessPartyEnvelope {
        let path = active ? "/api/party/session/start" : "/api/party/session/stop"
        let (data, _) = try await requestWithFailover(config: config, path: path, method: "POST", body: Data("{}".utf8))
        return try decoder.decode(WirelessPartyEnvelope.self, from: data)
    }

    public func sendServerPartyHostCommand(config: EchoServerConfig, command: [String: Any]) async throws {
        let body = try JSONSerialization.data(withJSONObject: command)
        _ = try await requestWithFailover(config: config, path: "/api/party/host/command", method: "POST", body: body)
    }

    public static func streamTrackURL(config: EchoServerConfig, trackID: String) -> URL? {
        guard let base = config.candidateBaseURLs.first else { return nil }
        let cleanPin = config.pairingPIN.trimmingCharacters(in: .whitespacesAndNewlines)
        let encoded = trackID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? trackID
        return URL(string: "\(base)/api/v1/catalog/track/\(encoded)?token=\(cleanPin)")
    }

    // MARK: - Batch Missing Artwork Prefetch (TAR pack)

    private func prefetchMissingArtwork(
        hashes: Set<String>,
        artworkCache: ArtworkCache,
        baseURL: String,
        pin: String
    ) async -> Int {
        let fm = FileManager.default
        let missing = hashes.filter { !fm.fileExists(atPath: artworkCache.thumbnailURL(for: $0).path) }
        guard !missing.isEmpty else { return 0 }

        var saved = 0
        let list = Array(missing)
        let batchSize = 80
        var offset = 0
        while offset < list.count {
            let batch = Array(list[offset..<min(offset + batchSize, list.count)])
            offset += batchSize
            let reqBody = (try? JSONSerialization.data(withJSONObject: ["hashes": batch, "size": "thumb"])) ?? Data()
            if let tarData = try? await requestSingleBase(baseURL: baseURL, pin: pin, path: "/api/v2/artwork/batch", method: "POST", body: reqBody) {
                for (name, fileData) in Self.unpackTar(tarData) where name.hasSuffix("_thumb.jpg") {
                    let hash = String(name.dropLast("_thumb.jpg".count))
                    guard !hash.isEmpty else { continue }
                    let dst = artworkCache.thumbnailURL(for: hash)
                    if (try? fileData.write(to: dst, options: .atomic)) != nil {
                        saved += 1
                    }
                }
            }
        }
        return saved
    }

    // MARK: - Networking Internals

    private func requestWithFailover(
        config: EchoServerConfig,
        path: String,
        method: String = "GET",
        body: Data? = nil
    ) async throws -> (Data, String) {
        let bases = config.candidateBaseURLs
        guard !bases.isEmpty else {
            throw NSError(domain: "EchoServer", code: 400, userInfo: [NSLocalizedDescriptionKey: "No Echo Server URL configured"])
        }
        var lastError: Error = URLError(.cannotConnectToHost)
        for base in bases {
            do {
                let data = try await requestSingleBase(baseURL: base, pin: config.pairingPIN, path: path, method: method, body: body)
                return (data, base)
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    private func requestSingleBase(
        baseURL: String,
        pin: String,
        path: String,
        method: String = "GET",
        body: Data? = nil
    ) async throws -> Data {
        guard let url = URL(string: baseURL + path) else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(pin.trimmingCharacters(in: .whitespacesAndNewlines), forHTTPHeaderField: "X-Echo-Token")
        if let body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if http.statusCode == 401 {
            throw NSError(domain: "EchoServer", code: 401, userInfo: [NSLocalizedDescriptionKey: "Invalid Echo Server Pairing PIN"])
        }
        guard (200...299).contains(http.statusCode) else {
            throw NSError(domain: "EchoServer", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Echo Server returned HTTP \(http.statusCode)"])
        }
        return data
    }

    // MARK: - Deterministic Shard Hash + Pure-Swift Gzip Decompression & TAR Reader

    public static func shardForRelativePath(_ relPath: String, shardCount: Int) -> Int {
        guard shardCount > 1 else { return 0 }
        let nfc = relPath.precomposedStringWithCanonicalMapping
        var h: UInt64 = 14695981039346656037
        for b in nfc.utf8 {
            h ^= UInt64(b)
            h = h &* 1099511628211
        }
        return Int(h % UInt64(shardCount))
    }

    /// Decompresses RFC 1952 gzip payload using Apple's built-in `Compression` (raw DEFLATE) framework.
    public static func gunzip(_ data: Data) throws -> Data {
        guard data.count >= 18, data[0] == 0x1F, data[1] == 0x8B, data[2] == 0x08 else {
            throw NSError(domain: "EchoServer.Gzip", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid gzip header"])
        }
        let flags = data[3]
        var offset = 10
        if flags & 0x04 != 0 { // FEXTRA
            guard offset + 2 <= data.count else { throw URLError(.cannotDecodeContentData) }
            let xlen = Int(data[offset]) | (Int(data[offset + 1]) << 8)
            offset += 2 + xlen
        }
        if flags & 0x08 != 0 { // FNAME
            while offset < data.count && data[offset] != 0 { offset += 1 }
            offset += 1
        }
        if flags & 0x10 != 0 { // FCOMMENT
            while offset < data.count && data[offset] != 0 { offset += 1 }
            offset += 1
        }
        if flags & 0x02 != 0 { // FHCRC
            offset += 2
        }
        guard offset < data.count - 8 else {
            return Data()
        }

        let deflatePayload = data.subdata(in: offset..<(data.count - 8))
        var output = Data()
        let bufferSize = 65_536
        let dstBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { dstBuffer.deallocate() }

        let streamPtr = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
        defer { streamPtr.deallocate() }
        var status = compression_stream_init(streamPtr, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB)
        guard status != COMPRESSION_STATUS_ERROR else {
            throw NSError(domain: "EchoServer.Gzip", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to init DEFLATE stream"])
        }
        defer { compression_stream_destroy(streamPtr) }

        try deflatePayload.withUnsafeBytes { rawBuf in
            guard let base = rawBuf.bindMemory(to: UInt8.self).baseAddress else { return }
            streamPtr.pointee.src_ptr = base
            streamPtr.pointee.src_size = deflatePayload.count
            repeat {
                streamPtr.pointee.dst_ptr = dstBuffer
                streamPtr.pointee.dst_size = bufferSize
                status = compression_stream_process(streamPtr, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))
                let written = bufferSize - streamPtr.pointee.dst_size
                if written > 0 {
                    output.append(dstBuffer, count: written)
                }
                if status == COMPRESSION_STATUS_ERROR {
                    throw NSError(domain: "EchoServer.Gzip", code: 3, userInfo: [NSLocalizedDescriptionKey: "Gzip decompression error"])
                }
            } while status == COMPRESSION_STATUS_OK
        }
        return output
    }

    /// Minimal POSIX ustar tar unpacker for batched artwork packs.
    public static func unpackTar(_ data: Data) -> [(name: String, data: Data)] {
        var out: [(String, Data)] = []
        var offset = 0
        while offset + 512 <= data.count {
            let header = data.subdata(in: offset..<(offset + 512))
            if header.allSatisfy({ $0 == 0 }) { break }
            let nameSlice = header[0..<100].prefix { $0 != 0 }
            let name = String(decoding: nameSlice, as: UTF8.self)
            let sizeSlice = header[124..<136].prefix { $0 != 0 && $0 != 32 }
            let sizeStr = String(decoding: sizeSlice, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            let fileSize = Int(sizeStr, radix: 8) ?? 0
            offset += 512
            guard fileSize >= 0, offset + fileSize <= data.count else { break }
            if !name.isEmpty && fileSize > 0 {
                out.append((name, data.subdata(in: offset..<(offset + fileSize))))
            }
            let padded = ((fileSize + 511) / 512) * 512
            offset += padded
        }
        return out
    }
}

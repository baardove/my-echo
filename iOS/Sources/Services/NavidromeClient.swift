import Foundation
import CryptoKit

enum NavidromeError: LocalizedError {
    case invalidURL
    case notConfigured
    case apiError(String)
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid Navidrome / Tailscale URL. Example: http://100.64.0.10:4533"
        case .notConfigured: return "Configure your Navidrome Tailscale URL, username, and password first."
        case .apiError(let msg): return "Navidrome error: \(msg)"
        case .httpError(let code): return "Navidrome HTTP error \(code)"
        }
    }
}

/// OpenSubsonic / Navidrome client designed for on-the-go streaming over Tailscale (or LAN/HTTPS).
actor NavidromeClient {
    private let session: URLSession

    init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 15
        cfg.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: cfg)
    }

    // MARK: - Subsonic Salted MD5 Auth URL Builder

    static func normalizeBaseURL(_ raw: String) -> URL? {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if !trimmed.lowercased().hasPrefix("http://") && !trimmed.lowercased().hasPrefix("https://") {
            trimmed = "http://" + trimmed
        }
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        return URL(string: trimmed)
    }

    static func buildSubsonicURL(
        endpoint: String,
        extraItems: [URLQueryItem] = [],
        config: NavidromeConfig
    ) throws -> URL {
        guard let base = normalizeBaseURL(config.serverURL) else {
            throw NavidromeError.invalidURL
        }
        guard config.isConfigured else {
            throw NavidromeError.notConfigured
        }

        let salt = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12)).lowercased()
        let tokenDigest = Insecure.MD5.hash(data: Data((config.password + salt).utf8))
        let tokenHex = tokenDigest.map { String(format: "%02x", $0) }.joined()

        var comps = URLComponents(url: base.appendingPathComponent("rest/\(endpoint)"), resolvingAgainstBaseURL: false)
        var items = [
            URLQueryItem(name: "u", value: config.username),
            URLQueryItem(name: "t", value: tokenHex),
            URLQueryItem(name: "s", value: salt),
            URLQueryItem(name: "v", value: "1.16.1"),
            URLQueryItem(name: "c", value: "MyEchoiOS"),
            URLQueryItem(name: "f", value: "json")
        ]
        items.append(contentsOf: extraItems)
        comps?.queryItems = items
        guard let url = comps?.url else { throw NavidromeError.invalidURL }
        return url
    }

    static func streamURL(songID: String, config: NavidromeConfig) -> URL? {
        var extra = [URLQueryItem(name: "id", value: songID)]
        if let bitRate = config.streamQuality.maxBitRateParam {
            extra.append(URLQueryItem(name: "maxBitRate", value: bitRate))
            extra.append(URLQueryItem(name: "format", value: "mp3"))
        } else {
            extra.append(URLQueryItem(name: "format", value: "raw"))
        }
        return try? buildSubsonicURL(endpoint: "stream.view", extraItems: extra, config: config)
    }

    static func coverArtURL(coverArtID: String?, size: Int = 500, config: NavidromeConfig) -> URL? {
        guard let coverArtID, !coverArtID.isEmpty else { return nil }
        return try? buildSubsonicURL(
            endpoint: "getCoverArt.view",
            extraItems: [
                URLQueryItem(name: "id", value: coverArtID),
                URLQueryItem(name: "size", value: String(size))
            ],
            config: config
        )
    }

    // MARK: - API Operations

    func ping(config: NavidromeConfig) async throws -> String {
        let root = try await callJSON(endpoint: "ping.view", config: config)
        let serverVersion = (root["serverVersion"] as? String) ?? (root["version"] as? String) ?? "Subsonic"
        let type = (root["type"] as? String) ?? "Navidrome"
        return "\(type) \(serverVersion)"
    }

    func fetchAlbums(type: String = "newest", size: Int = 40, config: NavidromeConfig) async throws -> [NavidromeAlbum] {
        let root = try await callJSON(
            endpoint: "getAlbumList2.view",
            extraItems: [
                URLQueryItem(name: "type", value: type),
                URLQueryItem(name: "size", value: String(size))
            ],
            config: config
        )
        let albumList2 = root["albumList2"] as? [String: Any]
        let list: [[String: Any]]
        if let arr = albumList2?["album"] as? [[String: Any]] {
            list = arr
        } else if let single = albumList2?["album"] as? [String: Any] {
            list = [single]
        } else {
            list = []
        }
        return list.compactMap(parseAlbum)
    }

    func fetchAlbumSongs(albumID: String, config: NavidromeConfig) async throws -> [NavidromeSong] {
        let root = try await callJSON(
            endpoint: "getAlbum.view",
            extraItems: [URLQueryItem(name: "id", value: albumID)],
            config: config
        )
        let songs = (root["album"] as? [String: Any])?["song"] as? [[String: Any]] ?? []
        return songs.compactMap(parseSong)
    }

    func fetchArtists(config: NavidromeConfig) async throws -> [NavidromeArtist] {
        let root = try await callJSON(endpoint: "getArtists.view", config: config)
        let indices = (root["artists"] as? [String: Any])?["index"] as? [[String: Any]] ?? []
        var out: [NavidromeArtist] = []
        for idx in indices {
            if let artists = idx["artist"] as? [[String: Any]] {
                for a in artists {
                    if let id = a["id"] as? String, let name = a["name"] as? String {
                        out.append(NavidromeArtist(
                            id: id,
                            name: name,
                            albumCount: (a["albumCount"] as? Int) ?? 0,
                            coverArt: a["coverArt"] as? String
                        ))
                    }
                }
            }
        }
        return out
    }

    func fetchArtistAlbums(artistID: String, config: NavidromeConfig) async throws -> [NavidromeAlbum] {
        let root = try await callJSON(
            endpoint: "getArtist.view",
            extraItems: [URLQueryItem(name: "id", value: artistID)],
            config: config
        )
        let albums = (root["artist"] as? [String: Any])?["album"] as? [[String: Any]] ?? []
        return albums.compactMap(parseAlbum)
    }

    func fetchPlaylists(config: NavidromeConfig) async throws -> [NavidromePlaylist] {
        let root = try await callJSON(endpoint: "getPlaylists.view", config: config)
        let list = (root["playlists"] as? [String: Any])?["playlist"] as? [[String: Any]] ?? []
        return list.compactMap { dict in
            guard let id = dict["id"] as? String, let name = dict["name"] as? String else { return nil }
            return NavidromePlaylist(
                id: id,
                name: name,
                songCount: (dict["songCount"] as? Int) ?? 0,
                duration: (dict["duration"] as? Int) ?? 0,
                coverArt: dict["coverArt"] as? String
            )
        }
    }

    func fetchPlaylistSongs(playlistID: String, config: NavidromeConfig) async throws -> [NavidromeSong] {
        let root = try await callJSON(
            endpoint: "getPlaylist.view",
            extraItems: [URLQueryItem(name: "id", value: playlistID)],
            config: config
        )
        let entries = (root["playlist"] as? [String: Any])?["entry"] as? [[String: Any]] ?? []
        return entries.compactMap(parseSong)
    }

    func search(query: String, config: NavidromeConfig) async throws -> (artists: [NavidromeArtist], albums: [NavidromeAlbum], songs: [NavidromeSong]) {
        let root = try await callJSON(
            endpoint: "search3.view",
            extraItems: [
                URLQueryItem(name: "query", value: query),
                URLQueryItem(name: "artistCount", value: "20"),
                URLQueryItem(name: "albumCount", value: "24"),
                URLQueryItem(name: "songCount", value: "40")
            ],
            config: config
        )
        let sr = root["searchResult3"] as? [String: Any] ?? [:]
        let artists = Self.extractDictArray(from: sr, key: "artist").compactMap { a -> NavidromeArtist? in
            guard let id = a["id"] as? String, let name = a["name"] as? String else { return nil }
            return NavidromeArtist(id: id, name: name, albumCount: (a["albumCount"] as? Int) ?? 0, coverArt: a["coverArt"] as? String)
        }
        let albums = Self.extractDictArray(from: sr, key: "album").compactMap(parseAlbum)
        let songs = Self.extractDictArray(from: sr, key: "song").compactMap(parseSong)
        return (artists, albums, songs)
    }

    private static func extractDictArray(from dict: [String: Any], key: String) -> [[String: Any]] {
        if let arr = dict[key] as? [[String: Any]] { return arr }
        if let single = dict[key] as? [String: Any] { return [single] }
        return []
    }

    func scrobble(songID: String, config: NavidromeConfig) async {
        _ = try? await callJSON(
            endpoint: "scrobble.view",
            extraItems: [
                URLQueryItem(name: "id", value: songID),
                URLQueryItem(name: "submission", value: "true")
            ],
            config: config
        )
    }

    // MARK: - Direct Offline Track & Album Caching (Independent of Mac Sync)

    private var offlineRootDir: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("MyEchoLibrary/NavidromeOffline", isDirectory: true)
    }

    private var offlineTracksDir: URL {
        offlineRootDir.appendingPathComponent("Tracks", isDirectory: true)
    }

    private var offlineArtworkDir: URL {
        offlineRootDir.appendingPathComponent("Artwork", isDirectory: true)
    }

    private var offlineManifestURL: URL {
        offlineRootDir.appendingPathComponent("navidrome_offline.json")
    }

    private func ensureOfflineDirs() {
        try? FileManager.default.createDirectory(at: offlineTracksDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: offlineArtworkDir, withIntermediateDirectories: true)
    }

    func loadOfflineTracks() -> [NavidromeOfflineTrack] {
        ensureOfflineDirs()
        guard let data = try? Data(contentsOf: offlineManifestURL) else { return [] }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let decoded = (try? dec.decode([NavidromeOfflineTrack].self, from: data)) ?? []
        return decoded.filter { FileManager.default.fileExists(atPath: offlineTracksDir.appendingPathComponent($0.localFileName).path) }
    }

    private func saveOfflineTracks(_ tracks: [NavidromeOfflineTrack]) {
        ensureOfflineDirs()
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted]
        if let data = try? enc.encode(tracks) {
            try? data.write(to: offlineManifestURL, options: .atomic)
        }
    }

    func localOfflineFileURL(forSongID songID: String) -> URL? {
        let existing = loadOfflineTracks()
        if let match = existing.first(where: { $0.id == songID }) {
            let url = offlineTracksDir.appendingPathComponent(match.localFileName)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return nil
    }

    func localOfflineArtworkURL(forCoverArtID coverArtID: String?) -> URL? {
        guard let coverArtID, !coverArtID.isEmpty else { return nil }
        let safe = coverArtID.replacingOccurrences(of: "/", with: "_")
        let url = offlineArtworkDir.appendingPathComponent("\(safe).jpg")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func offlineStorageBytes() -> Int64 {
        ensureOfflineDirs()
        var total: Int64 = 0
        for dir in [offlineTracksDir, offlineArtworkDir] {
            if let urls = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey]) {
                for u in urls {
                    if let sz = (try? u.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                        total += Int64(sz)
                    }
                }
            }
        }
        return total
    }

    func downloadSongOffline(_ song: NavidromeSong, config: NavidromeConfig) async throws -> [NavidromeOfflineTrack] {
        ensureOfflineDirs()
        var current = loadOfflineTracks()
        if current.contains(where: { $0.id == song.id }) {
            return current
        }
        guard let url = Self.streamURL(songID: song.id, config: config) else {
            throw NavidromeError.invalidURL
        }

        let (tempURL, resp) = try await session.download(from: url)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            try? FileManager.default.removeItem(at: tempURL)
            throw NavidromeError.httpError(http.statusCode)
        }

        let rawExt = (config.streamQuality == .original ? (song.suffix ?? "mp3") : "mp3").lowercased()
        let ext = rawExt.isEmpty ? "mp3" : rawExt
        let dest = offlineTracksDir.appendingPathComponent("\(song.id).\(ext)")
        if FileManager.default.fileExists(atPath: dest.path) {
            try? FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.moveItem(at: tempURL, to: dest)

        let attrs = try? FileManager.default.attributesOfItem(atPath: dest.path)
        let actualSize = (attrs?[.size] as? NSNumber)?.int64Value ?? (song.size ?? 0)

        // Cache artwork locally as well
        if let coverID = song.coverArt, !coverID.isEmpty, localOfflineArtworkURL(forCoverArtID: coverID) == nil,
           let artURL = Self.coverArtURL(coverArtID: coverID, size: 600, config: config),
           let (artData, artResp) = try? await session.data(from: artURL),
           let http = artResp as? HTTPURLResponse, (200...299).contains(http.statusCode) {
            let safe = coverID.replacingOccurrences(of: "/", with: "_")
            try? artData.write(to: offlineArtworkDir.appendingPathComponent("\(safe).jpg"), options: .atomic)
        }

        current = loadOfflineTracks()
        let record = NavidromeOfflineTrack(
            id: song.id,
            title: song.title,
            artist: song.artist,
            album: song.album,
            trackNumber: song.track,
            year: song.year,
            duration: TimeInterval(song.duration),
            format: ext,
            bitrate: config.streamQuality == .original ? song.bitRate : Int(config.streamQuality.rawValue),
            fileExtension: ext,
            fileSize: actualSize,
            coverArtID: song.coverArt,
            downloadedAt: Date()
        )
        current.removeAll { $0.id == song.id }
        current.insert(record, at: 0)
        saveOfflineTracks(current)
        return current
    }

    func removeOfflineSong(songID: String) -> [NavidromeOfflineTrack] {
        var current = loadOfflineTracks()
        if let match = current.first(where: { $0.id == songID }) {
            let url = offlineTracksDir.appendingPathComponent(match.localFileName)
            try? FileManager.default.removeItem(at: url)
        }
        current.removeAll { $0.id == songID }
        saveOfflineTracks(current)
        return current
    }

    // MARK: - Internals

    private func callJSON(
        endpoint: String,
        extraItems: [URLQueryItem] = [],
        config: NavidromeConfig
    ) async throws -> [String: Any] {
        let url = try Self.buildSubsonicURL(endpoint: endpoint, extraItems: extraItems, config: config)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            let host = url.host ?? config.serverURL
            throw NavidromeError.apiError("Cannot reach \(host): \(error.localizedDescription)")
        }
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw NavidromeError.httpError(http.statusCode)
        }
        guard let outer = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let root = outer["subsonic-response"] as? [String: Any] else {
            throw NavidromeError.apiError("Invalid Subsonic JSON response from \(url.host ?? config.serverURL)")
        }
        if (root["status"] as? String) == "failed" {
            let msg = ((root["error"] as? [String: Any])?["message"] as? String) ?? "Authentication or server error"
            throw NavidromeError.apiError(msg)
        }
        return root
    }

    private func parseAlbum(_ d: [String: Any]) -> NavidromeAlbum? {
        guard let id = d["id"] as? String,
              let name = (d["name"] as? String) ?? (d["title"] as? String) else { return nil }
        return NavidromeAlbum(
            id: id,
            name: name,
            artist: (d["artist"] as? String) ?? "Unknown Artist",
            artistId: d["artistId"] as? String,
            coverArt: d["coverArt"] as? String,
            songCount: (d["songCount"] as? Int) ?? 0,
            year: d["year"] as? Int,
            duration: (d["duration"] as? Int) ?? 0
        )
    }

    private func parseSong(_ d: [String: Any]) -> NavidromeSong? {
        guard let id = d["id"] as? String, let title = d["title"] as? String else { return nil }
        return NavidromeSong(
            id: id,
            title: title,
            artist: (d["artist"] as? String) ?? "Unknown Artist",
            album: (d["album"] as? String) ?? "Unknown Album",
            albumId: d["albumId"] as? String,
            track: d["track"] as? Int,
            year: d["year"] as? Int,
            duration: (d["duration"] as? Int) ?? 0,
            bitRate: d["bitRate"] as? Int,
            suffix: d["suffix"] as? String,
            coverArt: d["coverArt"] as? String,
            size: (d["size"] as? NSNumber)?.int64Value
        )
    }
}

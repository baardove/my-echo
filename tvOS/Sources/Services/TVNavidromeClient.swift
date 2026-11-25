import Foundation
import CryptoKit

enum TVNavidromeError: LocalizedError {
    case invalidURL
    case notConfigured
    case apiError(String)
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid Navidrome URL. Example: http://192.168.0.10:4533"
        case .notConfigured: return "Configure your Navidrome server URL, username, and password first."
        case .apiError(let msg): return "Navidrome error: \(msg)"
        case .httpError(let code): return "Navidrome HTTP error \(code)"
        }
    }
}

/// Pure-Swift OpenSubsonic / Navidrome client for Apple TV streaming over LAN or Tailscale.
actor TVNavidromeClient {
    private let session: URLSession

    init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 15
        cfg.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: cfg)
    }

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
        config: TVNavidromeConfig
    ) throws -> URL {
        guard let base = normalizeBaseURL(config.serverURL) else {
            throw TVNavidromeError.invalidURL
        }
        guard config.isConfigured else {
            throw TVNavidromeError.notConfigured
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
            URLQueryItem(name: "c", value: "MyEchoTV"),
            URLQueryItem(name: "f", value: "json")
        ]
        items.append(contentsOf: extraItems)
        comps?.queryItems = items
        guard let url = comps?.url else { throw TVNavidromeError.invalidURL }
        return url
    }

    static func streamURL(songID: String, config: TVNavidromeConfig) -> URL? {
        var extra = [URLQueryItem(name: "id", value: songID)]
        if let bitRate = config.streamQuality.maxBitRateParam {
            extra.append(URLQueryItem(name: "maxBitRate", value: bitRate))
            extra.append(URLQueryItem(name: "format", value: "mp3"))
        } else {
            extra.append(URLQueryItem(name: "format", value: "raw"))
        }
        return try? buildSubsonicURL(endpoint: "stream.view", extraItems: extra, config: config)
    }

    static func coverArtURL(coverArtID: String?, size: Int = 600, config: TVNavidromeConfig) -> URL? {
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

    func ping(config: TVNavidromeConfig) async throws -> String {
        let root = try await callJSON(endpoint: "ping.view", config: config)
        let serverVersion = (root["serverVersion"] as? String) ?? (root["version"] as? String) ?? "Subsonic"
        let type = (root["type"] as? String) ?? "Navidrome"
        return "\(type) \(serverVersion)"
    }

    func fetchAlbums(type: String = "newest", size: Int = 50, config: TVNavidromeConfig) async throws -> [TVNavidromeAlbum] {
        let root = try await callJSON(
            endpoint: "getAlbumList2.view",
            extraItems: [
                URLQueryItem(name: "type", value: type),
                URLQueryItem(name: "size", value: String(size))
            ],
            config: config
        )
        let albumList2 = root["albumList2"] as? [String: Any] ?? [:]
        return Self.extractDictArray(from: albumList2, key: "album").compactMap(parseAlbum)
    }

    func fetchAlbumSongs(albumID: String, config: TVNavidromeConfig) async throws -> [TVNavidromeSong] {
        let root = try await callJSON(
            endpoint: "getAlbum.view",
            extraItems: [URLQueryItem(name: "id", value: albumID)],
            config: config
        )
        let albumDict = root["album"] as? [String: Any] ?? [:]
        return Self.extractDictArray(from: albumDict, key: "song").compactMap(parseSong)
    }

    func fetchArtists(config: TVNavidromeConfig) async throws -> [TVNavidromeArtist] {
        let root = try await callJSON(endpoint: "getArtists.view", config: config)
        let indices = (root["artists"] as? [String: Any])?["index"] as? [[String: Any]] ?? []
        var out: [TVNavidromeArtist] = []
        for idx in indices {
            for a in Self.extractDictArray(from: idx, key: "artist") {
                if let id = a["id"] as? String, let name = a["name"] as? String {
                    out.append(TVNavidromeArtist(
                        id: id,
                        name: name,
                        albumCount: (a["albumCount"] as? Int) ?? 0,
                        coverArt: a["coverArt"] as? String
                    ))
                }
            }
        }
        return out
    }

    func fetchArtistAlbums(artistID: String, config: TVNavidromeConfig) async throws -> [TVNavidromeAlbum] {
        let root = try await callJSON(
            endpoint: "getArtist.view",
            extraItems: [URLQueryItem(name: "id", value: artistID)],
            config: config
        )
        let artistDict = root["artist"] as? [String: Any] ?? [:]
        return Self.extractDictArray(from: artistDict, key: "album").compactMap(parseAlbum)
    }

    func fetchPlaylists(config: TVNavidromeConfig) async throws -> [TVNavidromePlaylist] {
        let root = try await callJSON(endpoint: "getPlaylists.view", config: config)
        let playlistsDict = root["playlists"] as? [String: Any] ?? [:]
        return Self.extractDictArray(from: playlistsDict, key: "playlist").compactMap { dict in
            guard let id = dict["id"] as? String, let name = dict["name"] as? String else { return nil }
            return TVNavidromePlaylist(
                id: id,
                name: name,
                songCount: (dict["songCount"] as? Int) ?? 0,
                duration: (dict["duration"] as? Int) ?? 0,
                coverArt: dict["coverArt"] as? String
            )
        }
    }

    func fetchPlaylistSongs(playlistID: String, config: TVNavidromeConfig) async throws -> [TVNavidromeSong] {
        let root = try await callJSON(
            endpoint: "getPlaylist.view",
            extraItems: [URLQueryItem(name: "id", value: playlistID)],
            config: config
        )
        let plDict = root["playlist"] as? [String: Any] ?? [:]
        return Self.extractDictArray(from: plDict, key: "entry").compactMap(parseSong)
    }

    func search(query: String, config: TVNavidromeConfig) async throws -> (artists: [TVNavidromeArtist], albums: [TVNavidromeAlbum], songs: [TVNavidromeSong]) {
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
        let artists = Self.extractDictArray(from: sr, key: "artist").compactMap { a -> TVNavidromeArtist? in
            guard let id = a["id"] as? String, let name = a["name"] as? String else { return nil }
            return TVNavidromeArtist(id: id, name: name, albumCount: (a["albumCount"] as? Int) ?? 0, coverArt: a["coverArt"] as? String)
        }
        let albums = Self.extractDictArray(from: sr, key: "album").compactMap(parseAlbum)
        let songs = Self.extractDictArray(from: sr, key: "song").compactMap(parseSong)
        return (artists, albums, songs)
    }

    func scrobble(songID: String, config: TVNavidromeConfig) async {
        _ = try? await callJSON(
            endpoint: "scrobble.view",
            extraItems: [
                URLQueryItem(name: "id", value: songID),
                URLQueryItem(name: "submission", value: "true")
            ],
            config: config
        )
    }

    // MARK: - Internals

    private static func extractDictArray(from dict: [String: Any], key: String) -> [[String: Any]] {
        if let arr = dict[key] as? [[String: Any]] { return arr }
        if let single = dict[key] as? [String: Any] { return [single] }
        return []
    }

    private func callJSON(
        endpoint: String,
        extraItems: [URLQueryItem] = [],
        config: TVNavidromeConfig
    ) async throws -> [String: Any] {
        let url = try Self.buildSubsonicURL(endpoint: endpoint, extraItems: extraItems, config: config)
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw TVNavidromeError.httpError(http.statusCode)
        }
        guard let outer = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let root = outer["subsonic-response"] as? [String: Any] else {
            throw TVNavidromeError.apiError("Invalid Subsonic JSON response")
        }
        if (root["status"] as? String) == "failed" {
            let msg = ((root["error"] as? [String: Any])?["message"] as? String) ?? "Authentication or server error"
            throw TVNavidromeError.apiError(msg)
        }
        return root
    }

    private func parseAlbum(_ d: [String: Any]) -> TVNavidromeAlbum? {
        guard let id = d["id"] as? String,
              let name = (d["name"] as? String) ?? (d["title"] as? String) else { return nil }
        return TVNavidromeAlbum(
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

    private func parseSong(_ d: [String: Any]) -> TVNavidromeSong? {
        guard let id = d["id"] as? String, let title = d["title"] as? String else { return nil }
        return TVNavidromeSong(
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

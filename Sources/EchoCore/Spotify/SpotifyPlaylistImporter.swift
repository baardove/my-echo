import Foundation

// MARK: - Spotify Playlist Import Models

public struct SpotifyTrackItem: Identifiable, Hashable, Sendable {
    public var id: String
    public var uri: String
    public var title: String
    public var artist: String
    public var album: String?
    public var duration: TimeInterval
    public var isExplicit: Bool
    public var artworkURL: String?

    public init(
        id: String,
        uri: String,
        title: String,
        artist: String,
        album: String? = nil,
        duration: TimeInterval = 0,
        isExplicit: Bool = false,
        artworkURL: String? = nil
    ) {
        self.id = id
        self.uri = uri
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.isExplicit = isExplicit
        self.artworkURL = artworkURL
    }
}

public struct SpotifyPlaylistPayload: Hashable, Sendable {
    public var playlistID: String
    public var sourceURL: String
    public var name: String
    public var ownerName: String?
    public var coverURL: String?
    public var tracks: [SpotifyTrackItem]
    /// Spotify's public embed endpoint returns up to 100 tracks without OAuth
    public var hitPublicEmbedCap: Bool

    public init(
        playlistID: String,
        sourceURL: String,
        name: String,
        ownerName: String? = nil,
        coverURL: String? = nil,
        tracks: [SpotifyTrackItem],
        hitPublicEmbedCap: Bool = false
    ) {
        self.playlistID = playlistID
        self.sourceURL = sourceURL
        self.name = name
        self.ownerName = ownerName
        self.coverURL = coverURL
        self.tracks = tracks
        self.hitPublicEmbedCap = hitPublicEmbedCap
    }
}

public enum SpotifyTrackMatchResult: Identifiable, Hashable, Sendable {
    case matched(spotify: SpotifyTrackItem, local: Track, confidence: Int)
    case missing(spotify: SpotifyTrackItem)

    public var id: String {
        switch self {
        case .matched(let sp, _, _): return "matched:\(sp.id):\(sp.title)"
        case .missing(let sp): return "missing:\(sp.id):\(sp.title)"
        }
    }

    public var spotifyTrack: SpotifyTrackItem {
        switch self {
        case .matched(let sp, _, _): return sp
        case .missing(let sp): return sp
        }
    }

    public var localTrack: Track? {
        switch self {
        case .matched(_, let local, _): return local
        case .missing: return nil
        }
    }

    public var isMissing: Bool {
        if case .missing = self { return true }
        return false
    }
}

public struct SpotifyPlaylistMatchReport: Sendable {
    public var payload: SpotifyPlaylistPayload
    public var entries: [SpotifyTrackMatchResult]

    public var matchedCount: Int {
        entries.reduce(0) { $0 + ($1.isMissing ? 0 : 1) }
    }

    public var missingCount: Int {
        entries.reduce(0) { $0 + ($1.isMissing ? 1 : 0) }
    }

    public var totalCount: Int {
        entries.count
    }

    public init(payload: SpotifyPlaylistPayload, entries: [SpotifyTrackMatchResult]) {
        self.payload = payload
        self.entries = entries
    }

    /// Converts the match report into a persisted `Playlist` retaining exact order with missing track placeholders.
    public func buildPlaylist(customName: String? = nil, customDescription: String? = nil) -> Playlist {
        let chosenName = (customName ?? payload.name).trimmingCharacters(in: .whitespacesAndNewlines)
        let defaultDesc: String = {
            if let owner = payload.ownerName, !owner.isEmpty {
                return "Imported from Spotify (by \(owner))"
            }
            return "Imported from Spotify"
        }()
        let chosenDesc = customDescription ?? defaultDesc

        var orderedIDs: [String] = []
        var missingList: [MissingPlaylistTrack] = []
        var usedMissingIDs: Set<String> = []

        for entry in entries {
            switch entry {
            case .matched(_, let local, _):
                orderedIDs.append(local.id)
            case .missing(let sp):
                var placeholderID = "\(Playlist.missingTrackIDPrefix)spotify:\(sp.id)"
                if !usedMissingIDs.insert(placeholderID).inserted {
                    placeholderID = "\(Playlist.missingTrackIDPrefix)spotify:\(sp.id):\(orderedIDs.count)"
                    usedMissingIDs.insert(placeholderID)
                }
                orderedIDs.append(placeholderID)
                missingList.append(MissingPlaylistTrack(
                    id: placeholderID,
                    title: sp.title,
                    artist: sp.artist,
                    album: sp.album,
                    duration: sp.duration,
                    spotifyTrackID: sp.id,
                    spotifyURI: sp.uri,
                    artworkURL: sp.artworkURL,
                    lidarrStatus: .missing
                ))
            }
        }

        return Playlist(
            name: chosenName.isEmpty ? "Spotify Playlist" : chosenName,
            description: chosenDesc,
            trackIDs: orderedIDs,
            missingTracks: missingList,
            spotifyPlaylistID: payload.playlistID,
            spotifySourceURL: payload.sourceURL
        )
    }
}

public enum SpotifyImportError: LocalizedError, Equatable {
    case invalidURL
    case playlistNotFoundOrPrivate
    case emptyPlaylist
    case networkError(String)
    case parseError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Enter a valid Spotify playlist link (e.g. https://open.spotify.com/playlist/...) or URI."
        case .playlistNotFoundOrPrivate:
            return "Could not load this Spotify playlist. Make sure the playlist is set to Public in Spotify."
        case .emptyPlaylist:
            return "This Spotify playlist doesn't contain any tracks."
        case .networkError(let msg):
            return "Could not reach Spotify: \(msg)"
        case .parseError(let msg):
            return "Could not read Spotify playlist data: \(msg)"
        }
    }
}

/// Zero-config Spotify public playlist importer + local library track matcher + metadata enrichment.
public actor SpotifyPlaylistImporter {
    private let session: URLSession

    public init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 16
        cfg.timeoutIntervalForResource = 35
        cfg.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Safari/605.1.15",
            "Accept-Language": "en-US,en;q=0.9"
        ]
        self.session = URLSession(configuration: cfg)
    }

    // MARK: - URL / URI Parsing (Public for Unit Tests)

    /// Extracts a Spotify playlist ID from open.spotify.com URLs, embed URLs, user playlist URLs,
    /// `spotify:playlist:...` URIs, or a raw 22-character Base62 playlist ID.
    public static func parsePlaylistID(from rawInput: String) -> String? {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // 1. spotify:playlist:<id> or spotify:user:<user>:playlist:<id>
        let lower = trimmed.lowercased()
        if lower.hasPrefix("spotify:") {
            let parts = trimmed.split(separator: ":").map(String.init)
            if let plIdx = parts.firstIndex(where: { $0.caseInsensitiveCompare("playlist") == .orderedSame }),
               plIdx + 1 < parts.count {
                let candidate = parts[plIdx + 1].trimmingCharacters(in: .whitespacesAndNewlines)
                if isValidSpotifyID(candidate) {
                    return candidate
                }
            }
            return nil
        }

        // 2. HTTP(S) URL: open.spotify.com/playlist/<id>, /embed/playlist/<id>, /intl-xx/playlist/<id>, /user/.../playlist/<id>
        let urlCandidate: URL? = {
            if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
                return URL(string: trimmed)
            }
            if lower.contains("spotify.com/") || lower.contains("spotify.link/") || lower.contains("spoti.fi/") {
                return URL(string: "https://" + trimmed)
            }
            return nil
        }()

        if let url = urlCandidate {
            let pathSegments = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
            if let plIdx = pathSegments.firstIndex(where: { $0.caseInsensitiveCompare("playlist") == .orderedSame }),
               plIdx + 1 < pathSegments.count {
                let candidate = pathSegments[plIdx + 1]
                if isValidSpotifyID(candidate) {
                    return candidate
                }
            }
            return nil
        }

        // 3. Raw 22-char Spotify Base62 ID
        if isValidSpotifyID(trimmed), trimmed.count >= 16 {
            return trimmed
        }

        return nil
    }

    private static func isValidSpotifyID(_ s: String) -> Bool {
        guard s.count >= 10 && s.count <= 40 else { return false }
        return s.unicodeScalars.allSatisfy {
            CharacterSet.alphanumerics.contains($0)
        }
    }

    public static func isShortSpotifyLink(_ rawInput: String) -> Bool {
        let lower = rawInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return lower.contains("spotify.link/") || lower.contains("spoti.fi/")
    }

    // MARK: - Fetch Public Playlist

    public func fetchPlaylist(from rawInput: String) async throws -> SpotifyPlaylistPayload {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SpotifyImportError.invalidURL }

        var playlistID = Self.parsePlaylistID(from: trimmed)
        var resolvedSourceURL = trimmed

        // Resolve spotify.link / spoti.fi short links by following redirects
        if playlistID == nil && Self.isShortSpotifyLink(trimmed) {
            let normalized = trimmed.lowercased().hasPrefix("http") ? trimmed : "https://\(trimmed)"
            if let shortURL = URL(string: normalized) {
                var req = URLRequest(url: shortURL)
                req.httpMethod = "GET"
                if let (_, resp) = try? await session.data(for: req),
                   let finalURL = resp.url?.absoluteString {
                    resolvedSourceURL = finalURL
                    playlistID = Self.parsePlaylistID(from: finalURL)
                }
            }
        }

        guard let playlistID else {
            throw SpotifyImportError.invalidURL
        }

        let canonicalURL = "https://open.spotify.com/playlist/\(playlistID)"
        guard let embedURL = URL(string: "https://open.spotify.com/embed/playlist/\(playlistID)") else {
            throw SpotifyImportError.invalidURL
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: embedURL)
        } catch {
            throw SpotifyImportError.networkError(error.localizedDescription)
        }

        if let http = response as? HTTPURLResponse {
            if http.statusCode == 404 || http.statusCode == 403 {
                throw SpotifyImportError.playlistNotFoundOrPrivate
            }
            if !(200...299).contains(http.statusCode) {
                throw SpotifyImportError.networkError("HTTP \(http.statusCode)")
            }
        }

        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw SpotifyImportError.parseError("Unreadable response encoding")
        }

        return try Self.parseEmbedHTML(
            html,
            playlistID: playlistID,
            sourceURL: resolvedSourceURL.lowercased().hasPrefix("http") ? resolvedSourceURL : canonicalURL
        )
    }

    // MARK: - Embed HTML / __NEXT_DATA__ Parser (Public for Unit Tests)

    public static func parseEmbedHTML(
        _ html: String,
        playlistID: String,
        sourceURL: String
    ) throws -> SpotifyPlaylistPayload {
        // Extract <script id="__NEXT_DATA__" type="application/json">...</script>
        let markerPattern = #"<script\s+id="__NEXT_DATA__"[^>]*>(.*?)</script>"#
        guard let regex = try? NSRegularExpression(pattern: markerPattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) else {
            throw SpotifyImportError.parseError("Internal regex error")
        }
        let nsHTML = html as NSString
        guard let match = regex.firstMatch(in: html, range: NSRange(location: 0, length: nsHTML.length)),
              match.numberOfRanges >= 2 else {
            throw SpotifyImportError.playlistNotFoundOrPrivate
        }
        let jsonString = nsHTML.substring(with: match.range(at: 1))
        guard let jsonData = jsonString.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw SpotifyImportError.parseError("Invalid JSON payload")
        }

        guard let props = root["props"] as? [String: Any],
              let pageProps = props["pageProps"] as? [String: Any],
              let state = pageProps["state"] as? [String: Any],
              let dataObj = state["data"] as? [String: Any],
              let entity = dataObj["entity"] as? [String: Any] else {
            throw SpotifyImportError.playlistNotFoundOrPrivate
        }

        let rawName = (entity["name"] as? String) ?? (entity["title"] as? String) ?? "Spotify Playlist"
        let name = cleanSpotifyText(rawName)
        let owner = (entity["subtitle"] as? String).map(cleanSpotifyText).flatMap { $0.isEmpty ? nil : $0 }

        var coverURL: String? = nil
        if let coverArt = entity["coverArt"] as? [String: Any],
           let sources = coverArt["sources"] as? [[String: Any]] {
            coverURL = sources.first?["url"] as? String
        }
        if coverURL == nil,
           let visual = entity["visualIdentity"] as? [String: Any],
           let images = visual["image"] as? [[String: Any]] {
            coverURL = images.first?["url"] as? String
        }

        let rawTrackList = (entity["trackList"] as? [[String: Any]]) ?? []
        var tracks: [SpotifyTrackItem] = []
        tracks.reserveCapacity(rawTrackList.count)

        for (idx, item) in rawTrackList.enumerated() {
            let title = cleanSpotifyText((item["title"] as? String) ?? "")
            guard !title.isEmpty else { continue }
            let artist = cleanSpotifyText((item["subtitle"] as? String) ?? "")
            let uri = (item["uri"] as? String) ?? ""
            let trackID: String = {
                if uri.hasPrefix("spotify:track:") {
                    return String(uri.dropFirst("spotify:track:".count))
                }
                if let uid = item["uid"] as? String, !uid.isEmpty {
                    return uid
                }
                return "sp-\(playlistID)-\(idx)"
            }()
            let durationMs = (item["duration"] as? NSNumber)?.doubleValue ?? 0
            let isExplicit = (item["isExplicit"] as? Bool) ?? false

            tracks.append(SpotifyTrackItem(
                id: trackID,
                uri: uri.isEmpty ? "spotify:track:\(trackID)" : uri,
                title: title,
                artist: artist,
                album: nil,
                duration: durationMs / 1000.0,
                isExplicit: isExplicit,
                artworkURL: nil
            ))
        }

        guard !tracks.isEmpty else {
            throw SpotifyImportError.emptyPlaylist
        }

        return SpotifyPlaylistPayload(
            playlistID: playlistID,
            sourceURL: sourceURL,
            name: name.isEmpty ? "Spotify Playlist" : name,
            ownerName: owner,
            coverURL: coverURL,
            tracks: tracks,
            hitPublicEmbedCap: tracks.count >= 100
        )
    }

    public static func cleanSpotifyText(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{200B}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Lightweight Artwork & Album Enrichment for Missing Tracks

    /// Fetches a track's cover thumbnail URL via Spotify's public oEmbed endpoint (no API key required).
    public func fetchSpotifyTrackThumbnailURL(spotifyTrackID: String) async -> String? {
        guard !spotifyTrackID.isEmpty,
              let url = URL(string: "https://open.spotify.com/oembed?url=https://open.spotify.com/track/\(spotifyTrackID)") else {
            return nil
        }
        guard let (data, resp) = try? await session.data(from: url),
              let http = resp as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let thumb = obj["thumbnail_url"] as? String,
              !thumb.isEmpty else {
            return nil
        }
        return thumb
    }

    public struct ResolvedTrackAlbumInfo: Sendable {
        public var albumTitle: String
        public var artistName: String
        public var artworkURL: String?
        public var musicBrainzReleaseGroupID: String?
    }

    /// Resolves a missing track's parent album & artwork via Deezer public catalog (with MusicBrainz fallback)
    /// so Lidarr can search & order the exact parent album automatically.
    public func resolveAlbumInfoForMissingTrack(title: String, artist: String) async -> ResolvedTrackAlbumInfo? {
        let primaryArtist = ArtistNameParser.artistNames(artist).first ?? artist
        let cleanTitle = Self.stripSpotifyTitleSuffixes(title)
        let normTargetTitle = Self.normalizeForMatching(cleanTitle)
        let normTargetArtists = Self.normalizedArtistTokens(artist)

        struct DZResp: Decodable { let data: [DZTrack] }
        struct DZTrack: Decodable {
            let title: String
            let title_short: String?
            let artist: DZArtist
            let album: DZAlbum?
        }
        struct DZArtist: Decodable { let name: String }
        struct DZAlbum: Decodable {
            let title: String
            let cover_medium: String?
            let cover_big: String?
        }

        // 1. Try Deezer public track search (strict artist+track query, then looser query)
        let cleanArtistForQ = primaryArtist.replacingOccurrences(of: "\"", with: "")
        let cleanTitleForQ = cleanTitle.replacingOccurrences(of: "\"", with: "")
        let queries = [
            "artist:\"\(cleanArtistForQ)\" track:\"\(cleanTitleForQ)\"",
            "\(cleanArtistForQ) \(cleanTitleForQ)"
        ]

        for query in queries {
            guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: "https://api.deezer.com/search/track?q=\(encoded)&limit=10"),
                  let (data, _) = try? await session.data(from: url),
                  let decoded = try? JSONDecoder().decode(DZResp.self, from: data),
                  !decoded.data.isEmpty else {
                continue
            }

            if let best = decoded.data.first(where: { item in
                let tNorm = Self.normalizeForMatching(item.title_short ?? item.title)
                let tFull = Self.normalizeForMatching(item.title)
                let titleMatch = tNorm == normTargetTitle || tFull == normTargetTitle
                    || (normTargetTitle.count >= 4 && (tNorm.contains(normTargetTitle) || normTargetTitle.contains(tNorm)))
                let itemArtists = Self.normalizedArtistTokens(item.artist.name)
                let artistMatch = !normTargetArtists.isDisjoint(with: itemArtists)
                    || normTargetArtists.contains(where: { a in itemArtists.contains(where: { $0.contains(a) || a.contains($0) }) })
                return titleMatch && artistMatch && !(item.album?.title ?? "").isEmpty
            }) {
                return ResolvedTrackAlbumInfo(
                    albumTitle: best.album?.title ?? cleanTitle,
                    artistName: best.artist.name,
                    artworkURL: best.album?.cover_medium ?? best.album?.cover_big,
                    musicBrainzReleaseGroupID: nil
                )
            }
        }

        // 2. Fallback: MusicBrainz recording search (returns release-group MBID for exact Lidarr lookup!)
        let mbQuery = "recording:\"\(cleanTitleForQ)\" AND artist:\"\(cleanArtistForQ)\""
        if let encoded = mbQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://musicbrainz.org/ws/2/recording?query=\(encoded)&fmt=json&limit=5") {
            var req = URLRequest(url: url)
            req.timeoutInterval = 8
            req.setValue("MyEcho/1.4 (https://github.com/baardove/my-echo)", forHTTPHeaderField: "User-Agent")
            req.setValue("application/json", forHTTPHeaderField: "Accept")

            struct MBRecResp: Decodable { let recordings: [MBRecording]? }
            struct MBRecording: Decodable {
                let title: String
                let releases: [MBRelease]?
            }
            struct MBRelease: Decodable {
                let title: String
                let releaseGroup: MBReleaseGroup?
                enum CodingKeys: String, CodingKey {
                    case title
                    case releaseGroup = "release-group"
                }
            }
            struct MBReleaseGroup: Decodable {
                let id: String
                let title: String?
                let primaryType: String?
                enum CodingKeys: String, CodingKey {
                    case id, title
                    case primaryType = "primary-type"
                }
            }

            if let (data, resp) = try? await session.data(for: req),
               let http = resp as? HTTPURLResponse,
               (200...299).contains(http.statusCode),
               let decoded = try? JSONDecoder().decode(MBRecResp.self, from: data),
               let rec = decoded.recordings?.first,
               let rel = rec.releases?.first(where: { ($0.releaseGroup?.primaryType ?? "").lowercased() == "album" }) ?? rec.releases?.first {
                let rgID = rel.releaseGroup?.id
                return ResolvedTrackAlbumInfo(
                    albumTitle: rel.releaseGroup?.title ?? rel.title,
                    artistName: primaryArtist,
                    artworkURL: rgID.map { "https://coverartarchive.org/release-group/\($0)/front-250" },
                    musicBrainzReleaseGroupID: rgID
                )
            }
        }

        return nil
    }

    // MARK: - Local Library Matching Engine (Pure Static, Fast & Unit-Testable)

    /// Matches imported Spotify tracks against the user's local/NAS library tracks.
    public static func matchTracks(
        _ spotifyTracks: [SpotifyTrackItem],
        against libraryTracks: [Track]
    ) -> [SpotifyTrackMatchResult] {
        guard !spotifyTracks.isEmpty else { return [] }
        let index = LibraryMatchIndex(tracks: libraryTracks)
        return spotifyTracks.map { sp in
            if let hit = index.bestMatch(title: sp.title, artist: sp.artist, duration: sp.duration) {
                return .matched(spotify: sp, local: hit.track, confidence: hit.score)
            }
            return .missing(spotify: sp)
        }
    }

    /// Re-checks a playlist's retained missing tracks against the current library.
    /// Any newly available tracks replace their placeholder ID in-place (preserving exact playlist order!).
    public static func resolveMissingTracks(
        in playlist: Playlist,
        against libraryTracks: [Track]
    ) -> (updatedPlaylist: Playlist, resolvedCount: Int) {
        guard !playlist.missingTracks.isEmpty else {
            return (playlist, 0)
        }
        let index = LibraryMatchIndex(tracks: libraryTracks)
        let missingByID = playlist.missingTracksByID

        var updated = playlist
        var resolvedMissingIDs: Set<String> = []
        var newTrackIDs: [String] = []
        newTrackIDs.reserveCapacity(playlist.trackIDs.count)

        for tid in playlist.trackIDs {
            if Playlist.isMissingTrackID(tid), let missing = missingByID[tid] {
                if let hit = index.bestMatch(title: missing.title, artist: missing.artist, duration: missing.duration) {
                    newTrackIDs.append(hit.track.id)
                    resolvedMissingIDs.insert(tid)
                } else {
                    newTrackIDs.append(tid)
                }
            } else {
                newTrackIDs.append(tid)
            }
        }

        guard !resolvedMissingIDs.isEmpty else {
            return (playlist, 0)
        }

        updated.trackIDs = newTrackIDs
        updated.missingTracks.removeAll { resolvedMissingIDs.contains($0.id) }
        updated.updatedAt = Date()
        return (updated, resolvedMissingIDs.count)
    }

    // MARK: - Normalization & Fast Index Helpers

    public static func stripSpotifyTitleSuffixes(_ raw: String) -> String {
        var s = cleanSpotifyText(raw)
        let patterns = [
            #"\s*-\s*(?:remaster(?:ed)?|20\d\d|19\d\d|deluxe|bonus|radio\s+edit|single\s+version|album\s+version|mono|stereo|live|acoustic|acap+el+a(?:\s+version)?|instrumental|from\s+["“].*|anniversary).*$"#,
            #"\s*[\(\[]([^)\]]*(?:remaster|deluxe|bonus|radio\s+edit|album\s+version|single\s+version|explicit|clean|mono|stereo|anniversary|expanded|special\s+edition|feat\.?|ft\.?|featuring|from\s+["“])[^)\]]*)[\)\]]"#
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(s.startIndex..<s.endIndex, in: s)
                s = regex.stringByReplacingMatches(in: s, range: range, withTemplate: "")
            }
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func normalizeForMatching(_ raw: String) -> String {
        let base = OnlinePopularityService.normalizeTitleForMatching(cleanSpotifyText(raw))
        return base
    }

    public static func strictNormalizeTitle(_ raw: String) -> String {
        let folded = cleanSpotifyText(raw)
            .lowercased()
            .folding(options: [.diacriticInsensitive, .widthInsensitive], locale: .current)
        let scalars = folded.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : " " }
        return String(scalars)
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    public static func normalizedArtistTokens(_ raw: String) -> Set<String> {
        let cleaned = cleanSpotifyText(raw)
        guard !cleaned.isEmpty else { return [] }
        var out: Set<String> = []
        let parsed = ArtistNameParser.artistNames(cleaned)
        for name in parsed + [cleaned] {
            let norm = strictNormalizeTitle(name)
            if norm.hasPrefix("the ") && norm.count > 4 {
                out.insert(String(norm.dropFirst(4)))
            }
            if !norm.isEmpty {
                out.insert(norm)
            }
            // Also handle "&" vs "and"
            if norm.contains(" and ") {
                out.insert(norm.replacingOccurrences(of: " and ", with: " "))
            }
        }
        return out
    }

    private struct IndexedTrack {
        let track: Track
        let strictTitle: String
        let baseTitle: String
        let strippedTitle: String
        let artistTokens: Set<String>
        let fullArtistNorm: String
    }

    private struct LibraryMatchIndex {
        let entries: [IndexedTrack]
        let byBaseTitle: [String: [Int]]
        let byStrippedTitle: [String: [Int]]
        let byArtistToken: [String: [Int]]

        init(tracks: [Track]) {
            var list: [IndexedTrack] = []
            list.reserveCapacity(tracks.count)
            var baseMap: [String: [Int]] = [:]
            var strippedMap: [String: [Int]] = [:]
            var artistMap: [String: [Int]] = [:]

            for (idx, t) in tracks.enumerated() {
                let strictT = SpotifyPlaylistImporter.strictNormalizeTitle(t.title)
                let baseT = SpotifyPlaylistImporter.normalizeForMatching(t.title)
                let strippedT = SpotifyPlaylistImporter.normalizeForMatching(SpotifyPlaylistImporter.stripSpotifyTitleSuffixes(t.title))
                var aTokens = SpotifyPlaylistImporter.normalizedArtistTokens(t.artist)
                if !t.albumArtist.isEmpty {
                    aTokens.formUnion(SpotifyPlaylistImporter.normalizedArtistTokens(t.albumArtist))
                }
                let fullArtist = SpotifyPlaylistImporter.strictNormalizeTitle(t.artist.isEmpty ? t.albumArtist : t.artist)

                list.append(IndexedTrack(
                    track: t,
                    strictTitle: strictT,
                    baseTitle: baseT,
                    strippedTitle: strippedT,
                    artistTokens: aTokens,
                    fullArtistNorm: fullArtist
                ))

                if !baseT.isEmpty { baseMap[baseT, default: []].append(idx) }
                if !strippedT.isEmpty && strippedT != baseT { strippedMap[strippedT, default: []].append(idx) }
                for tok in aTokens where !tok.isEmpty {
                    artistMap[tok, default: []].append(idx)
                }
            }

            self.entries = list
            self.byBaseTitle = baseMap
            self.byStrippedTitle = strippedMap
            self.byArtistToken = artistMap
        }

        func bestMatch(title: String, artist: String, duration: TimeInterval) -> (track: Track, score: Int)? {
            let spStrict = SpotifyPlaylistImporter.strictNormalizeTitle(title)
            let spBase = SpotifyPlaylistImporter.normalizeForMatching(title)
            let spStripped = SpotifyPlaylistImporter.normalizeForMatching(SpotifyPlaylistImporter.stripSpotifyTitleSuffixes(title))
            let spArtists = SpotifyPlaylistImporter.normalizedArtistTokens(artist)
            let spFullArtist = SpotifyPlaylistImporter.strictNormalizeTitle(artist)

            guard !spBase.isEmpty || !spStrict.isEmpty else { return nil }

            // Gather candidate indices in O(1) from title & artist buckets
            var candidateIndices: Set<Int> = []
            if let list = byBaseTitle[spBase] { candidateIndices.formUnion(list) }
            if let list = byStrippedTitle[spBase] { candidateIndices.formUnion(list) }
            if let list = byBaseTitle[spStripped] { candidateIndices.formUnion(list) }
            if let list = byStrippedTitle[spStripped] { candidateIndices.formUnion(list) }
            for tok in spArtists {
                if let list = byArtistToken[tok] {
                    candidateIndices.formUnion(list)
                }
            }

            guard !candidateIndices.isEmpty else { return nil }

            var bestEntry: IndexedTrack? = nil
            var bestScore = 0

            for idx in candidateIndices {
                let entry = entries[idx]

                // 1. Title score
                var titleScore = 0
                if !spStrict.isEmpty && entry.strictTitle == spStrict {
                    titleScore = 100
                } else if !spBase.isEmpty && entry.baseTitle == spBase {
                    titleScore = 88
                } else if !spStripped.isEmpty && (entry.strippedTitle == spStripped || entry.baseTitle == spStripped) {
                    titleScore = 76
                } else if spStripped.count >= 5 && entry.strippedTitle.count >= 5 {
                    if entry.strippedTitle.contains(spStripped) || spStripped.contains(entry.strippedTitle) {
                        let minLen = min(entry.strippedTitle.count, spStripped.count)
                        let maxLen = max(entry.strippedTitle.count, spStripped.count)
                        if Double(minLen) / Double(maxLen) >= 0.55 {
                            titleScore = 58
                        }
                    }
                }
                guard titleScore > 0 else { continue }

                // 2. Artist score
                var artistScore = 0
                if !spFullArtist.isEmpty && entry.fullArtistNorm == spFullArtist {
                    artistScore = 85
                } else if !spArtists.isDisjoint(with: entry.artistTokens) {
                    artistScore = 70
                } else {
                    // Substring artist check for slight variations (e.g. "Rachel Hardy" vs "Rachel Hardy Music")
                    let partial = spArtists.contains { a in
                        a.count >= 4 && entry.artistTokens.contains { b in b.count >= 4 && (b.contains(a) || a.contains(b)) }
                    }
                    if partial {
                        artistScore = 48
                    }
                }
                guard artistScore > 0 else { continue }

                // 3. Duration proximity bonus/penalty
                var durationAdj = 0
                if duration > 10 && entry.track.duration > 10 {
                    let diff = abs(duration - entry.track.duration)
                    if diff <= 5 { durationAdj = 20 }
                    else if diff <= 12 { durationAdj = 12 }
                    else if diff <= 25 { durationAdj = 4 }
                    else if diff > 90 { durationAdj = -20 }
                }

                // 4. Availability & audio quality tiebreaker
                var qualityAdj = 0
                if entry.track.isAvailable { qualityAdj += 6 }
                if entry.track.format.isLossless { qualityAdj += 4 }
                if entry.track.isHiRes { qualityAdj += 2 }

                let total = titleScore + artistScore + durationAdj + qualityAdj
                if total > bestScore {
                    bestScore = total
                    bestEntry = entry
                }
            }

            // Require strong combined confidence (e.g. at least title >= 58 AND artist >= 48 -> 106+)
            if let bestEntry, bestScore >= 105 {
                return (bestEntry.track, bestScore)
            }
            return nil
        }
    }
}

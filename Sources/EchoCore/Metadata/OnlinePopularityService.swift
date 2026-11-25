import Foundation

public struct TrackPopularityResult: Sendable, Hashable {
    public var trackID: String
    public var popularity: Int          // 0...100 normalized score
    public var playCount: Int?          // Last.fm global plays or Deezer rank
    public var listeners: Int?          // Optional unique global listeners (Last.fm)
    public var source: String           // "deezer" | "lastfm"

    public init(trackID: String, popularity: Int, playCount: Int? = nil, listeners: Int? = nil, source: String) {
        self.trackID = trackID
        self.popularity = max(0, min(100, popularity))
        self.playCount = playCount
        self.listeners = listeners
        self.source = source
    }
}

public struct AlbumPopularityBatch: Sendable {
    public var trackResults: [TrackPopularityResult]
    public var artistStats: ArtistOnlineStats?

    public init(trackResults: [TrackPopularityResult], artistStats: ArtistOnlineStats? = nil) {
        self.trackResults = trackResults
        self.artistStats = artistStats
    }
}

/// Zero-config online popularity fetcher using Deezer's public catalog API,
/// with optional Last.fm global scrobble enrichment when an API key is provided.
public actor OnlinePopularityService {
    private let session: URLSession

    public init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 12
        cfg.timeoutIntervalForResource = 25
        cfg.httpAdditionalHeaders = [
            "User-Agent": "MyEcho/1.3 (macOS Hi-Fi Studio)"
        ]
        self.session = URLSession(configuration: cfg)
    }

    // MARK: - Normalization & Scoring Helpers (Public for Unit Tests)

    public static func scoreFromDeezerRank(_ rank: Int) -> Int {
        guard rank > 0 else { return 0 }
        // Deezer track rank spans roughly 0 ... 1,000,000 (hits ~800k-990k, album cuts ~300k-650k)
        let clamped = min(rank, 1_000_000)
        return max(1, min(100, Int((Double(clamped) / 10_000.0).rounded())))
    }

    public static func scoreFromLastFMPlaycount(_ playcount: Int) -> Int {
        guard playcount > 0 else { return 0 }
        // Logarithmic mapping: 100 -> 25, 10K -> 50, 1M -> 75, 100M -> 100
        let logVal = log10(Double(playcount))
        let score = Int(((logVal / 8.0) * 100.0).rounded())
        return max(1, min(100, score))
    }

    /// Strips remaster/deluxe/edition parentheticals & punctuation for resilient title matching.
    public static func normalizeTitleForMatching(_ raw: String) -> String {
        var s = raw.lowercased()
            .folding(options: [.diacriticInsensitive, .widthInsensitive], locale: .current)

        // Strip trailing/embedded edition tags like "(Remastered 2009)", "[Deluxe Edition]", "- 2011 Remaster"
        let patterns = [
            #"\s*[\(\[]([^)\]]*(remaster|deluxe|bonus|radio edit|album version|single version|explicit|clean|mono|stereo|anniversary|expanded|special edition|version)[^)\]]*)[\)\]]"#,
            #"\s*-\s*(remaster|20\d\d remaster|19\d\d remaster|deluxe|bonus track|radio edit|mono|stereo).*$"#,
            #"\s*[\(\[]\s*feat\.?[^)\]]*[\)\]]"#,
            #"\s+feat\.?\s+.*$"#
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(s.startIndex..<s.endIndex, in: s)
                s = regex.stringByReplacingMatches(in: s, range: range, withTemplate: "")
            }
        }

        let cleaned = s.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : " " }
        let collapsed = String(cleaned)
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        return collapsed
    }

    // MARK: - Album Batch Lookup (Fast: 2 HTTP requests for an entire album)

    public func fetchAlbumPopularity(
        artist: String,
        album: String,
        tracks: [Track],
        lastFMAPIKey: String? = nil
    ) async -> AlbumPopularityBatch {
        guard !tracks.isEmpty else { return AlbumPopularityBatch(trackResults: []) }

        var resultsByID: [String: TrackPopularityResult] = [:]
        var fetchedArtistStats: ArtistOnlineStats? = nil

        // 1. Search Deezer for the album
        if let deezerAlbum = await searchDeezerAlbum(artist: artist, album: album) {
            let remoteTracks = await fetchDeezerAlbumTracks(albumID: deezerAlbum.id)
            if !remoteTracks.isEmpty {
                let matched = Self.matchRemoteTracks(remoteTracks, to: tracks)
                for res in matched {
                    resultsByID[res.trackID] = res
                }
            }
            if let artistID = deezerAlbum.artist?.id,
               let artistFans = await fetchDeezerArtistFans(artistID: artistID) {
                fetchedArtistStats = ArtistOnlineStats(
                    artistKey: artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                    fans: artistFans,
                    source: "deezer",
                    fetchedAt: Date()
                )
            }
        }

        // 2. Fallback individual track search for any tracks still unmatched (capped for speed)
        let missing = tracks.filter { resultsByID[$0.id] == nil }
        for track in missing.prefix(12) {
            if let single = await fetchDeezerTrackPopularity(track: track) {
                resultsByID[track.id] = single
            }
        }

        // 3. Optional Last.fm global scrobble enrichment if user configured an API key
        if let apiKey = lastFMAPIKey?.trimmingCharacters(in: .whitespacesAndNewlines), !apiKey.isEmpty {
            for track in tracks.prefix(25) {
                if let lfm = await fetchLastFMTrackStats(artist: track.artist, title: track.title, apiKey: apiKey) {
                    if var existing = resultsByID[track.id] {
                        existing.playCount = lfm.playcount
                        existing.listeners = lfm.listeners
                        existing.source = "deezer+lastfm"
                        resultsByID[track.id] = existing
                    } else {
                        resultsByID[track.id] = TrackPopularityResult(
                            trackID: track.id,
                            popularity: Self.scoreFromLastFMPlaycount(lfm.playcount),
                            playCount: lfm.playcount,
                            listeners: lfm.listeners,
                            source: "lastfm"
                        )
                    }
                }
            }
        }

        return AlbumPopularityBatch(
            trackResults: Array(resultsByID.values),
            artistStats: fetchedArtistStats
        )
    }

    // MARK: - Artist Lookup (Fans + Top 50 Tracks)

    public func fetchArtistPopularity(
        artistName: String,
        artistKey: String,
        tracks: [Track],
        lastFMAPIKey: String? = nil
    ) async -> AlbumPopularityBatch {
        var resultsByID: [String: TrackPopularityResult] = [:]
        var artistStats: ArtistOnlineStats? = nil

        if let remoteArtist = await searchDeezerArtist(name: artistName) {
            artistStats = ArtistOnlineStats(
                artistKey: artistKey,
                fans: remoteArtist.nb_fan,
                source: "deezer",
                fetchedAt: Date()
            )
            let topTracks = await fetchDeezerArtistTopTracks(artistID: remoteArtist.id)
            if !topTracks.isEmpty {
                let matched = Self.matchRemoteTracks(topTracks, to: tracks, allowPositionFallback: false)
                for res in matched {
                    resultsByID[res.trackID] = res
                }
            }
        }

        // Also enrich up to 3 albums if many tracks still lack popularity
        let missingByAlbum = Dictionary(grouping: tracks.filter { resultsByID[$0.id] == nil }, by: \.albumKey)
        for (_, albumTracks) in missingByAlbum.sorted(by: { $0.value.count > $1.value.count }).prefix(3) {
            guard let first = albumTracks.first else { continue }
            if let deezerAlbum = await searchDeezerAlbum(artist: artistName, album: first.effectiveAlbum) {
                let remoteTracks = await fetchDeezerAlbumTracks(albumID: deezerAlbum.id)
                for res in Self.matchRemoteTracks(remoteTracks, to: albumTracks) {
                    resultsByID[res.trackID] = res
                }
            }
        }

        if let apiKey = lastFMAPIKey?.trimmingCharacters(in: .whitespacesAndNewlines), !apiKey.isEmpty {
            // Enrich top 10 matched or first tracks with Last.fm global plays
            let candidates = tracks.sorted {
                (resultsByID[$0.id]?.popularity ?? 0) > (resultsByID[$1.id]?.popularity ?? 0)
            }.prefix(10)
            for track in candidates {
                if let lfm = await fetchLastFMTrackStats(artist: track.artist, title: track.title, apiKey: apiKey) {
                    if var existing = resultsByID[track.id] {
                        existing.playCount = lfm.playcount
                        existing.listeners = lfm.listeners
                        existing.source = "deezer+lastfm"
                        resultsByID[track.id] = existing
                    } else {
                        resultsByID[track.id] = TrackPopularityResult(
                            trackID: track.id,
                            popularity: Self.scoreFromLastFMPlaycount(lfm.playcount),
                            playCount: lfm.playcount,
                            listeners: lfm.listeners,
                            source: "lastfm"
                        )
                    }
                }
            }
        }

        return AlbumPopularityBatch(
            trackResults: Array(resultsByID.values),
            artistStats: artistStats
        )
    }

    // MARK: - Single Track Lookup

    public func fetchTrackPopularity(track: Track, lastFMAPIKey: String? = nil) async -> TrackPopularityResult? {
        var result = await fetchDeezerTrackPopularity(track: track)

        if let apiKey = lastFMAPIKey?.trimmingCharacters(in: .whitespacesAndNewlines), !apiKey.isEmpty,
           let lfm = await fetchLastFMTrackStats(artist: track.artist, title: track.title, apiKey: apiKey) {
            if var existing = result {
                existing.playCount = lfm.playcount
                existing.listeners = lfm.listeners
                existing.source = "deezer+lastfm"
                result = existing
            } else {
                result = TrackPopularityResult(
                    trackID: track.id,
                    popularity: Self.scoreFromLastFMPlaycount(lfm.playcount),
                    playCount: lfm.playcount,
                    listeners: lfm.listeners,
                    source: "lastfm"
                )
            }
        }
        return result
    }

    // MARK: - Track Matching Engine (Testable)

    public struct RemoteTrackCandidate: Sendable {
        public var title: String
        public var shortTitle: String?
        public var trackPosition: Int?
        public var discNumber: Int?
        public var rank: Int

        public init(title: String, shortTitle: String? = nil, trackPosition: Int? = nil, discNumber: Int? = nil, rank: Int) {
            self.title = title
            self.shortTitle = shortTitle
            self.trackPosition = trackPosition
            self.discNumber = discNumber
            self.rank = rank
        }
    }

    public static func matchRemoteTracks(
        _ remoteTracks: [RemoteTrackCandidate],
        to localTracks: [Track],
        allowPositionFallback: Bool = true
    ) -> [TrackPopularityResult] {
        guard !remoteTracks.isEmpty, !localTracks.isEmpty else { return [] }

        // Index remote tracks by normalized title (keeping highest rank if duplicated)
        var byNormTitle: [String: RemoteTrackCandidate] = [:]
        var byPosition: [String: RemoteTrackCandidate] = [:]

        for remote in remoteTracks {
            let candidates = [remote.title, remote.shortTitle].compactMap { $0 }.map(normalizeTitleForMatching).filter { !$0.isEmpty }
            for key in candidates {
                if let existing = byNormTitle[key] {
                    if remote.rank > existing.rank { byNormTitle[key] = remote }
                } else {
                    byNormTitle[key] = remote
                }
            }
            if let pos = remote.trackPosition {
                let disc = remote.discNumber ?? 1
                byPosition["\(disc):\(pos)"] = remote
            }
        }

        var results: [TrackPopularityResult] = []
        for track in localTracks {
            let norm = normalizeTitleForMatching(track.title)
            var matched: RemoteTrackCandidate? = byNormTitle[norm]

            // Substring / prefix match fallback for slightly differing subtitles
            if matched == nil, norm.count >= 4 {
                matched = remoteTracks.first(where: { r in
                    let rNorm = normalizeTitleForMatching(r.shortTitle ?? r.title)
                    return !rNorm.isEmpty && (rNorm.contains(norm) || norm.contains(rNorm))
                })
            }

            // Track position fallback inside same album
            if matched == nil, allowPositionFallback, let num = track.trackNumber {
                let disc = track.discNumber ?? 1
                matched = byPosition["\(disc):\(num)"]
            }

            if let matched {
                results.append(TrackPopularityResult(
                    trackID: track.id,
                    popularity: scoreFromDeezerRank(matched.rank),
                    playCount: matched.rank,
                    listeners: nil,
                    source: "deezer"
                ))
            }
        }
        return results
    }

    // MARK: - Deezer REST Calls

    private struct DeezerAlbumSearchResponse: Decodable {
        let data: [DeezerAlbumSummary]
    }
    private struct DeezerAlbumSummary: Decodable {
        let id: Int
        let title: String
        let artist: DeezerArtistRef?
    }
    private struct DeezerArtistRef: Decodable {
        let id: Int
        let name: String?
    }
    private struct DeezerArtistSearchResponse: Decodable {
        let data: [DeezerArtistDetail]
    }
    private struct DeezerArtistDetail: Decodable {
        let id: Int
        let name: String
        let nb_fan: Int?
    }
    private struct DeezerTrackListResponse: Decodable {
        let data: [DeezerTrackItem]
    }
    private struct DeezerTrackItem: Decodable {
        let id: Int
        let title: String
        let title_short: String?
        let track_position: Int?
        let disk_number: Int?
        let rank: Int?
        let artist: DeezerArtistRef?
    }

    private func searchDeezerAlbum(artist: String, album: String) async -> DeezerAlbumSummary? {
        let cleanArtist = artist.replacingOccurrences(of: "\"", with: "")
        let cleanAlbum = album.replacingOccurrences(of: "\"", with: "")
        let queries = [
            "artist:\"\(cleanArtist)\" album:\"\(cleanAlbum)\"",
            "\(cleanArtist) \(cleanAlbum)"
        ]
        for query in queries {
            guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: "https://api.deezer.com/search/album?q=\(encoded)&limit=5"),
                  let (data, _) = try? await session.data(from: url),
                  let decoded = try? JSONDecoder().decode(DeezerAlbumSearchResponse.self, from: data),
                  !decoded.data.isEmpty else { continue }

            let targetAlbumNorm = Self.normalizeTitleForMatching(album)
            let targetArtistNorm = Self.normalizeTitleForMatching(artist)
            if let exact = decoded.data.first(where: { item in
                let aNorm = Self.normalizeTitleForMatching(item.title)
                let arNorm = Self.normalizeTitleForMatching(item.artist?.name ?? "")
                let albumMatch = aNorm == targetAlbumNorm || aNorm.contains(targetAlbumNorm) || targetAlbumNorm.contains(aNorm)
                let artistMatch = arNorm.isEmpty || arNorm.contains(targetArtistNorm) || targetArtistNorm.contains(arNorm)
                return albumMatch && artistMatch
            }) {
                return exact
            }
            if let first = decoded.data.first {
                let arNorm = Self.normalizeTitleForMatching(first.artist?.name ?? "")
                if arNorm.contains(targetArtistNorm) || targetArtistNorm.contains(arNorm) {
                    return first
                }
            }
        }
        return nil
    }

    private func fetchDeezerAlbumTracks(albumID: Int) async -> [RemoteTrackCandidate] {
        guard let url = URL(string: "https://api.deezer.com/album/\(albumID)/tracks?limit=100"),
              let (data, _) = try? await session.data(from: url),
              let decoded = try? JSONDecoder().decode(DeezerTrackListResponse.self, from: data) else {
            return []
        }
        return decoded.data.compactMap { item in
            guard let rank = item.rank else { return nil }
            return RemoteTrackCandidate(
                title: item.title,
                shortTitle: item.title_short,
                trackPosition: item.track_position,
                discNumber: item.disk_number,
                rank: rank
            )
        }
    }

    private func searchDeezerArtist(name: String) async -> DeezerArtistDetail? {
        guard let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.deezer.com/search/artist?q=\(encoded)&limit=5"),
              let (data, _) = try? await session.data(from: url),
              let decoded = try? JSONDecoder().decode(DeezerArtistSearchResponse.self, from: data) else {
            return nil
        }
        let target = Self.normalizeTitleForMatching(name)
        return decoded.data.first(where: { Self.normalizeTitleForMatching($0.name) == target })
            ?? decoded.data.first
    }

    private func fetchDeezerArtistFans(artistID: Int) async -> Int? {
        guard let url = URL(string: "https://api.deezer.com/artist/\(artistID)"),
              let (data, _) = try? await session.data(from: url),
              let decoded = try? JSONDecoder().decode(DeezerArtistDetail.self, from: data) else {
            return nil
        }
        return decoded.nb_fan
    }

    private func fetchDeezerArtistTopTracks(artistID: Int) async -> [RemoteTrackCandidate] {
        guard let url = URL(string: "https://api.deezer.com/artist/\(artistID)/top?limit=50"),
              let (data, _) = try? await session.data(from: url),
              let decoded = try? JSONDecoder().decode(DeezerTrackListResponse.self, from: data) else {
            return []
        }
        return decoded.data.compactMap { item in
            guard let rank = item.rank else { return nil }
            return RemoteTrackCandidate(
                title: item.title,
                shortTitle: item.title_short,
                trackPosition: item.track_position,
                discNumber: item.disk_number,
                rank: rank
            )
        }
    }

    private func fetchDeezerTrackPopularity(track: Track) async -> TrackPopularityResult? {
        let cleanArtist = track.artist.replacingOccurrences(of: "\"", with: "")
        let cleanTitle = track.title.replacingOccurrences(of: "\"", with: "")
        let queries = [
            "artist:\"\(cleanArtist)\" track:\"\(cleanTitle)\"",
            "\(cleanArtist) \(cleanTitle)"
        ]
        let targetTitle = Self.normalizeTitleForMatching(track.title)
        let targetArtist = Self.normalizeTitleForMatching(track.artist)

        for query in queries {
            guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: "https://api.deezer.com/search?q=\(encoded)&limit=5"),
                  let (data, _) = try? await session.data(from: url),
                  let decoded = try? JSONDecoder().decode(DeezerTrackListResponse.self, from: data),
                  !decoded.data.isEmpty else { continue }

            let match = decoded.data.first(where: { item in
                let tNorm = Self.normalizeTitleForMatching(item.title_short ?? item.title)
                let aNorm = Self.normalizeTitleForMatching(item.artist?.name ?? "")
                let titleOk = tNorm == targetTitle || tNorm.contains(targetTitle) || targetTitle.contains(tNorm)
                let artistOk = aNorm.isEmpty || aNorm.contains(targetArtist) || targetArtist.contains(aNorm)
                return titleOk && artistOk
            }) ?? decoded.data.first

            if let match, let rank = match.rank {
                return TrackPopularityResult(
                    trackID: track.id,
                    popularity: Self.scoreFromDeezerRank(rank),
                    playCount: rank,
                    listeners: nil,
                    source: "deezer"
                )
            }
        }
        return nil
    }

    // MARK: - Optional Last.fm API Enrichment

    private struct LastFMResponse: Decodable {
        let track: LastFMTrack?
    }
    private struct LastFMTrack: Decodable {
        let listeners: String?
        let playcount: String?
    }

    private func fetchLastFMTrackStats(artist: String, title: String, apiKey: String) async -> (playcount: Int, listeners: Int)? {
        var comps = URLComponents(string: "https://ws.audioscrobbler.com/2.0/")
        comps?.queryItems = [
            URLQueryItem(name: "method", value: "track.getInfo"),
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "artist", value: artist),
            URLQueryItem(name: "track", value: title),
            URLQueryItem(name: "autocorrect", value: "1"),
            URLQueryItem(name: "format", value: "json")
        ]
        guard let url = comps?.url,
              let (data, _) = try? await session.data(from: url),
              let decoded = try? JSONDecoder().decode(LastFMResponse.self, from: data),
              let lfmTrack = decoded.track,
              let plays = lfmTrack.playcount.flatMap(Int.init) else {
            return nil
        }
        let listeners = lfmTrack.listeners.flatMap(Int.init) ?? 0
        return (plays, listeners)
    }
}

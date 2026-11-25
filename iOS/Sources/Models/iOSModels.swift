import Foundation
import SwiftUI

// MARK: - Retro Hi-Fi Theme (Matches My Echo macOS)

enum EchoiOSTheme {
    static let canvas = Color(red: 0.047, green: 0.055, blue: 0.075)
    static let surface = Color(red: 0.082, green: 0.094, blue: 0.129)
    static let surfaceElevated = Color(red: 0.118, green: 0.135, blue: 0.180)
    static let neoMint = Color(red: 0.00, green: 0.94, blue: 0.60)
    static let neoCyan = Color(red: 0.00, green: 0.83, blue: 1.00)
    static let hiResGold = Color(red: 1.00, green: 0.72, blue: 0.00)
    static let dangerCoral = Color(red: 1.00, green: 0.34, blue: 0.38)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.70)
    static let textMuted = Color.white.opacity(0.45)
    static let border = Color.white.opacity(0.10)
    static let borderStrong = Color.white.opacity(0.20)
    static let radiusCard: CGFloat = 8
    static let radiusControl: CGFloat = 6
    static let radiusSmall: CGFloat = 4
}

// MARK: - Wire Models (1:1 Compatible with macOS WirelessSyncServer)

struct SyncedTrack: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var title: String
    var artist: String
    var albumArtist: String
    var album: String
    var trackNumber: Int?
    var discNumber: Int?
    var year: Int?
    var genre: String?
    var duration: TimeInterval
    var format: String
    var fileExtension: String
    var sampleRate: Int?
    var bitDepth: Int?
    var bitrate: Int?
    var fileSize: Int64
    var modifiedAt: Date
    var artworkHash: String?

    var effectiveArtist: String {
        let aa = albumArtist.trimmingCharacters(in: .whitespacesAndNewlines)
        if !aa.isEmpty { return aa }
        let a = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        return a.isEmpty ? "Unknown Artist" : a
    }

    var effectiveAlbum: String {
        let a = album.trimmingCharacters(in: .whitespacesAndNewlines)
        return a.isEmpty ? "Unknown Album" : a
    }

    /// Always group as one album instance per album title (never split by artist).
    var albumKey: String {
        effectiveAlbum.lowercased()
    }

    var formatPrimaryLabel: String {
        format.uppercased()
    }

    var formatDetailLabel: String? {
        if let bitDepth, let sampleRate, sampleRate > 0 {
            let khz = Double(sampleRate) / 1000.0
            let khzStr = khz.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(khz))" : String(format: "%.1f", khz)
            return "\(bitDepth)b/\(khzStr)kHz"
        }
        if let bitrate, bitrate > 0 {
            return "\(bitrate)k"
        }
        return nil
    }

    var isHiRes: Bool {
        (bitDepth ?? 0) >= 24 || (sampleRate ?? 0) >= 88_200
    }

    var isLossless: Bool {
        ["flac", "alac", "wav", "aiff"].contains(format.lowercased())
    }
}

struct SyncedPlaylist: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var name: String
    var description: String
    var trackIDs: [String]
}

struct SyncedPodcastFeed: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var title: String
    var author: String
    var description: String
    var feedURL: String
    var artworkURL: String?
    var artworkHash: String?
    var episodesToKeep: Int
    var isSelectedForAutoSync: Bool
}

struct SyncedEpisode: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var showID: String
    var showTitle: String
    var title: String
    var summary: String
    var publishedAt: Date?
    var duration: TimeInterval
    var fileSize: Int64
    var artworkHash: String?
    var fileExtension: String
    var guid: String?
    var audioURL: String?
}

enum PodcastEpisodeDownloadOrigin: String, Codable, Hashable, Sendable {
    case none
    case syncedFromMac
    case downloadedOnDevice
}

struct iOSPodcastEpisode: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var showID: String
    var showTitle: String
    var title: String
    var summary: String
    var publishedAt: Date?
    var duration: TimeInterval
    var fileSize: Int64
    var artworkHash: String?
    var fileExtension: String
    var guid: String
    var audioURL: String
    var downloadOrigin: PodcastEpisodeDownloadOrigin

    var localFileName: String {
        let ext = fileExtension.isEmpty ? "mp3" : fileExtension
        return "\(id).\(ext)"
    }
}

struct iOSPodcastShow: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var title: String
    var author: String
    var description: String
    var feedURL: String
    var artworkURL: String?
    var artworkHash: String?
    var episodesToKeep: Int
    var isSelectedForAutoSync: Bool
    var lastRefreshedAt: Date?
    var episodes: [iOSPodcastEpisode]
}

struct SyncedAlbumEditorial: Identifiable, Codable, Hashable, Sendable {
    var albumKey: String
    var releaseDate: String?
    var label: String?
    var genres: [String]
    var albumFans: Int?
    var artistFans: Int?
    var artistAlbumCount: Int?
    var albumSummary: String?
    var artistSummary: String?
    var artistImageURL: String?
    var fetchedAt: Date

    var id: String { albumKey }

    var hasDisplayableContent: Bool {
        albumSummary != nil || artistSummary != nil || label != nil || releaseDate != nil || !genres.isEmpty || albumFans != nil || artistFans != nil
    }
}

struct SyncedArtistEditorial: Identifiable, Codable, Hashable, Sendable {
    var artistKey: String
    var summary: String?
    var fans: Int?
    var albumCount: Int?
    var imageURL: String?
    var fetchedAt: Date

    var id: String { artistKey }

    var hasDisplayableContent: Bool {
        summary != nil || fans != nil || albumCount != nil
    }
}

struct SyncManifestPayload: Codable, Sendable {
    var deviceID: String
    var deviceName: String
    var serverName: String
    var manifestVersion: String
    var syncMode: String
    var generatedAt: Date
    var tracks: [SyncedTrack]
    var playlists: [SyncedPlaylist]
    var episodes: [SyncedEpisode]
    var podcastFeeds: [SyncedPodcastFeed]
    var albumEditorial: [SyncedAlbumEditorial]
    var artistEditorial: [SyncedArtistEditorial]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        deviceID = try c.decode(String.self, forKey: .deviceID)
        deviceName = try c.decode(String.self, forKey: .deviceName)
        serverName = try c.decode(String.self, forKey: .serverName)
        manifestVersion = try c.decode(String.self, forKey: .manifestVersion)
        syncMode = try c.decode(String.self, forKey: .syncMode)
        generatedAt = try c.decode(Date.self, forKey: .generatedAt)
        tracks = try c.decodeIfPresent([SyncedTrack].self, forKey: .tracks) ?? []
        playlists = try c.decodeIfPresent([SyncedPlaylist].self, forKey: .playlists) ?? []
        episodes = try c.decodeIfPresent([SyncedEpisode].self, forKey: .episodes) ?? []
        podcastFeeds = try c.decodeIfPresent([SyncedPodcastFeed].self, forKey: .podcastFeeds) ?? []
        albumEditorial = try c.decodeIfPresent([SyncedAlbumEditorial].self, forKey: .albumEditorial) ?? []
        artistEditorial = try c.decodeIfPresent([SyncedArtistEditorial].self, forKey: .artistEditorial) ?? []
    }
}

struct SyncPingPayload: Codable, Sendable {
    var app: String
    var serverName: String
    var deviceID: String
    var deviceName: String
    var manifestVersion: String
    var syncMode: String
    var trackCount: Int
    var playlistCount: Int
    var episodeCount: Int
    var totalBytes: Int64
}

struct SyncReportPayload: Codable, Sendable {
    var deviceID: String
    var clientName: String?
    var syncedTrackIDs: [String]
    var syncedEpisodeIDs: [String]
    var completedAt: Date?
}

struct SyncedAlbumGroup: Identifiable, Hashable {
    var id: String
    var title: String
    var artist: String
    var year: Int?
    var artworkHash: String?
    var tracks: [SyncedTrack]

    /// Resolves display artist strictly from track artists (albumArtist is advisory only):
    /// - Shows `"Various Artists"` if more than half of tracks have different artists.
    /// - Otherwise shows only the single artist appearing on at least half of the tracks.
    static func resolveDisplayArtist(for tracks: [SyncedTrack]) -> String {
        let total = tracks.count
        guard total > 0 else { return "Unknown Artist" }

        func isVarious(_ s: String) -> Bool {
            s == "various artists" || s == "various" || s == "va" || s == "v.a."
        }

        // Advisory albumArtist preference (used only as fallback or to break an exact 50/50 tie)
        var advisoryCounts: [String: (name: String, count: Int)] = [:]
        for t in tracks {
            let raw = t.albumArtist.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !raw.isEmpty else { continue }
            let k = raw.lowercased()
            guard !isVarious(k) else { continue }
            if let existing = advisoryCounts[k] {
                advisoryCounts[k] = (existing.name, existing.count + 1)
            } else {
                advisoryCounts[k] = (raw, 1)
            }
        }
        let advisoryBestKey = advisoryCounts.values.max(by: { $0.count < $1.count })?.name.lowercased()

        func pickWinner(from qualifying: [(name: String, count: Int)]) -> String? {
            guard let top = qualifying.first else { return nil }
            let tied = qualifying.filter { $0.count == top.count }
            if tied.count == 1 { return top.name }
            if let advisoryBestKey, let match = tied.first(where: { $0.name.lowercased() == advisoryBestKey }) {
                return match.name
            }
            return nil
        }

        // Step 1: Exact per-track artist counts
        var exactCounts: [String: (name: String, count: Int)] = [:]
        for t in tracks {
            let raw = t.artist.trimmingCharacters(in: .whitespacesAndNewlines)
            let effective = raw.isEmpty ? t.albumArtist.trimmingCharacters(in: .whitespacesAndNewlines) : raw
            guard !effective.isEmpty else { continue }
            let k = effective.lowercased()
            if let existing = exactCounts[k] {
                exactCounts[k] = (existing.name, existing.count + 1)
            } else {
                exactCounts[k] = (effective, 1)
            }
        }
        if exactCounts.isEmpty { return "Unknown Artist" }

        let exactQualifying = exactCounts.values
            .filter { $0.count * 2 >= total }
            .sorted { $0.count > $1.count }
        if let winner = pickWinner(from: exactQualifying) {
            return isVarious(winner.lowercased()) ? "Various Artists" : winner
        }

        // Step 2: Split multi-artist credits ("Main Artist feat. Guest", "A, B", "A; B")
        let pattern = #"(?i)(\s*;\s*|\s*,\s+|\s+(?:feat\.?|ft\.?|featuring|with|vs\.?|x)\s+|\s+\/\s+|\s+\+\s+(?!the\b)|\s+&\s+(?!the\b))"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        var splitCounts: [String: (name: String, count: Int)] = [:]
        for t in tracks {
            let raw = t.artist.trimmingCharacters(in: .whitespacesAndNewlines)
            let effective = raw.isEmpty ? t.albumArtist.trimmingCharacters(in: .whitespacesAndNewlines) : raw
            guard !effective.isEmpty else { continue }
            var names: [String] = [effective]
            if let regex {
                let ns = effective as NSString
                let matches = regex.matches(in: effective, options: [], range: NSRange(location: 0, length: ns.length))
                if !matches.isEmpty {
                    var parts: [String] = []
                    var cursor = 0
                    for m in matches {
                        let s = ns.substring(with: NSRange(location: cursor, length: m.range.location - cursor))
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        if !s.isEmpty { parts.append(s) }
                        cursor = m.range.location + m.range.length
                    }
                    let tail = ns.substring(from: cursor).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !tail.isEmpty { parts.append(tail) }
                    if !parts.isEmpty { names = parts }
                }
            }
            var seenOnTrack: Set<String> = []
            for n in names {
                let k = n.lowercased()
                guard !isVarious(k) else { continue }
                if seenOnTrack.insert(k).inserted {
                    if let existing = splitCounts[k] {
                        splitCounts[k] = (existing.name, existing.count + 1)
                    } else {
                        splitCounts[k] = (n, 1)
                    }
                }
            }
        }

        let splitQualifying = splitCounts.values
            .filter { $0.count * 2 >= total }
            .sorted { $0.count > $1.count }
        if let winner = pickWinner(from: splitQualifying) {
            return winner
        }

        return "Various Artists"
    }
}

// MARK: - Unified Playable Queue Item (Offline Local File OR Navidrome Tailscale Stream)

struct PlayableItem: Identifiable, Hashable, Sendable {
    enum SourceKind: Hashable, Sendable {
        case localFile(URL)
        case navidromeStream(songID: String, url: URL)
        case podcastStream(URL)
    }

    var id: String
    var title: String
    var artist: String
    var album: String
    var duration: TimeInterval
    var formatPrimary: String
    var formatDetail: String?
    var isHiRes: Bool
    var isLossless: Bool
    var localArtworkURL: URL?
    var remoteArtworkURL: URL?
    var source: SourceKind

    var isStreaming: Bool {
        switch source {
        case .localFile: return false
        case .navidromeStream, .podcastStream: return true
        }
    }
}

// MARK: - Navidrome (Subsonic) Models

enum NavidromeStreamQuality: String, Codable, CaseIterable, Identifiable, Sendable {
    case original = "raw"
    case high320 = "320"
    case medium192 = "192"
    case saver128 = "128"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .original: return "Original Lossless (FLAC / Raw)"
        case .high320: return "High · 320 kbps"
        case .medium192: return "Balanced · 192 kbps"
        case .saver128: return "Data Saver · 128 kbps"
        }
    }

    var maxBitRateParam: String? {
        self == .original ? nil : rawValue
    }
}

struct NavidromeServerAddress: Identifiable, Codable, Hashable, Sendable {
    var id: UUID = UUID()
    var label: String
    var url: String
}

struct NavidromeConfig: Codable, Hashable, Sendable {
    var isEnabled: Bool = false
    var serverURL: String = ""     // Active URL (e.g. http://192.168.0.x:4533 or http://100.92.217.88:4533)
    var savedAddresses: [NavidromeServerAddress] = []
    var username: String = ""
    var password: String = ""
    var streamQuality: NavidromeStreamQuality = .original

    init(
        isEnabled: Bool = false,
        serverURL: String = "",
        savedAddresses: [NavidromeServerAddress] = [],
        username: String = "",
        password: String = "",
        streamQuality: NavidromeStreamQuality = .original
    ) {
        self.isEnabled = isEnabled
        self.serverURL = serverURL
        self.savedAddresses = savedAddresses
        self.username = username
        self.password = password
        self.streamQuality = streamQuality
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        serverURL = try c.decodeIfPresent(String.self, forKey: .serverURL) ?? ""
        savedAddresses = try c.decodeIfPresent([NavidromeServerAddress].self, forKey: .savedAddresses) ?? []
        username = try c.decodeIfPresent(String.self, forKey: .username) ?? ""
        password = try c.decodeIfPresent(String.self, forKey: .password) ?? ""
        streamQuality = try c.decodeIfPresent(NavidromeStreamQuality.self, forKey: .streamQuality) ?? .original
    }

    var isConfigured: Bool {
        !serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !password.isEmpty
    }
}

struct NavidromeAlbum: Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var artist: String
    var artistId: String?
    var coverArt: String?
    var songCount: Int
    var year: Int?
    var duration: Int
}

struct NavidromeArtist: Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var albumCount: Int
    var coverArt: String?
}

struct NavidromeSong: Identifiable, Hashable, Sendable {
    var id: String
    var title: String
    var artist: String
    var album: String
    var albumId: String?
    var track: Int?
    var year: Int?
    var duration: Int
    var bitRate: Int?
    var suffix: String?
    var coverArt: String?
    var size: Int64?
}

struct NavidromePlaylist: Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var songCount: Int
    var duration: Int
    var coverArt: String?
}

// MARK: - Navidrome Offline Cached Track (Downloaded directly on iPhone/iPad)

struct NavidromeOfflineTrack: Identifiable, Codable, Hashable, Sendable {
    var id: String // Navidrome song ID
    var title: String
    var artist: String
    var album: String
    var trackNumber: Int?
    var year: Int?
    var duration: TimeInterval
    var format: String
    var bitrate: Int?
    var fileExtension: String
    var fileSize: Int64
    var coverArtID: String?
    var downloadedAt: Date

    var localFileName: String { "\(id).\(fileExtension)" }

    func asSyncedTrack() -> SyncedTrack {
        SyncedTrack(
            id: "ndoff-\(id)",
            title: title,
            artist: artist,
            albumArtist: artist,
            album: album,
            trackNumber: trackNumber,
            discNumber: nil,
            year: year,
            genre: nil,
            duration: duration,
            format: format,
            fileExtension: fileExtension,
            sampleRate: nil,
            bitDepth: nil,
            bitrate: bitrate,
            fileSize: fileSize,
            modifiedAt: downloadedAt,
            artworkHash: coverArtID.map { "ndart-\($0)" }
        )
    }
}

// MARK: - Mac Remote Library Search, Sync Toggle & Lidarr Relay Models

struct MacLibrarySearchAlbum: Identifiable, Codable, Hashable, Sendable {
    var id: String { albumKey }
    var albumKey: String
    var title: String
    var artist: String
    var year: Int?
    var trackCount: Int
    var artworkHash: String?
    var isSelectedForSync: Bool
}

struct MacLibrarySearchTrack: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var title: String
    var artist: String
    var album: String
    var albumKey: String
    var duration: TimeInterval
    var format: String
    var sampleRate: Int?
    var bitDepth: Int?
    var bitrate: Int?
    var artworkHash: String?
    var isSelectedForSync: Bool

    var formatPrimaryLabel: String { format.uppercased() }
    var formatDetailLabel: String? {
        if let bitDepth, let sampleRate, sampleRate > 0 {
            let khz = Double(sampleRate) / 1000.0
            let khzStr = khz.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(khz))" : String(format: "%.1f", khz)
            return "\(bitDepth)b/\(khzStr)kHz"
        }
        return bitrate.map { "\($0)k" }
    }
    var isHiRes: Bool { (bitDepth ?? 0) >= 24 || (sampleRate ?? 0) >= 88_200 }
    var isLossless: Bool { ["flac", "alac", "wav", "aiff"].contains(format.lowercased()) }
}

struct MacLibrarySearchResponse: Codable, Sendable {
    var query: String
    var albums: [MacLibrarySearchAlbum]
    var tracks: [MacLibrarySearchTrack]
}

struct MacRemoteSyncSelectRequest: Codable, Sendable {
    var deviceID: String?
    var trackID: String?
    var albumKey: String?
    var selected: Bool
}

struct MacRemoteSyncSelectResponse: Codable, Sendable {
    var ok: Bool
    var manifestVersion: String
    var message: String
}

struct MacLidarrAlbumItem: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var foreignAlbumId: String
    var title: String
    var artistName: String
    var releaseYear: Int?
    var coverURL: String?
    var monitored: Bool
    var inLibrary: Bool
}

struct MacLidarrTrackItem: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var title: String
    var artistName: String
    var albumTitle: String
    var duration: TimeInterval
    var coverURL: String?
}

struct MacLidarrSearchResponse: Codable, Sendable {
    var configured: Bool
    var albums: [MacLidarrAlbumItem]
    var tracks: [MacLidarrTrackItem]
    var message: String?
}

struct MacLidarrOrderRequest: Codable, Sendable {
    var foreignAlbumId: String?
    var title: String
    var artistName: String
    var albumTitle: String?
}

struct MacLidarrOrderResponse: Codable, Sendable {
    var ok: Bool
    var message: String
    var albumTitle: String?
    var artistName: String?
}

// MARK: - Online Podcast Directory Search & Sync-Back to Mac Models

enum iOSPodcastDirectory: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case apple = "Apple"
    case gpodder = "gPodder"
    case curated = "Featured"
    var id: String { rawValue }
}

enum iOSPodcastCategory: String, CaseIterable, Identifiable, Sendable {
    case featured = "Featured"
    case topCharts = "Top Charts"
    case news = "News"
    case technology = "Technology"
    case business = "Business"
    case musicAudio = "Music & Hi-Fi"
    case science = "Science"
    case history = "History"
    case comedy = "Comedy"
    case trueCrime = "True Crime"
    case societyCulture = "Society"
    case sports = "Sports"
    case healthFitness = "Health"
    case arts = "Arts"
    case tvFilm = "TV & Film"
    case education = "Education"
    case fiction = "Fiction"
    case nordic = "Nordic / NO"

    var id: String { rawValue }

    var appleGenreID: Int? {
        switch self {
        case .featured, .topCharts, .nordic: return nil
        case .news: return 1489
        case .technology: return 1318
        case .business: return 1321
        case .musicAudio: return 1310
        case .science: return 1533
        case .history: return 1487
        case .comedy: return 1303
        case .trueCrime: return 1488
        case .societyCulture: return 1324
        case .sports: return 1545
        case .healthFitness: return 1512
        case .arts: return 1301
        case .tvFilm: return 1309
        case .education: return 1304
        case .fiction: return 1483
        }
    }

    var gpodderTag: String? {
        switch self {
        case .featured, .topCharts, .nordic: return nil
        case .news: return "news"
        case .technology: return "technology"
        case .business: return "business"
        case .musicAudio: return "music"
        case .science: return "science"
        case .history: return "history"
        case .comedy: return "comedy"
        case .trueCrime: return "true-crime"
        case .societyCulture: return "society"
        case .sports: return "sports"
        case .healthFitness: return "health"
        case .arts: return "arts"
        case .tvFilm: return "tv-film"
        case .education: return "education"
        case .fiction: return "fiction"
        }
    }

    var countryCode: String {
        self == .nordic ? "NO" : "US"
    }

    var defaultBrowseTerm: String {
        switch self {
        case .featured, .topCharts: return "podcast"
        case .news: return "news"
        case .technology: return "technology"
        case .business: return "business"
        case .musicAudio: return "music"
        case .science: return "science"
        case .history: return "history"
        case .comedy: return "comedy"
        case .trueCrime: return "crime"
        case .societyCulture: return "culture"
        case .sports: return "sports"
        case .healthFitness: return "health"
        case .arts: return "arts"
        case .tvFilm: return "film"
        case .education: return "education"
        case .fiction: return "fiction"
        case .nordic: return "podkast"
        }
    }

    static func matchingGenre(for query: String) -> iOSPodcastCategory? {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return nil }
        let aliases: [(iOSPodcastCategory, [String])] = [
            (.news, ["news", "nyheter", "politics", "politikk"]),
            (.technology, ["tech", "technology", "teknologi", "software", "ai"]),
            (.business, ["business", "finance", "finans", "økonomi", "investing"]),
            (.musicAudio, ["music", "musikk", "hi-fi", "hifi", "audiophile", "audio"]),
            (.science, ["science", "vitenskap", "physics", "space"]),
            (.history, ["history", "historie", "documentary", "dokumentar"]),
            (.comedy, ["comedy", "humor", "funny"]),
            (.trueCrime, ["true crime", "crime", "krim", "mystery"]),
            (.societyCulture, ["society", "culture", "kultur", "samfunn"]),
            (.sports, ["sports", "sport", "football", "fotball", "soccer", "f1"]),
            (.healthFitness, ["health", "fitness", "helse", "trening"]),
            (.arts, ["arts", "art", "kunst", "design", "books"]),
            (.tvFilm, ["tv", "film", "movies", "cinema"]),
            (.education, ["education", "learning", "utdanning"]),
            (.fiction, ["fiction", "storytelling", "sci-fi"]),
            (.nordic, ["nordic", "norway", "norwegian", "norsk", "norge", "nrk", "podkast"])
        ]
        for (cat, words) in aliases {
            if cat.rawValue.lowercased() == q || words.contains(q) {
                return cat
            }
        }
        return nil
    }
}

struct iOSPodcastSearchResult: Identifiable, Codable, Hashable, Sendable {
    var id: String { feedURL }
    var title: String
    var author: String
    var feedURL: String
    var artworkURL: String?
    var genre: String?
    var episodeCount: Int?
    var directorySource: String
}

struct PendingMacPodcastSubscription: Codable, Hashable, Sendable {
    var feedURL: String
    var fallbackArtworkURL: String?
}

struct MacPodcastSubscribeRequest: Codable, Sendable {
    var feedURL: String
    var fallbackArtworkURL: String?
    var selectForSync: Bool
}

struct MacPodcastSubscribeResponse: Codable, Sendable {
    var ok: Bool
    var showID: String?
    var title: String?
    var manifestVersion: String
    var message: String
}

enum iOSFormatters {
    static func duration(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite && seconds > 0 else { return "0:00" }
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    static func bytes(_ count: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: max(0, count), countStyle: .file)
    }
}

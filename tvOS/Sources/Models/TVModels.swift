import Foundation
import SwiftUI

// MARK: - Retro Hi-Fi Living-Room Theme (Matches My Echo macOS & iOS)

enum EchoTVTheme {
    static let canvas = Color(red: 0.043, green: 0.051, blue: 0.071)
    static let surface = Color(red: 0.082, green: 0.094, blue: 0.132)
    static let surfaceElevated = Color(red: 0.125, green: 0.145, blue: 0.195)
    static let neoMint = Color(red: 0.00, green: 0.94, blue: 0.60)
    static let neoCyan = Color(red: 0.00, green: 0.83, blue: 1.00)
    static let hiResGold = Color(red: 1.00, green: 0.72, blue: 0.00)
    static let partyMagenta = Color(red: 1.00, green: 0.24, blue: 0.66)
    static let dangerCoral = Color(red: 1.00, green: 0.34, blue: 0.38)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.74)
    static let textMuted = Color.white.opacity(0.48)
    static let border = Color.white.opacity(0.12)
    static let borderStrong = Color.white.opacity(0.24)
    static let radiusCard: CGFloat = 14
    static let radiusControl: CGFloat = 10
    static let radiusSmall: CGFloat = 6
}

// MARK: - Formatting Helpers

enum TVFormatters {
    static func duration(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded(.down))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    static func shortTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: date)
    }
}

// MARK: - Wire Models (Compatible with macOS WirelessSyncServer + PartyModeServer)

struct TVTrack: Identifiable, Codable, Hashable, Sendable {
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

struct TVPlaylist: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var name: String
    var description: String
    var trackIDs: [String]
}

struct TVPodcastFeed: Identifiable, Codable, Hashable, Sendable {
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

struct TVPodcastEpisode: Identifiable, Codable, Hashable, Sendable {
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

struct TVAlbumEditorial: Identifiable, Codable, Hashable, Sendable {
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
        albumSummary != nil || artistSummary != nil || label != nil || releaseDate != nil || !genres.isEmpty
    }
}

struct TVArtistEditorial: Identifiable, Codable, Hashable, Sendable {
    var artistKey: String
    var summary: String?
    var fans: Int?
    var albumCount: Int?
    var imageURL: String?
    var fetchedAt: Date

    var id: String { artistKey }
}

struct TVPartyStatus: Codable, Hashable, Sendable {
    var isLive: Bool = false
    var port: Int?
    var lanIP: String?
    var joinURL: String?
    var playlistName: String = "Partymode"
}

struct TVFullCatalogPayload: Codable, Sendable {
    var serverName: String
    var serverKind: String?
    var catalogVersion: String
    var generatedAt: Date
    var tracks: [TVTrack]
    var playlists: [TVPlaylist]
    var podcastFeeds: [TVPodcastFeed]
    var episodes: [TVPodcastEpisode]
    var albumEditorial: [TVAlbumEditorial]
    var artistEditorial: [TVArtistEditorial]
    var partyStatus: TVPartyStatus

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        serverName = try c.decode(String.self, forKey: .serverName)
        serverKind = try c.decodeIfPresent(String.self, forKey: .serverKind)
        catalogVersion = try c.decode(String.self, forKey: .catalogVersion)
        generatedAt = try c.decode(Date.self, forKey: .generatedAt)
        tracks = try c.decodeIfPresent([TVTrack].self, forKey: .tracks) ?? []
        playlists = try c.decodeIfPresent([TVPlaylist].self, forKey: .playlists) ?? []
        podcastFeeds = try c.decodeIfPresent([TVPodcastFeed].self, forKey: .podcastFeeds) ?? []
        episodes = try c.decodeIfPresent([TVPodcastEpisode].self, forKey: .episodes) ?? []
        albumEditorial = try c.decodeIfPresent([TVAlbumEditorial].self, forKey: .albumEditorial) ?? []
        artistEditorial = try c.decodeIfPresent([TVArtistEditorial].self, forKey: .artistEditorial) ?? []
        partyStatus = try c.decodeIfPresent(TVPartyStatus.self, forKey: .partyStatus) ?? TVPartyStatus()
    }
}

struct TVPingPayload: Codable, Sendable {
    var app: String
    var serverKind: String?
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

// MARK: - Mac Remote Control Wire Models

struct TVRemotePlaybackState: Codable, Hashable, Sendable {
    var serverName: String
    var isPlaying: Bool
    var currentTrack: TVTrack?
    var currentTime: TimeInterval
    var duration: TimeInterval
    var volume: Double
    var isMuted: Bool
    var isShuffled: Bool
    var repeatMode: String
    var currentIndex: Int
    var queue: [TVTrack]
    var outputDeviceName: String
    var partyStatus: TVPartyStatus
}

struct TVRemoteCommandRequest: Codable, Sendable {
    var action: String
    var seconds: Double?
    var volume: Double?
    var queueIndex: Int?
    var trackID: String?
    var albumKey: String?
    var playlistID: String?
}

struct TVRemoteCommandResponse: Codable, Sendable {
    var ok: Bool
    var message: String?
    var state: TVRemotePlaybackState?
}

// MARK: - Party Mode Wire Models

struct TVPartyTrackItem: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var title: String
    var artist: String
    var album: String
    var duration: TimeInterval
    var year: Int?
    var format: String
    var artworkHash: String?
    var inPlaylist: Bool
    var inUpNext: Bool
}

struct TVPartyQueueEntry: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var position: Int
    var track: TVPartyTrackItem
    var isCurrent: Bool
    var isPlayed: Bool
    var addedBy: String?
    var addedByGuestID: String?
    var addedAt: Date?
    var plannedPlayAt: Date?
    var hasVoiceIntro: Bool
    var voiceIntroDuration: TimeInterval?
}

struct TVPartyGuestPresence: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var name: String
    var isActive: Bool
    var requestCount: Int
    var firstSeenAt: Date
    var lastSeenAt: Date
}

struct TVPartyChatMessage: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var guestID: String?
    var senderName: String
    var isHost: Bool
    var text: String
    var sentAt: Date
}

struct TVPartyPlaylistState: Codable, Hashable, Sendable {
    var playlistName: String
    var serverName: String
    var isPlaying: Bool
    var isPlayingVoiceIntro: Bool
    var currentTrackID: String?
    var currentIndex: Int?
    var currentTime: TimeInterval
    var duration: TimeInterval
    var libraryTotalCount: Int
    var upNextCount: Int
    var allowReRequestPlayed: Bool
    var chatEnabled: Bool
    var streamingEnabled: Bool
    var maxIntroSeconds: Int
    var httpsPort: Int?
    var stateUpdatedAt: Date
    var revision: Int
    var tracks: [TVPartyQueueEntry]
    var guests: [TVPartyGuestPresence]
    var chatMessages: [TVPartyChatMessage]
    var activeRendererID: String?
    var activeRendererName: String?
}

struct TVPartyEnvelope: Codable, Sendable {
    var status: TVPartyStatus
    var state: TVPartyPlaylistState?
}

// MARK: - Grouped Library Entities

struct TVAlbumGroup: Identifiable, Hashable, Sendable {
    var id: String
    var title: String
    var artist: String
    var year: Int?
    var artworkHash: String?
    var tracks: [TVTrack]
}

struct TVArtistGroup: Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var albums: [TVAlbumGroup]
    var trackCount: Int
    var artworkHash: String?
}

// MARK: - Unified Playable Item (Mac LAN Stream, Navidrome Stream, or Podcast Stream)

struct TVPlayableItem: Identifiable, Hashable, Sendable {
    enum SourceKind: Hashable, Sendable {
        case macStream(trackID: String, url: URL)
        case navidromeStream(songID: String, url: URL)
        case podcastStream(episodeID: String, url: URL)
    }

    var id: String
    var title: String
    var artist: String
    var album: String
    var albumKey: String?
    var duration: TimeInterval
    var formatPrimary: String
    var formatDetail: String?
    var isHiRes: Bool
    var isLossless: Bool
    var artworkURL: URL?
    var source: SourceKind
    var sourceBadge: String
}

// MARK: - Navidrome (Subsonic) Models

enum TVNavidromeStreamQuality: String, Codable, CaseIterable, Identifiable, Sendable {
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

struct TVNavidromeServerAddress: Identifiable, Codable, Hashable, Sendable {
    var id: UUID = UUID()
    var label: String
    var url: String
}

struct TVNavidromeConfig: Codable, Hashable, Sendable {
    var isEnabled: Bool = false
    var serverURL: String = ""
    var savedAddresses: [TVNavidromeServerAddress] = []
    var username: String = ""
    var password: String = ""
    var streamQuality: TVNavidromeStreamQuality = .original

    var isConfigured: Bool {
        !serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !password.isEmpty
    }
}

struct TVNavidromeAlbum: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var name: String
    var artist: String
    var artistId: String?
    var coverArt: String?
    var songCount: Int
    var year: Int?
    var duration: Int
}

struct TVNavidromeArtist: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var name: String
    var albumCount: Int
    var coverArt: String?
}

struct TVNavidromeSong: Identifiable, Codable, Hashable, Sendable {
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

struct TVNavidromePlaylist: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var name: String
    var songCount: Int
    var duration: Int
    var coverArt: String?
}

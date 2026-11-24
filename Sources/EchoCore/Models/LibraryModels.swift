import Foundation

public enum AudioFormat: String, Codable, CaseIterable, Sendable, Hashable {
    case flac
    case mp3
    case m4a
    case alac
    case wav
    case ogg
    case ape
    case dsf
    case dff
    case aiff
    case opus
    case wma
    case unknown

    public init(fileExtension: String) {
        switch fileExtension.lowercased() {
        case "flac": self = .flac
        case "mp3": self = .mp3
        case "m4a", "aac", "mp4": self = .m4a
        case "alac": self = .alac
        case "wav", "wave": self = .wav
        case "ogg", "oga": self = .ogg
        case "ape": self = .ape
        case "dsf": self = .dsf
        case "dff": self = .dff
        case "aif", "aiff": self = .aiff
        case "opus": self = .opus
        case "wma": self = .wma
        default: self = .unknown
        }
    }

    public var displayBadge: String {
        switch self {
        case .flac: return "FLAC"
        case .mp3: return "MP3"
        case .m4a: return "M4A"
        case .alac: return "ALAC"
        case .wav: return "WAV"
        case .ogg: return "OGG"
        case .ape: return "APE"
        case .dsf, .dff: return "DSD"
        case .aiff: return "AIFF"
        case .opus: return "OPUS"
        case .wma: return "WMA"
        case .unknown: return "AUDIO"
        }
    }

    public var isLossless: Bool {
        switch self {
        case .flac, .alac, .wav, .ape, .dsf, .dff, .aiff:
            return true
        default:
            return false
        }
    }

    public static let recognizedExtensions: Set<String> = [
        "flac", "mp3", "m4a", "aac", "alac", "wav", "wave",
        "ogg", "oga", "ape", "dsf", "dff", "aif", "aiff", "opus", "wma"
    ]
}

public struct LibrarySource: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var path: String
    public var isNetworkVolume: Bool
    public var lastIndexedAt: Date?
    public var trackCount: Int

    public init(
        id: UUID = UUID(),
        name: String,
        path: String,
        isNetworkVolume: Bool = false,
        lastIndexedAt: Date? = nil,
        trackCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.isNetworkVolume = isNetworkVolume
        self.lastIndexedAt = lastIndexedAt
        self.trackCount = trackCount
    }

    public var isAvailable: Bool {
        FileManager.default.fileExists(atPath: path)
    }
}

public struct Track: Identifiable, Codable, Hashable, Sendable {
    public var id: String // Stable hash of canonical file path
    public var sourceID: UUID
    public var filePath: String
    public var fileName: String
    public var fileSize: Int64
    public var modifiedAt: Date
    public var format: AudioFormat

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
    public var lyricsPath: String?
    public var isAvailable: Bool

    public init(
        id: String,
        sourceID: UUID,
        filePath: String,
        fileName: String,
        fileSize: Int64,
        modifiedAt: Date,
        format: AudioFormat,
        title: String,
        artist: String,
        albumArtist: String,
        album: String,
        trackNumber: Int? = nil,
        discNumber: Int? = nil,
        year: Int? = nil,
        genre: String? = nil,
        duration: TimeInterval = 0,
        sampleRate: Int? = nil,
        bitDepth: Int? = nil,
        bitrate: Int? = nil,
        artworkHash: String? = nil,
        hasEmbeddedArtwork: Bool = false,
        lyricsPath: String? = nil,
        isAvailable: Bool = true
    ) {
        self.id = id
        self.sourceID = sourceID
        self.filePath = filePath
        self.fileName = fileName
        self.fileSize = fileSize
        self.modifiedAt = modifiedAt
        self.format = format
        self.title = title
        self.artist = artist
        self.albumArtist = albumArtist
        self.album = album
        self.trackNumber = trackNumber
        self.discNumber = discNumber
        self.year = year
        self.genre = genre
        self.duration = duration
        self.sampleRate = sampleRate
        self.bitDepth = bitDepth
        self.bitrate = bitrate
        self.artworkHash = artworkHash
        self.hasEmbeddedArtwork = hasEmbeddedArtwork
        self.lyricsPath = lyricsPath
        self.isAvailable = isAvailable
    }

    /// Canonical grouping artist used for ARTIST/ALBUM/TRACK path structure
    public var effectiveArtist: String {
        let trimmedAlbumArtist = albumArtist.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedAlbumArtist.isEmpty { return trimmedAlbumArtist }
        let trimmedArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedArtist.isEmpty ? "Unknown Artist" : trimmedArtist
    }

    public var effectiveAlbum: String {
        let trimmed = album.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Unknown Album" : trimmed
    }

    public var albumKey: String {
        "\(effectiveArtist.lowercased())::\(effectiveAlbum.lowercased())"
    }

    public var artistKey: String {
        effectiveArtist.lowercased()
    }

    public var qualityLabel: String {
        if let bitDepth, let sampleRate, sampleRate > 0 {
            let khz = Double(sampleRate) / 1000.0
            let khzStr = khz.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(khz))" : String(format: "%.1f", khz)
            return "\(format.displayBadge) \(bitDepth)-bit/\(khzStr)kHz"
        }
        if format == .dsf || format == .dff {
            if let sampleRate, sampleRate >= 5_644_800 { return "DSD128" }
            return "DSD64"
        }
        if let bitrate, bitrate > 0 {
            return "\(format.displayBadge) \(bitrate)k"
        }
        return format.displayBadge
    }

    public var isHiRes: Bool {
        if format == .dsf || format == .dff { return true }
        if let bitDepth, bitDepth >= 24 { return true }
        if let sampleRate, sampleRate >= 88_200 { return true }
        return false
    }
}

public struct AlbumGroup: Identifiable, Hashable, Sendable {
    public var id: String // albumKey
    public var title: String
    public var artist: String
    public var year: Int?
    public var artworkHash: String?
    public var tracks: [Track]

    public init(
        id: String,
        title: String,
        artist: String,
        year: Int? = nil,
        artworkHash: String? = nil,
        tracks: [Track]
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.year = year
        self.artworkHash = artworkHash
        self.tracks = tracks
    }

    public var totalDuration: TimeInterval {
        tracks.reduce(0) { $0 + $1.duration }
    }

    public var totalSize: Int64 {
        tracks.reduce(0) { $0 + $1.fileSize }
    }
}

public struct ArtistGroup: Identifiable, Hashable, Sendable {
    public var id: String // artistKey
    public var name: String
    public var artworkHash: String?
    public var albums: [AlbumGroup]
    public var tracks: [Track]

    public init(
        id: String,
        name: String,
        artworkHash: String? = nil,
        albums: [AlbumGroup],
        tracks: [Track]
    ) {
        self.id = id
        self.name = name
        self.artworkHash = artworkHash
        self.albums = albums
        self.tracks = tracks
    }

    public var totalSize: Int64 {
        tracks.reduce(0) { $0 + $1.fileSize }
    }
}

public struct Playlist: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var description: String
    public var trackIDs: [String]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        trackIDs: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.trackIDs = trackIDs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

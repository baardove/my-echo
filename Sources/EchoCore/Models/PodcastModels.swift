import Foundation

public enum PodcastDirectory: String, Codable, CaseIterable, Identifiable, Sendable {
    case all = "all"
    case apple = "apple"
    case gpodder = "gpodder"
    case curated = "curated"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .all: return "All Directories"
        case .apple: return "Apple Podcasts"
        case .gpodder: return "gPodder Open"
        case .curated: return "Featured Picks"
        }
    }

    public var shortBadge: String {
        switch self {
        case .all: return "ALL"
        case .apple: return "APPLE"
        case .gpodder: return "GPODDER"
        case .curated: return "FEATURED"
        }
    }
}

public enum PodcastBrowseCategory: String, CaseIterable, Identifiable, Sendable {
    case featured = "Featured"
    case topCharts = "Top Charts"
    case technology = "Technology"
    case musicAudio = "Music & Hi-Fi"
    case science = "Science"
    case history = "History"
    case comedy = "Comedy"
    case trueCrime = "True Crime"
    case nordic = "Nordic / NO"

    public var id: String { rawValue }
}

public struct PodcastSearchResult: Identifiable, Codable, Hashable, Sendable {
    public var id: String { feedURL }
    public var title: String
    public var author: String
    public var feedURL: String
    public var artworkURL: String?
    public var genre: String?
    public var episodeCount: Int?
    public var directorySource: String

    public init(
        title: String,
        author: String,
        feedURL: String,
        artworkURL: String? = nil,
        genre: String? = nil,
        episodeCount: Int? = nil,
        directorySource: String = "APPLE"
    ) {
        self.title = title
        self.author = author
        self.feedURL = feedURL
        self.artworkURL = artworkURL
        self.genre = genre
        self.episodeCount = episodeCount
        self.directorySource = directorySource
    }
}

public struct PodcastShow: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var author: String
    public var description: String
    public var feedURL: String
    public var artworkURL: String?
    public var artworkHash: String?
    public var lastRefreshedAt: Date?
    /// Per-podcast retention limit: how many newest episodes to keep synced (0 = keep all).
    /// When newer episodes arrive, older episodes beyond this limit are automatically removed on sync.
    public var episodesToKeep: Int
    public var episodes: [PodcastEpisode]

    public init(
        id: UUID = UUID(),
        title: String,
        author: String,
        description: String = "",
        feedURL: String,
        artworkURL: String? = nil,
        artworkHash: String? = nil,
        lastRefreshedAt: Date? = nil,
        episodesToKeep: Int = 5,
        episodes: [PodcastEpisode] = []
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.description = description
        self.feedURL = feedURL
        self.artworkURL = artworkURL
        self.artworkHash = artworkHash
        self.lastRefreshedAt = lastRefreshedAt
        self.episodesToKeep = episodesToKeep
        self.episodes = episodes
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        author = try c.decode(String.self, forKey: .author)
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        feedURL = try c.decode(String.self, forKey: .feedURL)
        artworkURL = try c.decodeIfPresent(String.self, forKey: .artworkURL)
        artworkHash = try c.decodeIfPresent(String.self, forKey: .artworkHash)
        lastRefreshedAt = try c.decodeIfPresent(Date.self, forKey: .lastRefreshedAt)
        episodesToKeep = try c.decodeIfPresent(Int.self, forKey: .episodesToKeep) ?? 5
        episodes = try c.decodeIfPresent([PodcastEpisode].self, forKey: .episodes) ?? []
    }
}

public struct PodcastEpisode: Identifiable, Codable, Hashable, Sendable {
    public var id: String // Stable hash of showID + guid/audioURL
    public var showID: UUID
    public var showTitle: String
    public var showAuthor: String
    public var guid: String
    public var title: String
    public var summary: String
    public var publishedAt: Date?
    public var duration: TimeInterval
    public var audioURL: String
    public var fileSize: Int64
    public var fileExtension: String
    public var localFilePath: String?
    public var artworkHash: String?
    public var episodeNumber: Int?
    public var seasonNumber: Int?

    public init(
        id: String,
        showID: UUID,
        showTitle: String,
        showAuthor: String,
        guid: String,
        title: String,
        summary: String = "",
        publishedAt: Date? = nil,
        duration: TimeInterval = 0,
        audioURL: String,
        fileSize: Int64 = 0,
        fileExtension: String = "mp3",
        localFilePath: String? = nil,
        artworkHash: String? = nil,
        episodeNumber: Int? = nil,
        seasonNumber: Int? = nil
    ) {
        self.id = id
        self.showID = showID
        self.showTitle = showTitle
        self.showAuthor = showAuthor
        self.guid = guid
        self.title = title
        self.summary = summary
        self.publishedAt = publishedAt
        self.duration = duration
        self.audioURL = audioURL
        self.fileSize = fileSize
        self.fileExtension = fileExtension
        self.localFilePath = localFilePath
        self.artworkHash = artworkHash
        self.episodeNumber = episodeNumber
        self.seasonNumber = seasonNumber
    }

    public var isDownloaded: Bool {
        guard let path = localFilePath, !path.isEmpty else { return false }
        return FileManager.default.fileExists(atPath: path)
    }

    public var audioFormat: AudioFormat {
        let fmt = AudioFormat(fileExtension: fileExtension)
        return fmt == .unknown ? .mp3 : fmt
    }

    /// Converts a downloaded episode into a Track so it can play directly in AudioPlayerEngine.
    public func asPlayableTrack() -> Track? {
        guard let path = localFilePath, FileManager.default.fileExists(atPath: path) else { return nil }
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        let actualSize = (attrs?[.size] as? NSNumber)?.int64Value ?? fileSize
        let modDate = (attrs?[.modificationDate] as? Date) ?? publishedAt ?? Date()
        return Track(
            id: "podcast-\(id)",
            sourceID: showID,
            filePath: path,
            fileName: URL(fileURLWithPath: path).lastPathComponent,
            fileSize: actualSize,
            modifiedAt: modDate,
            format: audioFormat,
            title: title,
            artist: showAuthor.isEmpty ? showTitle : showAuthor,
            albumArtist: showTitle,
            album: showTitle,
            trackNumber: episodeNumber,
            discNumber: seasonNumber,
            duration: duration,
            artworkHash: artworkHash,
            isAvailable: true
        )
    }
}

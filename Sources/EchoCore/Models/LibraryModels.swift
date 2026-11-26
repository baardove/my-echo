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

public enum LibraryIndexingMode: String, Codable, CaseIterable, Hashable, Sendable {
    /// Traditional standalone local folder or mounted SMB/NFS NAS scanning via LibraryIndexer.
    case localDirect
    /// Optional remote indexing via My Echo Server (Unraid/Docker) using compressed delta/shard snapshots.
    case echoServer
}

public struct EchoServerConfig: Codable, Hashable, Sendable {
    public var isEnabled: Bool
    public var serverName: String
    public var lanURL: String
    public var tailscaleURL: String
    public var pairingPIN: String
    public var syncSharedState: Bool

    public init(
        isEnabled: Bool = false,
        serverName: String = "My Echo Server",
        lanURL: String = "",
        tailscaleURL: String = "",
        pairingPIN: String = "",
        syncSharedState: Bool = true
    ) {
        self.isEnabled = isEnabled
        self.serverName = serverName
        self.lanURL = lanURL
        self.tailscaleURL = tailscaleURL
        self.pairingPIN = pairingPIN
        self.syncSharedState = syncSharedState
    }

    public var isConfigured: Bool {
        isEnabled
            && (!lanURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !tailscaleURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            && !pairingPIN.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var candidateBaseURLs: [String] {
        [lanURL, tailscaleURL]
            .map { Self.normalizeURL($0) }
            .filter { !$0.isEmpty }
            .reduce(into: [String]()) { acc, u in
                if !acc.contains(u) { acc.append(u) }
            }
    }

    public static func normalizeURL(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return "" }
        if !s.lowercased().hasPrefix("http://") && !s.lowercased().hasPrefix("https://") {
            s = "http://" + s
        }
        while s.hasSuffix("/") { s.removeLast() }
        return s
    }
}

public struct LibrarySource: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var path: String
    public var isNetworkVolume: Bool
    public var lastIndexedAt: Date?
    public var trackCount: Int
    /// Defaults to `.localDirect` so standalone local/SMB NAS behavior is 100% preserved.
    public var indexingMode: LibraryIndexingMode
    public var remoteLibraryID: String?
    public var lastSyncedRevision: Int?
    public var cachedShardChecksums: [String: String]?

    public init(
        id: UUID = UUID(),
        name: String,
        path: String,
        isNetworkVolume: Bool = false,
        lastIndexedAt: Date? = nil,
        trackCount: Int = 0,
        indexingMode: LibraryIndexingMode = .localDirect,
        remoteLibraryID: String? = nil,
        lastSyncedRevision: Int? = nil,
        cachedShardChecksums: [String: String]? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.isNetworkVolume = isNetworkVolume
        self.lastIndexedAt = lastIndexedAt
        self.trackCount = trackCount
        self.indexingMode = indexingMode
        self.remoteLibraryID = remoteLibraryID
        self.lastSyncedRevision = lastSyncedRevision
        self.cachedShardChecksums = cachedShardChecksums
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, path, isNetworkVolume, lastIndexedAt, trackCount
        case indexingMode, remoteLibraryID, lastSyncedRevision, cachedShardChecksums
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        path = try c.decode(String.self, forKey: .path)
        isNetworkVolume = try c.decodeIfPresent(Bool.self, forKey: .isNetworkVolume) ?? false
        lastIndexedAt = try c.decodeIfPresent(Date.self, forKey: .lastIndexedAt)
        trackCount = try c.decodeIfPresent(Int.self, forKey: .trackCount) ?? 0
        indexingMode = try c.decodeIfPresent(LibraryIndexingMode.self, forKey: .indexingMode) ?? .localDirect
        remoteLibraryID = try c.decodeIfPresent(String.self, forKey: .remoteLibraryID)
        lastSyncedRevision = try c.decodeIfPresent(Int.self, forKey: .lastSyncedRevision)
        cachedShardChecksums = try c.decodeIfPresent([String: String].self, forKey: .cachedShardChecksums)
    }

    public var isLocalPathMounted: Bool {
        FileManager.default.fileExists(atPath: path)
    }

    public var isAvailable: Bool {
        if indexingMode == .echoServer {
            return true
        }
        return isLocalPathMounted
    }
}

public struct Track: Identifiable, Codable, Hashable, Sendable {
    public var id: String // Stable hash of canonical file path
    public var sourceID: UUID
    public var filePath: String
    public var fileName: String
    public var fileSize: Int64
    public var modifiedAt: Date
    public var addedAt: Date?
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
        addedAt: Date? = nil,
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
        self.addedAt = addedAt
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

    /// Best estimate of when this track arrived in the library (download / file added / modified date)
    public var arrivalDate: Date {
        if let addedAt {
            return max(addedAt, modifiedAt)
        }
        return modifiedAt
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

    private static let discFolderRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^(?i)(cd|disc|disk|digital\s*media|12\s*vinyl|vinyl|side)\s*\d+$"#,
        options: []
    )

    /// Normalized parent album directory of this track's file, collapsing multi-disc subfolders
    /// (e.g. `CD 1`, `Disc 2`, `Digital Media 01`, `12 Vinyl 02`) to their shared album folder.
    public var canonicalAlbumDirectory: String {
        let dirPath = (filePath as NSString).deletingLastPathComponent
        let base = (dirPath as NSString).lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        if let regex = Self.discFolderRegex,
           !base.isEmpty,
           regex.firstMatch(in: base, options: [], range: NSRange(location: 0, length: (base as NSString).length)) != nil {
            return (dirPath as NSString).deletingLastPathComponent.lowercased()
        }
        return dirPath.lowercased()
    }

    /// Canonical album key: normalized album title (never split by per-track artist within an album).
    public var albumKey: String {
        effectiveAlbum.lowercased()
    }

    /// Previous artist::album key format kept for backward compatibility with existing saved device selections.
    public var legacyAlbumKey: String {
        "\(effectiveArtist.lowercased())::\(effectiveAlbum.lowercased())"
    }

    public var artistKey: String {
        effectiveArtist.lowercased()
    }

    /// Primary format badge text (e.g. "FLAC", "MP3", "DSD")
    public var formatPrimaryLabel: String {
        format.displayBadge
    }

    /// Compact secondary quality spec (e.g. "16b/44.1kHz", "24b/96kHz", "320k", "DSD64")
    public var formatDetailLabel: String? {
        if format == .dsf || format == .dff {
            if let sampleRate, sampleRate >= 5_644_800 { return "DSD128" }
            return "DSD64"
        }
        if let bitDepth, let sampleRate, sampleRate > 0 {
            let khz = Double(sampleRate) / 1000.0
            let khzStr = khz.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(khz))" : String(format: "%.1f", khz)
            return "\(bitDepth)b/\(khzStr)kHz"
        }
        if let sampleRate, sampleRate > 0, format.isLossless {
            let khz = Double(sampleRate) / 1000.0
            let khzStr = khz.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(khz))" : String(format: "%.1f", khz)
            return "\(khzStr)kHz"
        }
        if let bitrate, bitrate > 0 {
            return "\(bitrate)k"
        }
        return nil
    }

    public var qualityLabel: String {
        if let detail = formatDetailLabel {
            if format == .dsf || format == .dff { return detail }
            return "\(format.displayBadge) \(detail)"
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
    public let totalDuration: TimeInterval
    public let totalSize: Int64
    /// Most recent arrival / download timestamp across tracks in this album (precomputed for O(1) sorting)
    public let latestArrivalDate: Date

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
        self.totalDuration = tracks.reduce(0) { $0 + $1.duration }
        self.totalSize = tracks.reduce(0) { $0 + $1.fileSize }
        self.latestArrivalDate = tracks.map(\.arrivalDate).max() ?? .distantPast
    }

    /// Groups tracks into AlbumGroups with one unified instance per album:
    /// - Never splits a compilation or multi-artist album across per-track artists (`albumArtist` is advisory only).
    /// - Shows `"Various Artists"` if more than half of tracks in the album have different artists; otherwise shows only the artist appearing on >= half.
    /// - Still keeps unrelated studio albums that happen to share a generic title (e.g. Anastacia's *Evolution* vs Sabrina Carpenter's *EVOLution*, or Seal's *7* vs Nelly Furtado's *7*) in separate album directories distinct!
    public static func buildGroups(from tracks: [Track]) -> [AlbumGroup] {
        buildGroupsWithTrackLookup(from: tracks).albums
    }

    /// Returns both the sorted `[AlbumGroup]` list and a `[trackID: AlbumGroup]` lookup so every caller
    /// (UI, SyncPlanner, PathFormatter, WirelessSyncServer) agrees identically on each track's unified album & folder artist.
    public static func buildGroupsWithTrackLookup(from tracks: [Track]) -> (albums: [AlbumGroup], albumByTrackID: [String: AlbumGroup]) {
        let byTitle = Dictionary(grouping: tracks, by: \.albumKey)
        var builtAlbums: [AlbumGroup] = []
        builtAlbums.reserveCapacity(byTitle.count)

        for (titleKey, titleTracks) in byTitle {
            // Partition by canonical album directory first (collapsing CD1/Disc 2/Digital Media 01 subfolders)
            let byDir = Dictionary(grouping: titleTracks, by: \.canonicalAlbumDirectory)

            // Resolve each folder's album artist using the track-majority / Various Artists rule,
            // then merge folders that share the same resolved artist (e.g. a compilation spread across 2 folders)
            var mergedByResolvedArtist: [String: (artist: String, tracks: [Track])] = [:]
            for (_, dirTracks) in byDir {
                let resolved = resolveDisplayArtist(for: dirTracks)
                let rk = resolved.lowercased()
                if var existing = mergedByResolvedArtist[rk] {
                    existing.tracks.append(contentsOf: dirTracks)
                    mergedByResolvedArtist[rk] = existing
                } else {
                    mergedByResolvedArtist[rk] = (resolved, dirTracks)
                }
            }

            let hasTitleCollision = mergedByResolvedArtist.count > 1
            for (artistKey, bucket) in mergedByResolvedArtist {
                let sorted = bucket.tracks.sorted {
                    ($0.discNumber ?? 1, $0.trackNumber ?? 999, $0.title.lowercased()) <
                    ($1.discNumber ?? 1, $1.trackNumber ?? 999, $1.title.lowercased())
                }
                guard let first = sorted.first else { continue }
                let art = sorted.first(where: { $0.artworkHash != nil })?.artworkHash
                let year = sorted.compactMap(\.year).first
                let finalArtist = resolveDisplayArtist(for: sorted)
                let albumID = hasTitleCollision ? "\(titleKey)::\(artistKey)" : titleKey
                builtAlbums.append(AlbumGroup(
                    id: albumID,
                    title: first.effectiveAlbum,
                    artist: finalArtist,
                    year: year,
                    artworkHash: art,
                    tracks: sorted
                ))
            }
        }

        builtAlbums.sort {
            let cmp = $0.title.localizedCaseInsensitiveCompare($1.title)
            if cmp != .orderedSame { return cmp == .orderedAscending }
            return $0.artist.localizedCaseInsensitiveCompare($1.artist) == .orderedAscending
        }

        var albumByTrackID: [String: AlbumGroup] = [:]
        albumByTrackID.reserveCapacity(tracks.count)
        for alb in builtAlbums {
            for t in alb.tracks {
                albumByTrackID[t.id] = alb
            }
        }
        return (builtAlbums, albumByTrackID)
    }

    /// Resolves the canonical display artist for an album from its tracks (`albumArtist` is advisory only).
    public static func resolveDisplayArtist(for tracks: [Track]) -> String {
        resolveDisplayArtist(trackCredits: tracks.map { ($0.artist, $0.albumArtist) })
    }

    /// Core album artist resolution rule:
    /// - Count track artists across all tracks (`albumArtist` is advisory only: used as fallback when track artist is blank or to break an exact 50/50 tie).
    /// - If one artist appears on at least half of the tracks (`count * 2 >= total`), display only that artist.
    /// - If more than half of the tracks have different artists (no single artist reaches half, or unresolved 50/50 split), display `"Various Artists"`.
    public static func resolveDisplayArtist(
        trackCredits: [(artist: String, albumArtist: String)]
    ) -> String {
        let total = trackCredits.count
        guard total > 0 else { return "Unknown Artist" }

        func clean(_ s: String) -> String {
            let scalars = s.unicodeScalars.filter { scalar in
                let v = scalar.value
                return !(v == 0xFEFF || (v >= 0x200B && v <= 0x200F) || v == 0x2060 || (v >= 0x2028 && v <= 0x202F))
            }
            return String(String.UnicodeScalarView(scalars)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Advisory albumArtist preference (only consulted as fallback or to break an exact 50/50 tie)
        var advisoryCounts: [String: (name: String, count: Int)] = [:]
        for item in trackCredits {
            let raw = clean(item.albumArtist)
            guard !raw.isEmpty else { continue }
            let key = raw.lowercased()
            guard !isVariousPlaceholder(key) else { continue }
            if let existing = advisoryCounts[key] {
                advisoryCounts[key] = (existing.name, existing.count + 1)
            } else {
                advisoryCounts[key] = (raw, 1)
            }
        }
        let advisoryBestKey = advisoryCounts.values.max(by: { $0.count < $1.count })?.name.lowercased()

        // Step 1: Exact normalized per-track artist counts (track.artist takes priority; albumArtist only if track.artist is empty)
        var exactCounts: [String: (name: String, count: Int)] = [:]
        for item in trackCredits {
            let rawArtist = clean(item.artist)
            let effective = rawArtist.isEmpty ? clean(item.albumArtist) : rawArtist
            guard !effective.isEmpty else { continue }
            let key = effective.lowercased()
            if let existing = exactCounts[key] {
                exactCounts[key] = (existing.name, existing.count + 1)
            } else {
                exactCounts[key] = (effective, 1)
            }
        }

        if exactCounts.isEmpty {
            return "Unknown Artist"
        }

        let exactQualifying = exactCounts.values
            .filter { $0.count * 2 >= total }
            .sorted { $0.count > $1.count }

        if let winner = pickUniqueOrAdvisoryWinner(from: exactQualifying, advisoryKey: advisoryBestKey) {
            if isVariousPlaceholder(winner.lowercased()) {
                return "Various Artists"
            }
            // If the winning track credit is a multi-artist collab (e.g. "Alan Walker, Noah Cyrus, ..."),
            // and the advisory albumArtist is one of the credited artists on that track, prefer the clean main artist!
            if let advisoryKey = advisoryBestKey,
               let advisoryName = advisoryCounts[advisoryKey]?.name {
                let parsed = ArtistNameParser.artistNames(winner)
                if parsed.count > 1, parsed.contains(where: { $0.lowercased() == advisoryKey }) {
                    return advisoryName
                }
            }
            return winner
        }

        // Step 2: Parsed individual artist credits per track (handles albums like "Main Artist feat. Guest A", "Main Artist feat. Guest B")
        var splitCounts: [String: (name: String, count: Int)] = [:]
        for item in trackCredits {
            let rawArtist = clean(item.artist)
            let effective = rawArtist.isEmpty ? clean(item.albumArtist) : rawArtist
            guard !effective.isEmpty else { continue }
            var seenOnTrack: Set<String> = []
            for name in ArtistNameParser.artistNames(effective) {
                let key = name.lowercased()
                guard !isVariousPlaceholder(key) else { continue }
                if seenOnTrack.insert(key).inserted {
                    if let existing = splitCounts[key] {
                        splitCounts[key] = (existing.name, existing.count + 1)
                    } else {
                        splitCounts[key] = (name, 1)
                    }
                }
            }
        }

        let splitQualifying = splitCounts.values
            .filter { $0.count * 2 >= total }
            .sorted { $0.count > $1.count }

        if let winner = pickUniqueOrAdvisoryWinner(from: splitQualifying, advisoryKey: advisoryBestKey) {
            return winner
        }

        return "Various Artists"
    }

    private static func isVariousPlaceholder(_ lowercased: String) -> Bool {
        lowercased == "various artists" || lowercased == "various" || lowercased == "va" || lowercased == "v.a."
    }

    private static func pickUniqueOrAdvisoryWinner(
        from qualifying: [(name: String, count: Int)],
        advisoryKey: String?
    ) -> String? {
        guard let top = qualifying.first else { return nil }
        let tied = qualifying.filter { $0.count == top.count }
        if tied.count == 1 {
            return top.name
        }
        if let advisoryKey, let match = tied.first(where: { $0.name.lowercased() == advisoryKey }) {
            return match.name
        }
        return nil
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

    /// Most recent arrival / download timestamp across tracks by this artist
    public var latestArrivalDate: Date {
        tracks.map(\.arrivalDate).max() ?? .distantPast
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

/// A single parsed artist token and its original trailing separator (e.g. ", ", " feat. ", " & ")
public struct ArtistNameSegment: Hashable, Sendable {
    public var name: String
    public var trailingSeparator: String

    public init(name: String, trailingSeparator: String = "") {
        self.name = name
        self.trailingSeparator = trailingSeparator
    }
}

/// Smart multi-artist splitter that separates collaborations ("A, B, C", "A feat. B & C", "A; B", "A x B")
/// while preserving iconic band names ("Earth, Wind & Fire", "Simon & Garfunkel", "Bruce Springsteen & The E Street Band", "AC/DC").
public enum ArtistNameParser {
    private static let atomicNames: Set<String> = [
        "earth, wind & fire",
        "earth, wind and fire",
        "crosby, stills & nash",
        "crosby, stills and nash",
        "crosby, stills, nash & young",
        "crosby, stills, nash and young",
        "emerson, lake & palmer",
        "emerson, lake and palmer",
        "blood, sweat & tears",
        "blood, sweat and tears",
        "peter, paul & mary",
        "peter, paul and mary",
        "tyler, the creator",
        "simon & garfunkel",
        "hall & oates",
        "daryl hall & john oates",
        "kool & the gang",
        "florence + the machine",
        "florence and the machine",
        "mumford & sons",
        "of monsters and men",
        "belle and sebastian",
        "coheed and cambria",
        "tegan and sara",
        "above & beyond",
        "chase & status",
        "brooks & dunn",
        "sonny & cher",
        "ike & tina turner",
        "sly & the family stone",
        "huey lewis & the news",
        "hootie & the blowfish",
        "bob marley & the wailers",
        "tom petty & the heartbreakers",
        "tom petty and the heartbreakers",
        "bruce springsteen & the e street band",
        "nick cave & the bad seeds",
        "gloria estefan & miami sound machine",
        "katrina & the waves",
        "echo & the bunnymen",
        "siouxsie and the banshees",
        "martha and the vandellas",
        "smokey robinson & the miracles",
        "diana ross & the supremes",
        "ac/dc"
    ]

    private static let splitRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)(\s*;\s*|\s*,\s+|\s+(?:feat\.?|ft\.?|featuring|with|vs\.?|x)\s+|\s+\/\s+|\s+\+\s+(?!the\b)|\s+&\s+(?!the\b))"#,
        options: []
    )

    /// Splits a raw artist credit string into individually linkable artist segments with their original separators.
    public static func splitSegments(_ raw: String) -> [ArtistNameSegment] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let lower = trimmed.lowercased()
        if atomicNames.contains(lower) {
            return [ArtistNameSegment(name: trimmed)]
        }

        // Fast path: 90%+ of artist names contain no multi-artist delimiter characters or keywords
        let mightHaveDelimiter = lower.contains(",") || lower.contains(";") || lower.contains("&")
            || lower.contains("+") || lower.contains("/") || lower.contains(" feat")
            || lower.contains(" ft") || lower.contains(" with ") || lower.contains(" vs")
            || lower.contains(" x ")
        guard mightHaveDelimiter else {
            return [ArtistNameSegment(name: trimmed)]
        }

        // First protect any embedded atomic band names (e.g. "Earth, Wind & Fire feat. Boogie Wonderland")
        var working = trimmed
        var placeholders: [(token: String, original: String)] = []
        for atomic in atomicNames {
            if let range = working.range(of: atomic, options: [.caseInsensitive]) {
                let originalSlice = String(working[range])
                let token = "__ECHO_ATOMIC_\(placeholders.count)__"
                placeholders.append((token, originalSlice))
                working.replaceSubrange(range, with: token)
            }
        }

        guard let regex = Self.splitRegex else {
            return [ArtistNameSegment(name: trimmed)]
        }

        let ns = working as NSString
        let fullRange = NSRange(location: 0, length: ns.length)
        let matches = regex.matches(in: working, options: [], range: fullRange)
        guard !matches.isEmpty else {
            return [ArtistNameSegment(name: trimmed)]
        }

        var segments: [ArtistNameSegment] = []
        var cursor = 0

        for match in matches {
            let nameRange = NSRange(location: cursor, length: match.range.location - cursor)
            let rawName = ns.substring(with: nameRange).trimmingCharacters(in: .whitespacesAndNewlines)
            let sep = ns.substring(with: match.range)
            cursor = match.range.location + match.range.length
            if !rawName.isEmpty {
                segments.append(ArtistNameSegment(name: restorePlaceholders(rawName, placeholders), trailingSeparator: sep))
            }
        }

        let tail = ns.substring(from: cursor).trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty {
            segments.append(ArtistNameSegment(name: restorePlaceholders(tail, placeholders), trailingSeparator: ""))
        } else if !segments.isEmpty {
            segments[segments.count - 1].trailingSeparator = ""
        }

        // Clean any leading/trailing parentheses left from "(feat. X)" patterns
        var cleaned: [ArtistNameSegment] = []
        for seg in segments {
            var name = seg.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if name.hasPrefix("(") && !name.contains(")") {
                name = String(name.dropFirst()).trimmingCharacters(in: .whitespaces)
            }
            if name.hasSuffix(")") && !name.contains("(") {
                name = String(name.dropLast()).trimmingCharacters(in: .whitespaces)
            }
            if !name.isEmpty {
                cleaned.append(ArtistNameSegment(name: name, trailingSeparator: seg.trailingSeparator))
            }
        }

        return cleaned.isEmpty ? [ArtistNameSegment(name: trimmed)] : cleaned
    }

    /// Convenience list of distinct artist names parsed from a credit string.
    public static func artistNames(_ raw: String) -> [String] {
        var seen: Set<String> = []
        var out: [String] = []
        for seg in splitSegments(raw) {
            let key = seg.name.lowercased()
            if seen.insert(key).inserted {
                out.append(seg.name)
            }
        }
        return out
    }

    private static func restorePlaceholders(_ text: String, _ placeholders: [(token: String, original: String)]) -> String {
        var result = text
        for (token, original) in placeholders {
            result = result.replacingOccurrences(of: token, with: original)
        }
        return result
    }
}

/// Persistent per-track listening, rating & online popularity stats (stored independently from re-indexed file metadata)
public struct TrackStats: Identifiable, Codable, Hashable, Sendable {
    public var trackID: String
    public var userPlayCount: Int
    public var lastPlayedAt: Date?
    /// Personal 1–5 star rating (nil = unrated)
    public var userRating: Int?
    /// Normalized 0–100 online popularity score (e.g. from Deezer rank or Last.fm)
    public var onlinePopularity: Int?
    /// Raw global play/rank counter (e.g. Last.fm global plays or Deezer rank score)
    public var onlinePlayCount: Int?
    /// Optional unique online listeners count (e.g. Last.fm listeners)
    public var onlineListeners: Int?
    /// Source identifier ("deezer", "lastfm", etc.)
    public var onlineSource: String?
    public var onlineFetchedAt: Date?

    public var id: String { trackID }

    public init(
        trackID: String,
        userPlayCount: Int = 0,
        lastPlayedAt: Date? = nil,
        userRating: Int? = nil,
        onlinePopularity: Int? = nil,
        onlinePlayCount: Int? = nil,
        onlineListeners: Int? = nil,
        onlineSource: String? = nil,
        onlineFetchedAt: Date? = nil
    ) {
        self.trackID = trackID
        self.userPlayCount = userPlayCount
        self.lastPlayedAt = lastPlayedAt
        self.userRating = userRating.map { max(1, min(5, $0)) }
        self.onlinePopularity = onlinePopularity
        self.onlinePlayCount = onlinePlayCount
        self.onlineListeners = onlineListeners
        self.onlineSource = onlineSource
        self.onlineFetchedAt = onlineFetchedAt
    }

    public var hasOnlinePopularity: Bool {
        onlinePopularity != nil
    }

    /// 1...5 visual popularity bar level
    public var popularityBars: Int {
        guard let pop = onlinePopularity else { return 0 }
        switch pop {
        case 80...: return 5
        case 60..<80: return 4
        case 40..<60: return 3
        case 20..<40: return 2
        case 1..<20: return 1
        default: return 0
        }
    }
}

/// Persistent personal 1–5 star rating for an album (stored independently from re-indexed file metadata)
public struct AlbumUserRating: Identifiable, Codable, Hashable, Sendable {
    public var albumKey: String
    public var rating: Int
    public var updatedAt: Date

    public var id: String { albumKey }

    public init(albumKey: String, rating: Int, updatedAt: Date = Date()) {
        self.albumKey = albumKey
        self.rating = max(1, min(5, rating))
        self.updatedAt = updatedAt
    }
}

/// Cached online artist metrics (fan / listener counts)
public struct ArtistOnlineStats: Identifiable, Codable, Hashable, Sendable {
    public var artistKey: String
    public var fans: Int?
    public var source: String
    public var fetchedAt: Date

    public var id: String { artistKey }

    public init(artistKey: String, fans: Int? = nil, source: String = "deezer", fetchedAt: Date = Date()) {
        self.artistKey = artistKey
        self.fans = fans
        self.source = source
        self.fetchedAt = fetchedAt
    }
}

/// Locally persisted album + artist editorial info pulled from online sources (Deezer + Wikipedia) and refreshed occasionally.
public struct AlbumEditorialInfo: Identifiable, Codable, Hashable, Sendable {
    public static let refreshTTL: TimeInterval = 14 * 24 * 60 * 60 // Refresh occasionally (every 14 days)

    public var albumKey: String
    public var releaseDate: String?
    public var label: String?
    public var genres: [String]
    public var albumFans: Int?
    public var artistFans: Int?
    public var artistAlbumCount: Int?
    public var albumSummary: String?
    public var artistSummary: String?
    public var artistImageURL: String?
    public var fetchedAt: Date

    public var id: String { albumKey }

    public init(
        albumKey: String,
        releaseDate: String? = nil,
        label: String? = nil,
        genres: [String] = [],
        albumFans: Int? = nil,
        artistFans: Int? = nil,
        artistAlbumCount: Int? = nil,
        albumSummary: String? = nil,
        artistSummary: String? = nil,
        artistImageURL: String? = nil,
        fetchedAt: Date = Date()
    ) {
        self.albumKey = albumKey
        self.releaseDate = releaseDate
        self.label = label
        self.genres = genres
        self.albumFans = albumFans
        self.artistFans = artistFans
        self.artistAlbumCount = artistAlbumCount
        self.albumSummary = albumSummary
        self.artistSummary = artistSummary
        self.artistImageURL = artistImageURL
        self.fetchedAt = fetchedAt
    }

    public var isStale: Bool {
        Date().timeIntervalSince(fetchedAt) >= Self.refreshTTL
    }

    public var hasDisplayableContent: Bool {
        albumSummary != nil || artistSummary != nil || label != nil || releaseDate != nil || !genres.isEmpty || albumFans != nil || artistFans != nil
    }
}

/// Locally persisted artist bio & metadata pulled from online sources and refreshed occasionally.
public struct ArtistEditorialInfo: Identifiable, Codable, Hashable, Sendable {
    public static let refreshTTL: TimeInterval = 14 * 24 * 60 * 60 // Refresh occasionally (every 14 days)

    public var artistKey: String
    public var summary: String?
    public var fans: Int?
    public var albumCount: Int?
    public var imageURL: String?
    public var fetchedAt: Date

    public var id: String { artistKey }

    public init(
        artistKey: String,
        summary: String? = nil,
        fans: Int? = nil,
        albumCount: Int? = nil,
        imageURL: String? = nil,
        fetchedAt: Date = Date()
    ) {
        self.artistKey = artistKey
        self.summary = summary
        self.fans = fans
        self.albumCount = albumCount
        self.imageURL = imageURL
        self.fetchedAt = fetchedAt
    }

    public var isStale: Bool {
        Date().timeIntervalSince(fetchedAt) >= Self.refreshTTL
    }

    public var hasDisplayableContent: Bool {
        summary != nil || fans != nil || albumCount != nil
    }
}

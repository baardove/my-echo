import Foundation

public enum DestinationMode: String, Codable, CaseIterable, Sendable, Hashable {
    case single = "single"
    case multi = "multi"

    public var displayName: String {
        switch self {
        case .single: return "Single Destination"
        case .multi: return "Multi-Destination"
        }
    }

    public var detail: String {
        switch self {
        case .single:
            return "Streamlined workflow targeting one primary player or SD card automatically."
        case .multi:
            return "Manage multiple players/SD cards independently. Explicitly select which destination to target — every track & podcast remembers which destination(s) it syncs to."
        }
    }
}

public enum DeviceAccentColor: String, Codable, CaseIterable, Sendable, Hashable {
    case mint
    case cyan
    case gold
    case violet
    case coral
    case blue

    public var displayName: String {
        rawValue.capitalized
    }
}

public enum DevicePresetKind: String, Codable, CaseIterable, Sendable, Hashable {
    case fiioEchoMini = "fiio_echo_mini"
    case fiioNano = "fiio_nano"
    case fiioDisc = "fiio_disc"
    case fiioAndroidDAP = "fiio_android_dap"
    case genericDAP = "generic_dap"

    public var displayName: String {
        switch self {
        case .fiioEchoMini: return "FiiO / Snowsky Echo"
        case .fiioNano: return "FiiO / Snowsky Nano"
        case .fiioDisc: return "FiiO / Snowsky Disc"
        case .fiioAndroidDAP: return "FiiO Android DAP (M / JM Series)"
        case .genericDAP: return "Generic SD Card / Audio Player"
        }
    }

    public var subtitle: String {
        switch self {
        case .fiioEchoMini:
            return "FAT32 · 600px Baseline JPEG · D:\\ M3U · 8,191 track cap"
        case .fiioNano:
            return "0.91\" OLED · FAT32/exFAT ≤256GB · 500px JPEG · Lightweight ID3v2.3"
        case .fiioDisc:
            return "Ingenic Linux · 1000px JPEG (≤1.35MB) · / M3U8 · Up to 2TB MicroSD"
        case .fiioAndroidDAP:
            return "exFAT/FAT32 · 1000px Baseline JPEG · / M3U8 · Wide format support"
        case .genericDAP:
            return "Relative / M3U8 · 800px Baseline JPEG · Clean macOS metadata"
        }
    }
}

public enum SyncMode: String, Codable, CaseIterable, Sendable, Hashable {
    case mirror = "mirror"
    case additive = "additive"

    public var displayName: String {
        switch self {
        case .mirror: return "Mirror Sync"
        case .additive: return "Additive Copy"
        }
    }

    public var detail: String {
        switch self {
        case .mirror: return "Copies selected music/podcasts and removes previously synced items that are no longer selected."
        case .additive: return "Copies new or updated selections without deleting anything from the player."
        }
    }
}

public enum PlaylistPathStyle: String, Codable, CaseIterable, Sendable, Hashable {
    case echoMiniSD = "echo_mini_sd"             // D:\Music\Artist\Album\Track.flac
    case echoMiniInternal = "echo_mini_internal" // C:\Music\Artist\Album\Track.flac
    case relativeForwardSlash = "relative_slash" // Music/Artist/Album/Track.flac
    case androidExternalSD = "android_ext_sd"    // /storage/external_sd/Music/Artist/Album/Track.flac

    public var displayName: String {
        switch self {
        case .echoMiniSD: return "Echo / Nano MicroSD (D:\\...)"
        case .echoMiniInternal: return "Echo Internal (C:\\...)"
        case .relativeForwardSlash: return "Relative Forward Slash (Music/...)"
        case .androidExternalSD: return "FiiO Android SD (/storage/external_sd/...)"
        }
    }
}

public struct DeviceProfile: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var hasCustomName: Bool
    public var accentColor: DeviceAccentColor
    public var volumeUUID: String?
    public var mountPath: String
    public var preset: DevicePresetKind
    public var syncMode: SyncMode

    // Folder & path settings
    public var musicSubfolder: String          // e.g. "Music" or "" for root
    public var podcastsSubfolder: String       // e.g. "Podcasts"
    public var playlistsSubfolder: String      // e.g. "" (root) or "Playlists"
    public var playlistPathStyle: PlaylistPathStyle
    public var useM3U8Extension: Bool

    // Artwork & metadata optimization
    public var optimizeArtwork: Bool
    public var maxArtworkDimension: Int        // e.g. 600 for Echo Mini, 1000 for Android DAP
    public var maxArtworkBytes: Int            // e.g. 350_000 bytes
    public var writeFolderCoverJPG: Bool
    public var stripMP3Comments: Bool
    public var copySidecarLyrics: Bool
    public var cleanMacOSDotFiles: Bool

    // Format compatibility & hardware limits
    public var supportedFormats: Set<AudioFormat>
    public var maxTrackLimit: Int?             // e.g. 8191 for FiiO Echo Mini

    // Saved sync selections for this device
    public var selectedArtistKeys: Set<String>
    public var selectedAlbumKeys: Set<String>
    public var selectedTrackIDs: Set<String>
    public var selectedPlaylistIDs: Set<UUID>

    // Podcast sync selections for this device
    public var selectedPodcastShowIDs: Set<UUID>
    public var selectedEpisodeIDs: Set<String>
    public var podcastEpisodesPerShowLimit: Int // e.g. latest 5 episodes when a whole show is synced

    // Persisted record of what has actually been synced to this destination (works even while offline!)
    public var syncedTrackIDs: Set<String>
    public var syncedEpisodeIDs: Set<String>

    public var lastSyncedAt: Date?

    public init(
        id: UUID = UUID(),
        name: String,
        hasCustomName: Bool = false,
        accentColor: DeviceAccentColor = .mint,
        volumeUUID: String? = nil,
        mountPath: String,
        preset: DevicePresetKind = .fiioEchoMini,
        syncMode: SyncMode = .mirror,
        musicSubfolder: String? = nil,
        podcastsSubfolder: String? = nil,
        playlistsSubfolder: String? = nil,
        playlistPathStyle: PlaylistPathStyle? = nil,
        useM3U8Extension: Bool? = nil,
        optimizeArtwork: Bool = true,
        maxArtworkDimension: Int? = nil,
        maxArtworkBytes: Int = 350_000,
        writeFolderCoverJPG: Bool = true,
        stripMP3Comments: Bool? = nil,
        copySidecarLyrics: Bool = true,
        cleanMacOSDotFiles: Bool = true,
        supportedFormats: Set<AudioFormat>? = nil,
        maxTrackLimit: Int?? = nil,
        selectedArtistKeys: Set<String> = [],
        selectedAlbumKeys: Set<String> = [],
        selectedTrackIDs: Set<String> = [],
        selectedPlaylistIDs: Set<UUID> = [],
        selectedPodcastShowIDs: Set<UUID> = [],
        selectedEpisodeIDs: Set<String> = [],
        podcastEpisodesPerShowLimit: Int = 5,
        syncedTrackIDs: Set<String> = [],
        syncedEpisodeIDs: Set<String> = [],
        lastSyncedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.hasCustomName = hasCustomName
        self.accentColor = accentColor
        self.volumeUUID = volumeUUID
        self.mountPath = mountPath
        self.preset = preset
        self.syncMode = syncMode

        switch preset {
        case .fiioEchoMini:
            self.musicSubfolder = musicSubfolder ?? "Music"
            self.podcastsSubfolder = podcastsSubfolder ?? "Podcasts"
            self.playlistsSubfolder = playlistsSubfolder ?? ""
            self.playlistPathStyle = playlistPathStyle ?? .echoMiniSD
            self.useM3U8Extension = useM3U8Extension ?? false
            self.maxArtworkDimension = maxArtworkDimension ?? 600
            self.stripMP3Comments = stripMP3Comments ?? true
            self.supportedFormats = supportedFormats ?? [.flac, .mp3, .wav, .m4a, .alac, .ogg, .ape, .dsf, .dff]
            self.maxTrackLimit = maxTrackLimit ?? 8191
        case .fiioNano:
            self.musicSubfolder = musicSubfolder ?? "Music"
            self.podcastsSubfolder = podcastsSubfolder ?? "Podcasts"
            self.playlistsSubfolder = playlistsSubfolder ?? ""
            self.playlistPathStyle = playlistPathStyle ?? .echoMiniSD
            self.useM3U8Extension = useM3U8Extension ?? false
            self.maxArtworkDimension = maxArtworkDimension ?? 500
            self.stripMP3Comments = stripMP3Comments ?? true
            self.supportedFormats = supportedFormats ?? [.flac, .mp3, .wav, .m4a, .alac, .ogg, .ape, .dsf, .dff]
            self.maxTrackLimit = maxTrackLimit ?? 8191
        case .fiioDisc:
            self.musicSubfolder = musicSubfolder ?? "Music"
            self.podcastsSubfolder = podcastsSubfolder ?? "Podcasts"
            self.playlistsSubfolder = playlistsSubfolder ?? "Playlists"
            self.playlistPathStyle = playlistPathStyle ?? .relativeForwardSlash
            self.useM3U8Extension = useM3U8Extension ?? true
            self.maxArtworkDimension = maxArtworkDimension ?? 1000
            self.stripMP3Comments = stripMP3Comments ?? false
            self.supportedFormats = supportedFormats ?? [.flac, .mp3, .wav, .m4a, .alac, .ogg, .ape, .dsf, .dff]
            self.maxTrackLimit = maxTrackLimit ?? nil
        case .fiioAndroidDAP:
            self.musicSubfolder = musicSubfolder ?? "Music"
            self.podcastsSubfolder = podcastsSubfolder ?? "Podcasts"
            self.playlistsSubfolder = playlistsSubfolder ?? "Playlists"
            self.playlistPathStyle = playlistPathStyle ?? .relativeForwardSlash
            self.useM3U8Extension = useM3U8Extension ?? true
            self.maxArtworkDimension = maxArtworkDimension ?? 1000
            self.stripMP3Comments = stripMP3Comments ?? false
            self.supportedFormats = supportedFormats ?? [.flac, .mp3, .wav, .m4a, .alac, .ogg, .ape, .dsf, .dff, .aiff, .opus, .wma]
            self.maxTrackLimit = maxTrackLimit ?? nil
        case .genericDAP:
            self.musicSubfolder = musicSubfolder ?? "Music"
            self.podcastsSubfolder = podcastsSubfolder ?? "Podcasts"
            self.playlistsSubfolder = playlistsSubfolder ?? "Playlists"
            self.playlistPathStyle = playlistPathStyle ?? .relativeForwardSlash
            self.useM3U8Extension = useM3U8Extension ?? false
            self.maxArtworkDimension = maxArtworkDimension ?? 800
            self.stripMP3Comments = stripMP3Comments ?? false
            self.supportedFormats = supportedFormats ?? [.flac, .mp3, .wav, .m4a, .alac, .ogg, .aiff]
            self.maxTrackLimit = maxTrackLimit ?? nil
        }

        self.optimizeArtwork = optimizeArtwork
        self.maxArtworkBytes = maxArtworkBytes
        self.writeFolderCoverJPG = writeFolderCoverJPG
        self.copySidecarLyrics = copySidecarLyrics
        self.cleanMacOSDotFiles = cleanMacOSDotFiles
        self.selectedArtistKeys = selectedArtistKeys
        self.selectedAlbumKeys = selectedAlbumKeys
        self.selectedTrackIDs = selectedTrackIDs
        self.selectedPlaylistIDs = selectedPlaylistIDs
        self.selectedPodcastShowIDs = selectedPodcastShowIDs
        self.selectedEpisodeIDs = selectedEpisodeIDs
        self.podcastEpisodesPerShowLimit = podcastEpisodesPerShowLimit
        self.syncedTrackIDs = syncedTrackIDs
        self.syncedEpisodeIDs = syncedEpisodeIDs
        self.lastSyncedAt = lastSyncedAt
    }

    // Backwards-compatible Codable decoder so existing saved DeviceProfiles in SQLite migrate seamlessly!
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        hasCustomName = try c.decodeIfPresent(Bool.self, forKey: .hasCustomName) ?? false
        accentColor = try c.decodeIfPresent(DeviceAccentColor.self, forKey: .accentColor) ?? .mint
        volumeUUID = try c.decodeIfPresent(String.self, forKey: .volumeUUID)
        mountPath = try c.decode(String.self, forKey: .mountPath)
        preset = try c.decode(DevicePresetKind.self, forKey: .preset)
        syncMode = try c.decode(SyncMode.self, forKey: .syncMode)
        musicSubfolder = try c.decode(String.self, forKey: .musicSubfolder)
        podcastsSubfolder = try c.decodeIfPresent(String.self, forKey: .podcastsSubfolder) ?? "Podcasts"
        playlistsSubfolder = try c.decode(String.self, forKey: .playlistsSubfolder)
        playlistPathStyle = try c.decode(PlaylistPathStyle.self, forKey: .playlistPathStyle)
        useM3U8Extension = try c.decode(Bool.self, forKey: .useM3U8Extension)
        optimizeArtwork = try c.decode(Bool.self, forKey: .optimizeArtwork)
        maxArtworkDimension = try c.decode(Int.self, forKey: .maxArtworkDimension)
        maxArtworkBytes = try c.decode(Int.self, forKey: .maxArtworkBytes)
        writeFolderCoverJPG = try c.decode(Bool.self, forKey: .writeFolderCoverJPG)
        stripMP3Comments = try c.decode(Bool.self, forKey: .stripMP3Comments)
        copySidecarLyrics = try c.decode(Bool.self, forKey: .copySidecarLyrics)
        cleanMacOSDotFiles = try c.decode(Bool.self, forKey: .cleanMacOSDotFiles)
        supportedFormats = try c.decode(Set<AudioFormat>.self, forKey: .supportedFormats)
        maxTrackLimit = try c.decodeIfPresent(Int.self, forKey: .maxTrackLimit)
        selectedArtistKeys = try c.decodeIfPresent(Set<String>.self, forKey: .selectedArtistKeys) ?? []
        selectedAlbumKeys = try c.decodeIfPresent(Set<String>.self, forKey: .selectedAlbumKeys) ?? []
        selectedTrackIDs = try c.decodeIfPresent(Set<String>.self, forKey: .selectedTrackIDs) ?? []
        selectedPlaylistIDs = try c.decodeIfPresent(Set<UUID>.self, forKey: .selectedPlaylistIDs) ?? []
        selectedPodcastShowIDs = try c.decodeIfPresent(Set<UUID>.self, forKey: .selectedPodcastShowIDs) ?? []
        selectedEpisodeIDs = try c.decodeIfPresent(Set<String>.self, forKey: .selectedEpisodeIDs) ?? []
        podcastEpisodesPerShowLimit = try c.decodeIfPresent(Int.self, forKey: .podcastEpisodesPerShowLimit) ?? 5
        syncedTrackIDs = try c.decodeIfPresent(Set<String>.self, forKey: .syncedTrackIDs) ?? []
        syncedEpisodeIDs = try c.decodeIfPresent(Set<String>.self, forKey: .syncedEpisodeIDs) ?? []
        lastSyncedAt = try c.decodeIfPresent(Date.self, forKey: .lastSyncedAt)
    }

    public mutating func applyPresetDefaults(_ newPreset: DevicePresetKind) {
        let defaults = DeviceProfile(name: name, accentColor: accentColor, volumeUUID: volumeUUID, mountPath: mountPath, preset: newPreset)
        self.preset = newPreset
        self.musicSubfolder = defaults.musicSubfolder
        self.podcastsSubfolder = defaults.podcastsSubfolder
        self.playlistsSubfolder = defaults.playlistsSubfolder
        self.playlistPathStyle = defaults.playlistPathStyle
        self.useM3U8Extension = defaults.useM3U8Extension
        self.maxArtworkDimension = defaults.maxArtworkDimension
        self.stripMP3Comments = defaults.stripMP3Comments
        self.supportedFormats = defaults.supportedFormats
        self.maxTrackLimit = defaults.maxTrackLimit
    }

    public var isConnected: Bool {
        !mountPath.isEmpty && FileManager.default.fileExists(atPath: mountPath)
    }

    public func supports(_ format: AudioFormat) -> Bool {
        supportedFormats.contains(format)
    }
}

public struct MountedVolumeInfo: Identifiable, Hashable, Sendable {
    public var id: String { volumeUUID ?? mountPath }
    public var name: String
    public var mountPath: String
    public var volumeUUID: String?
    public var totalBytes: Int64
    public var availableBytes: Int64
    public var isRemovable: Bool
    public var isExternal: Bool
    public var fileSystemType: String

    public var usedBytes: Int64 {
        max(0, totalBytes - availableBytes)
    }

    public init(
        name: String,
        mountPath: String,
        volumeUUID: String? = nil,
        totalBytes: Int64 = 0,
        availableBytes: Int64 = 0,
        isRemovable: Bool = true,
        isExternal: Bool = true,
        fileSystemType: String = "FAT32"
    ) {
        self.name = name
        self.mountPath = mountPath
        self.volumeUUID = volumeUUID
        self.totalBytes = totalBytes
        self.availableBytes = availableBytes
        self.isRemovable = isRemovable
        self.isExternal = isExternal
        self.fileSystemType = fileSystemType
    }
}

public enum SyncSelectionState: Sendable, Hashable {
    case none
    case partial
    case full
}

import Foundation

/// Records files managed by Echo on a target device/SD card so Mirror Sync safely removes
/// only Echo-managed tracks, podcast episodes, and playlists when deselected, without wiping unrelated files.
public struct DeviceSyncManifest: Codable, Sendable {
    public struct SyncedTrackEntry: Codable, Sendable, Hashable {
        public var trackID: String
        public var relativePath: String
        public var sourceFileSize: Int64
        public var sourceModifiedTimestamp: TimeInterval
        public var optimizedArtwork: Bool
        public var lyricsRelativePath: String?

        public init(
            trackID: String,
            relativePath: String,
            sourceFileSize: Int64,
            sourceModifiedTimestamp: TimeInterval,
            optimizedArtwork: Bool,
            lyricsRelativePath: String? = nil
        ) {
            self.trackID = trackID
            self.relativePath = relativePath
            self.sourceFileSize = sourceFileSize
            self.sourceModifiedTimestamp = sourceModifiedTimestamp
            self.optimizedArtwork = optimizedArtwork
            self.lyricsRelativePath = lyricsRelativePath
        }
    }

    public struct SyncedEpisodeEntry: Codable, Sendable, Hashable {
        public var episodeID: String
        public var showID: UUID?
        public var relativePath: String
        public var fileSize: Int64

        public init(episodeID: String, showID: UUID? = nil, relativePath: String, fileSize: Int64) {
            self.episodeID = episodeID
            self.showID = showID
            self.relativePath = relativePath
            self.fileSize = fileSize
        }
    }

    public var deviceID: UUID
    public var updatedAt: Date
    public var tracks: [String: SyncedTrackEntry]          // keyed by trackID
    public var episodes: [String: SyncedEpisodeEntry]      // keyed by episodeID
    public var playlistRelativePaths: [UUID: String]

    public init(
        deviceID: UUID,
        updatedAt: Date = Date(),
        tracks: [String: SyncedTrackEntry] = [:],
        episodes: [String: SyncedEpisodeEntry] = [:],
        playlistRelativePaths: [UUID: String] = [:]
    ) {
        self.deviceID = deviceID
        self.updatedAt = updatedAt
        self.tracks = tracks
        self.episodes = episodes
        self.playlistRelativePaths = playlistRelativePaths
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        deviceID = try c.decode(UUID.self, forKey: .deviceID)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        tracks = try c.decodeIfPresent([String: SyncedTrackEntry].self, forKey: .tracks) ?? [:]
        episodes = try c.decodeIfPresent([String: SyncedEpisodeEntry].self, forKey: .episodes) ?? [:]
        playlistRelativePaths = try c.decodeIfPresent([UUID: String].self, forKey: .playlistRelativePaths) ?? [:]
    }

    public static let manifestFileName = ".echo-sync-manifest.json"

    public static func load(fromMountPath mountPath: String, fallbackDeviceID: UUID) -> DeviceSyncManifest {
        let url = URL(fileURLWithPath: mountPath).appendingPathComponent(manifestFileName)
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(DeviceSyncManifest.self, from: data) {
            return decoded
        }
        return DeviceSyncManifest(deviceID: fallbackDeviceID)
    }

    public func save(toMountPath mountPath: String) throws {
        let url = URL(fileURLWithPath: mountPath).appendingPathComponent(Self.manifestFileName)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try AudioFileCopyOptimizer.writeRawDataWithoutXattrs(data, to: url)
    }
}

public struct SyncPlan: Sendable {
    public struct PlannedTrackCopy: Sendable, Hashable {
        public var track: Track
        public var relativeDestinationPath: String
    }

    public struct PlannedEpisodeCopy: Sendable, Hashable {
        public var episode: PodcastEpisode
        public var relativeDestinationPath: String
        public var needsDownloadFirst: Bool
    }

    public var deviceID: UUID
    public var tracksToCopy: [PlannedTrackCopy]
    public var tracksUpToDate: [PlannedTrackCopy]
    public var tracksToRemove: [DeviceSyncManifest.SyncedTrackEntry]
    public var episodesToCopy: [PlannedEpisodeCopy]
    public var episodesUpToDate: [PlannedEpisodeCopy]
    public var episodesToRemove: [DeviceSyncManifest.SyncedEpisodeEntry]
    public var unsupportedSkipped: [Track]
    public var offlineSkipped: [Track]
    public var playlistsToWrite: [(playlist: Playlist, relativePath: String, entries: [(track: Track, relativePath: String)])]
    public var playlistPathsToRemove: [String]
    public var estimatedBytesToWrite: Int64
    public var estimatedBytesToFree: Int64
    public var projectedTotalTracks: Int
    public var maxTrackLimit: Int?

    public var exceedsTrackLimit: Bool {
        guard let cap = maxTrackLimit else { return false }
        return projectedTotalTracks > cap
    }

    public var totalPendingCopies: Int {
        tracksToCopy.count + episodesToCopy.count
    }

    public var totalPendingRemovals: Int {
        tracksToRemove.count + episodesToRemove.count
    }

    public var hasPendingChanges: Bool {
        !tracksToCopy.isEmpty || !tracksToRemove.isEmpty
            || !episodesToCopy.isEmpty || !episodesToRemove.isEmpty
            || !playlistsToWrite.isEmpty || !playlistPathsToRemove.isEmpty
    }

    public static func empty(for device: DeviceProfile, projectedTracks: Int = 0) -> SyncPlan {
        SyncPlan(
            deviceID: device.id,
            tracksToCopy: [],
            tracksUpToDate: [],
            tracksToRemove: [],
            episodesToCopy: [],
            episodesUpToDate: [],
            episodesToRemove: [],
            unsupportedSkipped: [],
            offlineSkipped: [],
            playlistsToWrite: [],
            playlistPathsToRemove: [],
            estimatedBytesToWrite: 0,
            estimatedBytesToFree: 0,
            projectedTotalTracks: projectedTracks,
            maxTrackLimit: device.maxTrackLimit
        )
    }
}

public struct SyncProgress: Sendable {
    public var phase: String
    public var completedSteps: Int
    public var totalSteps: Int
    public var currentItem: String
    public var bytesCopied: Int64
    public var totalBytes: Int64
    public var isFinished: Bool

    public init(
        phase: String,
        completedSteps: Int,
        totalSteps: Int,
        currentItem: String,
        bytesCopied: Int64,
        totalBytes: Int64,
        isFinished: Bool
    ) {
        self.phase = phase
        self.completedSteps = completedSteps
        self.totalSteps = totalSteps
        self.currentItem = currentItem
        self.bytesCopied = bytesCopied
        self.totalBytes = totalBytes
        self.isFinished = isFinished
    }

    public var fraction: Double {
        guard totalSteps > 0 else { return isFinished ? 1.0 : 0.0 }
        return min(1.0, Double(completedSteps) / Double(totalSteps))
    }
}

public struct SyncExecutionSummary: Sendable {
    public var tracksCopied: Int
    public var tracksRemoved: Int
    public var episodesCopied: Int
    public var episodesRemoved: Int
    public var playlistsWritten: Int
    public var dotFilesCleaned: Int
    public var unsupportedSkipped: Int
    public var errors: [String]
    public var bytesWritten: Int64
    public var finalSyncedTrackIDs: Set<String>
    public var finalSyncedEpisodeIDs: Set<String>
    public var downloadedEpisodes: [PodcastEpisode]
    public var completedAt: Date
}

public enum SyncPlanner {
    /// Resolves all music tracks explicitly or implicitly selected on a DeviceProfile.
    public static func resolveSelectedTrackIDs(
        profile: DeviceProfile,
        allTracks: [Track],
        playlists: [Playlist],
        precomputedAlbumByTrackID: [String: AlbumGroup]? = nil
    ) -> Set<String> {
        var ids = profile.selectedTrackIDs

        // Use precomputed album map when supplied to avoid expensive O(N) rebuilds on hot UI paths
        let resolvedLookup: [String: AlbumGroup]
        if profile.selectedArtistKeys.isEmpty && profile.selectedAlbumKeys.isEmpty {
            resolvedLookup = [:]
        } else if let precomputedAlbumByTrackID {
            resolvedLookup = precomputedAlbumByTrackID
        } else {
            resolvedLookup = AlbumGroup.buildGroupsWithTrackLookup(from: allTracks).albumByTrackID
        }

        if !profile.selectedArtistKeys.isEmpty || !profile.selectedAlbumKeys.isEmpty {
            for track in allTracks {
                let resolvedAlbum = resolvedLookup[track.id]
                let resolvedAlbumID = resolvedAlbum?.id ?? track.albumKey
                let resolvedAlbumArtistKey = resolvedAlbum?.artist.lowercased()
                if profile.selectedArtistKeys.contains(track.artistKey) ||
                   (resolvedAlbumArtistKey.map { profile.selectedArtistKeys.contains($0) } ?? false) ||
                   profile.selectedAlbumKeys.contains(resolvedAlbumID) ||
                   profile.selectedAlbumKeys.contains(track.albumKey) ||
                   profile.selectedAlbumKeys.contains(track.legacyAlbumKey) {
                    ids.insert(track.id)
                }
            }
        }

        let playlistMap = Dictionary(uniqueKeysWithValues: playlists.map { ($0.id, $0) })
        for playlistID in profile.selectedPlaylistIDs {
            if let pl = playlistMap[playlistID] {
                for tid in pl.trackIDs where !Playlist.isMissingTrackID(tid) {
                    ids.insert(tid)
                }
            }
        }
        return ids
    }

    /// Resolves all podcast episodes selected on a DeviceProfile:
    /// uses each show's own `episodesToKeep` retention limit (newest first; 0 = keep all)
    /// plus any individually picked episodes.
    public static func resolveSelectedEpisodeIDs(
        profile: DeviceProfile,
        podcasts: [PodcastShow]
    ) -> Set<String> {
        var ids = profile.selectedEpisodeIDs
        for show in podcasts where profile.selectedPodcastShowIDs.contains(show.id) {
            let newestFirst = show.episodes.sorted {
                ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast)
            }
            let slice: ArraySlice<PodcastEpisode> = show.episodesToKeep > 0
                ? newestFirst.prefix(show.episodesToKeep)
                : newestFirst[...]
            for ep in slice {
                ids.insert(ep.id)
            }
        }
        return ids
    }

    /// Computes a complete diff SyncPlan between the user's selections and what is currently on the player.
    public static func buildPlan(
        profile: DeviceProfile,
        allTracks: [Track],
        playlists: [Playlist],
        podcasts: [PodcastShow] = [],
        manifest: DeviceSyncManifest? = nil,
        precomputedAlbumByTrackID: [String: AlbumGroup]? = nil
    ) -> SyncPlan {
        let tracksByID = Dictionary(uniqueKeysWithValues: allTracks.map { ($0.id, $0) })
        // Resolve one unified folder artist per album (reusing precomputed map when available!)
        let albumByTrackID = precomputedAlbumByTrackID ?? AlbumGroup.buildGroupsWithTrackLookup(from: allTracks).albumByTrackID
        let currentManifest: DeviceSyncManifest = {
            if let manifest { return manifest }
            if profile.isVirtualWireless {
                var m = DeviceSyncManifest(deviceID: profile.id)
                for tid in profile.syncedTrackIDs {
                    if let t = tracksByID[tid] {
                        m.tracks[tid] = .init(
                            trackID: tid,
                            relativePath: PathFormatter.relativeTrackPath(
                                for: t,
                                profile: profile,
                                albumArtistOverride: albumByTrackID[t.id]?.artist
                            ),
                            sourceFileSize: t.fileSize,
                            sourceModifiedTimestamp: t.modifiedAt.timeIntervalSince1970,
                            optimizedArtwork: false
                        )
                    } else {
                        m.tracks[tid] = .init(trackID: tid, relativePath: tid, sourceFileSize: 0, sourceModifiedTimestamp: 0, optimizedArtwork: false)
                    }
                }
                for show in podcasts {
                    for ep in show.episodes where profile.syncedEpisodeIDs.contains(ep.id) {
                        m.episodes[ep.id] = .init(
                            episodeID: ep.id,
                            showID: show.id,
                            relativePath: PathFormatter.relativeEpisodePath(for: ep, profile: profile),
                            fileSize: ep.fileSize
                        )
                    }
                }
                return m
            }
            return profile.isConnected
                ? DeviceSyncManifest.load(fromMountPath: profile.mountPath, fallbackDeviceID: profile.id)
                : DeviceSyncManifest(deviceID: profile.id)
        }()

        let selectedIDs = resolveSelectedTrackIDs(
            profile: profile,
            allTracks: allTracks,
            playlists: playlists,
            precomputedAlbumByTrackID: albumByTrackID
        )

        var desiredTracks: [Track] = []
        var unsupported: [Track] = []
        var offline: [Track] = []

        for id in selectedIDs {
            guard let track = tracksByID[id] else { continue }
            if !profile.supports(track.format) {
                unsupported.append(track)
                continue
            }
            if !track.isAvailable || !FileManager.default.fileExists(atPath: track.filePath) {
                if currentManifest.tracks[id] != nil {
                    desiredTracks.append(track)
                } else {
                    offline.append(track)
                }
                continue
            }
            desiredTracks.append(track)
        }

        desiredTracks.sort {
            (albumByTrackID[$0.id]?.artist ?? $0.effectiveArtist, $0.effectiveAlbum, $0.discNumber ?? 1, $0.trackNumber ?? 0, $0.title, $0.id) <
            (albumByTrackID[$1.id]?.artist ?? $1.effectiveArtist, $1.effectiveAlbum, $1.discNumber ?? 1, $1.trackNumber ?? 0, $1.title, $1.id)
        }

        var usedPaths: Set<String> = []
        var pathByTrackID: [String: String] = [:]
        var toCopy: [SyncPlan.PlannedTrackCopy] = []
        var upToDate: [SyncPlan.PlannedTrackCopy] = []
        var bytesToWrite: Int64 = 0

        for track in desiredTracks {
            var relPath = PathFormatter.relativeTrackPath(
                for: track,
                profile: profile,
                albumArtistOverride: albumByTrackID[track.id]?.artist
            )
            if usedPaths.contains(relPath.lowercased()) {
                let ns = relPath as NSString
                let base = ns.deletingPathExtension
                let ext = ns.pathExtension
                var suffix = 2
                while usedPaths.contains("\(base) (\(suffix)).\(ext)".lowercased()) {
                    suffix += 1
                }
                relPath = "\(base) (\(suffix)).\(ext)"
            }
            usedPaths.insert(relPath.lowercased())
            pathByTrackID[track.id] = relPath

            let destFullPath = URL(fileURLWithPath: profile.mountPath).appendingPathComponent(relPath).path
            if let existing = currentManifest.tracks[track.id],
               (profile.isVirtualWireless
                || (existing.relativePath == relPath
                    && existing.sourceFileSize == track.fileSize
                    && abs(existing.sourceModifiedTimestamp - track.modifiedAt.timeIntervalSince1970) < 2.0
                    && (!profile.isConnected || FileManager.default.fileExists(atPath: destFullPath)))) {
                upToDate.append(.init(track: track, relativeDestinationPath: relPath))
            } else {
                toCopy.append(.init(track: track, relativeDestinationPath: relPath))
                bytesToWrite += track.fileSize
            }
        }

        // Podcast episodes planning
        let selectedEpIDs = resolveSelectedEpisodeIDs(profile: profile, podcasts: podcasts)
        var episodesByID: [String: PodcastEpisode] = [:]
        for show in podcasts {
            for ep in show.episodes {
                episodesByID[ep.id] = ep
            }
        }

        let desiredEpisodes = selectedEpIDs
            .compactMap { episodesByID[$0] }
            .sorted { ($0.showTitle, $0.publishedAt ?? .distantPast, $0.title) < ($1.showTitle, $1.publishedAt ?? .distantPast, $1.title) }

        var episodesToCopy: [SyncPlan.PlannedEpisodeCopy] = []
        var episodesUpToDate: [SyncPlan.PlannedEpisodeCopy] = []
        var usedEpisodePaths: Set<String> = []

        for ep in desiredEpisodes {
            var relPath = PathFormatter.relativeEpisodePath(for: ep, profile: profile)
            if usedEpisodePaths.contains(relPath.lowercased()) {
                let ns = relPath as NSString
                relPath = "\(ns.deletingPathExtension)_\(ep.id.prefix(4)).\(ns.pathExtension)"
            }
            usedEpisodePaths.insert(relPath.lowercased())

            let destFullPath = URL(fileURLWithPath: profile.mountPath).appendingPathComponent(relPath).path
            if let existing = currentManifest.episodes[ep.id],
               (profile.isVirtualWireless
                || (existing.relativePath == relPath
                    && (!profile.isConnected || FileManager.default.fileExists(atPath: destFullPath)))) {
                episodesUpToDate.append(.init(episode: ep, relativeDestinationPath: relPath, needsDownloadFirst: false))
            } else {
                episodesToCopy.append(.init(episode: ep, relativeDestinationPath: relPath, needsDownloadFirst: !ep.isDownloaded))
                let estimatedSize: Int64 = ep.fileSize > 0
                    ? ep.fileSize
                    : (ep.duration > 0 ? Int64(ep.duration * 16_000) : 0)
                bytesToWrite += estimatedSize
            }
        }

        // Removals:
        // - In Mirror mode: remove any previously synced track or episode no longer desired.
        // - In Additive mode: STILL rotate out older episodes for subscribed shows that have an `episodesToKeep > 0` cap!
        var toRemove: [DeviceSyncManifest.SyncedTrackEntry] = []
        var episodesToRemove: [DeviceSyncManifest.SyncedEpisodeEntry] = []
        var bytesToFree: Int64 = 0
        let desiredIDSet = Set(desiredTracks.map(\.id))
        let desiredEpIDSet = Set(desiredEpisodes.map(\.id))
        let showsByID = Dictionary(uniqueKeysWithValues: podcasts.map { ($0.id, $0) })

        if profile.syncMode == .mirror {
            for (tid, entry) in currentManifest.tracks where !desiredIDSet.contains(tid) {
                toRemove.append(entry)
                bytesToFree += entry.sourceFileSize
            }
            for (eid, entry) in currentManifest.episodes where !desiredEpIDSet.contains(eid) {
                episodesToRemove.append(entry)
                bytesToFree += entry.fileSize
            }
        } else {
            // Additive mode: enforce per-podcast `episodesToKeep` rotation so syncing new episodes throws out old ones
            for (eid, entry) in currentManifest.episodes where !desiredEpIDSet.contains(eid) {
                let showID = entry.showID ?? episodesByID[eid]?.showID
                if let showID,
                   profile.selectedPodcastShowIDs.contains(showID),
                   let show = showsByID[showID],
                   show.episodesToKeep > 0 {
                    episodesToRemove.append(entry)
                    bytesToFree += entry.fileSize
                }
            }
        }

        // Playlists to write
        let selectedPlaylists = playlists
            .filter { profile.selectedPlaylistIDs.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        var playlistsToWrite: [(playlist: Playlist, relativePath: String, entries: [(track: Track, relativePath: String)])] = []
        for pl in selectedPlaylists {
            var entries: [(track: Track, relativePath: String)] = []
            for tid in pl.trackIDs {
                if let track = tracksByID[tid], let rel = pathByTrackID[tid] {
                    entries.append((track, rel))
                }
            }
            if !entries.isEmpty {
                let plPath = PathFormatter.relativePlaylistPath(for: pl, profile: profile)
                playlistsToWrite.append((pl, plPath, entries))
            }
        }

        var playlistPathsToRemove: [String] = []
        if profile.syncMode == .mirror {
            let activePLPaths = Set(playlistsToWrite.map(\.relativePath))
            for (_, oldPath) in currentManifest.playlistRelativePaths {
                if !activePLPaths.contains(oldPath) {
                    playlistPathsToRemove.append(oldPath)
                }
            }
        }

        let projectedTotal: Int
        if profile.syncMode == .mirror {
            projectedTotal = desiredTracks.count + desiredEpisodes.count
        } else {
            let existingUntouchedTracks = currentManifest.tracks.keys.filter { !desiredIDSet.contains($0) }.count
            let existingUntouchedEps = currentManifest.episodes.keys.filter { !desiredEpIDSet.contains($0) }.count
            projectedTotal = desiredTracks.count + desiredEpisodes.count + existingUntouchedTracks + existingUntouchedEps
        }

        return SyncPlan(
            deviceID: profile.id,
            tracksToCopy: toCopy,
            tracksUpToDate: upToDate,
            tracksToRemove: toRemove,
            episodesToCopy: episodesToCopy,
            episodesUpToDate: episodesUpToDate,
            episodesToRemove: episodesToRemove,
            unsupportedSkipped: unsupported,
            offlineSkipped: offline,
            playlistsToWrite: playlistsToWrite,
            playlistPathsToRemove: playlistPathsToRemove,
            estimatedBytesToWrite: bytesToWrite,
            estimatedBytesToFree: bytesToFree,
            projectedTotalTracks: projectedTotal,
            maxTrackLimit: profile.maxTrackLimit
        )
    }
}

public actor SyncEngine {
    private let artworkCache: ArtworkCache
    private let podcastService: PodcastService?

    public init(artworkCache: ArtworkCache, podcastService: PodcastService? = nil) {
        self.artworkCache = artworkCache
        self.podcastService = podcastService
    }

    public func execute(
        plan: SyncPlan,
        profile: DeviceProfile,
        onProgress: @escaping @Sendable (SyncProgress) -> Void
    ) async throws -> SyncExecutionSummary {
        let mountURL = URL(fileURLWithPath: profile.mountPath)
        let fm = FileManager.default
        guard fm.fileExists(atPath: mountURL.path) else {
            throw NSError(domain: "Echo.Sync", code: 404, userInfo: [NSLocalizedDescriptionKey: "Target device '\(profile.name)' is not mounted at \(profile.mountPath)."])
        }

        var manifest = DeviceSyncManifest.load(fromMountPath: profile.mountPath, fallbackDeviceID: profile.id)
        let totalSteps = max(
            1,
            plan.tracksToRemove.count + plan.episodesToRemove.count
                + plan.tracksToCopy.count + plan.episodesToCopy.count
                + plan.playlistsToWrite.count + 1
        )
        var completed = 0
        var bytesCopied: Int64 = 0
        var tracksCopied = 0
        var tracksRemoved = 0
        var episodesCopied = 0
        var episodesRemoved = 0
        var playlistsWritten = 0
        var downloadedEpisodes: [PodcastEpisode] = []
        var errors: [String] = []

        // 1. Remove deselected tracks & episodes (Mirror mode)
        for entry in plan.tracksToRemove {
            try Task.checkCancellation()
            onProgress(SyncProgress(
                phase: "Removing deselected tracks",
                completedSteps: completed,
                totalSteps: totalSteps,
                currentItem: entry.relativePath,
                bytesCopied: bytesCopied,
                totalBytes: plan.estimatedBytesToWrite,
                isFinished: false
            ))

            let fileURL = mountURL.appendingPathComponent(entry.relativePath)
            if fm.fileExists(atPath: fileURL.path) {
                do {
                    try fm.removeItem(at: fileURL)
                    tracksRemoved += 1
                } catch {
                    errors.append("Failed to remove \(entry.relativePath): \(error.localizedDescription)")
                }
            }
            if let lrcRel = entry.lyricsRelativePath {
                try? fm.removeItem(at: mountURL.appendingPathComponent(lrcRel))
            }
            manifest.tracks.removeValue(forKey: entry.trackID)
            pruneEmptyAlbumFolder(fileURL.deletingLastPathComponent(), stopAt: mountURL)
            completed += 1
        }

        for entry in plan.episodesToRemove {
            try Task.checkCancellation()
            onProgress(SyncProgress(
                phase: "Removing deselected podcasts",
                completedSteps: completed,
                totalSteps: totalSteps,
                currentItem: entry.relativePath,
                bytesCopied: bytesCopied,
                totalBytes: plan.estimatedBytesToWrite,
                isFinished: false
            ))

            let fileURL = mountURL.appendingPathComponent(entry.relativePath)
            if fm.fileExists(atPath: fileURL.path) {
                do {
                    try fm.removeItem(at: fileURL)
                    episodesRemoved += 1
                } catch {
                    errors.append("Failed to remove \(entry.relativePath): \(error.localizedDescription)")
                }
            }
            manifest.episodes.removeValue(forKey: entry.episodeID)
            pruneEmptyAlbumFolder(fileURL.deletingLastPathComponent(), stopAt: mountURL)
            completed += 1
        }

        for plRel in plan.playlistPathsToRemove {
            try? fm.removeItem(at: mountURL.appendingPathComponent(plRel))
        }
        if profile.syncMode == .mirror {
            manifest.playlistRelativePaths = [:]
        }

        // 2. Copy & optimize selected music tracks preserving ARTIST/ALBUM/TRACK structure
        for item in plan.tracksToCopy {
            try Task.checkCancellation()
            onProgress(SyncProgress(
                phase: profile.optimizeArtwork ? "Copying & optimizing for \(profile.preset.displayName)" : "Copying tracks",
                completedSteps: completed,
                totalSteps: totalSteps,
                currentItem: item.relativeDestinationPath,
                bytesCopied: bytesCopied,
                totalBytes: plan.estimatedBytesToWrite,
                isFinished: false
            ))

            let destURL = mountURL.appendingPathComponent(item.relativeDestinationPath)

            // Fast in-place relocation: if the exact same source file is ALREADY synced on the device
            // under an older path (e.g. migrating split VA album folders -> Music/Various Artists/<Album>/),
            // move it in-place on the SD card without re-copying over USB!
            if let oldEntry = manifest.tracks[item.track.id], oldEntry.relativePath != item.relativeDestinationPath {
                let oldURL = mountURL.appendingPathComponent(oldEntry.relativePath)
                let canRelocateInPlace = fm.fileExists(atPath: oldURL.path)
                    && oldEntry.sourceFileSize == item.track.fileSize
                    && abs(oldEntry.sourceModifiedTimestamp - item.track.modifiedAt.timeIntervalSince1970) < 2.0

                if canRelocateInPlace {
                    do {
                        let destDir = destURL.deletingLastPathComponent()
                        try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
                        if fm.fileExists(atPath: destURL.path) {
                            try fm.removeItem(at: destURL)
                        }
                        try fm.moveItem(at: oldURL, to: destURL)

                        // Move .lrc sidecar if present
                        var newLrcRel: String? = nil
                        if let oldLrcRel = oldEntry.lyricsRelativePath {
                            let oldLrcURL = mountURL.appendingPathComponent(oldLrcRel)
                            let candidateLrcRel = (item.relativeDestinationPath as NSString).deletingPathExtension + ".lrc"
                            let destLrcURL = mountURL.appendingPathComponent(candidateLrcRel)
                            if fm.fileExists(atPath: oldLrcURL.path) {
                                try? fm.removeItem(at: destLrcURL)
                                if (try? fm.moveItem(at: oldLrcURL, to: destLrcURL)) != nil {
                                    newLrcRel = candidateLrcRel
                                }
                            }
                        }

                        // Preserve folder.jpg in the unified album folder
                        if profile.writeFolderCoverJPG {
                            let oldFolderJPG = oldURL.deletingLastPathComponent().appendingPathComponent("folder.jpg")
                            let destFolderJPG = destDir.appendingPathComponent("folder.jpg")
                            if !fm.fileExists(atPath: destFolderJPG.path), fm.fileExists(atPath: oldFolderJPG.path) {
                                try? fm.copyItem(at: oldFolderJPG, to: destFolderJPG)
                            }
                        }

                        pruneEmptyAlbumFolder(oldURL.deletingLastPathComponent(), stopAt: mountURL)

                        manifest.tracks[item.track.id] = DeviceSyncManifest.SyncedTrackEntry(
                            trackID: item.track.id,
                            relativePath: item.relativeDestinationPath,
                            sourceFileSize: oldEntry.sourceFileSize,
                            sourceModifiedTimestamp: oldEntry.sourceModifiedTimestamp,
                            optimizedArtwork: oldEntry.optimizedArtwork,
                            lyricsRelativePath: newLrcRel
                        )
                        tracksCopied += 1
                        completed += 1
                        continue
                    } catch {
                        // Fall through to full copy if in-place move fails
                    }
                }

                try? fm.removeItem(at: oldURL)
                if let oldLrcRel = oldEntry.lyricsRelativePath {
                    try? fm.removeItem(at: mountURL.appendingPathComponent(oldLrcRel))
                }
                pruneEmptyAlbumFolder(oldURL.deletingLastPathComponent(), stopAt: mountURL)
            }

            do {
                let report = try AudioFileCopyOptimizer.copyTrack(
                    item.track,
                    to: destURL,
                    profile: profile,
                    artworkCache: artworkCache
                )
                bytesCopied += report.bytesWritten
                tracksCopied += 1

                let lrcRel: String? = report.lyricsCopied
                    ? (item.relativeDestinationPath as NSString).deletingPathExtension + ".lrc"
                    : nil

                manifest.tracks[item.track.id] = DeviceSyncManifest.SyncedTrackEntry(
                    trackID: item.track.id,
                    relativePath: item.relativeDestinationPath,
                    sourceFileSize: item.track.fileSize,
                    sourceModifiedTimestamp: item.track.modifiedAt.timeIntervalSince1970,
                    optimizedArtwork: report.artworkOptimized,
                    lyricsRelativePath: lrcRel
                )
            } catch {
                errors.append("Failed to copy \(item.track.title): \(error.localizedDescription)")
            }
            completed += 1
        }

        // 3. Download (if needed) & copy selected podcast episodes
        for item in plan.episodesToCopy {
            try Task.checkCancellation()
            var ep = item.episode

            if !ep.isDownloaded {
                onProgress(SyncProgress(
                    phase: "Downloading podcast episode",
                    completedSteps: completed,
                    totalSteps: totalSteps,
                    currentItem: "\(ep.showTitle) – \(ep.title)",
                    bytesCopied: bytesCopied,
                    totalBytes: plan.estimatedBytesToWrite,
                    isFinished: false
                ))
                if let svc = podcastService {
                    do {
                        ep = try await svc.downloadEpisode(ep)
                        downloadedEpisodes.append(ep)
                    } catch {
                        errors.append("Download failed for '\(ep.title)': \(error.localizedDescription)")
                        completed += 1
                        continue
                    }
                } else {
                    errors.append("Podcast '\(ep.title)' is not downloaded locally")
                    completed += 1
                    continue
                }
            }

            onProgress(SyncProgress(
                phase: "Copying podcasts to \(profile.name)",
                completedSteps: completed,
                totalSteps: totalSteps,
                currentItem: item.relativeDestinationPath,
                bytesCopied: bytesCopied,
                totalBytes: plan.estimatedBytesToWrite,
                isFinished: false
            ))

            guard let tempTrack = ep.asPlayableTrack() else {
                errors.append("Podcast file missing for '\(ep.title)'")
                completed += 1
                continue
            }

            let destURL = mountURL.appendingPathComponent(item.relativeDestinationPath)
            do {
                let report = try AudioFileCopyOptimizer.copyTrack(
                    tempTrack,
                    to: destURL,
                    profile: profile,
                    artworkCache: artworkCache
                )
                bytesCopied += report.bytesWritten
                episodesCopied += 1
                manifest.episodes[ep.id] = DeviceSyncManifest.SyncedEpisodeEntry(
                    episodeID: ep.id,
                    showID: ep.showID,
                    relativePath: item.relativeDestinationPath,
                    fileSize: report.bytesWritten
                )
            } catch {
                errors.append("Failed to copy podcast '\(ep.title)': \(error.localizedDescription)")
            }
            completed += 1
        }

        // 4. Write M3U / M3U8 playlists formatted for the device
        for plItem in plan.playlistsToWrite {
            try Task.checkCancellation()
            onProgress(SyncProgress(
                phase: "Writing playlists",
                completedSteps: completed,
                totalSteps: totalSteps,
                currentItem: plItem.relativePath,
                bytesCopied: bytesCopied,
                totalBytes: plan.estimatedBytesToWrite,
                isFinished: false
            ))

            let plURL = mountURL.appendingPathComponent(plItem.relativePath)
            let plDir = plURL.deletingLastPathComponent()
            do {
                try fm.createDirectory(at: plDir, withIntermediateDirectories: true)
                let content = PathFormatter.buildM3UContent(
                    playlist: plItem.playlist,
                    trackRelativePaths: plItem.entries,
                    profile: profile
                )
                try AudioFileCopyOptimizer.writeRawDataWithoutXattrs(Data(content.utf8), to: plURL)
                manifest.playlistRelativePaths[plItem.playlist.id] = plItem.relativePath
                playlistsWritten += 1
            } catch {
                errors.append("Failed to write playlist \(plItem.playlist.name): \(error.localizedDescription)")
            }
            completed += 1
        }

        // 5. Persist manifest & purge macOS `._*` and `.DS_Store` junk files
        manifest.updatedAt = Date()
        try? manifest.save(toMountPath: profile.mountPath)

        var dotFilesCleaned = 0
        if profile.cleanMacOSDotFiles {
            onProgress(SyncProgress(
                phase: "Cleaning macOS ._* & .DS_Store files",
                completedSteps: completed,
                totalSteps: totalSteps,
                currentItem: profile.name,
                bytesCopied: bytesCopied,
                totalBytes: plan.estimatedBytesToWrite,
                isFinished: false
            ))
            dotFilesCleaned = Self.cleanMacOSJunkFiles(at: mountURL)
        }

        onProgress(SyncProgress(
            phase: "Sync Complete",
            completedSteps: totalSteps,
            totalSteps: totalSteps,
            currentItem: "",
            bytesCopied: bytesCopied,
            totalBytes: plan.estimatedBytesToWrite,
            isFinished: true
        ))

        return SyncExecutionSummary(
            tracksCopied: tracksCopied,
            tracksRemoved: tracksRemoved,
            episodesCopied: episodesCopied,
            episodesRemoved: episodesRemoved,
            playlistsWritten: playlistsWritten,
            dotFilesCleaned: dotFilesCleaned,
            unsupportedSkipped: plan.unsupportedSkipped.count,
            errors: errors,
            bytesWritten: bytesCopied,
            finalSyncedTrackIDs: Set(manifest.tracks.keys),
            finalSyncedEpisodeIDs: Set(manifest.episodes.keys),
            downloadedEpisodes: downloadedEpisodes,
            completedAt: Date()
        )
    }

    /// Recursively removes macOS AppleDouble (`._*`) resource fork files and `.DS_Store` files
    /// that cause "Format not supported" errors and database crashes on FiiO Echo Mini.
    /// Uses POSIX `opendir`/`readdir` because macOS Foundation's `FileManager.enumerator`
    /// can silently skip AppleDouble (`._*`) entries.
    @discardableResult
    public static func cleanMacOSJunkFiles(at rootURL: URL) -> Int {
        var removedCount = 0
        let fm = FileManager.default
        var stack: [URL] = [rootURL]

        while let dirURL = stack.popLast() {
            guard let dir = opendir(dirURL.path) else { continue }
            defer { closedir(dir) }

            while let entryPtr = readdir(dir) {
                let nameBytes = withUnsafePointer(to: &entryPtr.pointee.d_name) { ptr in
                    ptr.withMemoryRebound(to: CChar.self, capacity: Int(MAXNAMLEN)) {
                        String(cString: $0)
                    }
                }
                if nameBytes == "." || nameBytes == ".." { continue }
                if nameBytes == ".Spotlight-V100" || nameBytes == ".Trashes" || nameBytes == ".fseventsd" {
                    continue
                }

                let childURL = dirURL.appendingPathComponent(nameBytes)
                if nameBytes.hasPrefix("._") || nameBytes == ".DS_Store" {
                    if unlink(childURL.path) == 0 || (try? fm.removeItem(at: childURL)) != nil {
                        removedCount += 1
                    }
                    continue
                }

                var isDir: ObjCBool = false
                if fm.fileExists(atPath: childURL.path, isDirectory: &isDir), isDir.boolValue {
                    if let attrs = try? fm.attributesOfItem(atPath: childURL.path),
                       (attrs[.type] as? FileAttributeType) == .typeDirectory {
                        stack.append(childURL)
                    }
                }
            }
        }
        return removedCount
    }

    private func pruneEmptyAlbumFolder(_ directory: URL, stopAt root: URL) {
        let fm = FileManager.default
        var current = directory.standardizedFileURL
        let rootStd = root.standardizedFileURL

        while current.path.hasPrefix(rootStd.path) && current.path != rootStd.path {
            guard let items = try? fm.contentsOfDirectory(at: current, includingPropertiesForKeys: nil) else { break }
            let meaningful = items.filter {
                let n = $0.lastPathComponent.lowercased()
                return n != "folder.jpg" && n != "cover.jpg" && !n.hasPrefix("._") && n != ".ds_store"
            }
            if meaningful.isEmpty {
                try? fm.removeItem(at: current)
                current = current.deletingLastPathComponent()
            } else {
                break
            }
        }
    }
}

import Foundation

public struct IndexProgress: Sendable {
    public var sourceName: String
    public var scannedCount: Int
    public var totalFound: Int
    public var currentFile: String
    public var isComplete: Bool

    public init(sourceName: String, scannedCount: Int, totalFound: Int, currentFile: String, isComplete: Bool = false) {
        self.sourceName = sourceName
        self.scannedCount = scannedCount
        self.totalFound = totalFound
        self.currentFile = currentFile
        self.isComplete = isComplete
    }
}

public struct IndexResult: Sendable {
    public var sourceID: UUID
    public var isSourceOffline: Bool
    public var tracks: [Track]
    public var addedCount: Int
    public var updatedCount: Int
    public var unchangedCount: Int
}

public actor LibraryIndexer {
    private let artworkCache: ArtworkCache

    public init(artworkCache: ArtworkCache) {
        self.artworkCache = artworkCache
    }

    /// Incrementally scans a LibrarySource (local folder or mounted NAS share).
    /// Reuses existing cached Track entries when (filePath, fileSize, modifiedAt) haven't changed.
    public func indexSource(
        _ source: LibrarySource,
        existingTracks: [Track],
        onProgress: @escaping @Sendable (IndexProgress) -> Void
    ) async -> IndexResult {
        let rootURL = URL(fileURLWithPath: source.path)
        let fm = FileManager.default

        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: rootURL.path, isDirectory: &isDir), isDir.boolValue else {
            // Source (e.g. NAS) is currently offline — preserve existing tracks marked unavailable
            let offlineTracks = existingTracks.map { t -> Track in
                var copy = t
                copy.isAvailable = false
                return copy
            }
            return IndexResult(
                sourceID: source.id,
                isSourceOffline: true,
                tracks: offlineTracks,
                addedCount: 0,
                updatedCount: 0,
                unchangedCount: offlineTracks.count
            )
        }

        let existingByPath = Dictionary(uniqueKeysWithValues: existingTracks.map { ($0.filePath, $0) })

        // Discover audio files cleanly, skipping macOS hidden dot-underscore files & packages
        var discoveredURLs: [URL] = []
        if let enumerator = fm.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) {
            while let obj = enumerator.nextObject() {
                guard let url = obj as? URL else { continue }
                let name = url.lastPathComponent
                if name.hasPrefix("._") || name.hasPrefix(".") { continue }
                let ext = url.pathExtension.lowercased()
                if AudioFormat.recognizedExtensions.contains(ext) {
                    discoveredURLs.append(url)
                }
            }
        }

        var resultTracks: [Track] = []
        resultTracks.reserveCapacity(discoveredURLs.count)
        var added = 0
        var updated = 0
        var unchanged = 0

        let total = discoveredURLs.count
        for (idx, url) in discoveredURLs.enumerated() {
            if idx % 20 == 0 || idx == total - 1 {
                onProgress(IndexProgress(
                    sourceName: source.name,
                    scannedCount: idx + 1,
                    totalFound: total,
                    currentFile: url.lastPathComponent
                ))
            }

            if let vals = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]),
               let cached = existingByPath[url.path],
               let size = vals.fileSize,
               let mod = vals.contentModificationDate,
               Int64(size) == cached.fileSize,
               abs(mod.timeIntervalSince(cached.modifiedAt)) < 1.5 {
                var refreshed = cached
                refreshed.isAvailable = true
                resultTracks.append(refreshed)
                unchanged += 1
                continue
            }

            if let parsed = await AudioMetadataReader.readTrack(at: url, sourceID: source.id, artworkCache: artworkCache) {
                resultTracks.append(parsed)
                if existingByPath[url.path] != nil {
                    updated += 1
                } else {
                    added += 1
                }
            }
        }

        onProgress(IndexProgress(
            sourceName: source.name,
            scannedCount: total,
            totalFound: total,
            currentFile: "",
            isComplete: true
        ))

        return IndexResult(
            sourceID: source.id,
            isSourceOffline: false,
            tracks: resultTracks,
            addedCount: added,
            updatedCount: updated,
            unchangedCount: unchanged
        )
    }

    public static func detectIsNetworkVolume(path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        if let vals = try? url.resourceValues(forKeys: [.volumeIsLocalKey]),
           let isLocal = vals.volumeIsLocal {
            return !isLocal
        }
        return path.hasPrefix("/Volumes/")
    }
}

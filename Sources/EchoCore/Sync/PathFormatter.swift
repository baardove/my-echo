import Foundation

public enum PathFormatter {
    /// Sanitizes a single folder or filename segment for FAT32/exFAT & FiiO firmware safety.
    /// - Normalizes Unicode to NFC (macOS uses NFD which breaks accents on DAPs)
    /// - Replaces FAT32 forbidden characters (: * ? " < > | / \)
    /// - Trims leading/trailing whitespace and trailing dots
    /// - Caps length cleanly to prevent path overflows on embedded DAP firmware
    public static func sanitizeSegment(_ raw: String, fallback: String = "Unknown", maxLength: Int = 85) -> String {
        let nfc = raw.precomposedStringWithCanonicalMapping
        var result = ""
        result.reserveCapacity(min(nfc.count, maxLength))

        for scalar in nfc.unicodeScalars {
            let v = scalar.value
            // Strip ASCII control characters & invisible Unicode format/BOM/zero-width characters
            // (prevents duplicate phantom folders like "Alan Walker\u{FEFF}\u{FEFF}" on FAT32/exFAT)
            if v < 0x20 || v == 0x7F || v == 0xFEFF || (v >= 0x200B && v <= 0x200F) || v == 0x2060 || (v >= 0x2028 && v <= 0x202F) {
                continue
            }
            switch scalar {
            case ":", "*", "?", "\"", "<", ">", "|", "/", "\\":
                result.append("-")
            default:
                result.unicodeScalars.append(scalar)
            }
        }

        // Collapse repeated spaces and trim trailing dots/spaces (invalid on FAT32)
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        result = result.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))

        if result.isEmpty {
            return fallback
        }
        if result.count > maxLength {
            result = String(result.prefix(maxLength))
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        }
        return result.isEmpty ? fallback : result
    }

    /// Computes the canonical relative storage path in ARTIST/ALBUM/TRACK format,
    /// prefixed with the device profile's musicSubfolder (if non-empty).
    /// Pass `albumArtistOverride` (e.g. resolved `"Various Artists"` or album's majority artist)
    /// so compilation and multi-artist albums stay together in ONE album folder on the device.
    public static func relativeTrackPath(
        for track: Track,
        profile: DeviceProfile,
        albumArtistOverride: String? = nil
    ) -> String {
        let rawArtist: String = {
            if let override = albumArtistOverride?.trimmingCharacters(in: .whitespacesAndNewlines), !override.isEmpty {
                return override
            }
            return track.effectiveArtist
        }()
        let artistDir = sanitizeSegment(rawArtist, fallback: "Unknown Artist")
        let albumDir = sanitizeSegment(track.effectiveAlbum, fallback: "Unknown Album")

        let trackTitle = sanitizeSegment(track.title, fallback: sanitizeSegment(URL(fileURLWithPath: track.fileName).deletingPathExtension().lastPathComponent, fallback: "Track"))
        let ext = URL(fileURLWithPath: track.fileName).pathExtension.lowercased()
        let safeExt = ext.isEmpty ? track.format.rawValue : ext

        let trackFileName: String
        if let trackNum = track.trackNumber, trackNum > 0 {
            let numStr = String(format: "%02d", trackNum)
            if let disc = track.discNumber, disc > 1 {
                trackFileName = "\(disc)-\(numStr) - \(trackTitle).\(safeExt)"
            } else {
                trackFileName = "\(numStr) - \(trackTitle).\(safeExt)"
            }
        } else {
            trackFileName = "\(trackTitle).\(safeExt)"
        }

        let cleanMusicSub = profile.musicSubfolder
            .trimmingCharacters(in: CharacterSet(charactersIn: "/\\ "))
        if cleanMusicSub.isEmpty {
            return "\(artistDir)/\(albumDir)/\(trackFileName)"
        } else {
            return "\(cleanMusicSub)/\(artistDir)/\(albumDir)/\(trackFileName)"
        }
    }

    /// Computes relative destination path for a podcast episode:
    /// <Podcasts>/<Show>/<YYYY-MM-DD> - <Episode Title>.<ext>
    public static func relativeEpisodePath(for episode: PodcastEpisode, profile: DeviceProfile) -> String {
        let showDir = sanitizeSegment(episode.showTitle, fallback: "Podcast")
        let epTitle = sanitizeSegment(episode.title, fallback: "Episode", maxLength: 75)
        let safeExt = episode.fileExtension.isEmpty ? "mp3" : episode.fileExtension.lowercased()

        let fileName: String
        if let date = episode.publishedAt {
            let fmt = DateFormatter()
            fmt.locale = Locale(identifier: "en_US_POSIX")
            fmt.dateFormat = "yyyy-MM-dd"
            fileName = "\(fmt.string(from: date)) - \(epTitle).\(safeExt)"
        } else if let num = episode.episodeNumber, num > 0 {
            fileName = String(format: "%03d - %@.%@", num, epTitle, safeExt)
        } else {
            fileName = "\(epTitle).\(safeExt)"
        }

        let cleanSub = profile.podcastsSubfolder
            .trimmingCharacters(in: CharacterSet(charactersIn: "/\\ "))
        if cleanSub.isEmpty {
            return "\(showDir)/\(fileName)"
        } else {
            return "\(cleanSub)/\(showDir)/\(fileName)"
        }
    }

    /// Computes relative path for a playlist file on the device.
    public static func relativePlaylistPath(for playlist: Playlist, profile: DeviceProfile) -> String {
        let baseName = sanitizeSegment(playlist.name, fallback: "Playlist")
        let ext = profile.useM3U8Extension ? "m3u8" : "m3u"
        let sub = profile.playlistsSubfolder.trimmingCharacters(in: CharacterSet(charactersIn: "/\\ "))
        if sub.isEmpty {
            return "\(baseName).\(ext)"
        } else {
            return "\(sub)/\(baseName).\(ext)"
        }
    }

    /// Generates an M3U / M3U8 playlist payload formatted for the target device profile.
    public static func buildM3UContent(
        playlist: Playlist,
        trackRelativePaths: [(track: Track, relativePath: String)],
        profile: DeviceProfile
    ) -> String {
        let usesBackslash = (profile.playlistPathStyle == .echoMiniSD || profile.playlistPathStyle == .echoMiniInternal)
        let lineEnding = usesBackslash ? "\r\n" : "\n"
        var lines: [String] = ["#EXTM3U"]

        let playlistDepth: Int = {
            let sub = profile.playlistsSubfolder.trimmingCharacters(in: CharacterSet(charactersIn: "/\\ "))
            guard !sub.isEmpty else { return 0 }
            return sub.split(separator: "/").count
        }()

        for item in trackRelativePaths {
            let secs = max(0, Int(item.track.duration.rounded()))
            lines.append("#EXTINF:\(secs),\(item.track.artist) - \(item.track.title)")

            let formattedPath: String
            switch profile.playlistPathStyle {
            case .echoMiniSD:
                formattedPath = "D:\\" + item.relativePath.replacingOccurrences(of: "/", with: "\\")
            case .echoMiniInternal:
                formattedPath = "C:\\" + item.relativePath.replacingOccurrences(of: "/", with: "\\")
            case .androidExternalSD:
                formattedPath = "/storage/external_sd/" + item.relativePath
            case .relativeForwardSlash:
                if playlistDepth > 0 {
                    let prefix = Array(repeating: "..", count: playlistDepth).joined(separator: "/")
                    formattedPath = "\(prefix)/\(item.relativePath)"
                } else {
                    formattedPath = item.relativePath
                }
            }
            lines.append(formattedPath)
        }

        return lines.joined(separator: lineEnding) + lineEnding
    }
}

import Foundation

/// Copies audio files cleanly to external audio players/SD cards without macOS extended attributes,
/// while optionally optimizing embedded artwork to FiiO-compatible sRGB Baseline JPEG (and stripping
/// bloated MP3 comments when requested) without ever modifying source files in the library.
public enum AudioFileCopyOptimizer {
    public struct CopyReport: Sendable {
        public var bytesWritten: Int64
        public var artworkOptimized: Bool
        public var folderCoverWritten: Bool
        public var lyricsCopied: Bool
    }

    public static func copyTrack(
        _ track: Track,
        to destinationURL: URL,
        profile: DeviceProfile,
        artworkCache: ArtworkCache
    ) throws -> CopyReport {
        let fm = FileManager.default
        let sourceURL = URL(fileURLWithPath: track.filePath)
        let destDir = destinationURL.deletingLastPathComponent()
        try fm.createDirectory(at: destDir, withIntermediateDirectories: true)

        // Prepare optimized baseline JPEG artwork if available
        var optimizedJPEG: Data? = nil
        if profile.optimizeArtwork || profile.writeFolderCoverJPG {
            if let hash = track.artworkHash,
               let rawArt = artworkCache.loadOriginalData(for: hash) {
                if ArtworkOptimizer.isAlreadyCompliantBaselineJPEG(
                    imageData: rawArt,
                    maxDimension: profile.maxArtworkDimension,
                    maxBytes: profile.maxArtworkBytes
                ) {
                    optimizedJPEG = rawArt
                } else {
                    optimizedJPEG = ArtworkOptimizer.convertToBaselineJPEG(
                        imageData: rawArt,
                        maxDimension: profile.maxArtworkDimension,
                        maxBytes: profile.maxArtworkBytes
                    )
                }
            }
        }

        var artworkOptimized = false
        var bytesWritten: Int64 = 0

        if profile.optimizeArtwork, let jpeg = optimizedJPEG, track.format == .flac {
            if let written = try? copyFLACWithEmbeddedJPEG(from: sourceURL, to: destinationURL, jpegData: jpeg) {
                bytesWritten = written
                artworkOptimized = true
            } else {
                bytesWritten = try cleanStreamCopy(from: sourceURL, to: destinationURL)
            }
        } else if (profile.optimizeArtwork || profile.stripMP3Comments), track.format == .mp3 {
            if let written = try? copyMP3WithCleanID3v23(
                from: sourceURL,
                to: destinationURL,
                jpegData: profile.optimizeArtwork ? optimizedJPEG : nil,
                stripComments: profile.stripMP3Comments
            ) {
                bytesWritten = written
                artworkOptimized = (profile.optimizeArtwork && optimizedJPEG != nil)
            } else {
                bytesWritten = try cleanStreamCopy(from: sourceURL, to: destinationURL)
            }
        } else {
            bytesWritten = try cleanStreamCopy(from: sourceURL, to: destinationURL)
        }

        // Write folder.jpg fallback inside ARTIST/ALBUM/ if enabled and missing
        var folderCoverWritten = false
        if profile.writeFolderCoverJPG, let jpeg = optimizedJPEG {
            let folderJPG = destDir.appendingPathComponent("folder.jpg")
            if !fm.fileExists(atPath: folderJPG.path) {
                try? writeRawDataWithoutXattrs(jpeg, to: folderJPG)
                folderCoverWritten = true
            }
        }

        // Copy matching .lrc synced lyrics sidecar if present
        var lyricsCopied = false
        if profile.copySidecarLyrics, let lrcPath = track.lyricsPath, fm.fileExists(atPath: lrcPath) {
            let destLRC = destinationURL.deletingPathExtension().appendingPathExtension("lrc")
            if let lrcData = try? Data(contentsOf: URL(fileURLWithPath: lrcPath)) {
                try? writeRawDataWithoutXattrs(lrcData, to: destLRC)
                lyricsCopied = true
            }
        }

        return CopyReport(
            bytesWritten: bytesWritten,
            artworkOptimized: artworkOptimized,
            folderCoverWritten: folderCoverWritten,
            lyricsCopied: lyricsCopied
        )
    }

    /// Stream-copies file contents via raw POSIX I/O so macOS does not attach Finder/Quarantine xattrs
    /// that spawn `._*` AppleDouble files on FAT32/exFAT SD cards.
    public static func cleanStreamCopy(from sourceURL: URL, to destURL: URL) throws -> Int64 {
        let src = try FileHandle(forReadingFrom: sourceURL)
        defer { try? src.close() }

        let fm = FileManager.default
        if fm.fileExists(atPath: destURL.path) {
            try fm.removeItem(at: destURL)
        }
        fm.createFile(atPath: destURL.path, contents: nil)
        let dst = try FileHandle(forWritingTo: destURL)
        defer { try? dst.close() }

        var total: Int64 = 0
        let chunkSize = 1_048_576 // 1 MB
        while let chunk = try src.read(upToCount: chunkSize), !chunk.isEmpty {
            try dst.write(contentsOf: chunk)
            total += Int64(chunk.count)
        }
        return total
    }

    public static func writeRawDataWithoutXattrs(_ data: Data, to destURL: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: destURL.path) {
            try fm.removeItem(at: destURL)
        }
        fm.createFile(atPath: destURL.path, contents: nil)
        let dst = try FileHandle(forWritingTo: destURL)
        defer { try? dst.close() }
        try dst.write(contentsOf: data)
    }

    // MARK: - FLAC Safe Re-Mux (Replaces PICTURE metadata block, leaves audio frames 100% bit-exact)

    public static func copyFLACWithEmbeddedJPEG(
        from sourceURL: URL,
        to destURL: URL,
        jpegData: Data
    ) throws -> Int64 {
        let src = try FileHandle(forReadingFrom: sourceURL)
        defer { try? src.close() }

        guard let magic = try src.read(upToCount: 4), magic == Data("fLaC".utf8) else {
            throw NSError(domain: "Echo.FLAC", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not a valid FLAC stream"])
        }

        // Read all existing metadata blocks except existing PICTURE (type 6) blocks
        var keptBlocks: [(type: UInt8, payload: Data)] = []
        var isLast = false
        while !isLast {
            guard let hdr = try src.read(upToCount: 4), hdr.count == 4 else {
                throw NSError(domain: "Echo.FLAC", code: 2, userInfo: nil)
            }
            isLast = (hdr[0] & 0x80) != 0
            let blockType = hdr[0] & 0x7F
            let length = (Int(hdr[1]) << 16) | (Int(hdr[2]) << 8) | Int(hdr[3])
            guard length >= 0, length < 64_000_000 else {
                throw NSError(domain: "Echo.FLAC", code: 3, userInfo: nil)
            }
            let payload: Data
            if length > 0 {
                guard let readPayload = try src.read(upToCount: length), readPayload.count == length else {
                    throw NSError(domain: "Echo.FLAC", code: 4, userInfo: nil)
                }
                payload = readPayload
            } else {
                payload = Data()
            }

            if blockType != 6 { // Drop old picture blocks; we insert our single optimized baseline JPEG
                keptBlocks.append((blockType, payload))
            }
        }

        // Build new FLAC PICTURE block (type 6, Front Cover = 3, mime = image/jpeg)
        let picPayload = buildFLACPicturePayload(jpegData: jpegData)
        guard picPayload.count < 16_777_215 else {
            throw NSError(domain: "Echo.FLAC", code: 5, userInfo: nil)
        }
        keptBlocks.append((6, picPayload))

        let fm = FileManager.default
        if fm.fileExists(atPath: destURL.path) {
            try fm.removeItem(at: destURL)
        }
        fm.createFile(atPath: destURL.path, contents: nil)
        let dst = try FileHandle(forWritingTo: destURL)
        defer { try? dst.close() }

        var total: Int64 = 0
        try dst.write(contentsOf: magic)
        total += 4

        for (index, block) in keptBlocks.enumerated() {
            let lastFlag: UInt8 = (index == keptBlocks.count - 1) ? 0x80 : 0x00
            let len = block.payload.count
            let header = Data([
                lastFlag | (block.type & 0x7F),
                UInt8((len >> 16) & 0xFF),
                UInt8((len >> 8) & 0xFF),
                UInt8(len & 0xFF)
            ])
            try dst.write(contentsOf: header)
            if !block.payload.isEmpty {
                try dst.write(contentsOf: block.payload)
            }
            total += Int64(4 + len)
        }

        // Stream-copy all FLAC audio frames untouched
        let chunkSize = 1_048_576
        while let chunk = try src.read(upToCount: chunkSize), !chunk.isEmpty {
            try dst.write(contentsOf: chunk)
            total += Int64(chunk.count)
        }

        return total
    }

    private static func buildFLACPicturePayload(jpegData: Data) -> Data {
        var out = Data()
        let mime = Data("image/jpeg".utf8)
        out.appendBE32(3) // Picture type 3: Cover (front)
        out.appendBE32(UInt32(mime.count))
        out.append(mime)
        out.appendBE32(0) // Empty description
        out.appendBE32(0) // Width (0 = decoder determines from JPEG)
        out.appendBE32(0) // Height
        out.appendBE32(0) // Color depth
        out.appendBE32(0) // Indexed colors
        out.appendBE32(UInt32(jpegData.count))
        out.append(jpegData)
        return out
    }

    // MARK: - MP3 Safe ID3v2.3 Optimizer (Replaces APIC with Baseline JPEG, optional COMM strip)

    public static func copyMP3WithCleanID3v23(
        from sourceURL: URL,
        to destURL: URL,
        jpegData: Data?,
        stripComments: Bool
    ) throws -> Int64 {
        let src = try FileHandle(forReadingFrom: sourceURL)
        defer { try? src.close() }

        guard let head = try src.read(upToCount: 10), head.count == 10 else {
            return try cleanStreamCopy(from: sourceURL, to: destURL)
        }

        var keptFrames: [(id: String, flags: (UInt8, UInt8), body: Data)] = []
        var audioStartOffset: UInt64 = 0

        if head[0] == 0x49, head[1] == 0x44, head[2] == 0x33 { // "ID3"
            let majorVersion = head[3]
            let headerFlags = head[5]
            let tagSize = (Int(head[6] & 0x7F) << 21)
                | (Int(head[7] & 0x7F) << 14)
                | (Int(head[8] & 0x7F) << 7)
                | Int(head[9] & 0x7F)
            audioStartOffset = UInt64(10 + tagSize)

            // Only rewrite ID3v2.3 and ID3v2.4 frames cleanly (skip unsynchronized exotic tags)
            if (majorVersion == 3 || majorVersion == 4) && (headerFlags & 0x80) == 0,
               let tagBody = try src.read(upToCount: tagSize) {
                let b = [UInt8](tagBody)
                var offset = 0
                if (headerFlags & 0x40) != 0 && offset + 4 <= b.count {
                    let extSize = majorVersion == 4
                        ? ((Int(b[offset] & 0x7F) << 21) | (Int(b[offset+1] & 0x7F) << 14) | (Int(b[offset+2] & 0x7F) << 7) | Int(b[offset+3] & 0x7F))
                        : Int((UInt32(b[offset]) << 24) | (UInt32(b[offset+1]) << 16) | (UInt32(b[offset+2]) << 8) | UInt32(b[offset+3]))
                    offset += (majorVersion == 4 ? extSize : extSize + 4)
                }

                while offset + 10 <= b.count {
                    if b[offset] == 0 { break }
                    guard let frameID = String(bytes: b[offset..<(offset + 4)], encoding: .isoLatin1) else { break }
                    let size: Int = majorVersion == 4
                        ? ((Int(b[offset+4] & 0x7F) << 21) | (Int(b[offset+5] & 0x7F) << 14) | (Int(b[offset+6] & 0x7F) << 7) | Int(b[offset+7] & 0x7F))
                        : Int((UInt32(b[offset+4]) << 24) | (UInt32(b[offset+5]) << 16) | (UInt32(b[offset+6]) << 8) | UInt32(b[offset+7]))
                    let f1 = b[offset + 8]
                    offset += 10
                    guard size > 0, offset + size <= b.count else { break }
                    var frameBody = Data(b[offset..<(offset + size)])
                    offset += size

                    if jpegData != nil && frameID == "APIC" { continue }
                    if stripComments && frameID == "COMM" { continue }

                    // Convert UTF-8 text frames (encoding byte 3 in ID3v2.4) to UTF-16 BOM (encoding byte 1)
                    // so strict ID3v2.3 hardware players like Echo Mini read international characters cleanly!
                    if majorVersion == 4 && frameID.hasPrefix("T") && frameID != "TXXX",
                       !frameBody.isEmpty, frameBody[0] == 3,
                       let text = String(data: frameBody.dropFirst(), encoding: .utf8),
                       let utf16 = text.data(using: .utf16) {
                        var converted = Data([1])
                        converted.append(utf16)
                        frameBody = converted
                    }

                    // Map TDRC (ID3v2.4 recording time) to TYER (ID3v2.3 year) if 4 digits
                    let outID = (majorVersion == 4 && frameID == "TDRC") ? "TYER" : frameID
                    keptFrames.append((outID, (f1 & 0xE0, 0), frameBody))
                }
            } else {
                // Unknown or unsynchronized ID3v2 variant — copy untouched for safety
                return try cleanStreamCopy(from: sourceURL, to: destURL)
            }
        } else {
            audioStartOffset = 0
        }

        // Append optimized APIC frame (ID3v2.3: encoding=0, "image/jpeg\0", picType=3, "\0", jpegBytes)
        if let jpegData {
            var apic = Data([0x00])
            apic.append(Data("image/jpeg".utf8))
            apic.append(0x00)
            apic.append(0x03) // Front Cover
            apic.append(0x00) // Empty description
            apic.append(jpegData)
            keptFrames.append(("APIC", (0, 0), apic))
        }

        // Build complete ID3v2.3 tag
        var framesBuffer = Data()
        for frame in keptFrames {
            guard let idBytes = frame.id.data(using: .isoLatin1), idBytes.count == 4 else { continue }
            framesBuffer.append(idBytes)
            framesBuffer.appendBE32(UInt32(frame.body.count))
            framesBuffer.append(frame.flags.0)
            framesBuffer.append(frame.flags.1)
            framesBuffer.append(frame.body)
        }

        let tagSize = framesBuffer.count
        var tagHeader = Data([0x49, 0x44, 0x33, 0x03, 0x00, 0x00]) // ID3v2.3.0
        tagHeader.append(UInt8((tagSize >> 21) & 0x7F))
        tagHeader.append(UInt8((tagSize >> 14) & 0x7F))
        tagHeader.append(UInt8((tagSize >> 7) & 0x7F))
        tagHeader.append(UInt8(tagSize & 0x7F))

        let fm = FileManager.default
        if fm.fileExists(atPath: destURL.path) {
            try fm.removeItem(at: destURL)
        }
        fm.createFile(atPath: destURL.path, contents: nil)
        let dst = try FileHandle(forWritingTo: destURL)
        defer { try? dst.close() }

        var total: Int64 = 0
        try dst.write(contentsOf: tagHeader)
        try dst.write(contentsOf: framesBuffer)
        total += Int64(tagHeader.count + framesBuffer.count)

        try src.seek(toOffset: audioStartOffset)
        let chunkSize = 1_048_576
        while let chunk = try src.read(upToCount: chunkSize), !chunk.isEmpty {
            try dst.write(contentsOf: chunk)
            total += Int64(chunk.count)
        }
        return total
    }
}

private extension Data {
    mutating func appendBE32(_ value: UInt32) {
        append(UInt8((value >> 24) & 0xFF))
        append(UInt8((value >> 16) & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8(value & 0xFF))
    }
}

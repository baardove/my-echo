import Foundation
import AVFoundation
import CryptoKit

public struct ParsedAudioMetadata: Sendable {
    public var title: String?
    public var artist: String?
    public var albumArtist: String?
    public var album: String?
    public var trackNumber: Int?
    public var discNumber: Int?
    public var year: Int?
    public var genre: String?
    public var duration: TimeInterval = 0
    public var sampleRate: Int?
    public var bitDepth: Int?
    public var bitrate: Int?
    public var artworkData: Data?
    public var hasEmbeddedArtwork: Bool = false

    public init() {}
}

public enum AudioMetadataReader {
    public static func stableTrackID(forPath path: String) -> String {
        let digest = SHA256.hash(data: Data(path.precomposedStringWithCanonicalMapping.utf8))
        return digest.prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    public static func readTrack(
        at url: URL,
        sourceID: UUID,
        artworkCache: ArtworkCache
    ) async -> Track? {
        let fm = FileManager.default
        guard let attrs = try? fm.attributesOfItem(atPath: url.path) else { return nil }
        let fileSize = (attrs[.size] as? NSNumber)?.int64Value ?? 0
        let modifiedAt = (attrs[.modificationDate] as? Date) ?? Date()
        let resourceVals = try? url.resourceValues(forKeys: [.addedToDirectoryDateKey, .creationDateKey])
        let addedAt = [resourceVals?.addedToDirectoryDate, resourceVals?.creationDate, modifiedAt].compactMap { $0 }.max()
        let ext = url.pathExtension.lowercased()
        let format = AudioFormat(fileExtension: ext)
        guard format != .unknown else { return nil }

        var parsed = ParsedAudioMetadata()

        switch format {
        case .flac:
            parsed = parseFLAC(url: url)
        case .mp3:
            parsed = parseMP3(url: url)
        case .ogg:
            parsed = parseOGG(url: url)
        case .wav:
            parsed = parseWAV(url: url)
        case .dsf:
            parsed = parseDSF(url: url)
        case .ape:
            parsed = parseAPE(url: url)
        default:
            break
        }

        // Fill any missing fields (especially for M4A/ALAC/AIFF/MP3 duration/bitrate) via AVURLAsset
        if parsed.title == nil || parsed.artist == nil || parsed.duration <= 0 || format == .m4a || format == .alac || format == .aiff {
            await mergeAVFoundationMetadata(url: url, into: &parsed)
        }

        // Folder cover art fallback if no embedded art found
        var artworkHash: String? = nil
        if let art = parsed.artworkData, !art.isEmpty {
            artworkHash = artworkCache.store(imageData: art)
        } else if let folderArt = findFolderArtwork(in: url.deletingLastPathComponent()) {
            artworkHash = artworkCache.store(imageData: folderArt)
        }

        // Sidecar .lrc lyrics detection
        let lrcURL = url.deletingPathExtension().appendingPathExtension("lrc")
        let lyricsPath = fm.fileExists(atPath: lrcURL.path) ? lrcURL.path : nil

        // Fallback metadata inferred from ARTIST/ALBUM/01 - Title.ext path structure
        let fallback = inferFromPath(url: url)
        let title = nonEmpty(parsed.title) ?? fallback.title
        let artist = nonEmpty(parsed.artist) ?? fallback.artist
        let albumArtist = nonEmpty(parsed.albumArtist) ?? artist
        let album = nonEmpty(parsed.album) ?? fallback.album
        let trackNum = parsed.trackNumber ?? fallback.trackNumber

        return Track(
            id: stableTrackID(forPath: url.path),
            sourceID: sourceID,
            filePath: url.path,
            fileName: url.lastPathComponent,
            fileSize: fileSize,
            modifiedAt: modifiedAt,
            addedAt: addedAt,
            format: format,
            title: title,
            artist: artist,
            albumArtist: albumArtist,
            album: album,
            trackNumber: trackNum,
            discNumber: parsed.discNumber,
            year: parsed.year,
            genre: parsed.genre,
            duration: parsed.duration,
            sampleRate: parsed.sampleRate,
            bitDepth: parsed.bitDepth,
            bitrate: parsed.bitrate,
            artworkHash: artworkHash,
            hasEmbeddedArtwork: parsed.hasEmbeddedArtwork,
            lyricsPath: lyricsPath,
            isAvailable: true
        )
    }

    // MARK: - FLAC Parser

    public static func parseFLAC(url: URL) -> ParsedAudioMetadata {
        var meta = ParsedAudioMetadata()
        guard let fh = try? FileHandle(forReadingFrom: url) else { return meta }
        defer { try? fh.close() }

        guard let magic = try? fh.read(upToCount: 4), magic == Data("fLaC".utf8) else {
            return meta
        }

        var isLast = false
        while !isLast {
            guard let header = try? fh.read(upToCount: 4), header.count == 4 else { break }
            isLast = (header[0] & 0x80) != 0
            let blockType = header[0] & 0x7F
            let length = (Int(header[1]) << 16) | (Int(header[2]) << 8) | Int(header[3])
            guard length >= 0, length < 64_000_000 else { break }

            if blockType == 0 || blockType == 4 || blockType == 6 {
                guard let blockData = try? fh.read(upToCount: length), blockData.count == length else { break }
                if blockType == 0 && blockData.count >= 18 {
                    // STREAMINFO
                    let b = [UInt8](blockData)
                    let sampleRate = (Int(b[10]) << 12) | (Int(b[11]) << 4) | (Int(b[12]) >> 4)
                    let bps = (((Int(b[12]) & 0x01) << 4) | (Int(b[13]) >> 4)) + 1
                    let totalSamples = (UInt64(b[13] & 0x0F) << 32)
                        | (UInt64(b[14]) << 24)
                        | (UInt64(b[15]) << 16)
                        | (UInt64(b[16]) << 8)
                        | UInt64(b[17])
                    meta.sampleRate = sampleRate
                    meta.bitDepth = bps
                    if sampleRate > 0 && totalSamples > 0 {
                        meta.duration = Double(totalSamples) / Double(sampleRate)
                    }
                } else if blockType == 4 {
                    parseVorbisComments(blockData, into: &meta)
                } else if blockType == 6 {
                    if let pic = parseFLACPictureBlock(blockData) {
                        // Prefer front cover (type 3), otherwise keep first picture
                        if meta.artworkData == nil || pic.pictureType == 3 {
                            meta.artworkData = pic.data
                            meta.hasEmbeddedArtwork = true
                        }
                    }
                }
            } else {
                // Skip non-essential blocks without loading them
                if let current = try? fh.offset() {
                    try? fh.seek(toOffset: current + UInt64(length))
                } else {
                    break
                }
            }
        }
        return meta
    }

    static func parseVorbisComments(_ data: Data, into meta: inout ParsedAudioMetadata) {
        let bytes = [UInt8](data)
        var offset = 0
        guard offset + 4 <= bytes.count else { return }
        let vendorLen = readLE32(bytes, offset)
        offset += 4 + vendorLen
        guard offset + 4 <= bytes.count else { return }
        let commentCount = readLE32(bytes, offset)
        offset += 4

        for _ in 0..<min(commentCount, 512) {
            guard offset + 4 <= bytes.count else { break }
            let len = readLE32(bytes, offset)
            offset += 4
            guard len >= 0, offset + len <= bytes.count else { break }
            if let str = String(bytes: bytes[offset..<(offset + len)], encoding: .utf8),
               let eq = str.firstIndex(of: "=") {
                let key = str[..<eq].uppercased()
                let value = String(str[str.index(after: eq)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                switch key {
                case "TITLE": meta.title = value
                case "ARTIST": meta.artist = value
                case "ALBUMARTIST", "ALBUM ARTIST": meta.albumArtist = value
                case "ALBUM": meta.album = value
                case "TRACKNUMBER": meta.trackNumber = parseLeadingInt(value)
                case "DISCNUMBER": meta.discNumber = parseLeadingInt(value)
                case "DATE", "YEAR": meta.year = parseYear(value)
                case "GENRE": meta.genre = value
                case "METADATA_BLOCK_PICTURE":
                    if meta.artworkData == nil, let raw = Data(base64Encoded: value),
                       let pic = parseFLACPictureBlock(raw) {
                        meta.artworkData = pic.data
                        meta.hasEmbeddedArtwork = true
                    }
                default: break
                }
            }
            offset += len
        }
    }

    static func parseFLACPictureBlock(_ data: Data) -> (pictureType: UInt32, mime: String, data: Data)? {
        let b = [UInt8](data)
        var offset = 0
        guard offset + 8 <= b.count else { return nil }
        let picType = readBE32U(b, offset); offset += 4
        let mimeLen = Int(readBE32U(b, offset)); offset += 4
        guard offset + mimeLen + 4 <= b.count else { return nil }
        let mime = String(bytes: b[offset..<(offset + mimeLen)], encoding: .utf8) ?? "image/jpeg"
        offset += mimeLen
        let descLen = Int(readBE32U(b, offset)); offset += 4
        guard offset + descLen + 20 <= b.count else { return nil }
        offset += descLen + 16 // skip width, height, depth, indexed colors
        let dataLen = Int(readBE32U(b, offset)); offset += 4
        guard dataLen > 0, offset + dataLen <= b.count else { return nil }
        let imgData = Data(b[offset..<(offset + dataLen)])
        return (picType, mime, imgData)
    }

    // MARK: - MP3 / ID3v2 + ID3v1 Parser

    public static func parseMP3(url: URL) -> ParsedAudioMetadata {
        var meta = ParsedAudioMetadata()
        guard let fh = try? FileHandle(forReadingFrom: url) else { return meta }
        defer { try? fh.close() }

        if let header = try? fh.read(upToCount: 10), header.count == 10,
           header[0] == 0x49, header[1] == 0x44, header[2] == 0x33 { // "ID3"
            let majorVersion = header[3]
            let flags = header[5]
            let tagSize = decodeSynchsafe(header[6], header[7], header[8], header[9])
            if tagSize > 0, tagSize < 64_000_000,
               let tagBody = try? fh.read(upToCount: tagSize) {
                parseID3v2Body(tagBody, majorVersion: majorVersion, flags: flags, into: &meta)
            }
        }

        // Fallback to ID3v1 at end of file if essential fields missing
        if meta.title == nil || meta.artist == nil || meta.album == nil {
            if let fileSize = try? fh.seekToEnd(), fileSize >= 128 {
                try? fh.seek(toOffset: fileSize - 128)
                if let tail = try? fh.read(upToCount: 128), tail.count == 128,
                   tail[0] == 0x54, tail[1] == 0x41, tail[2] == 0x47 { // "TAG"
                    let b = [UInt8](tail)
                    meta.title = meta.title ?? cleanNullString(b[3..<33])
                    meta.artist = meta.artist ?? cleanNullString(b[33..<63])
                    meta.album = meta.album ?? cleanNullString(b[63..<93])
                    if meta.year == nil, let y = cleanNullString(b[93..<97]) {
                        meta.year = parseYear(y)
                    }
                    if meta.trackNumber == nil && b[125] == 0 && b[126] != 0 {
                        meta.trackNumber = Int(b[126])
                    }
                }
            }
        }
        return meta
    }

    static func parseID3v2Body(_ data: Data, majorVersion: UInt8, flags: UInt8, into meta: inout ParsedAudioMetadata) {
        let bytes = [UInt8](data)
        var offset = 0

        // Skip extended header if present (bit 6)
        if (flags & 0x40) != 0 && offset + 4 <= bytes.count {
            let extSize = majorVersion == 4
                ? decodeSynchsafe(bytes[offset], bytes[offset+1], bytes[offset+2], bytes[offset+3])
                : Int(readBE32U(bytes, offset))
            offset += (majorVersion == 4 ? extSize : extSize + 4)
        }

        let headerLen = majorVersion == 2 ? 6 : 10
        while offset + headerLen <= bytes.count {
            if bytes[offset] == 0 { break } // padding

            let frameID: String
            let frameSize: Int
            if majorVersion == 2 {
                frameID = String(bytes: bytes[offset..<(offset + 3)], encoding: .isoLatin1) ?? ""
                frameSize = (Int(bytes[offset + 3]) << 16) | (Int(bytes[offset + 4]) << 8) | Int(bytes[offset + 5])
                offset += 6
            } else {
                frameID = String(bytes: bytes[offset..<(offset + 4)], encoding: .isoLatin1) ?? ""
                frameSize = majorVersion == 4
                    ? decodeSynchsafe(bytes[offset + 4], bytes[offset + 5], bytes[offset + 6], bytes[offset + 7])
                    : Int(readBE32U(bytes, offset + 4))
                offset += 10
            }

            guard frameSize > 0, offset + frameSize <= bytes.count else { break }
            let frameData = Array(bytes[offset..<(offset + frameSize)])
            offset += frameSize

            switch frameID {
            case "TIT2", "TT2": meta.title = decodeID3Text(frameData)
            case "TPE1", "TP1": meta.artist = decodeID3Text(frameData)
            case "TPE2", "TP2": meta.albumArtist = decodeID3Text(frameData)
            case "TALB", "TAL": meta.album = decodeID3Text(frameData)
            case "TRCK", "TRK": meta.trackNumber = decodeID3Text(frameData).flatMap(parseLeadingInt)
            case "TPOS", "TPA": meta.discNumber = decodeID3Text(frameData).flatMap(parseLeadingInt)
            case "TYER", "TDRC", "TYE": meta.year = decodeID3Text(frameData).flatMap(parseYear)
            case "TCON", "TCO": meta.genre = decodeID3Text(frameData)
            case "APIC":
                if let img = decodeAPIC(frameData) {
                    if meta.artworkData == nil || img.picType == 3 {
                        meta.artworkData = img.data
                        meta.hasEmbeddedArtwork = true
                    }
                }
            case "PIC":
                if let img = decodePIC(frameData) {
                    if meta.artworkData == nil {
                        meta.artworkData = img
                        meta.hasEmbeddedArtwork = true
                    }
                }
            default:
                break
            }
        }
    }

    private static func decodeID3Text(_ bytes: [UInt8]) -> String? {
        guard !bytes.isEmpty else { return nil }
        let encoding = bytes[0]
        let payload = Array(bytes.dropFirst())
        let raw: String?
        switch encoding {
        case 0:
            raw = String(bytes: payload, encoding: .isoLatin1)
        case 1:
            raw = String(bytes: payload, encoding: .utf16)
        case 2:
            raw = String(bytes: payload, encoding: .utf16BigEndian)
        case 3:
            raw = String(bytes: payload, encoding: .utf8)
        default:
            raw = String(bytes: payload, encoding: .utf8) ?? String(bytes: payload, encoding: .isoLatin1)
        }
        return raw?.replacingOccurrences(of: "\0", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decodeAPIC(_ bytes: [UInt8]) -> (picType: UInt8, data: Data)? {
        guard bytes.count > 4 else { return nil }
        let encoding = bytes[0]
        var i = 1
        // Null-terminated MIME
        while i < bytes.count && bytes[i] != 0 { i += 1 }
        i += 1
        guard i < bytes.count else { return nil }
        let picType = bytes[i]
        i += 1
        // Null-terminated description (1 byte null for enc 0/3, 2 byte null for enc 1/2)
        if encoding == 1 || encoding == 2 {
            while i + 1 < bytes.count && !(bytes[i] == 0 && bytes[i + 1] == 0) { i += 2 }
            i += 2
        } else {
            while i < bytes.count && bytes[i] != 0 { i += 1 }
            i += 1
        }
        guard i < bytes.count else { return nil }
        return (picType, Data(bytes[i...]))
    }

    private static func decodePIC(_ bytes: [UInt8]) -> Data? {
        guard bytes.count > 6 else { return nil }
        let encoding = bytes[0]
        var i = 5 // encoding(1) + format(3) + picType(1)
        if encoding == 1 || encoding == 2 {
            while i + 1 < bytes.count && !(bytes[i] == 0 && bytes[i + 1] == 0) { i += 2 }
            i += 2
        } else {
            while i < bytes.count && bytes[i] != 0 { i += 1 }
            i += 1
        }
        guard i < bytes.count else { return nil }
        return Data(bytes[i...])
    }

    // MARK: - OGG Vorbis Parser

    public static func parseOGG(url: URL) -> ParsedAudioMetadata {
        var meta = ParsedAudioMetadata()
        guard let fh = try? FileHandle(forReadingFrom: url),
              let head = try? fh.read(upToCount: 65536) else { return meta }
        defer { try? fh.close() }

        let bytes = [UInt8](head)
        // Find Vorbis identification header: 0x01 "vorbis"
        let idSig: [UInt8] = [0x01, 0x76, 0x6F, 0x72, 0x62, 0x69, 0x73]
        if let idx = findPattern(idSig, in: bytes), idx + 28 < bytes.count {
            let sr = readLE32(bytes, idx + 12)
            let nomBitrate = readLE32(bytes, idx + 20)
            if sr > 0 { meta.sampleRate = sr }
            if nomBitrate > 0 { meta.bitrate = nomBitrate / 1000 }
        }

        // Find Vorbis comment header: 0x03 "vorbis"
        let commentSig: [UInt8] = [0x03, 0x76, 0x6F, 0x72, 0x62, 0x69, 0x73]
        if let idx = findPattern(commentSig, in: bytes) {
            let start = idx + 7
            if start < bytes.count {
                parseVorbisComments(Data(bytes[start...]), into: &meta)
            }
        }

        // Estimate duration from last OggS page granule position
        if let sr = meta.sampleRate, sr > 0, let fileSize = try? fh.seekToEnd() {
            let tailSize = min(fileSize, 16384)
            try? fh.seek(toOffset: fileSize - tailSize)
            if let tail = try? fh.read(upToCount: Int(tailSize)) {
                let tb = [UInt8](tail)
                let oggSig: [UInt8] = [0x4F, 0x67, 0x67, 0x53] // "OggS"
                var lastGranule: UInt64 = 0
                var i = 0
                while i + 14 < tb.count {
                    if tb[i] == oggSig[0] && tb[i+1] == oggSig[1] && tb[i+2] == oggSig[2] && tb[i+3] == oggSig[3] {
                        let g = readLE64U(tb, i + 6)
                        if g != UInt64.max && g > lastGranule {
                            lastGranule = g
                        }
                        i += 14
                    } else {
                        i += 1
                    }
                }
                if lastGranule > 0 {
                    meta.duration = Double(lastGranule) / Double(sr)
                }
            }
        }

        return meta
    }

    // MARK: - WAV Parser

    public static func parseWAV(url: URL) -> ParsedAudioMetadata {
        var meta = ParsedAudioMetadata()
        guard let fh = try? FileHandle(forReadingFrom: url),
              let riff = try? fh.read(upToCount: 12), riff.count == 12,
              String(bytes: riff[0..<4], encoding: .ascii) == "RIFF",
              String(bytes: riff[8..<12], encoding: .ascii) == "WAVE" else {
            return meta
        }
        defer { try? fh.close() }

        var byteRate = 0
        var dataSize = 0
        while let ch = try? fh.read(upToCount: 8), ch.count == 8 {
            let chunkID = String(bytes: ch[0..<4], encoding: .ascii) ?? ""
            let chunkSize = Int(readLE32U([UInt8](ch), 4))
            guard chunkSize >= 0 else { break }

            if chunkID == "fmt " && chunkSize >= 16, let body = try? fh.read(upToCount: chunkSize) {
                let b = [UInt8](body)
                meta.sampleRate = readLE32(b, 4)
                byteRate = readLE32(b, 8)
                meta.bitDepth = Int(b[14]) | (Int(b[15]) << 8)
            } else if chunkID == "data" {
                dataSize = chunkSize
                if let pos = try? fh.offset() {
                    try? fh.seek(toOffset: pos + UInt64(chunkSize + (chunkSize % 2)))
                }
                continue
            } else if (chunkID == "id3 " || chunkID == "ID3 "), chunkSize < 32_000_000,
                      let body = try? fh.read(upToCount: chunkSize), body.count >= 10,
                      body[0] == 0x49, body[1] == 0x44, body[2] == 0x33 {
                let major = body[3]
                let flags = body[5]
                let size = decodeSynchsafe(body[6], body[7], body[8], body[9])
                if body.count >= 10 + min(size, body.count - 10) {
                    parseID3v2Body(body.subdata(in: 10..<min(body.count, 10 + size)), majorVersion: major, flags: flags, into: &meta)
                }
            } else if chunkID == "LIST", chunkSize < 1_000_000,
                      let body = try? fh.read(upToCount: chunkSize), body.count >= 4,
                      String(bytes: body[0..<4], encoding: .ascii) == "INFO" {
                parseRIFFInfo(body.subdata(in: 4..<body.count), into: &meta)
            } else {
                if let pos = try? fh.offset() {
                    try? fh.seek(toOffset: pos + UInt64(chunkSize))
                } else {
                    break
                }
            }
            if chunkSize % 2 == 1, let pos = try? fh.offset() {
                try? fh.seek(toOffset: pos + 1)
            }
        }
        if byteRate > 0 && dataSize > 0 {
            meta.duration = Double(dataSize) / Double(byteRate)
        }
        return meta
    }

    private static func parseRIFFInfo(_ data: Data, into meta: inout ParsedAudioMetadata) {
        let b = [UInt8](data)
        var offset = 0
        while offset + 8 <= b.count {
            let tag = String(bytes: b[offset..<(offset + 4)], encoding: .ascii) ?? ""
            let size = Int(readLE32U(b, offset + 4))
            offset += 8
            guard size >= 0, offset + size <= b.count else { break }
            let val = cleanNullString(b[offset..<(offset + size)])
            switch tag {
            case "INAM": meta.title = meta.title ?? val
            case "IART": meta.artist = meta.artist ?? val
            case "IPRD": meta.album = meta.album ?? val
            case "ITRK": meta.trackNumber = meta.trackNumber ?? val.flatMap(parseLeadingInt)
            case "ICRD": meta.year = meta.year ?? val.flatMap(parseYear)
            case "IGNR": meta.genre = meta.genre ?? val
            default: break
            }
            offset += size + (size % 2)
        }
    }

    // MARK: - DSF (DSD) Parser

    public static func parseDSF(url: URL) -> ParsedAudioMetadata {
        var meta = ParsedAudioMetadata()
        guard let fh = try? FileHandle(forReadingFrom: url),
              let dsd = try? fh.read(upToCount: 28), dsd.count == 28,
              String(bytes: dsd[0..<4], encoding: .ascii) == "DSD " else {
            return meta
        }
        defer { try? fh.close() }

        let dsdBytes = [UInt8](dsd)
        let metadataPointer = readLE64U(dsdBytes, 20)

        if let fmt = try? fh.read(upToCount: 52), fmt.count == 52,
           String(bytes: fmt[0..<4], encoding: .ascii) == "fmt " {
            let fb = [UInt8](fmt)
            let sr = Int(readLE32U(fb, 28))
            let bps = Int(readLE32U(fb, 32))
            let sampleCount = readLE64U(fb, 36)
            meta.sampleRate = sr
            meta.bitDepth = bps
            if sr > 0 && sampleCount > 0 {
                meta.duration = Double(sampleCount) / Double(sr)
            }
        }

        if metadataPointer > 0 {
            try? fh.seek(toOffset: metadataPointer)
            if let header = try? fh.read(upToCount: 10), header.count == 10,
               header[0] == 0x49, header[1] == 0x44, header[2] == 0x33 {
                let major = header[3]
                let flags = header[5]
                let tagSize = decodeSynchsafe(header[6], header[7], header[8], header[9])
                if tagSize > 0, tagSize < 32_000_000,
                   let body = try? fh.read(upToCount: tagSize) {
                    parseID3v2Body(body, majorVersion: major, flags: flags, into: &meta)
                }
            }
        }
        return meta
    }

    // MARK: - APE Parser (APEv2 footer)

    public static func parseAPE(url: URL) -> ParsedAudioMetadata {
        var meta = ParsedAudioMetadata()
        guard let fh = try? FileHandle(forReadingFrom: url),
              let fileSize = try? fh.seekToEnd(), fileSize >= 32 else { return meta }
        defer { try? fh.close() }

        // Check APEv2 footer at EOF (or EOF - 128 if ID3v1 is appended)
        for suffixOffset in [UInt64(32), UInt64(160)] where fileSize >= suffixOffset {
            try? fh.seek(toOffset: fileSize - suffixOffset)
            guard let footer = try? fh.read(upToCount: 32), footer.count == 32,
                  String(bytes: footer[0..<8], encoding: .ascii) == "APETAGEX" else { continue }
            let fb = [UInt8](footer)
            let tagSize = Int(readLE32U(fb, 12))
            let itemCount = Int(readLE32U(fb, 16))
            guard tagSize >= 32, UInt64(tagSize) <= fileSize else { break }
            let bodySize = tagSize - 32
            try? fh.seek(toOffset: fileSize - suffixOffset - UInt64(bodySize))
            guard let body = try? fh.read(upToCount: bodySize) else { break }
            let b = [UInt8](body)
            var offset = 0
            for _ in 0..<min(itemCount, 256) {
                guard offset + 8 <= b.count else { break }
                let valSize = Int(readLE32U(b, offset))
                let flags = readLE32U(b, offset + 4)
                offset += 8
                var keyEnd = offset
                while keyEnd < b.count && b[keyEnd] != 0 { keyEnd += 1 }
                let key = (String(bytes: b[offset..<keyEnd], encoding: .utf8) ?? "").uppercased()
                offset = keyEnd + 1
                guard offset + valSize <= b.count else { break }
                let isBinary = ((flags >> 1) & 0x03) == 1
                if isBinary && key.contains("COVER") {
                    // Format: filename\0imagebytes
                    if let zeroIdx = b[offset..<(offset + valSize)].firstIndex(of: 0), zeroIdx + 1 < offset + valSize {
                        meta.artworkData = Data(b[(zeroIdx + 1)..<(offset + valSize)])
                        meta.hasEmbeddedArtwork = true
                    }
                } else if !isBinary, let val = String(bytes: b[offset..<(offset + valSize)], encoding: .utf8) {
                    switch key {
                    case "TITLE": meta.title = val
                    case "ARTIST": meta.artist = val
                    case "ALBUM ARTIST", "ALBUMARTIST": meta.albumArtist = val
                    case "ALBUM": meta.album = val
                    case "TRACK": meta.trackNumber = parseLeadingInt(val)
                    case "DISC": meta.discNumber = parseLeadingInt(val)
                    case "YEAR", "DATE": meta.year = parseYear(val)
                    case "GENRE": meta.genre = val
                    default: break
                    }
                }
                offset += valSize
            }
            break
        }
        return meta
    }

    // MARK: - AVFoundation Fallback (M4A/ALAC/MP3/AIFF)

    private static func mergeAVFoundationMetadata(url: URL, into meta: inout ParsedAudioMetadata) async {
        let asset = AVURLAsset(url: url)

        if meta.duration <= 0 {
            if let cmDuration = try? await asset.load(.duration) {
                let secs = CMTimeGetSeconds(cmDuration)
                if secs.isFinite && secs > 0 { meta.duration = secs }
            }
        }

        if meta.sampleRate == nil || meta.bitrate == nil {
            if let tracks = try? await asset.loadTracks(withMediaType: .audio), let first = tracks.first {
                if meta.bitrate == nil, let rate = try? await first.load(.estimatedDataRate), rate > 0 {
                    meta.bitrate = Int((rate / 1000.0).rounded())
                }
                if let descs = try? await first.load(.formatDescriptions), let desc = descs.first {
                    if let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(desc)?.pointee {
                        if meta.sampleRate == nil && asbd.mSampleRate > 0 {
                            meta.sampleRate = Int(asbd.mSampleRate)
                        }
                        if meta.bitDepth == nil && asbd.mBitsPerChannel > 0 {
                            meta.bitDepth = Int(asbd.mBitsPerChannel)
                        }
                    }
                }
            }
        }

        guard let allMeta = try? await asset.load(.metadata) else { return }
        for item in allMeta {
            let commonKey = item.commonKey
            let identifier = item.identifier?.rawValue ?? ""

            if commonKey == .commonKeyTitle, meta.title == nil {
                meta.title = try? await item.load(.stringValue)
            } else if commonKey == .commonKeyArtist, meta.artist == nil {
                meta.artist = try? await item.load(.stringValue)
            } else if commonKey == .commonKeyAlbumName, meta.album == nil {
                meta.album = try? await item.load(.stringValue)
            } else if commonKey == .commonKeyArtwork, meta.artworkData == nil {
                if let data = try? await item.load(.dataValue), !data.isEmpty {
                    meta.artworkData = data
                    meta.hasEmbeddedArtwork = true
                }
            } else if commonKey == .commonKeyType, meta.genre == nil {
                meta.genre = try? await item.load(.stringValue)
            } else if commonKey == .commonKeyCreationDate, meta.year == nil {
                if let s = try? await item.load(.stringValue) {
                    meta.year = parseYear(s)
                }
            } else if identifier.contains("aART") || identifier.lowercased().contains("albumartist") {
                if meta.albumArtist == nil {
                    meta.albumArtist = try? await item.load(.stringValue)
                }
            } else if identifier.contains("trkn") || identifier.contains("TRCK") {
                if meta.trackNumber == nil {
                    if let data = try? await item.load(.dataValue), data.count >= 4 {
                        let n = (Int(data[2]) << 8) | Int(data[3])
                        if n > 0 { meta.trackNumber = n }
                    } else if let s = try? await item.load(.stringValue) {
                        meta.trackNumber = parseLeadingInt(s)
                    }
                }
            } else if identifier.contains("disk") || identifier.contains("TPOS") {
                if meta.discNumber == nil {
                    if let data = try? await item.load(.dataValue), data.count >= 4 {
                        let n = (Int(data[2]) << 8) | Int(data[3])
                        if n > 0 { meta.discNumber = n }
                    } else if let s = try? await item.load(.stringValue) {
                        meta.discNumber = parseLeadingInt(s)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    public static func findFolderArtwork(in directory: URL) -> Data? {
        let preferredNames = [
            "cover.jpg", "folder.jpg", "front.jpg", "album.jpg",
            "cover.jpeg", "folder.jpeg", "front.jpeg",
            "cover.png", "folder.png", "front.png", "album.png"
        ]
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return nil }

        let byLowerName = Dictionary(uniqueKeysWithValues: entries.map { ($0.lastPathComponent.lowercased(), $0) })
        for name in preferredNames {
            if let url = byLowerName[name], let data = try? Data(contentsOf: url), !data.isEmpty {
                return data
            }
        }
        // Fallback to first image in folder
        if let firstImg = entries.first(where: { ["jpg", "jpeg", "png"].contains($0.pathExtension.lowercased()) }),
           let data = try? Data(contentsOf: firstImg), !data.isEmpty {
            return data
        }
        return nil
    }

    private static func inferFromPath(url: URL) -> (artist: String, album: String, title: String, trackNumber: Int?) {
        let baseName = url.deletingPathExtension().lastPathComponent
        let albumDir = url.deletingLastPathComponent().lastPathComponent
        let artistDir = url.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent

        var trackNum: Int?
        var cleanTitle = baseName

        // Match "01 - Track Title" or "01. Track Title" or "01 Track Title"
        if let match = baseName.range(of: #"^\d{1,3}[\s._-]+(.+)$"#, options: .regularExpression) {
            let digits = baseName.prefix(while: { $0.isNumber })
            trackNum = Int(digits)
            let rest = baseName[match].drop(while: { $0.isNumber || $0 == " " || $0 == "-" || $0 == "." || $0 == "_" })
            if !rest.isEmpty { cleanTitle = String(rest) }
        }

        let album = (albumDir.isEmpty || albumDir == "/") ? "Unknown Album" : albumDir
        let artist = (artistDir.isEmpty || artistDir == "/" || artistDir == "Volumes" || artistDir == "Music") ? "Unknown Artist" : artistDir
        return (artist, album, cleanTitle, trackNum)
    }

    private static func nonEmpty(_ s: String?) -> String? {
        guard let trimmed = s?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private static func parseLeadingInt(_ s: String) -> Int? {
        let part = s.split(separator: "/").first.map(String.init) ?? s
        let digits = part.trimmingCharacters(in: .whitespaces).prefix(while: { $0.isNumber })
        return Int(digits)
    }

    private static func parseYear(_ s: String) -> Int? {
        let digits = s.prefix(4)
        if digits.count == 4, let y = Int(digits), y >= 1900 && y <= 2100 {
            return y
        }
        return nil
    }

    private static func decodeSynchsafe(_ b0: UInt8, _ b1: UInt8, _ b2: UInt8, _ b3: UInt8) -> Int {
        (Int(b0 & 0x7F) << 21) | (Int(b1 & 0x7F) << 14) | (Int(b2 & 0x7F) << 7) | Int(b3 & 0x7F)
    }

    private static func readLE32(_ b: [UInt8], _ o: Int) -> Int {
        Int(UInt32(b[o]) | (UInt32(b[o+1]) << 8) | (UInt32(b[o+2]) << 16) | (UInt32(b[o+3]) << 24))
    }

    private static func readLE32U(_ b: [UInt8], _ o: Int) -> UInt32 {
        UInt32(b[o]) | (UInt32(b[o+1]) << 8) | (UInt32(b[o+2]) << 16) | (UInt32(b[o+3]) << 24)
    }

    private static func readLE64U(_ b: [UInt8], _ o: Int) -> UInt64 {
        let lo = UInt64(readLE32U(b, o))
        let hi = UInt64(readLE32U(b, o + 4))
        return lo | (hi << 32)
    }

    private static func readBE32U(_ b: [UInt8], _ o: Int) -> UInt32 {
        (UInt32(b[o]) << 24) | (UInt32(b[o+1]) << 16) | (UInt32(b[o+2]) << 8) | UInt32(b[o+3])
    }

    private static func cleanNullString(_ slice: ArraySlice<UInt8>) -> String? {
        let trimmed = slice.prefix(while: { $0 != 0 })
        guard !trimmed.isEmpty,
              let s = String(bytes: trimmed, encoding: .utf8) ?? String(bytes: trimmed, encoding: .isoLatin1) else {
            return nil
        }
        let cleaned = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    private static func findPattern(_ pattern: [UInt8], in buffer: [UInt8]) -> Int? {
        guard !pattern.isEmpty, buffer.count >= pattern.count else { return nil }
        let limit = buffer.count - pattern.count
        for i in 0...limit {
            var matched = true
            for j in 0..<pattern.count {
                if buffer[i + j] != pattern[j] {
                    matched = false
                    break
                }
            }
            if matched { return i }
        }
        return nil
    }
}

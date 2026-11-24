import Foundation
import CryptoKit
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers

public final class ArtworkCache: @unchecked Sendable {
    public let cacheDirectory: URL
    private let fileManager = FileManager.default
    private let lock = NSLock()

    public init(cacheDirectory: URL? = nil) {
        if let cacheDirectory {
            self.cacheDirectory = cacheDirectory
        } else {
            let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            self.cacheDirectory = caches.appendingPathComponent("Echo/Artwork", isDirectory: true)
        }
        try? fileManager.createDirectory(at: self.cacheDirectory, withIntermediateDirectories: true)
    }

    public static func hash(for data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    /// Stores raw original artwork and a fast UI thumbnail (512px) keyed by SHA256 prefix.
    @discardableResult
    public func store(imageData: Data) -> String? {
        guard !imageData.isEmpty else { return nil }
        let key = Self.hash(for: imageData)
        let thumbURL = thumbnailURL(for: key)
        let origURL = originalURL(for: key)

        lock.lock()
        let exists = fileManager.fileExists(atPath: thumbURL.path)
        lock.unlock()
        if exists { return key }

        // Persist original for high-quality device optimization later
        try? imageData.write(to: origURL, options: .atomic)

        // Generate a crisp 512px JPEG thumbnail for snappy Spotify-like scrolling
        if let thumbData = ArtworkOptimizer.convertToBaselineJPEG(
            imageData: imageData,
            maxDimension: 512,
            maxBytes: 220_000,
            initialQuality: 0.85
        ) {
            try? thumbData.write(to: thumbURL, options: .atomic)
            return key
        } else {
            try? imageData.write(to: thumbURL, options: .atomic)
            return key
        }
    }

    public func thumbnailURL(for hash: String) -> URL {
        cacheDirectory.appendingPathComponent("\(hash)_thumb.jpg")
    }

    public func originalURL(for hash: String) -> URL {
        cacheDirectory.appendingPathComponent("\(hash)_orig.dat")
    }

    public func loadOriginalData(for hash: String) -> Data? {
        let orig = originalURL(for: hash)
        if let data = try? Data(contentsOf: orig) { return data }
        return try? Data(contentsOf: thumbnailURL(for: hash))
    }

    public func loadThumbnailData(for hash: String) -> Data? {
        try? Data(contentsOf: thumbnailURL(for: hash))
    }
}

public enum ArtworkOptimizer {
    /// Converts arbitrary image data (PNG, WebP, Progressive JPEG, CMYK, huge JPEG) into a
    /// strict sRGB Baseline JPEG resized to fit within maxDimension and maxBytes.
    /// FiiO Echo Mini rejects PNG, progressive JPEGs, and oversized (>1200px) covers.
    public static func convertToBaselineJPEG(
        imageData: Data,
        maxDimension: Int,
        maxBytes: Int,
        initialQuality: CGFloat = 0.88
    ) -> Data? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }

        let targetImage = resizeToSRGB(cgImage: cgImage, maxDimension: maxDimension) ?? cgImage

        var quality = initialQuality
        var lastResult: Data?
        for _ in 0..<5 {
            if let encoded = encodeBaselineJPEG(cgImage: targetImage, quality: quality) {
                lastResult = encoded
                if encoded.count <= maxBytes || quality <= 0.45 {
                    return encoded
                }
            }
            quality -= 0.12
        }
        return lastResult
    }

    /// Checks whether raw image bytes are already a compliant sRGB baseline JPEG within bounds.
    public static func isAlreadyCompliantBaselineJPEG(
        imageData: Data,
        maxDimension: Int,
        maxBytes: Int
    ) -> Bool {
        guard imageData.count <= maxBytes else { return false }
        // Quick JPEG SOI magic check
        guard imageData.count > 4, imageData[0] == 0xFF, imageData[1] == 0xD8 else { return false }
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return false
        }
        let width = props[kCGImagePropertyPixelWidth] as? Int ?? 0
        let height = props[kCGImagePropertyPixelHeight] as? Int ?? 0
        if width == 0 || height == 0 || width > maxDimension || height > maxDimension {
            return false
        }
        if let colorModel = props[kCGImagePropertyColorModel] as? String, colorModel != (kCGImagePropertyColorModelRGB as String) {
            return false
        }
        if let jfif = props[kCGImagePropertyJFIFDictionary] as? [CFString: Any],
           let isProg = jfif[kCGImagePropertyJFIFIsProgressive] as? Bool, isProg {
            return false
        }
        // Also scan JPEG SOF2 (0xFFC2 = progressive DCT) marker directly to be 100% certain
        if containsProgressiveSOF2(imageData) {
            return false
        }
        return true
    }

    private static func containsProgressiveSOF2(_ data: Data) -> Bool {
        let bytes = [UInt8](data)
        var i = 2
        while i + 3 < bytes.count {
            if bytes[i] != 0xFF {
                i += 1
                continue
            }
            while i < bytes.count && bytes[i] == 0xFF { i += 1 }
            guard i < bytes.count else { break }
            let marker = bytes[i]
            i += 1
            if marker == 0xC2 || marker == 0xCA { return true } // SOF2 / SOF10 progressive
            if marker == 0xDA || marker == 0xD9 { break }       // SOS / EOI
            if marker == 0x01 || (marker >= 0xD0 && marker <= 0xD8) { continue }
            guard i + 1 < bytes.count else { break }
            let segLen = (Int(bytes[i]) << 8) | Int(bytes[i + 1])
            if segLen < 2 { break }
            i += segLen
        }
        return false
    }

    private static func resizeToSRGB(cgImage: CGImage, maxDimension: Int) -> CGImage? {
        let srcW = cgImage.width
        let srcH = cgImage.height
        guard srcW > 0 && srcH > 0 else { return nil }

        let maxSide = max(srcW, srcH)
        let scale = maxSide > maxDimension ? CGFloat(maxDimension) / CGFloat(maxSide) : 1.0
        let dstW = max(1, Int((CGFloat(srcW) * scale).rounded()))
        let dstH = max(1, Int((CGFloat(srcH) * scale).rounded()))

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(
                data: nil,
                width: dstW,
                height: dstH,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              ) else {
            return nil
        }

        ctx.interpolationQuality = .high
        ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: dstW, height: dstH))
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: dstW, height: dstH))
        return ctx.makeImage()
    }

    private static func encodeBaselineJPEG(cgImage: CGImage, quality: CGFloat) -> Data? {
        let mutableData = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            mutableData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality,
            kCGImagePropertyJFIFDictionary: [
                kCGImagePropertyJFIFIsProgressive: false
            ]
        ]
        CGImageDestinationAddImage(dest, cgImage, options as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return mutableData as Data
    }
}

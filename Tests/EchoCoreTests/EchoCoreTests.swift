import XCTest
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import EchoCore

final class EchoCoreTests: XCTestCase {

    // MARK: - PathFormatter & FiiO M3U Tests

    func testArtistAlbumTrackPathAndFAT32Sanitization() {
        let profile = DeviceProfile(name: "Echo Mini", mountPath: "/tmp/echo", preset: .fiioEchoMini)
        // Decomposed NFD accented artist + FAT32 illegal chars in album & title
        let nfdArtist = "Bjo\u{0308}rk"
        let track = Track(
            id: "t1",
            sourceID: UUID(),
            filePath: "/music/t1.flac",
            fileName: "t1.flac",
            fileSize: 1024,
            modifiedAt: Date(),
            format: .flac,
            title: "All Is Full of Love?",
            artist: nfdArtist,
            albumArtist: nfdArtist,
            album: "Homogenic: Live * 1998...",
            trackNumber: 3,
            discNumber: 1
        )

        let rel = PathFormatter.relativeTrackPath(for: track, profile: profile)
        XCTAssertEqual(rel, "Music/Björk/Homogenic- Live - 1998/03 - All Is Full of Love-.flac")
        // Verify NFC normalized (not NFD)
        XCTAssertEqual(rel, rel.precomposedStringWithCanonicalMapping)
    }

    func testMultiDiscTrackPath() {
        let profile = DeviceProfile(name: "Echo", mountPath: "/tmp/echo", preset: .fiioEchoMini)
        let track = Track(
            id: "t2",
            sourceID: UUID(),
            filePath: "/music/t2.mp3",
            fileName: "t2.mp3",
            fileSize: 512,
            modifiedAt: Date(),
            format: .mp3,
            title: "Comfortably Numb",
            artist: "Pink Floyd",
            albumArtist: "Pink Floyd",
            album: "The Wall",
            trackNumber: 6,
            discNumber: 2
        )

        let rel = PathFormatter.relativeTrackPath(for: track, profile: profile)
        XCTAssertEqual(rel, "Music/Pink Floyd/The Wall/2-06 - Comfortably Numb.mp3")
    }

    func testEchoMiniM3UUsesDrivePrefixAndBackslashes() {
        let profile = DeviceProfile(name: "Echo Mini", mountPath: "/tmp/echo", preset: .fiioEchoMini)
        let track = Track(
            id: "t1",
            sourceID: UUID(),
            filePath: "/music/song.flac",
            fileName: "song.flac",
            fileSize: 1000,
            modifiedAt: Date(),
            format: .flac,
            title: "Time",
            artist: "Pink Floyd",
            albumArtist: "Pink Floyd",
            album: "Dark Side",
            trackNumber: 4,
            duration: 413
        )
        let pl = Playlist(name: "Late Night", trackIDs: [track.id])
        let rel = PathFormatter.relativeTrackPath(for: track, profile: profile)
        let m3u = PathFormatter.buildM3UContent(playlist: pl, trackRelativePaths: [(track, rel)], profile: profile)

        XCTAssertTrue(m3u.hasPrefix("#EXTM3U\r\n"))
        XCTAssertTrue(m3u.contains("#EXTINF:413,Pink Floyd - Time\r\n"))
        XCTAssertTrue(m3u.contains("D:\\Music\\Pink Floyd\\Dark Side\\04 - Time.flac\r\n"))
        XCTAssertEqual(PathFormatter.relativePlaylistPath(for: pl, profile: profile), "Late Night.m3u")
    }

    func testAndroidAndGenericRelativeM3UPaths() {
        let profile = DeviceProfile(name: "FiiO JM21", mountPath: "/tmp/jm21", preset: .fiioAndroidDAP)
        let track = Track(
            id: "t1",
            sourceID: UUID(),
            filePath: "/music/song.flac",
            fileName: "song.flac",
            fileSize: 1000,
            modifiedAt: Date(),
            format: .flac,
            title: "Time",
            artist: "Pink Floyd",
            albumArtist: "Pink Floyd",
            album: "Dark Side",
            trackNumber: 4,
            duration: 413
        )
        let pl = Playlist(name: "Mix", trackIDs: [track.id])
        let rel = PathFormatter.relativeTrackPath(for: track, profile: profile)
        let m3u = PathFormatter.buildM3UContent(playlist: pl, trackRelativePaths: [(track, rel)], profile: profile)

        // Playlists live in "Playlists/", so relative path steps up with "../"
        XCTAssertTrue(m3u.contains("../Music/Pink Floyd/Dark Side/04 - Time.flac\n"))
        XCTAssertEqual(PathFormatter.relativePlaylistPath(for: pl, profile: profile), "Playlists/Mix.m3u8")
    }

    // MARK: - Artwork Optimizer Tests

    func testPNGConversionToResizedBaselineJPEG() throws {
        let bigPNG = try XCTUnwrap(makeSyntheticPNG(width: 1400, height: 1400))
        XCTAssertFalse(ArtworkOptimizer.isAlreadyCompliantBaselineJPEG(imageData: bigPNG, maxDimension: 600, maxBytes: 300_000))

        let converted = try XCTUnwrap(ArtworkOptimizer.convertToBaselineJPEG(imageData: bigPNG, maxDimension: 600, maxBytes: 300_000))
        XCTAssertTrue(ArtworkOptimizer.isAlreadyCompliantBaselineJPEG(imageData: converted, maxDimension: 600, maxBytes: 300_000))

        let source = try XCTUnwrap(CGImageSourceCreateWithData(converted as CFData, nil))
        let props = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        XCTAssertEqual(props[kCGImagePropertyPixelWidth] as? Int, 600)
        XCTAssertEqual(props[kCGImagePropertyPixelHeight] as? Int, 600)
    }

    // MARK: - FLAC & MP3 Binary Tag Parsing + FiiO Copy Optimization Tests

    func testFLACArtworkOptimizationPreservesAudioFramesAndTags() throws {
        let tmp = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let srcFLAC = tmp.appendingPathComponent("source.flac")
        let dstFLAC = tmp.appendingPathComponent("dest.flac")
        let bigPNG = try XCTUnwrap(makeSyntheticPNG(width: 1200, height: 1200))
        let fakeAudioFrames = Data([0xFF, 0xF8, 0xAA, 0xBB, 0xCC, 0xDD, 0x11, 0x22, 0x33, 0x44])

        try buildSyntheticFLAC(
            to: srcFLAC,
            title: "Neon Pulse",
            artist: "Echo Synth",
            album: "Midnight Hi-Fi",
            trackNum: "02",
            pngArt: bigPNG,
            audioPayload: fakeAudioFrames
        )

        // Verify original parses cleanly
        let parsedOrig = AudioMetadataReader.parseFLAC(url: srcFLAC)
        XCTAssertEqual(parsedOrig.title, "Neon Pulse")
        XCTAssertEqual(parsedOrig.artist, "Echo Synth")
        XCTAssertEqual(parsedOrig.album, "Midnight Hi-Fi")
        XCTAssertEqual(parsedOrig.trackNumber, 2)
        XCTAssertEqual(parsedOrig.sampleRate, 96000)
        XCTAssertEqual(parsedOrig.bitDepth, 24)
        XCTAssertEqual(parsedOrig.artworkData, bigPNG)

        // Optimize copy to 600px Baseline JPEG
        let jpeg = try XCTUnwrap(ArtworkOptimizer.convertToBaselineJPEG(imageData: bigPNG, maxDimension: 600, maxBytes: 300_000))
        _ = try AudioFileCopyOptimizer.copyFLACWithEmbeddedJPEG(from: srcFLAC, to: dstFLAC, jpegData: jpeg)

        // Verify copied FLAC still parses tags, has Baseline JPEG art, and ends with exact audio frames
        let parsedDst = AudioMetadataReader.parseFLAC(url: dstFLAC)
        XCTAssertEqual(parsedDst.title, "Neon Pulse")
        XCTAssertEqual(parsedDst.artist, "Echo Synth")
        XCTAssertEqual(parsedDst.album, "Midnight Hi-Fi")
        let dstArt = try XCTUnwrap(parsedDst.artworkData)
        XCTAssertTrue(ArtworkOptimizer.isAlreadyCompliantBaselineJPEG(imageData: dstArt, maxDimension: 600, maxBytes: 300_000))

        let dstBytes = try Data(contentsOf: dstFLAC)
        XCTAssertTrue(dstBytes.suffix(fakeAudioFrames.count) == fakeAudioFrames)
    }

    func testMP3ID3v23RewriteStripsCommentsAndOptimizesArt() throws {
        let tmp = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let srcMP3 = tmp.appendingPathComponent("source.mp3")
        let dstMP3 = tmp.appendingPathComponent("dest.mp3")
        let bigPNG = try XCTUnwrap(makeSyntheticPNG(width: 1000, height: 1000))
        let fakeMPEG = Data([0xFF, 0xFB, 0x90, 0x64, 0x00, 0x01, 0x02, 0x03])

        try buildSyntheticMP3ID3v24(
            to: srcMP3,
            title: "Starlight",
            artist: "Muse",
            album: "Black Holes",
            comment: "Bloated comment that breaks Echo Mini",
            pngArt: bigPNG,
            mpegPayload: fakeMPEG
        )

        let jpeg = try XCTUnwrap(ArtworkOptimizer.convertToBaselineJPEG(imageData: bigPNG, maxDimension: 600, maxBytes: 300_000))
        _ = try AudioFileCopyOptimizer.copyMP3WithCleanID3v23(
            from: srcMP3,
            to: dstMP3,
            jpegData: jpeg,
            stripComments: true
        )

        let dstData = try Data(contentsOf: dstMP3)
        // Must be ID3v2.3 now
        XCTAssertEqual(dstData[3], 3)
        // Must not contain COMM frame
        XCTAssertNil(dstData.range(of: Data("COMM".utf8)))
        // Audio payload untouched
        XCTAssertTrue(dstData.suffix(fakeMPEG.count) == fakeMPEG)

        let parsed = AudioMetadataReader.parseMP3(url: dstMP3)
        XCTAssertEqual(parsed.title, "Starlight")
        XCTAssertEqual(parsed.artist, "Muse")
        XCTAssertEqual(parsed.album, "Black Holes")
        let dstArt = try XCTUnwrap(parsed.artworkData)
        XCTAssertTrue(ArtworkOptimizer.isAlreadyCompliantBaselineJPEG(imageData: dstArt, maxDimension: 600, maxBytes: 300_000))
    }

    // MARK: - End-to-End SyncEngine Test (Playlist preserves ARTIST/ALBUM/TRACK, Mirror & Additive, ._* cleanup)

    func testSyncEnginePreservesStructureForSingleTrackAndPlaylistAndMirrorRemoves() async throws {
        let tmp = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let libDir = tmp.appendingPathComponent("Library")
        let devDir = tmp.appendingPathComponent("EchoSD")
        let cacheDir = tmp.appendingPathComponent("Cache")
        try FileManager.default.createDirectory(at: libDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: devDir, withIntermediateDirectories: true)

        let artCache = ArtworkCache(cacheDirectory: cacheDir)
        let png = try XCTUnwrap(makeSyntheticPNG(width: 900, height: 900))
        let artHash = artCache.store(imageData: png)

        // Create two FLAC tracks + lyrics + one unsupported WMA track
        let f1 = libDir.appendingPathComponent("t1.flac")
        let lrc1 = libDir.appendingPathComponent("t1.lrc")
        let f2 = libDir.appendingPathComponent("t2.flac")
        let f3 = libDir.appendingPathComponent("t3.wma")

        try buildSyntheticFLAC(to: f1, title: "Track One", artist: "Artist A", album: "Album X", trackNum: "1", pngArt: png, audioPayload: Data([0xAA, 0xBB]))
        try "[00:01.00]Hello Echo".write(to: lrc1, atomically: true, encoding: .utf8)
        try buildSyntheticFLAC(to: f2, title: "Track Two", artist: "Artist B", album: "Album Y", trackNum: "5", pngArt: png, audioPayload: Data([0xCC, 0xDD]))
        try Data([0x00, 0x01, 0x02]).write(to: f3)

        // Drop fake macOS junk file onto device SD card
        try Data([0x00]).write(to: devDir.appendingPathComponent("._junk.flac"))
        try Data([0x00]).write(to: devDir.appendingPathComponent(".DS_Store"))

        let srcID = UUID()
        let t1 = Track(id: "id1", sourceID: srcID, filePath: f1.path, fileName: "t1.flac", fileSize: 200, modifiedAt: Date(), format: .flac, title: "Track One", artist: "Artist A", albumArtist: "Artist A", album: "Album X", trackNumber: 1, duration: 180, artworkHash: artHash, hasEmbeddedArtwork: true, lyricsPath: lrc1.path)
        let t2 = Track(id: "id2", sourceID: srcID, filePath: f2.path, fileName: "t2.flac", fileSize: 200, modifiedAt: Date(), format: .flac, title: "Track Two", artist: "Artist B", albumArtist: "Artist B", album: "Album Y", trackNumber: 5, duration: 210, artworkHash: artHash, hasEmbeddedArtwork: true)
        let t3 = Track(id: "id3", sourceID: srcID, filePath: f3.path, fileName: "t3.wma", fileSize: 3, modifiedAt: Date(), format: .wma, title: "Old WMA", artist: "Artist C", albumArtist: "Artist C", album: "Album Z", trackNumber: 1, duration: 100)

        let playlist = Playlist(name: "Road Trip", trackIDs: [t2.id])
        var profile = DeviceProfile(
            name: "Echo Mini",
            mountPath: devDir.path,
            preset: .fiioEchoMini,
            syncMode: .mirror,
            selectedTrackIDs: [t1.id, t3.id],
            selectedPlaylistIDs: [playlist.id]
        )

        let plan1 = SyncPlanner.buildPlan(profile: profile, allTracks: [t1, t2, t3], playlists: [playlist])
        XCTAssertEqual(plan1.tracksToCopy.count, 2)
        XCTAssertEqual(plan1.unsupportedSkipped.count, 1) // WMA skipped on Echo Mini
        XCTAssertEqual(plan1.playlistsToWrite.count, 1)

        let engine = SyncEngine(artworkCache: artCache)
        let summary1 = try await engine.execute(plan: plan1, profile: profile) { _ in }
        XCTAssertEqual(summary1.tracksCopied, 2)
        XCTAssertEqual(summary1.playlistsWritten, 1)
        XCTAssertGreaterThanOrEqual(summary1.dotFilesCleaned, 2)

        // Verify ARTIST/ALBUM/TRACK structure preserved even for single track & playlist track!
        let expectedT1 = devDir.appendingPathComponent("Music/Artist A/Album X/01 - Track One.flac")
        let expectedLRC1 = devDir.appendingPathComponent("Music/Artist A/Album X/01 - Track One.lrc")
        let expectedCover1 = devDir.appendingPathComponent("Music/Artist A/Album X/folder.jpg")
        let expectedT2 = devDir.appendingPathComponent("Music/Artist B/Album Y/05 - Track Two.flac")
        let expectedM3U = devDir.appendingPathComponent("Road Trip.m3u")

        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedT1.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedLRC1.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedCover1.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedT2.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedM3U.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: devDir.appendingPathComponent("._junk.flac").path))

        let m3uText = try String(contentsOf: expectedM3U, encoding: .utf8)
        XCTAssertTrue(m3uText.contains("D:\\Music\\Artist B\\Album Y\\05 - Track Two.flac"))

        // Now deselect t1 in Mirror mode -> verify t1, its lyrics, and empty Artist A folder are pruned!
        profile.selectedTrackIDs.remove(t1.id)
        let plan2 = SyncPlanner.buildPlan(profile: profile, allTracks: [t1, t2, t3], playlists: [playlist])
        XCTAssertEqual(plan2.tracksToCopy.count, 0)
        XCTAssertEqual(plan2.tracksToRemove.count, 1)

        let summary2 = try await engine.execute(plan: plan2, profile: profile) { _ in }
        XCTAssertEqual(summary2.tracksRemoved, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: expectedT1.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: devDir.appendingPathComponent("Music/Artist A").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedT2.path))
    }

    // MARK: - FiiO Disc, FiiO Nano, Podcasts & Multi-Destination Tests

    func testFiioDiscAndFiioNanoPresets() {
        let disc = DeviceProfile(name: "Snowsky Disc", mountPath: "/tmp/disc", preset: .fiioDisc)
        XCTAssertEqual(disc.maxArtworkDimension, 1000)
        XCTAssertEqual(disc.playlistPathStyle, .relativeForwardSlash)
        XCTAssertTrue(disc.useM3U8Extension)
        XCTAssertNil(disc.maxTrackLimit)
        XCTAssertTrue(disc.supports(.flac))
        XCTAssertTrue(disc.supports(.dsf))

        let nano = DeviceProfile(name: "Echo Nano", mountPath: "/tmp/nano", preset: .fiioNano)
        XCTAssertEqual(nano.maxArtworkDimension, 500)
        XCTAssertEqual(nano.playlistPathStyle, .echoMiniSD)
        XCTAssertEqual(nano.maxTrackLimit, 8191)
        XCTAssertTrue(nano.stripMP3Comments)
        XCTAssertTrue(nano.supports(.dsf))
        XCTAssertTrue(nano.supports(.flac))
    }

    func testPodcastRSSParsingAndSyncPath() throws {
        let rssXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
          <channel>
            <title>Hi-Fi Tape Club</title>
            <itunes:author>Snowsky Audio</itunes:author>
            <description>Weekly cassette &amp; DAP talk.</description>
            <itunes:image href="https://example.com/art.jpg" />
            <item>
              <title>Ep 42: Echo Mini vs Disc?</title>
              <guid>ep-42</guid>
              <pubDate>Tue, 10 Nov 2026 12:00:00 +0000</pubDate>
              <itunes:duration>01:12:30</itunes:duration>
              <enclosure url="https://example.com/ep42.mp3" length="45000000" type="audio/mpeg" />
            </item>
          </channel>
        </rss>
        """

        let show = try PodcastRSSParser.parse(data: Data(rssXML.utf8), showID: UUID(), feedURL: "https://example.com/feed.xml")
        XCTAssertEqual(show.title, "Hi-Fi Tape Club")
        XCTAssertEqual(show.author, "Snowsky Audio")
        XCTAssertEqual(show.artworkURL, "https://example.com/art.jpg")
        XCTAssertEqual(show.episodes.count, 1)

        let ep = try XCTUnwrap(show.episodes.first)
        XCTAssertEqual(ep.duration, 4350, accuracy: 0.5)
        XCTAssertEqual(ep.fileExtension, "mp3")

        let profile = DeviceProfile(name: "ECHO SD", mountPath: "/tmp/sd", preset: .fiioEchoMini)
        let rel = PathFormatter.relativeEpisodePath(for: ep, profile: profile)
        XCTAssertEqual(rel, "Podcasts/Hi-Fi Tape Club/2026-11-10 - Ep 42- Echo Mini vs Disc-.mp3")
    }

    func testMultiDestinationSyncTracksAndPodcastsSeparately() async throws {
        let tmp = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let libDir = tmp.appendingPathComponent("Lib")
        let destA = tmp.appendingPathComponent("ECHO")
        let destB = tmp.appendingPathComponent("ECHO_SD")
        let cacheDir = tmp.appendingPathComponent("Cache")
        for d in [libDir, destA, destB, cacheDir] {
            try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        }

        let artCache = ArtworkCache(cacheDirectory: cacheDir)
        let png = try XCTUnwrap(makeSyntheticPNG(width: 600, height: 600))
        let artHash = artCache.store(imageData: png)

        let epFile = libDir.appendingPathComponent("ep1.mp3")
        try buildSyntheticMP3ID3v24(to: epFile, title: "Podcast Ep 1", artist: "Host", album: "PodShow", comment: "", pngArt: png, mpegPayload: Data([0xFF, 0xFB, 0x90, 0x64]))

        let showID = UUID()
        let ep = PodcastEpisode(
            id: "ep1-id",
            showID: showID,
            showTitle: "PodShow",
            showAuthor: "Host",
            guid: "g1",
            title: "Podcast Ep 1",
            publishedAt: Date(timeIntervalSince1970: 1_762_732_800),
            duration: 600,
            audioURL: "https://example.com/ep1.mp3",
            fileSize: 500,
            fileExtension: "mp3",
            localFilePath: epFile.path,
            artworkHash: artHash
        )
        let show = PodcastShow(id: showID, title: "PodShow", author: "Host", feedURL: "https://example.com/rss", artworkHash: artHash, episodes: [ep])

        let profileA = DeviceProfile(name: "ECHO", mountPath: destA.path, preset: .fiioEchoMini, selectedPodcastShowIDs: [showID])
        let profileB = DeviceProfile(name: "ECHO SD", mountPath: destB.path, preset: .fiioDisc)

        let engine = SyncEngine(artworkCache: artCache)
        let planA = SyncPlanner.buildPlan(profile: profileA, allTracks: [], playlists: [], podcasts: [show])
        let planB = SyncPlanner.buildPlan(profile: profileB, allTracks: [], playlists: [], podcasts: [show])

        XCTAssertEqual(planA.episodesToCopy.count, 1)
        XCTAssertEqual(planB.episodesToCopy.count, 0)

        let summaryA = try await engine.execute(plan: planA, profile: profileA) { _ in }
        XCTAssertEqual(summaryA.episodesCopied, 1)
        XCTAssertTrue(summaryA.finalSyncedEpisodeIDs.contains(ep.id))
    }

    func testOPMLParsingExtractsFeeds() {
        let opml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="2.0">
          <body>
            <outline text="Tech" title="Tech">
              <outline type="rss" text="Darknet Diaries" xmlUrl="https://feeds.megaphone.fm/darknetdiaries" />
              <outline type="rss" title="ATP" xmlUrl="https://atp.fm/episodes?format=rss" />
            </outline>
          </body>
        </opml>
        """
        let feeds = PodcastService.parseOPMLFeedURLs(data: Data(opml.utf8))
        XCTAssertEqual(feeds.count, 2)
        XCTAssertEqual(feeds[0].feedURL, "https://feeds.megaphone.fm/darknetdiaries")
        XCTAssertEqual(feeds[1].title, "ATP")
    }

    func testPerPodcastEpisodesToKeepRotatesOutOlderEpisodes() async throws {
        let tmp = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let libDir = tmp.appendingPathComponent("Lib")
        let destDir = tmp.appendingPathComponent("ECHO_SD")
        let cacheDir = tmp.appendingPathComponent("Cache")
        for d in [libDir, destDir, cacheDir] {
            try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        }

        let artCache = ArtworkCache(cacheDirectory: cacheDir)
        let png = try XCTUnwrap(makeSyntheticPNG(width: 500, height: 500))
        let artHash = artCache.store(imageData: png)
        let showID = UUID()

        func makeEp(_ id: String, _ title: String, day: Int) throws -> PodcastEpisode {
            let file = libDir.appendingPathComponent("\(id).mp3")
            try buildSyntheticMP3ID3v24(to: file, title: title, artist: "Host", album: "Daily Pod", comment: "", pngArt: png, mpegPayload: Data([0xFF, 0xFB, 0x90, 0x64]))
            return PodcastEpisode(
                id: id,
                showID: showID,
                showTitle: "Daily Pod",
                showAuthor: "Host",
                guid: id,
                title: title,
                publishedAt: Date(timeIntervalSince1970: TimeInterval(1_762_000_000 + day * 86400)),
                duration: 300,
                audioURL: "https://example.com/\(id).mp3",
                fileSize: 500,
                fileExtension: "mp3",
                localFilePath: file.path,
                artworkHash: artHash
            )
        }

        let ep1 = try makeEp("ep1", "Episode 1", day: 1)
        let ep2 = try makeEp("ep2", "Episode 2", day: 2)
        let ep3 = try makeEp("ep3", "Episode 3", day: 3)

        // Keep only 2 newest episodes — even in Additive mode!
        var show = PodcastShow(id: showID, title: "Daily Pod", author: "Host", feedURL: "https://example.com/rss", artworkHash: artHash, episodesToKeep: 2, episodes: [ep1, ep2])
        let profile = DeviceProfile(name: "ECHO SD", mountPath: destDir.path, preset: .fiioEchoMini, syncMode: .additive, selectedPodcastShowIDs: [showID])
        let engine = SyncEngine(artworkCache: artCache)

        // Sync #1: copies ep1 and ep2
        let plan1 = SyncPlanner.buildPlan(profile: profile, allTracks: [], playlists: [], podcasts: [show])
        XCTAssertEqual(plan1.episodesToCopy.count, 2)
        let summary1 = try await engine.execute(plan: plan1, profile: profile) { _ in }
        XCTAssertEqual(summary1.episodesCopied, 2)

        // New episode ep3 arrives! Sync #2 should copy ep3 AND automatically throw out oldest ep1!
        show.episodes = [ep1, ep2, ep3]
        let plan2 = SyncPlanner.buildPlan(profile: profile, allTracks: [], playlists: [], podcasts: [show])
        XCTAssertEqual(plan2.episodesToCopy.map(\.episode.id), ["ep3"])
        XCTAssertEqual(plan2.episodesToRemove.map(\.episodeID), ["ep1"])

        let summary2 = try await engine.execute(plan: plan2, profile: profile) { _ in }
        XCTAssertEqual(summary2.episodesCopied, 1)
        XCTAssertEqual(summary2.episodesRemoved, 1)
        XCTAssertEqual(summary2.finalSyncedEpisodeIDs, Set(["ep2", "ep3"]))
    }

    // MARK: - SQLite Persistence Test

    func testSQLiteRoundTripPersistence() throws {
        let tmp = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let dbURL = tmp.appendingPathComponent("test.sqlite")
        let src = LibrarySource(name: "NAS Music", path: "/Volumes/NAS/Music", isNetworkVolume: true, trackCount: 1)
        let track = Track(id: "abc", sourceID: src.id, filePath: "/Volumes/NAS/Music/a.flac", fileName: "a.flac", fileSize: 999, modifiedAt: Date(), format: .flac, title: "Song", artist: "Band", albumArtist: "Band", album: "Record")
        let playlist = Playlist(name: "Favorites", trackIDs: [track.id])
        let device = DeviceProfile(name: "FiiO Echo Mini", volumeUUID: "UUID-123", mountPath: "/Volumes/ECHO", preset: .fiioEchoMini, selectedPlaylistIDs: [playlist.id])

        do {
            let db = try EchoDatabase(dbURL: dbURL)
            db.saveSource(src)
            db.replaceTracks(forSourceID: src.id, tracks: [track])
            db.savePlaylist(playlist)
            db.saveDevice(device)
            db.setSetting("activeDeviceID", value: device.id.uuidString)
        }

        // Reopen DB from disk and verify everything survived
        let reopened = try EchoDatabase(dbURL: dbURL)
        XCTAssertEqual(reopened.loadSources().count, 1)
        XCTAssertEqual(reopened.loadAllTracks().first?.title, "Song")
        XCTAssertEqual(reopened.loadPlaylists().first?.name, "Favorites")
        XCTAssertEqual(reopened.loadDevices().first?.selectedPlaylistIDs, [playlist.id])
        XCTAssertEqual(reopened.getSetting("activeDeviceID"), device.id.uuidString)
    }

    // MARK: - Test Fixtures Helpers

    private func makeTempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("EchoTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeSyntheticPNG(width: Int, height: Int) -> Data? {
        guard let cs = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        ctx.setFillColor(CGColor(red: 0.12, green: 0.92, blue: 0.61, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let img = ctx.makeImage() else { return nil }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, img, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }

    private func buildSyntheticFLAC(
        to url: URL,
        title: String,
        artist: String,
        album: String,
        trackNum: String,
        pngArt: Data,
        audioPayload: Data
    ) throws {
        var out = Data("fLaC".utf8)

        // Block 0: STREAMINFO (34 bytes) — 96kHz, 2ch, 24-bit, 960000 samples (10s)
        var si = [UInt8](repeating: 0, count: 34)
        // sampleRate = 96000 (0x17700): 20 bits across bytes 10, 11, 12[7:4]
        si[10] = 0x17
        si[11] = 0x70
        // channels = 2 -> (2-1)=1 in bits [3:1], bps=24 -> (24-1)=23 (0b10111): top bit 1 in byte12[0], low 4 bits 0111 in byte13[7:4]
        si[12] = 0x03
        si[13] = 0x70
        // totalSamples = 960000 (0x0EA600) in bytes 14..17
        si[15] = 0x0E
        si[16] = 0xA6
        si[17] = 0x00
        appendFLACBlock(&out, type: 0, isLast: false, payload: Data(si))

        // Block 4: VORBIS_COMMENT
        var vc = Data()
        let vendor = Data("EchoTest".utf8)
        appendLE32(&vc, UInt32(vendor.count)); vc.append(vendor)
        let tags = ["TITLE=\(title)", "ARTIST=\(artist)", "ALBUM=\(album)", "TRACKNUMBER=\(trackNum)"]
        appendLE32(&vc, UInt32(tags.count))
        for tag in tags {
            let td = Data(tag.utf8)
            appendLE32(&vc, UInt32(td.count)); vc.append(td)
        }
        appendFLACBlock(&out, type: 4, isLast: false, payload: vc)

        // Block 6: PICTURE (PNG)
        var pic = Data()
        let mime = Data("image/png".utf8)
        appendBE32(&pic, 3)
        appendBE32(&pic, UInt32(mime.count)); pic.append(mime)
        appendBE32(&pic, 0)
        appendBE32(&pic, 0); appendBE32(&pic, 0); appendBE32(&pic, 0); appendBE32(&pic, 0)
        appendBE32(&pic, UInt32(pngArt.count)); pic.append(pngArt)
        appendFLACBlock(&out, type: 6, isLast: true, payload: pic)

        out.append(audioPayload)
        try out.write(to: url)
    }

    private func buildSyntheticMP3ID3v24(
        to url: URL,
        title: String,
        artist: String,
        album: String,
        comment: String,
        pngArt: Data,
        mpegPayload: Data
    ) throws {
        var frames = Data()

        func addTextFrame(_ id: String, _ text: String) {
            var body = Data([0x03]) // UTF-8 (ID3v2.4)
            body.append(Data(text.utf8))
            frames.append(Data(id.utf8))
            appendSynchsafe(&frames, body.count)
            frames.append(contentsOf: [0, 0])
            frames.append(body)
        }

        addTextFrame("TIT2", title)
        addTextFrame("TPE1", artist)
        addTextFrame("TALB", album)

        // COMM frame
        var comm = Data([0x03, 0x65, 0x6E, 0x67, 0x00])
        comm.append(Data(comment.utf8))
        frames.append(Data("COMM".utf8))
        appendSynchsafe(&frames, comm.count)
        frames.append(contentsOf: [0, 0])
        frames.append(comm)

        // APIC frame (PNG)
        var apic = Data([0x00])
        apic.append(Data("image/png".utf8))
        apic.append(0x00)
        apic.append(0x03)
        apic.append(0x00)
        apic.append(pngArt)
        frames.append(Data("APIC".utf8))
        appendSynchsafe(&frames, apic.count)
        frames.append(contentsOf: [0, 0])
        frames.append(apic)

        var out = Data([0x49, 0x44, 0x33, 0x04, 0x00, 0x00]) // ID3v2.4
        appendSynchsafe(&out, frames.count)
        out.append(frames)
        out.append(mpegPayload)
        try out.write(to: url)
    }

    private func appendFLACBlock(_ out: inout Data, type: UInt8, isLast: Bool, payload: Data) {
        let b0 = (isLast ? UInt8(0x80) : UInt8(0x00)) | (type & 0x7F)
        let len = payload.count
        out.append(contentsOf: [b0, UInt8((len >> 16) & 0xFF), UInt8((len >> 8) & 0xFF), UInt8(len & 0xFF)])
        out.append(payload)
    }

    private func appendLE32(_ d: inout Data, _ v: UInt32) {
        d.append(contentsOf: [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8((v >> 24) & 0xFF)])
    }

    private func appendBE32(_ d: inout Data, _ v: UInt32) {
        d.append(contentsOf: [UInt8((v >> 24) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)])
    }

    private func appendSynchsafe(_ d: inout Data, _ v: Int) {
        d.append(contentsOf: [
            UInt8((v >> 21) & 0x7F),
            UInt8((v >> 14) & 0x7F),
            UInt8((v >> 7) & 0x7F),
            UInt8(v & 0x7F)
        ])
    }
}

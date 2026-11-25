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

    // MARK: - 2-Factor Format Labels, Play Counters & Online Popularity Tests

    func testTwoFactorFormatLabels() {
        let flac16 = Track(
            id: "f1", sourceID: UUID(), filePath: "/m/1.flac", fileName: "1.flac",
            fileSize: 1000, modifiedAt: Date(), format: .flac,
            title: "T", artist: "A", albumArtist: "A", album: "AL",
            sampleRate: 44_100, bitDepth: 16
        )
        XCTAssertEqual(flac16.formatPrimaryLabel, "FLAC")
        XCTAssertEqual(flac16.formatDetailLabel, "16b/44.1kHz")

        let flac24 = Track(
            id: "f2", sourceID: UUID(), filePath: "/m/2.flac", fileName: "2.flac",
            fileSize: 1000, modifiedAt: Date(), format: .flac,
            title: "T", artist: "A", albumArtist: "A", album: "AL",
            sampleRate: 96_000, bitDepth: 24
        )
        XCTAssertEqual(flac24.formatPrimaryLabel, "FLAC")
        XCTAssertEqual(flac24.formatDetailLabel, "24b/96kHz")

        let mp3 = Track(
            id: "m1", sourceID: UUID(), filePath: "/m/3.mp3", fileName: "3.mp3",
            fileSize: 1000, modifiedAt: Date(), format: .mp3,
            title: "T", artist: "A", albumArtist: "A", album: "AL",
            bitrate: 320
        )
        XCTAssertEqual(mp3.formatPrimaryLabel, "MP3")
        XCTAssertEqual(mp3.formatDetailLabel, "320k")
    }

    func testTrackStatsPersistAcrossTrackReindexing() throws {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("echo-stats-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let db = try EchoDatabase(dbURL: tmpDir.appendingPathComponent("test.sqlite"))
        let sourceID = UUID()
        let track = Track(
            id: "track-abc", sourceID: sourceID, filePath: "/m/a.flac", fileName: "a.flac",
            fileSize: 2048, modifiedAt: Date(), format: .flac,
            title: "Here Comes the Sun", artist: "The Beatles", albumArtist: "The Beatles", album: "Abbey Road"
        )
        db.replaceTracks(forSourceID: sourceID, tracks: [track])

        let savedStats = TrackStats(
            trackID: track.id,
            userPlayCount: 7,
            lastPlayedAt: Date(),
            onlinePopularity: 89,
            onlinePlayCount: 886_736,
            onlineSource: "deezer",
            onlineFetchedAt: Date()
        )
        db.saveTrackStats(savedStats)

        // Simulate full re-index replacing track rows for this source
        db.replaceTracks(forSourceID: sourceID, tracks: [track])

        let reloaded = db.loadAllTrackStats()
        XCTAssertEqual(reloaded[track.id]?.userPlayCount, 7)
        XCTAssertEqual(reloaded[track.id]?.onlinePopularity, 89)
        XCTAssertEqual(reloaded[track.id]?.popularityBars, 5)
    }

    func testOnlinePopularityScoringAndTitleMatching() {
        XCTAssertEqual(OnlinePopularityService.scoreFromDeezerRank(886_736), 89)
        XCTAssertEqual(OnlinePopularityService.scoreFromDeezerRank(182_028), 18)
        XCTAssertEqual(OnlinePopularityService.scoreFromLastFMPlaycount(10_000_000), 88)

        XCTAssertEqual(
            OnlinePopularityService.normalizeTitleForMatching("Here Comes The Sun (Remastered 2009)"),
            "here comes the sun"
        )
        XCTAssertEqual(
            OnlinePopularityService.normalizeTitleForMatching("Come Together - 2019 Mix [Deluxe Edition]"),
            "come together 2019 mix"
        )

        let src = UUID()
        let local = [
            Track(id: "t1", sourceID: src, filePath: "/1.flac", fileName: "1.flac", fileSize: 1, modifiedAt: Date(), format: .flac,
                  title: "Here Comes the Sun", artist: "The Beatles", albumArtist: "The Beatles", album: "Abbey Road", trackNumber: 7),
            Track(id: "t2", sourceID: src, filePath: "/2.flac", fileName: "2.flac", fileSize: 1, modifiedAt: Date(), format: .flac,
                  title: "Untitled Bonus Track", artist: "The Beatles", albumArtist: "The Beatles", album: "Abbey Road", trackNumber: 17)
        ]
        let remote = [
            OnlinePopularityService.RemoteTrackCandidate(title: "Here Comes The Sun (Remastered 2009)", shortTitle: "Here Comes The Sun", trackPosition: 7, discNumber: 1, rank: 886_736),
            OnlinePopularityService.RemoteTrackCandidate(title: "Her Majesty (Remastered 2009)", shortTitle: "Her Majesty", trackPosition: 17, discNumber: 1, rank: 182_028)
        ]
        let matched = OnlinePopularityService.matchRemoteTracks(remote, to: local)
        let byID = Dictionary(uniqueKeysWithValues: matched.map { ($0.trackID, $0) })
        XCTAssertEqual(byID["t1"]?.popularity, 89)
        XCTAssertEqual(byID["t2"]?.popularity, 18) // matched via trackPosition fallback
    }

    func testTrackArrivalDateAndAlbumLatestArrivalDate() {
        let src = UUID()
        let oldMod = Date(timeIntervalSince1970: 1_600_000_000)
        let recentDownload = Date(timeIntervalSince1970: 1_795_000_000)

        let t1 = Track(id: "a1", sourceID: src, filePath: "/a1.flac", fileName: "a1.flac", fileSize: 100,
                       modifiedAt: oldMod, addedAt: recentDownload, format: .flac,
                       title: "Track 1", artist: "Artist", albumArtist: "Artist", album: "Album", year: 2026)
        let t2 = Track(id: "a2", sourceID: src, filePath: "/a2.flac", fileName: "a2.flac", fileSize: 100,
                       modifiedAt: oldMod, addedAt: nil, format: .flac,
                       title: "Track 2", artist: "Artist", albumArtist: "Artist", album: "Album", year: 2026)

        XCTAssertEqual(t1.arrivalDate, recentDownload)
        XCTAssertEqual(t2.arrivalDate, oldMod)

        let album = AlbumGroup(id: "k", title: "Album", artist: "Artist", year: 2026, tracks: [t1, t2])
        XCTAssertEqual(album.latestArrivalDate, recentDownload)
    }

    // MARK: - Lidarr Client URL & Payload Builder Tests

    func testLidarrURLNormalizationAndAddAlbumPayload() throws {
        XCTAssertEqual(LidarrClient.normalizeBaseURL("192.168.1.50:8686/")?.absoluteString, "http://192.168.1.50:8686")
        XCTAssertEqual(LidarrClient.normalizeBaseURL("https://lidarr.home.arpa/api/v1/")?.absoluteString, "https://lidarr.home.arpa")
        XCTAssertNil(LidarrClient.normalizeBaseURL("   "))

        let lookupJSON: [String: Any] = [
            "foreignAlbumId": "mb-album-123",
            "title": "Abbey Road",
            "releases": [["foreignReleaseId": "rel-1", "monitored": true]],
            "artist": [
                "foreignArtistId": "mb-artist-456",
                "artistName": "The Beatles"
            ]
        ]
        let lookupData = try JSONSerialization.data(withJSONObject: lookupJSON)
        let cfg = LidarrConfig(
            isEnabled: true,
            baseURL: "http://nas.local:8686",
            apiKey: "secret-key",
            rootFolderPath: "/music",
            qualityProfileId: 2,
            metadataProfileId: 1,
            searchOnAdd: true
        )

        let payload = try LidarrClient.buildAddAlbumPayload(fromLookupData: lookupData, config: cfg)
        let decoded = try XCTUnwrap(JSONSerialization.jsonObject(with: payload) as? [String: Any])
        XCTAssertEqual(decoded["monitored"] as? Bool, true)
        XCTAssertEqual(decoded["foreignAlbumId"] as? String, "mb-album-123")
        let addOpts = try XCTUnwrap(decoded["addOptions"] as? [String: Any])
        XCTAssertEqual(addOpts["searchForNewAlbum"] as? Bool, true)

        let artist = try XCTUnwrap(decoded["artist"] as? [String: Any])
        XCTAssertEqual(artist["rootFolderPath"] as? String, "/music")
        XCTAssertEqual(artist["qualityProfileId"] as? Int, 2)
        XCTAssertEqual(artist["metadataProfileId"] as? Int, 1)
        let artistAddOpts = try XCTUnwrap(artist["addOptions"] as? [String: Any])
        // Ensures ordering a single album doesn't accidentally download the artist's entire discography
        XCTAssertEqual(artistAddOpts["monitor"] as? String, "none")
        XCTAssertEqual(artistAddOpts["searchForMissingAlbums"] as? Bool, false)
    }

    func testLidarrQueueStatusReconciliationLifecycle() {
        let now = Date()
        let order1 = LidarrTrackedOrder(
            id: "o1",
            albumTitle: "Dark Side of the Moon",
            artistName: "Pink Floyd",
            lidarrAlbumID: 42,
            orderedAt: now.addingTimeInterval(-30),
            phase: .searching
        )
        let order2 = LidarrTrackedOrder(
            id: "o2",
            albumTitle: "Abbey Road",
            artistName: "The Beatles",
            lidarrAlbumID: 99,
            orderedAt: now.addingTimeInterval(-120),
            phase: .downloading,
            progress: 0.75
        )

        let activeQueue = [
            LidarrQueueItem(
                id: 1,
                albumId: 42,
                title: "Pink Floyd - Dark Side of the Moon [FLAC]",
                artistName: "Pink Floyd",
                albumTitle: "Dark Side of the Moon",
                status: "downloading",
                trackedDownloadState: "downloading",
                size: 400_000_000,
                sizeleft: 100_000_000,
                timeleft: "00:01:20",
                qualityName: "FLAC"
            )
        ]

        let history = [
            LidarrHistoryItem(
                id: 500,
                albumId: 99,
                albumTitle: "Abbey Road",
                artistName: "The Beatles",
                sourceTitle: "Abbey Road FLAC",
                eventType: "trackFileImported",
                qualityName: "FLAC",
                date: now.addingTimeInterval(-10)
            )
        ]

        let (updated, newlyCompleted) = LidarrClient.reconcileTrackedOrders([order1, order2], queue: activeQueue, history: history, now: now)
        let u1 = updated.first { $0.id == "o1" }
        let u2 = updated.first { $0.id == "o2" }

        XCTAssertEqual(u1?.phase, .downloading)
        XCTAssertEqual(u1?.progress ?? 0, 0.75, accuracy: 0.01)
        XCTAssertEqual(u1?.qualityName, "FLAC")

        XCTAssertEqual(u2?.phase, .completed)
        XCTAssertEqual(u2?.progress ?? 0, 1.0, accuracy: 0.001)
        XCTAssertEqual(newlyCompleted.map(\.id), ["o2"])
    }

    func testArtistNameParserSplitsListsAndProtectsBandNames() {
        XCTAssertEqual(
            ArtistNameParser.artistNames("Alan Walker, Noah Cyrus, Digital Farm Animals, Juliander"),
            ["Alan Walker", "Noah Cyrus", "Digital Farm Animals", "Juliander"]
        )
        XCTAssertEqual(
            ArtistNameParser.artistNames("112 feat. Mase & Notorious B.I.G."),
            ["112", "Mase", "Notorious B.I.G."]
        )
        XCTAssertEqual(
            ArtistNameParser.artistNames("David Guetta; Sia / Afrojack"),
            ["David Guetta", "Sia", "Afrojack"]
        )
        XCTAssertEqual(
            ArtistNameParser.artistNames("Earth, Wind & Fire"),
            ["Earth, Wind & Fire"]
        )
        XCTAssertEqual(
            ArtistNameParser.artistNames("Bruce Springsteen & The E Street Band"),
            ["Bruce Springsteen & The E Street Band"]
        )
        XCTAssertEqual(
            ArtistNameParser.artistNames("Tyler, The Creator"),
            ["Tyler, The Creator"]
        )
        XCTAssertEqual(
            ArtistNameParser.artistNames("AC/DC"),
            ["AC/DC"]
        )
        let segs = ArtistNameParser.splitSegments("Kygo x Whitney Houston")
        XCTAssertEqual(segs.map(\.name), ["Kygo", "Whitney Houston"])
        XCTAssertEqual(segs.first?.trailingSeparator, " x ")
    }

    @MainActor
    func testEqualPowerCrossfadeGainsAndShortTrackClamping() {
        let start = AudioPlayerEngine.equalPowerGains(progress: 0.0)
        XCTAssertEqual(start.outgoing, 1.0, accuracy: 0.0001)
        XCTAssertEqual(start.incoming, 0.0, accuracy: 0.0001)

        let mid = AudioPlayerEngine.equalPowerGains(progress: 0.5)
        XCTAssertEqual(mid.outgoing * mid.outgoing + mid.incoming * mid.incoming, 1.0, accuracy: 0.0001)
        XCTAssertGreaterThan(mid.outgoing, 0.70)
        XCTAssertGreaterThan(mid.incoming, 0.70)

        let end = AudioPlayerEngine.equalPowerGains(progress: 1.0)
        XCTAssertEqual(end.outgoing, 0.0, accuracy: 0.0001)
        XCTAssertEqual(end.incoming, 1.0, accuracy: 0.0001)

        // Short 10s track caps a 12s crossfade to 4s (40%)
        XCTAssertEqual(AudioPlayerEngine.effectiveCrossfadeDuration(configured: 12, trackDuration: 10), 4.0, accuracy: 0.001)
        // Normal 240s track keeps full configured 5s crossfade
        XCTAssertEqual(AudioPlayerEngine.effectiveCrossfadeDuration(configured: 5, trackDuration: 240), 5.0, accuracy: 0.001)
    }

    func testVirtualIPhonePresetAndWirelessManifestVersioning() {
        let dev = DeviceProfile(name: "iPhone", mountPath: "echo-wireless://iphone", preset: .iphoneWireless)
        XCTAssertTrue(dev.isVirtualWireless)
        XCTAssertTrue(dev.isConnected)
        XCTAssertEqual(dev.wirelessSyncToken?.count, 6)
        XCTAssertTrue(dev.supports(.flac))
        XCTAssertTrue(dev.supports(.alac))
        XCTAssertFalse(dev.supports(.dsf))

        let t1 = WirelessSyncTrack(from: Track(
            id: "t1", sourceID: UUID(), filePath: "/music/a.flac", fileName: "a.flac",
            fileSize: 1000, modifiedAt: Date(timeIntervalSince1970: 1_700_000_000),
            format: .flac, title: "Song A", artist: "Artist", albumArtist: "Artist", album: "Album"
        ))
        let feed = WirelessSyncPodcastFeed(
            from: PodcastShow(title: "Darknet Diaries", author: "Jack Rhysider", feedURL: "https://feeds.megaphone.fm/darknetdiaries", episodesToKeep: 5),
            isSelectedForAutoSync: true
        )
        let v1 = WirelessDeviceSnapshot.computeManifestVersion(syncMode: "mirror", tracks: [t1], playlists: [], episodes: [], podcastFeeds: [])
        let v2 = WirelessDeviceSnapshot.computeManifestVersion(syncMode: "mirror", tracks: [t1], playlists: [], episodes: [], podcastFeeds: [])
        let v3 = WirelessDeviceSnapshot.computeManifestVersion(syncMode: "additive", tracks: [t1], playlists: [], episodes: [], podcastFeeds: [])
        let v4 = WirelessDeviceSnapshot.computeManifestVersion(syncMode: "mirror", tracks: [t1], playlists: [], episodes: [], podcastFeeds: [feed])
        XCTAssertEqual(v1, v2)
        XCTAssertNotEqual(v1, v3)
        XCTAssertNotEqual(v1, v4)

        let ep = PodcastEpisode(
            id: PodcastRSSParser.stableEpisodeID(showID: UUID(), guidOrURL: "ep-guid-1"),
            showID: UUID(),
            showTitle: "Darknet Diaries",
            showAuthor: "Jack Rhysider",
            guid: "ep-guid-1",
            title: "Ep 1",
            audioURL: "https://example.com/ep1.mp3",
            fileSize: 12345
        )
        let wireEp = WirelessSyncEpisode(from: ep)
        XCTAssertEqual(wireEp.guid, "ep-guid-1")
        XCTAssertEqual(wireEp.audioURL, "https://example.com/ep1.mp3")

        // Verify WirelessLibraryCatalog full-library search marks already-synced tracks accurately
        let tr1 = Track(id: "t1", sourceID: UUID(), filePath: "/m/1.flac", fileName: "1.flac", fileSize: 100, modifiedAt: Date(), format: .flac, title: "Born to Run", artist: "Bruce Springsteen", albumArtist: "Bruce Springsteen", album: "Born to Run")
        let tr2 = Track(id: "t2", sourceID: UUID(), filePath: "/m/2.flac", fileName: "2.flac", fileSize: 100, modifiedAt: Date(), format: .flac, title: "Thunder Road", artist: "Bruce Springsteen", albumArtist: "Bruce Springsteen", album: "Born to Run")
        let alb = AlbumGroup(id: tr1.albumKey, title: "Born to Run", artist: "Bruce Springsteen", year: 1975, tracks: [tr1, tr2])
        let catalog = WirelessLibraryCatalog(tracks: [tr1, tr2], albums: [alb])
        let res = catalog.search(query: "springsteen", syncedTrackIDs: ["t1"])
        XCTAssertEqual(res.albums.count, 1)
        XCTAssertFalse(res.albums[0].isSelectedForSync) // only 1 of 2 tracks synced
        XCTAssertEqual(res.tracks.count, 2)
        XCTAssertEqual(res.tracks.first(where: { $0.id == "t1" })?.isSelectedForSync, true)
        XCTAssertEqual(res.tracks.first(where: { $0.id == "t2" })?.isSelectedForSync, false)
    }

    func testUnifiedAlbumGroupingAndMajorityOrVariousArtistsResolution() {
        let src = UUID()
        func makeTrack(_ id: String, artist: String, albumArtist: String, album: String, num: Int) -> Track {
            Track(
                id: id, sourceID: src, filePath: "/m/\(id).flac", fileName: "\(id).flac",
                fileSize: 1000, modifiedAt: Date(), format: .flac,
                title: "Track \(num)", artist: artist, albumArtist: albumArtist, album: album, trackNumber: num
            )
        }

        // 1. Compilation with mismatched albumArtist tags -> MUST still be 1 album, showing "Various Artists"
        let compilation = [
            makeTrack("c1", artist: "Bruce Springsteen", albumArtist: "Bruce Springsteen", album: "2000s Rock Essentials", num: 1),
            makeTrack("c2", artist: "Coldplay", albumArtist: "Bruce Springsteen", album: "2000s Rock Essentials", num: 2),
            makeTrack("c3", artist: "Foo Fighters", albumArtist: "Foo Fighters", album: "2000s Rock Essentials", num: 3),
            makeTrack("c4", artist: "Green Day", albumArtist: "", album: "2000s Rock Essentials", num: 4),
            makeTrack("c5", artist: "Oasis", albumArtist: "Various Artists", album: "2000s Rock Essentials", num: 5)
        ]
        let compAlbums = AlbumGroup.buildGroups(from: compilation)
        XCTAssertEqual(compAlbums.count, 1)
        XCTAssertEqual(compAlbums[0].tracks.count, 5)
        XCTAssertEqual(compAlbums[0].artist, "Various Artists")

        // 2. Album where one artist appears on >= half the tracks (2 of 4, others distinct), even with wrong/mixed albumArtist
        let halfMajority = [
            makeTrack("h1", artist: "Pink Floyd", albumArtist: "Various Artists", album: "Echoes Mix", num: 1),
            makeTrack("h2", artist: "Pink Floyd", albumArtist: "Pink Floyd", album: "Echoes Mix", num: 2),
            makeTrack("h3", artist: "Roger Waters", albumArtist: "Roger Waters", album: "Echoes Mix", num: 3),
            makeTrack("h4", artist: "Clare Torry", albumArtist: "", album: "Echoes Mix", num: 4)
        ]
        let halfAlbums = AlbumGroup.buildGroups(from: halfMajority)
        XCTAssertEqual(halfAlbums.count, 1)
        XCTAssertEqual(halfAlbums[0].tracks.count, 4)
        XCTAssertEqual(halfAlbums[0].artist, "Pink Floyd")

        // 3. Album where more than half of tracks have different artists (2 of 5 by same artist -> 3 of 5 different) -> Various Artists
        let minority = [
            makeTrack("m1", artist: "Oasis", albumArtist: "Oasis", album: "Britpop Hits", num: 1),
            makeTrack("m2", artist: "Oasis", albumArtist: "Oasis", album: "Britpop Hits", num: 2),
            makeTrack("m3", artist: "Blur", albumArtist: "Oasis", album: "Britpop Hits", num: 3),
            makeTrack("m4", artist: "Pulp", albumArtist: "Oasis", album: "Britpop Hits", num: 4),
            makeTrack("m5", artist: "Suede", albumArtist: "Oasis", album: "Britpop Hits", num: 5)
        ]
        let minorityAlbums = AlbumGroup.buildGroups(from: minority)
        XCTAssertEqual(minorityAlbums.count, 1)
        XCTAssertEqual(minorityAlbums[0].artist, "Various Artists")

        // 4. Collaboration album where main artist appears on every track with different guests
        let collab = [
            makeTrack("k1", artist: "Kygo feat. Imagine Dragons", albumArtist: "", album: "Golden Hour", num: 1),
            makeTrack("k2", artist: "Kygo feat. OneRepublic", albumArtist: "", album: "Golden Hour", num: 2),
            makeTrack("k3", artist: "Kygo, Selena Gomez", albumArtist: "", album: "Golden Hour", num: 3),
            makeTrack("k4", artist: "Kygo feat. Ellie Goulding", albumArtist: "", album: "Golden Hour", num: 4)
        ]
        let collabAlbums = AlbumGroup.buildGroups(from: collab)
        XCTAssertEqual(collabAlbums.count, 1)
        XCTAssertEqual(collabAlbums[0].artist, "Kygo")

        // 5. Exact 50/50 split between two artists with no advisory albumArtist -> Various Artists
        let tieNoAdvisory = [
            makeTrack("s1", artist: "Artist A", albumArtist: "", album: "Split EP", num: 1),
            makeTrack("s2", artist: "Artist B", albumArtist: "", album: "Split EP", num: 2)
        ]
        XCTAssertEqual(AlbumGroup.buildGroups(from: tieNoAdvisory).first?.artist, "Various Artists")

        // 6. SyncPlanner keeps ALL tracks of a VA album inside ONE "Various Artists/<Album>/" folder (never splits per track artist!)
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("echo-va-sync-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let f1 = tmp.appendingPathComponent("1.mp3")
        let f2 = tmp.appendingPathComponent("2.mp3")
        let f3 = tmp.appendingPathComponent("3.mp3")
        try? Data([0xFF, 0xFB]).write(to: f1)
        try? Data([0xFF, 0xFB]).write(to: f2)
        try? Data([0xFF, 0xFB]).write(to: f3)
        let vaTracks = [
            Track(id: "va1", sourceID: src, filePath: f1.path, fileName: "1.mp3", fileSize: 2, modifiedAt: Date(), format: .mp3, title: "Someone You Loved", artist: "Lewis Capaldi", albumArtist: "", album: "Road Trip Hits", trackNumber: 1),
            Track(id: "va2", sourceID: src, filePath: f2.path, fileName: "2.mp3", fileSize: 2, modifiedAt: Date(), format: .mp3, title: "Yellow", artist: "Coldplay", albumArtist: "Coldplay", album: "Road Trip Hits", trackNumber: 2),
            Track(id: "va3", sourceID: src, filePath: f3.path, fileName: "3.mp3", fileSize: 2, modifiedAt: Date(), format: .mp3, title: "Wonderwall", artist: "Oasis", albumArtist: "Oasis", album: "Road Trip Hits", trackNumber: 3)
        ]
        let dev = DeviceProfile(name: "ECHO SD", mountPath: tmp.appendingPathComponent("dev").path, preset: .fiioEchoMini, selectedAlbumKeys: [vaTracks[0].albumKey])
        let plan = SyncPlanner.buildPlan(profile: dev, allTracks: vaTracks, playlists: [])
        XCTAssertEqual(plan.tracksToCopy.count, 3)
        for item in plan.tracksToCopy {
            XCTAssertTrue(item.relativeDestinationPath.hasPrefix("Music/Various Artists/Road Trip Hits/"), "Unexpected split path: \(item.relativeDestinationPath)")
        }

        // 7. Distinct studio albums sharing a common title (e.g. Anastacia/Evolution vs Sabrina Carpenter/EVOLution) stay separate!
        let evo1 = Track(id: "e1", sourceID: src, filePath: "/MUSIC/Anastacia/Evolution (2017)/01.flac", fileName: "01.flac", fileSize: 1000, modifiedAt: Date(), format: .flac, title: "Caught in the Middle", artist: "Anastacia", albumArtist: "Anastacia", album: "Evolution", trackNumber: 1)
        let evo2 = Track(id: "e2", sourceID: src, filePath: "/MUSIC/Sabrina Carpenter/EVOLution (2016)/01.flac", fileName: "01.flac", fileSize: 1000, modifiedAt: Date(), format: .flac, title: "On Purpose", artist: "Sabrina Carpenter", albumArtist: "Sabrina Carpenter", album: "EVOLution", trackNumber: 1)
        let evoAlbums = AlbumGroup.buildGroups(from: [evo1, evo2])
        XCTAssertEqual(evoAlbums.count, 2)
        XCTAssertEqual(Set(evoAlbums.map(\.artist)), Set(["Anastacia", "Sabrina Carpenter"]))

        // 8. Zero-width BOM characters are stripped from folder paths
        XCTAssertEqual(PathFormatter.sanitizeSegment("Alan Walker\u{FEFF}\u{FEFF}"), "Alan Walker")
    }

    func testVolumeHardwareConnectionClassificationAndZeroUUIDSanitization() {
        // 1. All-zero FAT32 UUID must be sanitized to nil
        XCTAssertNil(VolumeMonitor.sanitizedVolumeUUID("00000000-0000-0000-0000-000000000000"))
        XCTAssertEqual(
            VolumeMonitor.sanitizedVolumeUUID("A7E25008-C053-472B-BE1E-F866654136B7"),
            "A7E25008-C053-472B-BE1E-F866654136B7"
        )

        // 2. Genesys Logic USB Card Reader (0x05E3:0x0751, "USB Storage" / "Generic STORAGE DEVICE")
        let usbReader = VolumeMonitor.classifyHardware(
            classNames: ["IOMedia", "IOBlockStorageDriver", "IOUSBMassStorageDriver", "IOUSBHostDevice"],
            interconnect: "USB",
            interconnectLocation: "External",
            usbVendorID: 0x05E3,
            usbProductID: 0x0751,
            usbVendorName: "USB Storage",
            usbProductName: "USB Storage",
            scsiVendor: "Generic",
            scsiProduct: "STORAGE DEVICE"
        )
        XCTAssertEqual(usbReader.connectionKind, .usbCardReader)
        XCTAssertEqual(usbReader.vendorName, "Genesys Logic")

        // 3. Built-in Mac SDXC Slot
        let macSD = VolumeMonitor.classifyHardware(
            classNames: ["IOMedia", "AppleSDXCBlockStorageDevice", "AppleSDXC"],
            interconnect: "Secure Digital",
            interconnectLocation: "Internal",
            usbVendorID: nil,
            usbProductID: nil,
            usbVendorName: nil,
            usbProductName: nil,
            scsiVendor: nil,
            scsiProduct: "APPLE SD Card Reader"
        )
        XCTAssertEqual(macSD.connectionKind, .builtInCardReader)

        // 4. FiiO / Snowsky DAP over USB
        let fiioPlayer = VolumeMonitor.classifyHardware(
            classNames: ["IOMedia", "IOUSBMassStorageDriver", "IOUSBHostDevice"],
            interconnect: "USB",
            interconnectLocation: "External",
            usbVendorID: 0x2972,
            usbProductID: 0x0012,
            usbVendorName: "FiiO",
            usbProductName: "ECHO MINI",
            scsiVendor: "FiiO",
            scsiProduct: "ECHO MINI SD"
        )
        XCTAssertEqual(fiioPlayer.connectionKind, .inPlayer)
        XCTAssertEqual(fiioPlayer.vendorName, "FiiO / Snowsky")

        // 5. Rockchip / Actions DAP over USB
        let rockchipPlayer = VolumeMonitor.classifyHardware(
            classNames: ["IOMedia", "IOUSBMassStorageDriver", "IOUSBHostDevice"],
            interconnect: "USB",
            interconnectLocation: "External",
            usbVendorID: 0x2207,
            usbProductID: 0x0001,
            usbVendorName: "Rockchip",
            usbProductName: "USB Mass Storage",
            scsiVendor: "Rockchip",
            scsiProduct: "DAP"
        )
        XCTAssertEqual(rockchipPlayer.connectionKind, .inPlayer)
    }

    func testEditorialInfoSQLitePersistenceAndStalenessTTL() throws {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("echo-editorial-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let db = try EchoDatabase(dbURL: tmpDir.appendingPathComponent("test.sqlite"))
        let now = Date()
        let freshAlbum = AlbumEditorialInfo(
            albumKey: "faithless::reverence",
            releaseDate: "1996-04-08",
            label: "Cheeky Records",
            genres: ["Electronic", "Dance"],
            albumFans: 48200,
            artistFans: 615000,
            artistAlbumCount: 19,
            albumSummary: "Reverence is the debut studio album by British electronic band Faithless.",
            artistSummary: "Faithless are a British electronic band formed in London in 1995.",
            artistImageURL: "https://example.com/faithless.jpg",
            fetchedAt: now
        )
        let staleArtist = ArtistEditorialInfo(
            artistKey: "faithless",
            summary: "British electronic band formed in 1995.",
            fans: 615000,
            albumCount: 19,
            imageURL: "https://example.com/faithless.jpg",
            fetchedAt: now.addingTimeInterval(-15 * 24 * 60 * 60)
        )

        db.saveAlbumEditorial(freshAlbum)
        db.saveArtistEditorial(staleArtist)

        let loadedAlbums = db.loadAllAlbumEditorial()
        let loadedArtists = db.loadAllArtistEditorial()

        let roundTripAlbum = try XCTUnwrap(loadedAlbums["faithless::reverence"])
        XCTAssertEqual(roundTripAlbum.label, "Cheeky Records")
        XCTAssertEqual(roundTripAlbum.releaseDate, "1996-04-08")
        XCTAssertEqual(roundTripAlbum.genres, ["Electronic", "Dance"])
        XCTAssertFalse(roundTripAlbum.isStale)
        XCTAssertTrue(roundTripAlbum.hasDisplayableContent)

        let roundTripArtist = try XCTUnwrap(loadedArtists["faithless"])
        XCTAssertEqual(roundTripArtist.fans, 615000)
        XCTAssertTrue(roundTripArtist.isStale)
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

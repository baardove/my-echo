import Foundation
import CryptoKit

/// Pure-Swift RSS 2.0 / iTunes podcast parser using the EXACT same deterministic episode ID formula as macOS EchoCore.
enum iOSPodcastRSSParser {
    static func stableEpisodeID(showID: String, guidOrURL: String) -> String {
        let input = "\(showID)::\(guidOrURL)"
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    static func normalizedKey(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed.lowercased()
    }

    static func parse(data: Data, show: iOSPodcastShow) throws -> [iOSPodcastEpisode] {
        let delegate = RSSDelegate(show: show)
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldProcessNamespaces = false
        guard parser.parse() else {
            throw parser.parserError ?? NSError(domain: "MyEcho.iOSPodcastRSS", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse RSS XML"])
        }
        return delegate.episodes
    }

    static func parseDuration(_ raw: String) -> TimeInterval {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let secs = Double(trimmed) { return max(0, secs) }
        let parts = trimmed.split(separator: ":").compactMap { Double($0) }
        if parts.count == 3 {
            return parts[0] * 3600 + parts[1] * 60 + parts[2]
        } else if parts.count == 2 {
            return parts[0] * 60 + parts[1]
        }
        return 0
    }

    static func parseRFC822Date(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let formats = [
            "EEE, dd MMM yyyy HH:mm:ss Z",
            "EEE, d MMM yyyy HH:mm:ss Z",
            "EEE, dd MMM yyyy HH:mm:ss zzz",
            "dd MMM yyyy HH:mm:ss Z",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        ]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for fmt in formats {
            formatter.dateFormat = fmt
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }
        return nil
    }

    private final class RSSDelegate: NSObject, XMLParserDelegate {
        let show: iOSPodcastShow
        var inItem = false
        var buffer = ""

        var itemTitle = ""
        var itemGUID = ""
        var itemSummary = ""
        var itemPubDate = ""
        var itemDuration = ""
        var itemAudioURL = ""
        var itemFileSize: Int64 = 0
        var itemAudioType = ""

        var episodes: [iOSPodcastEpisode] = []

        init(show: iOSPodcastShow) {
            self.show = show
        }

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
            let tag = elementName.lowercased()
            buffer = ""
            if tag == "item" {
                inItem = true
                itemTitle = ""
                itemGUID = ""
                itemSummary = ""
                itemPubDate = ""
                itemDuration = ""
                itemAudioURL = ""
                itemFileSize = 0
                itemAudioType = ""
            } else if tag == "enclosure" && inItem {
                if let url = attributeDict["url"], !url.isEmpty { itemAudioURL = url }
                if let lenStr = attributeDict["length"], let len = Int64(lenStr) { itemFileSize = len }
                if let mime = attributeDict["type"] { itemAudioType = mime.lowercased() }
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            buffer.append(string)
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            let tag = elementName.lowercased()
            let text = buffer.trimmingCharacters(in: .whitespacesAndNewlines)

            if inItem {
                switch tag {
                case "title":
                    if itemTitle.isEmpty { itemTitle = text }
                case "guid":
                    itemGUID = text
                case "description", "itunes:summary":
                    if itemSummary.isEmpty || tag == "itunes:summary" {
                        itemSummary = stripHTML(text)
                    }
                case "pubdate":
                    itemPubDate = text
                case "itunes:duration":
                    itemDuration = text
                case "item":
                    if !itemAudioURL.isEmpty {
                        let guid = itemGUID.isEmpty ? itemAudioURL : itemGUID
                        let ext = inferExtension(urlStr: itemAudioURL, mime: itemAudioType)
                        let epID = iOSPodcastRSSParser.stableEpisodeID(showID: show.id, guidOrURL: guid)
                        episodes.append(iOSPodcastEpisode(
                            id: epID,
                            showID: show.id,
                            showTitle: show.title,
                            title: itemTitle.isEmpty ? "Untitled Episode" : itemTitle,
                            summary: itemSummary,
                            publishedAt: iOSPodcastRSSParser.parseRFC822Date(itemPubDate),
                            duration: iOSPodcastRSSParser.parseDuration(itemDuration),
                            fileSize: itemFileSize,
                            artworkHash: show.artworkHash,
                            fileExtension: ext,
                            guid: guid,
                            audioURL: itemAudioURL,
                            downloadOrigin: .none
                        ))
                    }
                    inItem = false
                default:
                    break
                }
            }
            buffer = ""
        }

        private func inferExtension(urlStr: String, mime: String) -> String {
            if let url = URL(string: urlStr) {
                let ext = url.pathExtension.lowercased()
                if ["mp3", "m4a", "aac", "ogg", "opus", "wav", "flac"].contains(ext) {
                    return ext
                }
            }
            if mime.contains("m4a") || mime.contains("mp4") || mime.contains("aac") { return "m4a" }
            if mime.contains("ogg") { return "ogg" }
            if mime.contains("wav") { return "wav" }
            return "mp3"
        }

        private func stripHTML(_ raw: String) -> String {
            raw.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&#39;", with: "'")
                .replacingOccurrences(of: "&nbsp;", with: " ")
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}

/// Snapshot of episodes currently downloaded on this iPhone/iPad, used to prevent duplicate Mac Wi-Fi syncing
/// and to protect device-downloaded episodes during Mac Mirror cleanup.
struct LocalPodcastDownloadIndex: Sendable {
    var downloadedIDs: Set<String>
    var downloadedGUIDs: Set<String>
    var downloadedAudioURLs: Set<String>
    var selfDownloadedFileNames: Set<String>

    func contains(id: String, guid: String?, audioURL: String?) -> Bool {
        if downloadedIDs.contains(id) { return true }
        if let g = iOSPodcastRSSParser.normalizedKey(guid), downloadedGUIDs.contains(g) { return true }
        if let u = iOSPodcastRSSParser.normalizedKey(audioURL), downloadedAudioURLs.contains(u) { return true }
        return false
    }
}

/// Manages synced podcast feeds, direct on-device RSS refreshes, and deduplicated local episode downloads.
actor iOSPodcastManager {
    struct PersistedState: Codable, Sendable {
        var shows: [iOSPodcastShow]
    }

    let episodesDir: URL
    let stateFileURL: URL

    private let session: URLSession
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted]
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let root = docs.appendingPathComponent("MyEchoLibrary", isDirectory: true)
        self.episodesDir = root.appendingPathComponent("Episodes", isDirectory: true)
        self.stateFileURL = root.appendingPathComponent("podcasts_state.json")
        try? FileManager.default.createDirectory(at: episodesDir, withIntermediateDirectories: true)

        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 25
        cfg.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: cfg)
    }

    func loadShows() -> [iOSPodcastShow] {
        guard let data = try? Data(contentsOf: stateFileURL),
              let state = try? decoder.decode(PersistedState.self, from: data) else {
            return []
        }
        return reconcileWithDisk(shows: state.shows)
    }

    private func saveShows(_ shows: [iOSPodcastShow]) {
        let state = PersistedState(shows: shows)
        if let data = try? encoder.encode(state) {
            try? data.write(to: stateFileURL, options: .atomic)
        }
    }

    func localFileURL(for episode: iOSPodcastEpisode) -> URL? {
        let direct = episodesDir.appendingPathComponent(episode.localFileName)
        if FileManager.default.fileExists(atPath: direct.path) {
            return direct
        }
        // Check any extension matching episode ID
        if let files = try? FileManager.default.contentsOfDirectory(at: episodesDir, includingPropertiesForKeys: nil) {
            if let match = files.first(where: { $0.deletingPathExtension().lastPathComponent == episode.id }) {
                return match
            }
        }
        return nil
    }

    /// Returns an airtight lookup of every episode currently on disk so Mac Wi-Fi sync skips already-downloaded episodes
    /// and Mirror cleanup never removes episodes downloaded directly by the iOS app.
    func downloadIndex() -> LocalPodcastDownloadIndex {
        let shows = loadShows()
        var ids: Set<String> = []
        var guids: Set<String> = []
        var urls: Set<String> = []
        var selfFiles: Set<String> = []

        if let files = try? FileManager.default.contentsOfDirectory(at: episodesDir, includingPropertiesForKeys: nil) {
            for f in files {
                ids.insert(f.deletingPathExtension().lastPathComponent)
            }
        }

        for show in shows {
            for ep in show.episodes {
                if let file = localFileURL(for: ep) {
                    ids.insert(ep.id)
                    if let g = iOSPodcastRSSParser.normalizedKey(ep.guid) { guids.insert(g) }
                    if let u = iOSPodcastRSSParser.normalizedKey(ep.audioURL) { urls.insert(u) }
                    if ep.downloadOrigin == .downloadedOnDevice {
                        selfFiles.insert(file.lastPathComponent)
                    }
                }
            }
        }

        return LocalPodcastDownloadIndex(
            downloadedIDs: ids,
            downloadedGUIDs: guids,
            downloadedAudioURLs: urls,
            selfDownloadedFileNames: selfFiles
        )
    }

    /// Merges synced podcast feeds and Mac-synced episodes into the local iOS catalog without losing
    /// RSS-fetched episodes, device-downloaded episodes, or shows subscribed on iOS awaiting Mac sync.
    func mergeFromMacManifest(
        feeds: [SyncedPodcastFeed],
        syncedEpisodes: [SyncedEpisode],
        pendingFeedURLs: Set<String> = []
    ) -> [iOSPodcastShow] {
        let existingShows = loadShows()
        let existingByID = Dictionary(uniqueKeysWithValues: existingShows.map { ($0.id, $0) })
        let existingByNormFeed: [String: iOSPodcastShow] = Dictionary(
            existingShows.compactMap { show in
                let norm = show.feedURL.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
                return norm.isEmpty ? nil : (norm, show)
            },
            uniquingKeysWith: { first, _ in first }
        )
        let syncedByShow = Dictionary(grouping: syncedEpisodes, by: \.showID)

        var mergedShows: [iOSPodcastShow] = []
        var seenShowIDs: Set<String> = []
        var seenNormFeeds: Set<String> = []

        for feed in feeds {
            seenShowIDs.insert(feed.id)
            let normFeed = feed.feedURL.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
            if !normFeed.isEmpty { seenNormFeeds.insert(normFeed) }

            var show = existingByID[feed.id]
                ?? (!normFeed.isEmpty ? existingByNormFeed[normFeed] : nil)
                ?? iOSPodcastShow(
                    id: feed.id,
                    title: feed.title,
                    author: feed.author,
                    description: feed.description,
                    feedURL: feed.feedURL,
                    artworkURL: feed.artworkURL,
                    artworkHash: feed.artworkHash,
                    episodesToKeep: feed.episodesToKeep,
                    isSelectedForAutoSync: feed.isSelectedForAutoSync,
                    lastRefreshedAt: nil,
                    episodes: []
                )
            // Adopt Mac's canonical ID and keep metadata fresh from Mac
            show.id = feed.id
            show.title = feed.title
            show.author = feed.author
            show.description = feed.description
            show.feedURL = feed.feedURL
            show.artworkURL = feed.artworkURL ?? show.artworkURL
            show.artworkHash = feed.artworkHash ?? show.artworkHash
            show.episodesToKeep = feed.episodesToKeep
            show.isSelectedForAutoSync = feed.isSelectedForAutoSync

            let macEps = syncedByShow[feed.id] ?? []
            show.episodes = mergeEpisodes(existing: show.episodes, incomingFromMac: macEps, showArtworkHash: show.artworkHash)
            mergedShows.append(show)
        }

        // Preserve any orphaned Mac-synced episodes whose show wasn't in podcastFeeds
        for (showID, eps) in syncedByShow where !seenShowIDs.contains(showID) {
            guard let first = eps.first else { continue }
            var show = existingByID[showID] ?? iOSPodcastShow(
                id: showID,
                title: first.showTitle,
                author: first.showTitle,
                description: "",
                feedURL: "",
                artworkURL: nil,
                artworkHash: first.artworkHash,
                episodesToKeep: 5,
                isSelectedForAutoSync: true,
                lastRefreshedAt: nil,
                episodes: []
            )
            show.episodes = mergeEpisodes(existing: show.episodes, incomingFromMac: eps, showArtworkHash: show.artworkHash)
            mergedShows.append(show)
            seenShowIDs.insert(showID)
        }

        // Preserve shows subscribed on iOS that are still queued to sync back to Mac
        for localShow in existingShows {
            let norm = localShow.feedURL.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
            if !norm.isEmpty && pendingFeedURLs.contains(norm) && !seenNormFeeds.contains(norm) && !seenShowIDs.contains(localShow.id) {
                mergedShows.append(localShow)
                seenNormFeeds.insert(norm)
                seenShowIDs.insert(localShow.id)
            }
        }

        mergedShows = reconcileWithDisk(shows: mergedShows)
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        saveShows(mergedShows)
        return mergedShows
    }

    /// Fetches the latest RSS feed directly over the internet (no Mac required) and merges new episodes.
    /// Episodes already synced from Mac or already downloaded on device are preserved and never re-downloaded.
    func refreshFeed(showID: String) async throws -> [iOSPodcastShow] {
        var shows = loadShows()
        guard let idx = shows.firstIndex(where: { $0.id == showID }) else { return shows }
        let show = shows[idx]
        guard let url = URL(string: show.feedURL.trimmingCharacters(in: .whitespacesAndNewlines)), !show.feedURL.isEmpty else {
            return shows
        }

        var req = URLRequest(url: url)
        req.timeoutInterval = 20
        req.setValue("MyEchoiOS/1.3", forHTTPHeaderField: "User-Agent")

        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw NSError(domain: "MyEcho.iOSPodcast", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Feed returned HTTP \(http.statusCode)"])
        }

        let parsed = try iOSPodcastRSSParser.parse(data: data, show: show)
        shows[idx].episodes = mergeEpisodes(existing: shows[idx].episodes, incomingFromRSS: parsed)
        shows[idx].lastRefreshedAt = Date()
        shows = reconcileWithDisk(shows: shows)
        saveShows(shows)
        return shows
    }

    /// Downloads a single episode directly from its RSS `audioURL` to the shared Episodes folder.
    /// If the episode is already present on disk (e.g. synced from Mac, matched by ID, GUID, or audioURL),
    /// it skips the network download completely!
    func downloadEpisode(showID: String, episodeID: String) async throws -> [iOSPodcastShow] {
        var shows = loadShows()
        guard let sIdx = shows.firstIndex(where: { $0.id == showID }),
              let eIdx = shows[sIdx].episodes.firstIndex(where: { $0.id == episodeID }) else {
            return shows
        }

        let ep = shows[sIdx].episodes[eIdx]

        // Deduplication check: never re-download an episode that was already synced from Mac or downloaded on device!
        let idx = downloadIndex()
        if idx.contains(id: ep.id, guid: ep.guid, audioURL: ep.audioURL) {
            if shows[sIdx].episodes[eIdx].downloadOrigin == .none {
                shows[sIdx].episodes[eIdx].downloadOrigin = .syncedFromMac
            }
            saveShows(shows)
            return shows
        }

        guard let audioURL = URL(string: ep.audioURL), !ep.audioURL.isEmpty else {
            throw NSError(domain: "MyEcho.iOSPodcast", code: 400, userInfo: [NSLocalizedDescriptionKey: "Episode has no valid audio URL"])
        }

        var req = URLRequest(url: audioURL)
        req.timeoutInterval = 180
        req.setValue("MyEchoiOS/1.3", forHTTPHeaderField: "User-Agent")

        let (tempURL, resp) = try await session.download(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            try? FileManager.default.removeItem(at: tempURL)
            throw NSError(domain: "MyEcho.iOSPodcast", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Download failed (HTTP \(http.statusCode))"])
        }

        let dest = episodesDir.appendingPathComponent(ep.localFileName)
        if FileManager.default.fileExists(atPath: dest.path) {
            try? FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.moveItem(at: tempURL, to: dest)

        let attrs = try? FileManager.default.attributesOfItem(atPath: dest.path)
        let actualSize = (attrs?[.size] as? NSNumber)?.int64Value ?? ep.fileSize

        // Reload in case another operation modified state while downloading
        shows = loadShows()
        if let s2 = shows.firstIndex(where: { $0.id == showID }),
           let e2 = shows[s2].episodes.firstIndex(where: { $0.id == episodeID }) {
            shows[s2].episodes[e2].downloadOrigin = .downloadedOnDevice
            shows[s2].episodes[e2].fileSize = actualSize
            saveShows(shows)
        }
        return shows
    }

    func deleteDownloadedEpisode(showID: String, episodeID: String) -> [iOSPodcastShow] {
        var shows = loadShows()
        if let sIdx = shows.firstIndex(where: { $0.id == showID }),
           let eIdx = shows[sIdx].episodes.firstIndex(where: { $0.id == episodeID }) {
            let ep = shows[sIdx].episodes[eIdx]
            if let file = localFileURL(for: ep) {
                try? FileManager.default.removeItem(at: file)
            }
            shows[sIdx].episodes[eIdx].downloadOrigin = .none
            saveShows(shows)
        }
        return shows
    }

    // MARK: - Online Podcast Directory Search (Apple Podcasts + gPodder + Curated)

    private struct ITunesSearchResponse: Decodable {
        struct Item: Decodable {
            let collectionName: String?
            let trackName: String?
            let artistName: String?
            let feedUrl: String?
            let artworkUrl600: String?
            let artworkUrl100: String?
            let primaryGenreName: String?
            let trackCount: Int?
        }
        let results: [Item]
    }

    private struct GPodderItem: Decodable {
        let url: String?
        let title: String?
        let author: String?
        let logo_url: String?
        let scaled_logo_url: String?
        let subscribers: Int?
    }

    static let curatedFeaturedShows: [iOSPodcastSearchResult] = [
        iOSPodcastSearchResult(title: "Darknet Diaries", author: "Jack Rhysider", feedURL: "https://feeds.megaphone.fm/darknetdiaries", genre: "Technology · Security", directorySource: "FEATURED"),
        iOSPodcastSearchResult(title: "Accidental Tech Podcast", author: "Marco Arment, Casey Liss, John Siracusa", feedURL: "https://atp.fm/episodes?format=rss", genre: "Technology", directorySource: "FEATURED"),
        iOSPodcastSearchResult(title: "Waveform: The MKBHD Podcast", author: "Vox Media Podcast Network", feedURL: "https://feeds.megaphone.fm/STU4418364045", genre: "Technology · Audio", directorySource: "FEATURED"),
        iOSPodcastSearchResult(title: "Acquired", author: "Ben Gilbert and David Rosenthal", feedURL: "https://feeds.transistor.fm/acquired", genre: "Business · Tech", directorySource: "FEATURED"),
        iOSPodcastSearchResult(title: "99% Invisible", author: "Roman Mars", feedURL: "https://feeds.simplecast.com/BqbsxVfO", genre: "Design · Culture", directorySource: "FEATURED"),
        iOSPodcastSearchResult(title: "Song Exploder", author: "Hrishikesh Hirway", feedURL: "https://feed.songexploder.net/SongExploder", genre: "Music", directorySource: "FEATURED"),
        iOSPodcastSearchResult(title: "Twenty Thousand Hertz", author: "Dallas Taylor", feedURL: "https://feeds.megaphone.fm/20k", genre: "Sound & Audio", directorySource: "FEATURED"),
        iOSPodcastSearchResult(title: "NRK Oppdatert", author: "NRK", feedURL: "https://podkast.nrk.no/program/oppdatert.rss", genre: "Nordic · News", directorySource: "FEATURED")
    ]

    func searchDirectories(
        query: String,
        directory: iOSPodcastDirectory = .all,
        category: iOSPodcastCategory? = nil
    ) async throws -> [iOSPodcastSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            if let category {
                return try await browseCategory(category, directory: directory)
            }
            return Self.curatedFeaturedShows
        }

        let activeGenre: iOSPodcastCategory? = {
            if let category, category != .featured, category != .topCharts {
                return category
            }
            return iOSPodcastCategory.matchingGenre(for: trimmed)
        }()

        switch directory {
        case .curated:
            let q = trimmed.lowercased()
            return Self.curatedFeaturedShows.filter {
                $0.title.lowercased().contains(q)
                    || $0.author.lowercased().contains(q)
                    || ($0.genre?.lowercased().contains(q) ?? false)
            }
        case .apple:
            if let genre = activeGenre {
                if category != nil && category != .featured && category != .topCharts {
                    return try await searchApplePodcasts(term: trimmed, country: genre.countryCode, genreID: genre.appleGenreID, limit: 25)
                } else {
                    async let byGenre: [iOSPodcastSearchResult] = (try? await searchApplePodcasts(term: genre.defaultBrowseTerm, country: genre.countryCode, genreID: genre.appleGenreID, limit: 22)) ?? []
                    async let byTerm: [iOSPodcastSearchResult] = (try? await searchApplePodcasts(term: trimmed, country: genre.countryCode, genreID: nil, limit: 22)) ?? []
                    return mergeDeduplicatedResults((await byGenre) + (await byTerm))
                }
            }
            return try await searchApplePodcasts(term: trimmed, limit: 25)
        case .gpodder:
            if let tag = activeGenre?.gpodderTag {
                async let byTag: [iOSPodcastSearchResult] = (try? await fetchGPodderTag(tag: tag, limit: 20)) ?? []
                async let byQuery: [iOSPodcastSearchResult] = (try? await searchGPodder(term: trimmed, limit: 20)) ?? []
                return mergeDeduplicatedResults((await byQuery) + (await byTag))
            }
            return try await searchGPodder(term: trimmed, limit: 20)
        case .all:
            let country = activeGenre?.countryCode ?? "US"
            let genreID = activeGenre?.appleGenreID
            let tag = activeGenre?.gpodderTag
            async let appleTask: [iOSPodcastSearchResult] = (try? await searchApplePodcasts(term: trimmed, country: country, genreID: genreID, limit: 25)) ?? []
            async let appleGenreTask: [iOSPodcastSearchResult] = {
                if let genre = activeGenre, category == nil {
                    return (try? await searchApplePodcasts(term: genre.defaultBrowseTerm, country: genre.countryCode, genreID: genre.appleGenreID, limit: 18)) ?? []
                }
                return []
            }()
            async let gpodderTask: [iOSPodcastSearchResult] = (try? await searchGPodder(term: trimmed, limit: 20)) ?? []
            async let gpodderTagTask: [iOSPodcastSearchResult] = {
                if let tag {
                    return (try? await fetchGPodderTag(tag: tag, limit: 15)) ?? []
                }
                return []
            }()
            return mergeDeduplicatedResults((await appleTask) + (await appleGenreTask) + (await gpodderTask) + (await gpodderTagTask))
        }
    }

    func browseCategory(_ category: iOSPodcastCategory, directory: iOSPodcastDirectory = .all) async throws -> [iOSPodcastSearchResult] {
        switch category {
        case .featured:
            return Self.curatedFeaturedShows
        case .topCharts:
            async let appleTop: [iOSPodcastSearchResult] = (try? await searchApplePodcasts(term: "podcast", limit: 22)) ?? []
            async let gpodTop: [iOSPodcastSearchResult] = (try? await fetchGPodderTop(limit: 20)) ?? []
            if directory == .apple { return await appleTop }
            if directory == .gpodder { return await gpodTop }
            return mergeDeduplicatedResults((await appleTop) + (await gpodTop))
        case .nordic:
            async let nrk: [iOSPodcastSearchResult] = (try? await searchApplePodcasts(term: "NRK", country: "NO", limit: 18)) ?? []
            async let noPod: [iOSPodcastSearchResult] = (try? await searchApplePodcasts(term: "podkast", country: "NO", limit: 18)) ?? []
            return mergeDeduplicatedResults((await nrk) + (await noPod))
        default:
            switch directory {
            case .curated:
                let key = category.defaultBrowseTerm.lowercased()
                return Self.curatedFeaturedShows.filter {
                    ($0.genre?.lowercased().contains(key) ?? false) || $0.title.lowercased().contains(key)
                }
            case .apple:
                return try await searchApplePodcasts(term: category.defaultBrowseTerm, country: category.countryCode, genreID: category.appleGenreID, limit: 25)
            case .gpodder:
                if let tag = category.gpodderTag {
                    let tagged = (try? await fetchGPodderTag(tag: tag, limit: 20)) ?? []
                    if !tagged.isEmpty { return tagged }
                }
                return try await searchGPodder(term: category.defaultBrowseTerm, limit: 20)
            case .all:
                async let appleTask: [iOSPodcastSearchResult] = (try? await searchApplePodcasts(term: category.defaultBrowseTerm, country: category.countryCode, genreID: category.appleGenreID, limit: 25)) ?? []
                async let gpodTask: [iOSPodcastSearchResult] = {
                    if let tag = category.gpodderTag {
                        let tagged = (try? await fetchGPodderTag(tag: tag, limit: 15)) ?? []
                        if !tagged.isEmpty { return tagged }
                    }
                    return (try? await searchGPodder(term: category.defaultBrowseTerm, limit: 15)) ?? []
                }()
                return mergeDeduplicatedResults((await appleTask) + (await gpodTask))
            }
        }
    }

    private func searchApplePodcasts(term: String, country: String = "US", genreID: Int? = nil, limit: Int) async throws -> [iOSPodcastSearchResult] {
        var comps = URLComponents(string: "https://itunes.apple.com/search")!
        var items = [
            URLQueryItem(name: "media", value: "podcast"),
            URLQueryItem(name: "entity", value: "podcast"),
            URLQueryItem(name: "country", value: country),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "term", value: term)
        ]
        if let genreID {
            items.append(URLQueryItem(name: "genreId", value: String(genreID)))
        }
        comps.queryItems = items
        guard let url = comps.url else { return [] }
        var req = URLRequest(url: url)
        req.timeoutInterval = 15
        req.setValue("MyEchoiOS/1.3", forHTTPHeaderField: "User-Agent")
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw NSError(domain: "MyEcho.iOSPodcast", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Apple Podcasts HTTP \(http.statusCode)"])
        }
        let decoded = try JSONDecoder().decode(ITunesSearchResponse.self, from: data)
        var out: [iOSPodcastSearchResult] = []
        for item in decoded.results {
            guard let feed = item.feedUrl, !feed.isEmpty else { continue }
            out.append(iOSPodcastSearchResult(
                title: item.collectionName ?? item.trackName ?? "Untitled Podcast",
                author: item.artistName ?? "Unknown Author",
                feedURL: feed,
                artworkURL: item.artworkUrl600 ?? item.artworkUrl100,
                genre: item.primaryGenreName,
                episodeCount: item.trackCount,
                directorySource: "APPLE"
            ))
        }
        return mergeDeduplicatedResults(out)
    }

    private func searchGPodder(term: String, limit: Int) async throws -> [iOSPodcastSearchResult] {
        var comps = URLComponents(string: "https://gpodder.net/search.json")!
        comps.queryItems = [URLQueryItem(name: "q", value: term)]
        guard let url = comps.url else { return [] }
        return try await fetchGPodder(url: url, limit: limit)
    }

    private func fetchGPodderTop(limit: Int) async throws -> [iOSPodcastSearchResult] {
        guard let url = URL(string: "https://gpodder.net/toplist/\(limit).json") else { return [] }
        return try await fetchGPodder(url: url, limit: limit)
    }

    private func fetchGPodderTag(tag: String, limit: Int) async throws -> [iOSPodcastSearchResult] {
        let safeTag = tag.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? tag
        guard let url = URL(string: "https://gpodder.net/api/2/tag/\(safeTag)/\(limit).json") else { return [] }
        return try await fetchGPodder(url: url, limit: limit)
    }

    private func fetchGPodder(url: URL, limit: Int) async throws -> [iOSPodcastSearchResult] {
        var req = URLRequest(url: url)
        req.timeoutInterval = 12
        req.setValue("MyEchoiOS/1.3", forHTTPHeaderField: "User-Agent")
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw NSError(domain: "MyEcho.iOSPodcast", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "gPodder HTTP \(http.statusCode)"])
        }
        let decoded = try JSONDecoder().decode([GPodderItem].self, from: data)
        var out: [iOSPodcastSearchResult] = []
        for item in decoded.prefix(limit) {
            guard let feed = item.url, !feed.isEmpty else { continue }
            out.append(iOSPodcastSearchResult(
                title: (item.title?.isEmpty == false ? item.title! : "Untitled Podcast"),
                author: (item.author?.isEmpty == false ? item.author! : "gPodder Directory"),
                feedURL: feed,
                artworkURL: item.scaled_logo_url ?? item.logo_url,
                genre: item.subscribers.map { "\($0) subs" },
                episodeCount: nil,
                directorySource: "GPODDER"
            ))
        }
        return mergeDeduplicatedResults(out)
    }

    private func mergeDeduplicatedResults(_ items: [iOSPodcastSearchResult]) -> [iOSPodcastSearchResult] {
        var seen: Set<String> = []
        var out: [iOSPodcastSearchResult] = []
        for item in items {
            let norm = item.feedURL.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
            if seen.insert(norm).inserted {
                out.append(item)
            }
        }
        return out
    }

    /// Subscribes to a podcast feed directly on iOS (using Mac's canonical showID if available) and fetches its RSS episodes.
    func subscribeLocally(
        result: iOSPodcastSearchResult,
        preferredShowID: String? = nil
    ) async throws -> [iOSPodcastShow] {
        var shows = loadShows()
        let normFeed = result.feedURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existingIdx = shows.firstIndex(where: { $0.feedURL.caseInsensitiveCompare(normFeed) == .orderedSame }) {
            let existingID = shows[existingIdx].id
            return try await refreshFeed(showID: existingID)
        }

        let newID = (preferredShowID?.isEmpty == false ? preferredShowID! : UUID().uuidString)
        let stub = iOSPodcastShow(
            id: newID,
            title: result.title,
            author: result.author,
            description: "",
            feedURL: normFeed,
            artworkURL: result.artworkURL,
            artworkHash: nil,
            episodesToKeep: 5,
            isSelectedForAutoSync: true,
            lastRefreshedAt: nil,
            episodes: []
        )
        shows.append(stub)
        shows.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        saveShows(shows)
        return (try? await refreshFeed(showID: newID)) ?? shows
    }

    // MARK: - Merging & Disk Reconciliation Helpers

    private func mergeEpisodes(
        existing: [iOSPodcastEpisode],
        incomingFromMac: [SyncedEpisode],
        showArtworkHash: String?
    ) -> [iOSPodcastEpisode] {
        var list = existing
        for macEp in incomingFromMac {
            let matchIdx = findMatchingEpisodeIndex(in: list, id: macEp.id, guid: macEp.guid, audioURL: macEp.audioURL)
            if let idx = matchIdx {
                // Preserve `.downloadedOnDevice` if iPhone already downloaded it; otherwise mark `.syncedFromMac` if on disk
                let existsOnDisk = localFileURL(for: list[idx]) != nil
                    || FileManager.default.fileExists(atPath: episodesDir.appendingPathComponent("\(macEp.id).\(macEp.fileExtension)").path)
                if list[idx].downloadOrigin == .none && existsOnDisk {
                    list[idx].downloadOrigin = .syncedFromMac
                }
                if list[idx].artworkHash == nil { list[idx].artworkHash = macEp.artworkHash ?? showArtworkHash }
                if list[idx].fileSize == 0 { list[idx].fileSize = macEp.fileSize }
                if list[idx].duration == 0 { list[idx].duration = macEp.duration }
            } else {
                let onDisk = FileManager.default.fileExists(atPath: episodesDir.appendingPathComponent("\(macEp.id).\(macEp.fileExtension)").path)
                list.append(iOSPodcastEpisode(
                    id: macEp.id,
                    showID: macEp.showID,
                    showTitle: macEp.showTitle,
                    title: macEp.title,
                    summary: macEp.summary,
                    publishedAt: macEp.publishedAt,
                    duration: macEp.duration,
                    fileSize: macEp.fileSize,
                    artworkHash: macEp.artworkHash ?? showArtworkHash,
                    fileExtension: macEp.fileExtension,
                    guid: macEp.guid ?? macEp.id,
                    audioURL: macEp.audioURL ?? "",
                    downloadOrigin: onDisk ? .syncedFromMac : .none
                ))
            }
        }
        return list.sorted { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }
    }

    private func mergeEpisodes(
        existing: [iOSPodcastEpisode],
        incomingFromRSS: [iOSPodcastEpisode]
    ) -> [iOSPodcastEpisode] {
        var list = existing
        for rssEp in incomingFromRSS {
            if let idx = findMatchingEpisodeIndex(in: list, id: rssEp.id, guid: rssEp.guid, audioURL: rssEp.audioURL) {
                // Keep existing downloadOrigin (.syncedFromMac or .downloadedOnDevice) and file!
                if list[idx].audioURL.isEmpty { list[idx].audioURL = rssEp.audioURL }
                if list[idx].guid.isEmpty { list[idx].guid = rssEp.guid }
                if list[idx].summary.isEmpty { list[idx].summary = rssEp.summary }
                if list[idx].duration == 0 { list[idx].duration = rssEp.duration }
                if list[idx].publishedAt == nil { list[idx].publishedAt = rssEp.publishedAt }
            } else {
                var ep = rssEp
                if localFileURL(for: ep) != nil {
                    ep.downloadOrigin = .syncedFromMac
                }
                list.append(ep)
            }
        }
        return list.sorted { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }
    }

    private func findMatchingEpisodeIndex(
        in list: [iOSPodcastEpisode],
        id: String,
        guid: String?,
        audioURL: String?
    ) -> Int? {
        if let idx = list.firstIndex(where: { $0.id == id }) { return idx }
        if let g = iOSPodcastRSSParser.normalizedKey(guid),
           let idx = list.firstIndex(where: { iOSPodcastRSSParser.normalizedKey($0.guid) == g }) {
            return idx
        }
        if let u = iOSPodcastRSSParser.normalizedKey(audioURL),
           let idx = list.firstIndex(where: { iOSPodcastRSSParser.normalizedKey($0.audioURL) == u }) {
            return idx
        }
        return nil
    }

    private func reconcileWithDisk(shows: [iOSPodcastShow]) -> [iOSPodcastShow] {
        var copy = shows
        for sIdx in copy.indices {
            for eIdx in copy[sIdx].episodes.indices {
                let onDisk = localFileURL(for: copy[sIdx].episodes[eIdx]) != nil
                if !onDisk && copy[sIdx].episodes[eIdx].downloadOrigin != .none {
                    copy[sIdx].episodes[eIdx].downloadOrigin = .none
                } else if onDisk && copy[sIdx].episodes[eIdx].downloadOrigin == .none {
                    copy[sIdx].episodes[eIdx].downloadOrigin = .syncedFromMac
                }
            }
        }
        return copy
    }
}

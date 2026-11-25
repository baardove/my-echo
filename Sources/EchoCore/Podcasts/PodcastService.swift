import Foundation
import CryptoKit

public actor PodcastService {
    private let artworkCache: ArtworkCache
    public let downloadsDirectory: URL

    public init(artworkCache: ArtworkCache, downloadsDirectory: URL? = nil) {
        self.artworkCache = artworkCache
        if let downloadsDirectory {
            self.downloadsDirectory = downloadsDirectory
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.downloadsDirectory = appSupport.appendingPathComponent("Echo/Podcasts", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: self.downloadsDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Multi-Directory Podcast Search (Apple Podcasts + gPodder Open Directory + Featured)

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

    public static let curatedFeaturedShows: [PodcastSearchResult] = [
        PodcastSearchResult(title: "Darknet Diaries", author: "Jack Rhysider", feedURL: "https://feeds.megaphone.fm/darknetdiaries", genre: "Technology · Security", directorySource: "FEATURED"),
        PodcastSearchResult(title: "Accidental Tech Podcast", author: "Marco Arment, Casey Liss, John Siracusa", feedURL: "https://atp.fm/episodes?format=rss", genre: "Technology", directorySource: "FEATURED"),
        PodcastSearchResult(title: "Waveform: The MKBHD Podcast", author: "Vox Media Podcast Network", feedURL: "https://feeds.megaphone.fm/STU4418364045", genre: "Technology · Audio", directorySource: "FEATURED"),
        PodcastSearchResult(title: "Acquired", author: "Ben Gilbert and David Rosenthal", feedURL: "https://feeds.transistor.fm/acquired", genre: "Business · Tech", directorySource: "FEATURED"),
        PodcastSearchResult(title: "99% Invisible", author: "Roman Mars", feedURL: "https://feeds.simplecast.com/BqbsxVfO", genre: "Design · Culture", directorySource: "FEATURED"),
        PodcastSearchResult(title: "Song Exploder", author: "Hrishikesh Hirway", feedURL: "https://feed.songexploder.net/SongExploder", genre: "Music", directorySource: "FEATURED"),
        PodcastSearchResult(title: "Twenty Thousand Hertz", author: "Dallas Taylor", feedURL: "https://feeds.megaphone.fm/20k", genre: "Sound & Audio", directorySource: "FEATURED"),
        PodcastSearchResult(title: "Radiolab", author: "WNYC Studios", feedURL: "https://feeds.simplecast.com/EmVW7VGp", genre: "Science", directorySource: "FEATURED"),
        PodcastSearchResult(title: "Dan Carlin's Hardcore History", author: "Dan Carlin", feedURL: "https://feeds.feedburner.com/dancarlin/history?format=xml", genre: "History", directorySource: "FEATURED"),
        PodcastSearchResult(title: "NRK Oppdatert", author: "NRK", feedURL: "https://podkast.nrk.no/program/oppdatert.rss", genre: "Nordic · News", directorySource: "FEATURED")
    ]

    public func searchPodcasts(
        query: String,
        directory: PodcastDirectory = .all,
        category: PodcastBrowseCategory? = nil,
        limit: Int = 25
    ) async throws -> [PodcastSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            if let category {
                return try await browseCategory(category, directory: directory)
            }
            return directory == .curated ? Self.curatedFeaturedShows : []
        }

        // If the user explicitly picked a genre chip, OR typed a genre name directly (e.g. "true crime", "sports"),
        // apply Apple's official genreId & gPodder tag search alongside regular keyword search!
        let activeGenre: PodcastBrowseCategory? = {
            if let category, category != .featured, category != .topCharts {
                return category
            }
            return PodcastBrowseCategory.matchingGenre(for: trimmed)
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
                    // Explicit genre filter + search term inside that genre
                    return try await searchApplePodcasts(
                        term: trimmed,
                        country: genre.countryCode,
                        genreID: genre.appleGenreID,
                        limit: limit
                    )
                } else {
                    // User typed a genre name: combine genreId browse + direct term search
                    async let byGenre: [PodcastSearchResult] = (try? await searchApplePodcasts(
                        term: genre.defaultBrowseTerm,
                        country: genre.countryCode,
                        genreID: genre.appleGenreID,
                        limit: limit
                    )) ?? []
                    async let byTerm: [PodcastSearchResult] = (try? await searchApplePodcasts(
                        term: trimmed,
                        country: genre.countryCode,
                        genreID: nil,
                        limit: limit
                    )) ?? []
                    return mergeDeduplicated((await byGenre) + (await byTerm))
                }
            }
            return try await searchApplePodcasts(term: trimmed, limit: limit)
        case .gpodder:
            if let tag = activeGenre?.gpodderTag {
                async let byTag: [PodcastSearchResult] = (try? await fetchGPodderTag(tag: tag, limit: limit)) ?? []
                async let byQuery: [PodcastSearchResult] = (try? await searchGPodder(term: trimmed, limit: limit)) ?? []
                return mergeDeduplicated((await byQuery) + (await byTag))
            }
            return try await searchGPodder(term: trimmed, limit: limit)
        case .all:
            let appleGenreID = activeGenre?.appleGenreID
            let country = activeGenre?.countryCode ?? "US"
            let gpodTag = activeGenre?.gpodderTag
            async let applePrimary: [PodcastSearchResult] = (try? await searchApplePodcasts(
                term: trimmed,
                country: country,
                genreID: appleGenreID,
                limit: limit
            )) ?? []
            async let appleGenreBrowse: [PodcastSearchResult] = {
                if let genre = activeGenre, category == nil {
                    return (try? await searchApplePodcasts(
                        term: genre.defaultBrowseTerm,
                        country: genre.countryCode,
                        genreID: genre.appleGenreID,
                        limit: 18
                    )) ?? []
                }
                return []
            }()
            async let gpodderTask: [PodcastSearchResult] = (try? await searchGPodder(term: trimmed, limit: limit)) ?? []
            async let gpodderTagTask: [PodcastSearchResult] = {
                if let tag = gpodTag {
                    return (try? await fetchGPodderTag(tag: tag, limit: 15)) ?? []
                }
                return []
            }()
            return mergeDeduplicated((await applePrimary) + (await appleGenreBrowse) + (await gpodderTask) + (await gpodderTagTask))
        }
    }

    public func browseCategory(_ category: PodcastBrowseCategory, directory: PodcastDirectory = .all) async throws -> [PodcastSearchResult] {
        switch category {
        case .featured:
            return Self.curatedFeaturedShows
        case .topCharts:
            async let gpodTop: [PodcastSearchResult] = (try? await fetchGPodderTop(limit: 20)) ?? []
            async let appleTop: [PodcastSearchResult] = (try? await searchApplePodcasts(term: "podcast", limit: 20)) ?? []
            if directory == .gpodder { return await gpodTop }
            if directory == .apple { return await appleTop }
            return mergeDeduplicated((await appleTop) + (await gpodTop))
        case .nordic:
            async let nrk: [PodcastSearchResult] = (try? await searchApplePodcasts(term: "NRK", country: "NO", limit: 18)) ?? []
            async let norwegian: [PodcastSearchResult] = (try? await searchApplePodcasts(term: "podkast", country: "NO", limit: 18)) ?? []
            return mergeDeduplicated((await nrk) + (await norwegian))
        default:
            switch directory {
            case .curated:
                let key = category.defaultBrowseTerm.lowercased()
                return Self.curatedFeaturedShows.filter {
                    ($0.genre?.lowercased().contains(key) ?? false)
                        || $0.title.lowercased().contains(key)
                }
            case .apple:
                return try await searchApplePodcasts(
                    term: category.defaultBrowseTerm,
                    country: category.countryCode,
                    genreID: category.appleGenreID,
                    limit: 25
                )
            case .gpodder:
                if let tag = category.gpodderTag {
                    let tagged = (try? await fetchGPodderTag(tag: tag, limit: 20)) ?? []
                    if !tagged.isEmpty { return tagged }
                }
                return try await searchGPodder(term: category.defaultBrowseTerm, limit: 20)
            case .all:
                async let appleTask: [PodcastSearchResult] = (try? await searchApplePodcasts(
                    term: category.defaultBrowseTerm,
                    country: category.countryCode,
                    genreID: category.appleGenreID,
                    limit: 25
                )) ?? []
                async let gpodTask: [PodcastSearchResult] = {
                    if let tag = category.gpodderTag {
                        let tagged = (try? await fetchGPodderTag(tag: tag, limit: 15)) ?? []
                        if !tagged.isEmpty { return tagged }
                    }
                    return (try? await searchGPodder(term: category.defaultBrowseTerm, limit: 15)) ?? []
                }()
                return mergeDeduplicated((await appleTask) + (await gpodTask))
            }
        }
    }

    private func searchApplePodcasts(
        term: String,
        country: String = "US",
        genreID: Int? = nil,
        limit: Int = 25
    ) async throws -> [PodcastSearchResult] {
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
        req.setValue("EchoMacOS/1.3", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw NSError(domain: "Echo.Podcast", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Apple Podcasts returned HTTP \(http.statusCode)"])
        }

        let decoded = try JSONDecoder().decode(ITunesSearchResponse.self, from: data)
        var out: [PodcastSearchResult] = []
        for item in decoded.results {
            guard let feed = item.feedUrl, !feed.isEmpty else { continue }
            out.append(PodcastSearchResult(
                title: item.collectionName ?? item.trackName ?? "Untitled Podcast",
                author: item.artistName ?? "Unknown Author",
                feedURL: feed,
                artworkURL: item.artworkUrl600 ?? item.artworkUrl100,
                genre: item.primaryGenreName,
                episodeCount: item.trackCount,
                directorySource: "APPLE"
            ))
        }
        return mergeDeduplicated(out)
    }

    private func searchGPodder(term: String, limit: Int = 20) async throws -> [PodcastSearchResult] {
        var comps = URLComponents(string: "https://gpodder.net/search.json")!
        comps.queryItems = [URLQueryItem(name: "q", value: term)]
        guard let url = comps.url else { return [] }
        return try await fetchGPodderItems(from: url, limit: limit)
    }

    private func fetchGPodderTag(tag: String, limit: Int = 20) async throws -> [PodcastSearchResult] {
        let safeTag = tag.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? tag
        guard let url = URL(string: "https://gpodder.net/api/2/tag/\(safeTag)/\(limit).json") else { return [] }
        return try await fetchGPodderItems(from: url, limit: limit)
    }

    private func fetchGPodderTop(limit: Int = 20) async throws -> [PodcastSearchResult] {
        guard let url = URL(string: "https://gpodder.net/toplist/\(limit).json") else { return [] }
        return try await fetchGPodderItems(from: url, limit: limit)
    }

    private func fetchGPodderItems(from url: URL, limit: Int) async throws -> [PodcastSearchResult] {
        var req = URLRequest(url: url)
        req.timeoutInterval = 10
        req.setValue("EchoMacOS/1.2", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw NSError(domain: "Echo.Podcast", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "gPodder returned HTTP \(http.statusCode)"])
        }

        let decoded = try JSONDecoder().decode([GPodderItem].self, from: data)
        var out: [PodcastSearchResult] = []
        for item in decoded.prefix(limit) {
            guard let feed = item.url, !feed.isEmpty else { continue }
            out.append(PodcastSearchResult(
                title: (item.title?.isEmpty == false ? item.title! : "Untitled Podcast"),
                author: (item.author?.isEmpty == false ? item.author! : "gPodder Directory"),
                feedURL: feed,
                artworkURL: item.scaled_logo_url ?? item.logo_url,
                genre: item.subscribers.map { "\($0) subs" },
                episodeCount: nil,
                directorySource: "GPODDER"
            ))
        }
        return mergeDeduplicated(out)
    }

    private func mergeDeduplicated(_ items: [PodcastSearchResult]) -> [PodcastSearchResult] {
        var seen: Set<String> = []
        var out: [PodcastSearchResult] = []
        for item in items {
            let norm = item.feedURL.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
            if seen.insert(norm).inserted {
                out.append(item)
            }
        }
        return out
    }

    // MARK: - OPML Subscription File Parser

    public static func parseOPMLFeedURLs(data: Data) -> [(title: String?, feedURL: String)] {
        let delegate = OPMLDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        _ = parser.parse()
        return delegate.feeds
    }

    private final class OPMLDelegate: NSObject, XMLParserDelegate {
        var feeds: [(title: String?, feedURL: String)] = []
        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
            guard elementName.lowercased() == "outline" else { return }
            let xmlURL = attributeDict["xmlUrl"] ?? attributeDict["xmlurl"] ?? attributeDict["url"]
            guard let url = xmlURL?.trimmingCharacters(in: .whitespacesAndNewlines), !url.isEmpty else { return }
            let title = attributeDict["title"] ?? attributeDict["text"]
            feeds.append((title, url))
        }
    }

    // MARK: - Fetch & Parse RSS Feed

    public func fetchFeed(
        feedURLString: String,
        existingShow: PodcastShow? = nil,
        fallbackArtworkURL: String? = nil
    ) async throws -> PodcastShow {
        guard let url = URL(string: feedURLString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw NSError(domain: "Echo.Podcast", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid RSS feed URL"])
        }

        var req = URLRequest(url: url)
        req.timeoutInterval = 20
        req.setValue("EchoMacOS/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw NSError(domain: "Echo.Podcast", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Feed returned HTTP \(http.statusCode)"])
        }

        let showID = existingShow?.id ?? UUID()
        var parsed = try PodcastRSSParser.parse(data: data, showID: showID, feedURL: feedURLString)

        // Preserve per-show settings (episodesToKeep) & already-downloaded local file paths
        if let existingShow {
            parsed.episodesToKeep = existingShow.episodesToKeep
            let existingByID = Dictionary(uniqueKeysWithValues: existingShow.episodes.map { ($0.id, $0) })
            for i in parsed.episodes.indices {
                if let prev = existingByID[parsed.episodes[i].id], prev.isDownloaded {
                    parsed.episodes[i].localFilePath = prev.localFilePath
                    if parsed.episodes[i].fileSize == 0 {
                        parsed.episodes[i].fileSize = prev.fileSize
                    }
                }
            }
        }

        // Download and cache show artwork if available
        let artURLStr = parsed.artworkURL ?? fallbackArtworkURL ?? existingShow?.artworkURL
        parsed.artworkURL = artURLStr
        if let existingHash = existingShow?.artworkHash {
            parsed.artworkHash = existingHash
        }
        if parsed.artworkHash == nil, let artURLStr, let artURL = URL(string: artURLStr) {
            if let (imgData, _) = try? await URLSession.shared.data(from: artURL),
               let hash = artworkCache.store(imageData: imgData) {
                parsed.artworkHash = hash
            }
        }

        // Propagate show artwork hash to episodes
        if let showArtHash = parsed.artworkHash {
            for i in parsed.episodes.indices {
                parsed.episodes[i].artworkHash = showArtHash
            }
        }

        parsed.lastRefreshedAt = Date()
        return parsed
    }

    // MARK: - Download Episode Audio Locally

    public func downloadEpisode(_ episode: PodcastEpisode) async throws -> PodcastEpisode {
        if episode.isDownloaded {
            return episode
        }
        guard let url = URL(string: episode.audioURL) else {
            throw NSError(domain: "Echo.Podcast", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid episode audio URL"])
        }

        let showDirName = PathFormatter.sanitizeSegment(episode.showTitle, fallback: "Podcast")
        let showDir = downloadsDirectory.appendingPathComponent(showDirName, isDirectory: true)
        try FileManager.default.createDirectory(at: showDir, withIntermediateDirectories: true)

        let ext = episode.fileExtension.isEmpty ? "mp3" : episode.fileExtension
        let epName = PathFormatter.sanitizeSegment("\(episode.title)_\(episode.id.prefix(6))", fallback: "episode")
        let destURL = showDir.appendingPathComponent("\(epName).\(ext)")

        var req = URLRequest(url: url)
        req.timeoutInterval = 180
        req.setValue("EchoMacOS/1.0", forHTTPHeaderField: "User-Agent")

        let (tempURL, response) = try await URLSession.shared.download(for: req)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            try? FileManager.default.removeItem(at: tempURL)
            throw NSError(domain: "Echo.Podcast", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Episode download failed (HTTP \(http.statusCode))"])
        }

        let fm = FileManager.default
        if fm.fileExists(atPath: destURL.path) {
            try fm.removeItem(at: destURL)
        }
        try fm.moveItem(at: tempURL, to: destURL)

        let attrs = try? fm.attributesOfItem(atPath: destURL.path)
        let actualSize = (attrs?[.size] as? NSNumber)?.int64Value ?? episode.fileSize

        var updated = episode
        updated.localFilePath = destURL.path
        updated.fileSize = actualSize
        return updated
    }

    public func deleteDownloadedEpisode(_ episode: PodcastEpisode) -> PodcastEpisode {
        if let path = episode.localFilePath {
            try? FileManager.default.removeItem(atPath: path)
        }
        var updated = episode
        updated.localFilePath = nil
        return updated
    }
}

// MARK: - Pure-Swift RSS 2.0 / iTunes Podcast XML Parser

public enum PodcastRSSParser {
    public static func parse(data: Data, showID: UUID, feedURL: String) throws -> PodcastShow {
        let delegate = RSSDelegate(showID: showID, feedURL: feedURL)
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldProcessNamespaces = false
        guard parser.parse() else {
            throw parser.parserError ?? NSError(domain: "Echo.PodcastRSS", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse RSS XML"])
        }
        return delegate.buildShow()
    }

    public static func stableEpisodeID(showID: UUID, guidOrURL: String) -> String {
        let input = "\(showID.uuidString)::\(guidOrURL)"
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    public static func parseDuration(_ raw: String) -> TimeInterval {
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

    public static func parseRFC822Date(_ raw: String) -> Date? {
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
        let showID: UUID
        let feedURL: String

        var showTitle = ""
        var showAuthor = ""
        var showDescription = ""
        var showArtworkURL: String?

        var inItem = false
        var inImage = false
        var currentElement = ""
        var buffer = ""

        var itemTitle = ""
        var itemGUID = ""
        var itemSummary = ""
        var itemPubDate = ""
        var itemDuration = ""
        var itemAudioURL = ""
        var itemFileSize: Int64 = 0
        var itemAudioType = ""
        var itemEpisodeNum: Int?
        var itemSeasonNum: Int?

        var episodes: [PodcastEpisode] = []

        init(showID: UUID, feedURL: String) {
            self.showID = showID
            self.feedURL = feedURL
        }

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
            let tag = elementName.lowercased()
            currentElement = tag
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
                itemEpisodeNum = nil
                itemSeasonNum = nil
            } else if tag == "image" && !inItem {
                inImage = true
            } else if tag == "itunes:image" && !inItem {
                if let href = attributeDict["href"], !href.isEmpty {
                    showArtworkURL = href
                }
            } else if tag == "enclosure" && inItem {
                if let url = attributeDict["url"], !url.isEmpty {
                    itemAudioURL = url
                }
                if let lenStr = attributeDict["length"], let len = Int64(lenStr) {
                    itemFileSize = len
                }
                if let mime = attributeDict["type"] {
                    itemAudioType = mime.lowercased()
                }
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
                case "itunes:episode":
                    itemEpisodeNum = Int(text)
                case "itunes:season":
                    itemSeasonNum = Int(text)
                case "item":
                    if !itemAudioURL.isEmpty {
                        let guid = itemGUID.isEmpty ? itemAudioURL : itemGUID
                        let ext = inferExtension(urlStr: itemAudioURL, mime: itemAudioType)
                        let ep = PodcastEpisode(
                            id: PodcastRSSParser.stableEpisodeID(showID: showID, guidOrURL: guid),
                            showID: showID,
                            showTitle: showTitle.isEmpty ? "Podcast" : showTitle,
                            showAuthor: showAuthor,
                            guid: guid,
                            title: itemTitle.isEmpty ? "Untitled Episode" : itemTitle,
                            summary: itemSummary,
                            publishedAt: PodcastRSSParser.parseRFC822Date(itemPubDate),
                            duration: PodcastRSSParser.parseDuration(itemDuration),
                            audioURL: itemAudioURL,
                            fileSize: itemFileSize,
                            fileExtension: ext,
                            episodeNumber: itemEpisodeNum,
                            seasonNumber: itemSeasonNum
                        )
                        episodes.append(ep)
                    }
                    inItem = false
                default:
                    break
                }
            } else if inImage {
                if tag == "url" && showArtworkURL == nil && !text.isEmpty {
                    showArtworkURL = text
                } else if tag == "image" {
                    inImage = false
                }
            } else {
                switch tag {
                case "title":
                    if showTitle.isEmpty { showTitle = text }
                case "itunes:author", "author", "managingeditor":
                    if showAuthor.isEmpty || tag == "itunes:author" { showAuthor = text }
                case "description", "itunes:summary":
                    if showDescription.isEmpty || tag == "itunes:summary" { showDescription = stripHTML(text) }
                default:
                    break
                }
            }
            buffer = ""
        }

        func buildShow() -> PodcastShow {
            let finalTitle = showTitle.isEmpty ? "Untitled Podcast" : showTitle
            let finalAuthor = showAuthor.isEmpty ? finalTitle : showAuthor
            let updatedEpisodes = episodes.map { ep -> PodcastEpisode in
                var copy = ep
                copy.showTitle = finalTitle
                copy.showAuthor = finalAuthor
                return copy
            }
            return PodcastShow(
                id: showID,
                title: finalTitle,
                author: finalAuthor,
                description: showDescription,
                feedURL: feedURL,
                artworkURL: showArtworkURL,
                episodes: updatedEpisodes
            )
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

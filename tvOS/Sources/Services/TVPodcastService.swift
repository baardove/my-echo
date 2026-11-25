import Foundation
import CryptoKit

/// Lightweight pure-Swift RSS parser for refreshing podcast episodes directly on Apple TV without local disk bloat.
actor TVPodcastService {
    private let session: URLSession

    init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 15
        cfg.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: cfg)
    }

    func fetchEpisodes(for feed: TVPodcastFeed) async throws -> [TVPodcastEpisode] {
        guard let url = URL(string: feed.feedURL), !feed.feedURL.isEmpty else { return [] }
        let (data, _) = try await session.data(from: url)
        return try TVPodcastRSSParser.parse(data: data, feed: feed)
    }
}

enum TVPodcastRSSParser {
    static func stableEpisodeID(showID: String, guidOrURL: String) -> String {
        let input = "\(showID)::\(guidOrURL)"
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    static func parse(data: Data, feed: TVPodcastFeed) throws -> [TVPodcastEpisode] {
        let delegate = RSSDelegate(feed: feed)
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldProcessNamespaces = false
        guard parser.parse() else {
            throw parser.parserError ?? NSError(domain: "MyEchoTV.PodcastRSS", code: 1)
        }
        return delegate.episodes
    }

    static func parseDuration(_ raw: String) -> TimeInterval {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let secs = Double(trimmed) { return max(0, secs) }
        let parts = trimmed.split(separator: ":").compactMap { Double($0) }
        if parts.count == 3 { return parts[0] * 3600 + parts[1] * 60 + parts[2] }
        if parts.count == 2 { return parts[0] * 60 + parts[1] }
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
            if let date = formatter.date(from: trimmed) { return date }
        }
        return nil
    }

    private final class RSSDelegate: NSObject, XMLParserDelegate {
        let feed: TVPodcastFeed
        var inItem = false
        var buffer = ""

        var itemTitle = ""
        var itemGUID = ""
        var itemSummary = ""
        var itemPubDate = ""
        var itemDuration = ""
        var itemAudioURL = ""
        var itemFileSize: Int64 = 0

        var episodes: [TVPodcastEpisode] = []

        init(feed: TVPodcastFeed) {
            self.feed = feed
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
            } else if tag == "enclosure" && inItem {
                if let url = attributeDict["url"], !url.isEmpty { itemAudioURL = url }
                if let lenStr = attributeDict["length"], let len = Int64(lenStr) { itemFileSize = len }
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
                        itemSummary = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    }
                case "pubdate":
                    itemPubDate = text
                case "itunes:duration":
                    itemDuration = text
                case "item":
                    inItem = false
                    if !itemAudioURL.isEmpty && episodes.count < 40 {
                        let key = itemGUID.isEmpty ? itemAudioURL : itemGUID
                        let id = TVPodcastRSSParser.stableEpisodeID(showID: feed.id, guidOrURL: key)
                        let ext = URL(string: itemAudioURL)?.pathExtension.lowercased()
                        episodes.append(TVPodcastEpisode(
                            id: id,
                            showID: feed.id,
                            showTitle: feed.title,
                            title: itemTitle.isEmpty ? "Untitled Episode" : itemTitle,
                            summary: itemSummary,
                            publishedAt: TVPodcastRSSParser.parseRFC822Date(itemPubDate),
                            duration: TVPodcastRSSParser.parseDuration(itemDuration),
                            fileSize: itemFileSize,
                            artworkHash: feed.artworkHash,
                            fileExtension: (ext?.isEmpty == false ? ext! : "mp3"),
                            guid: itemGUID.isEmpty ? nil : itemGUID,
                            audioURL: itemAudioURL
                        ))
                    }
                default:
                    break
                }
            }
            buffer = ""
        }
    }
}

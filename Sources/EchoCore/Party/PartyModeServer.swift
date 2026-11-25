import Foundation
import Network
@preconcurrency import Security

// MARK: - Party Mode Wire Models

public enum PartySearchScope: String, Codable, CaseIterable, Sendable {
    case all
    case track
    case artist
    case album

    public init(rawQueryValue: String?) {
        switch rawQueryValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "track", "title": self = .track
        case "artist": self = .artist
        case "album": self = .album
        default: self = .all
        }
    }
}

public struct PartyTrackItem: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var artist: String
    public var album: String
    public var duration: TimeInterval
    public var year: Int?
    public var format: String
    public var artworkHash: String?
    public var inPlaylist: Bool
    public var inUpNext: Bool

    public init(
        id: String,
        title: String,
        artist: String,
        album: String,
        duration: TimeInterval,
        year: Int? = nil,
        format: String = "",
        artworkHash: String? = nil,
        inPlaylist: Bool = false,
        inUpNext: Bool = false
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.year = year
        self.format = format
        self.artworkHash = artworkHash
        self.inPlaylist = inPlaylist
        self.inUpNext = inUpNext
    }

    public init(from track: Track, resolvedAlbumTitle: String? = nil, inPlaylist: Bool = false, inUpNext: Bool = false) {
        self.id = track.id
        self.title = track.title
        self.artist = track.artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? track.effectiveArtist : track.artist
        self.album = (resolvedAlbumTitle?.isEmpty == false ? resolvedAlbumTitle! : track.effectiveAlbum)
        self.duration = track.duration
        self.year = track.year
        self.format = track.format.displayBadge
        self.artworkHash = track.artworkHash
        self.inPlaylist = inPlaylist
        self.inUpNext = inUpNext
    }
}

public struct PartyQueueEntry: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var position: Int
    public var track: PartyTrackItem
    public var isCurrent: Bool
    public var isPlayed: Bool
    public var addedBy: String?
    public var addedByGuestID: String?
    public var addedAt: Date?
    public var plannedPlayAt: Date?
    public var hasVoiceIntro: Bool
    public var voiceIntroDuration: TimeInterval?

    public init(
        position: Int,
        track: PartyTrackItem,
        isCurrent: Bool = false,
        isPlayed: Bool = false,
        addedBy: String? = nil,
        addedByGuestID: String? = nil,
        addedAt: Date? = nil,
        plannedPlayAt: Date? = nil,
        hasVoiceIntro: Bool = false,
        voiceIntroDuration: TimeInterval? = nil
    ) {
        self.id = "\(position):\(track.id)"
        self.position = position
        self.track = track
        self.isCurrent = isCurrent
        self.isPlayed = isPlayed
        self.addedBy = addedBy
        self.addedByGuestID = addedByGuestID
        self.addedAt = addedAt
        self.plannedPlayAt = plannedPlayAt
        self.hasVoiceIntro = hasVoiceIntro
        self.voiceIntroDuration = voiceIntroDuration
    }
}

public struct PartyGuestPresence: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var isActive: Bool
    public var requestCount: Int
    public var firstSeenAt: Date
    public var lastSeenAt: Date

    public init(
        id: String,
        name: String,
        isActive: Bool = true,
        requestCount: Int = 0,
        firstSeenAt: Date = Date(),
        lastSeenAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.isActive = isActive
        self.requestCount = requestCount
        self.firstSeenAt = firstSeenAt
        self.lastSeenAt = lastSeenAt
    }
}

public struct PartyChatMessage: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var guestID: String?
    public var senderName: String
    public var isHost: Bool
    public var text: String
    public var sentAt: Date

    public init(
        id: String = UUID().uuidString,
        guestID: String? = nil,
        senderName: String,
        isHost: Bool = false,
        text: String,
        sentAt: Date = Date()
    ) {
        self.id = id
        self.guestID = guestID
        self.senderName = senderName
        self.isHost = isHost
        self.text = text
        self.sentAt = sentAt
    }
}

public struct PartyChatSendRequest: Codable, Sendable {
    public var guestId: String?
    public var guestName: String?
    public var text: String

    public init(guestId: String? = nil, guestName: String? = nil, text: String) {
        self.guestId = guestId
        self.guestName = guestName
        self.text = text
    }
}

public struct PartyChatSendResponse: Codable, Sendable {
    public var ok: Bool
    public var message: String?
    public var chatMessage: PartyChatMessage?
    public var state: PartyPlaylistState?

    public init(ok: Bool, message: String? = nil, chatMessage: PartyChatMessage? = nil, state: PartyPlaylistState? = nil) {
        self.ok = ok
        self.message = message
        self.chatMessage = chatMessage
        self.state = state
    }
}

public struct PartyIntroUploadResponse: Codable, Sendable {
    public var ok: Bool
    public var message: String
    public var duration: TimeInterval?
    public var state: PartyPlaylistState?

    public init(ok: Bool, message: String, duration: TimeInterval? = nil, state: PartyPlaylistState? = nil) {
        self.ok = ok
        self.message = message
        self.duration = duration
        self.state = state
    }
}

public struct PartyTrackInfoResponse: Codable, Sendable {
    public var ok: Bool
    public var trackId: String
    public var title: String
    public var artist: String
    public var album: String
    public var year: Int?
    public var duration: TimeInterval
    public var format: String
    public var artworkHash: String?
    public var addedBy: String?
    public var releaseDate: String?
    public var label: String?
    public var genres: [String]
    public var albumFans: Int?
    public var albumSummary: String?
    public var albumTrackCount: Int
    public var artistSummary: String?
    public var artistFans: Int?
    public var artistAlbumCount: Int?
    public var artistImageURL: String?
    public var localArtistAlbumCount: Int
    public var localArtistTrackCount: Int

    public init(
        ok: Bool = true,
        trackId: String,
        title: String,
        artist: String,
        album: String,
        year: Int? = nil,
        duration: TimeInterval = 0,
        format: String = "",
        artworkHash: String? = nil,
        addedBy: String? = nil,
        releaseDate: String? = nil,
        label: String? = nil,
        genres: [String] = [],
        albumFans: Int? = nil,
        albumSummary: String? = nil,
        albumTrackCount: Int = 0,
        artistSummary: String? = nil,
        artistFans: Int? = nil,
        artistAlbumCount: Int? = nil,
        artistImageURL: String? = nil,
        localArtistAlbumCount: Int = 0,
        localArtistTrackCount: Int = 0
    ) {
        self.ok = ok
        self.trackId = trackId
        self.title = title
        self.artist = artist
        self.album = album
        self.year = year
        self.duration = duration
        self.format = format
        self.artworkHash = artworkHash
        self.addedBy = addedBy
        self.releaseDate = releaseDate
        self.label = label
        self.genres = genres
        self.albumFans = albumFans
        self.albumSummary = albumSummary
        self.albumTrackCount = albumTrackCount
        self.artistSummary = artistSummary
        self.artistFans = artistFans
        self.artistAlbumCount = artistAlbumCount
        self.artistImageURL = artistImageURL
        self.localArtistAlbumCount = localArtistAlbumCount
        self.localArtistTrackCount = localArtistTrackCount
    }
}

public struct PartyPlaylistState: Codable, Sendable {
    public var playlistName: String
    public var serverName: String
    public var isPlaying: Bool
    public var isPlayingVoiceIntro: Bool
    public var currentTrackID: String?
    public var currentIndex: Int?
    public var currentTime: TimeInterval
    public var duration: TimeInterval
    public var libraryTotalCount: Int
    public var upNextCount: Int
    public var allowReRequestPlayed: Bool
    public var chatEnabled: Bool
    public var streamingEnabled: Bool
    public var maxIntroSeconds: Int
    public var httpsPort: Int?
    public var stateUpdatedAt: Date
    public var revision: Int
    public var tracks: [PartyQueueEntry]
    public var guests: [PartyGuestPresence]
    public var chatMessages: [PartyChatMessage]

    public init(
        playlistName: String = "Partymode",
        serverName: String = "My Echo",
        isPlaying: Bool = false,
        isPlayingVoiceIntro: Bool = false,
        currentTrackID: String? = nil,
        currentIndex: Int? = nil,
        currentTime: TimeInterval = 0,
        duration: TimeInterval = 0,
        libraryTotalCount: Int = 0,
        upNextCount: Int = 0,
        allowReRequestPlayed: Bool = true,
        chatEnabled: Bool = true,
        streamingEnabled: Bool = true,
        maxIntroSeconds: Int = 15,
        httpsPort: Int? = nil,
        stateUpdatedAt: Date = Date(),
        revision: Int = 0,
        tracks: [PartyQueueEntry] = [],
        guests: [PartyGuestPresence] = [],
        chatMessages: [PartyChatMessage] = []
    ) {
        self.playlistName = playlistName
        self.serverName = serverName
        self.isPlaying = isPlaying
        self.isPlayingVoiceIntro = isPlayingVoiceIntro
        self.currentTrackID = currentTrackID
        self.currentIndex = currentIndex
        self.currentTime = currentTime
        self.duration = duration
        self.libraryTotalCount = libraryTotalCount
        self.upNextCount = upNextCount
        self.allowReRequestPlayed = allowReRequestPlayed
        self.chatEnabled = chatEnabled
        self.streamingEnabled = streamingEnabled
        self.maxIntroSeconds = maxIntroSeconds
        self.httpsPort = httpsPort
        self.stateUpdatedAt = stateUpdatedAt
        self.revision = revision
        self.tracks = tracks
        self.guests = guests
        self.chatMessages = chatMessages
    }
}

public struct PartyTrackSearchResponse: Codable, Sendable {
    public var query: String
    public var scope: String
    public var sort: String
    public var totalMatches: Int
    public var offset: Int
    public var limit: Int
    public var hasMore: Bool
    public var tracks: [PartyTrackItem]

    public init(
        query: String,
        scope: String,
        sort: String,
        totalMatches: Int,
        offset: Int,
        limit: Int,
        hasMore: Bool,
        tracks: [PartyTrackItem]
    ) {
        self.query = query
        self.scope = scope
        self.sort = sort
        self.totalMatches = totalMatches
        self.offset = offset
        self.limit = limit
        self.hasMore = hasMore
        self.tracks = tracks
    }
}

public struct PartyAddTrackRequest: Codable, Sendable {
    public var trackId: String
    public var guestName: String?
    public var guestId: String?

    public init(trackId: String, guestName: String? = nil, guestId: String? = nil) {
        self.trackId = trackId
        self.guestName = guestName
        self.guestId = guestId
    }
}

public struct PartyRenameGuestRequest: Codable, Sendable {
    public var guestId: String
    public var guestName: String?

    public init(guestId: String, guestName: String? = nil) {
        self.guestId = guestId
        self.guestName = guestName
    }
}

public struct PartyRenameGuestResponse: Codable, Sendable {
    public var ok: Bool
    public var updatedCount: Int
    public var guestName: String
    public var state: PartyPlaylistState?

    public init(ok: Bool, updatedCount: Int = 0, guestName: String, state: PartyPlaylistState? = nil) {
        self.ok = ok
        self.updatedCount = updatedCount
        self.guestName = guestName
        self.state = state
    }
}

public struct PartyAddTrackResponse: Codable, Sendable {
    public var ok: Bool
    public var alreadyQueued: Bool
    public var message: String
    public var position: Int?
    public var track: PartyTrackItem?
    public var state: PartyPlaylistState?

    public init(
        ok: Bool,
        alreadyQueued: Bool = false,
        message: String,
        position: Int? = nil,
        track: PartyTrackItem? = nil,
        state: PartyPlaylistState? = nil
    ) {
        self.ok = ok
        self.alreadyQueued = alreadyQueued
        self.message = message
        self.position = position
        self.track = track
        self.state = state
    }
}

// MARK: - Fast Track-Focused Search Catalog

public struct PartyTrackCatalog: Sendable {
    private struct IndexedTrack: Sendable {
        let track: Track
        let displayArtist: String
        let displayAlbum: String
        let titleLower: String
        let artistLower: String
        let albumArtistLower: String
        let albumLower: String
        let genreLower: String
        let yearString: String
        let arrivalEpoch: TimeInterval
    }

    private let entries: [IndexedTrack]
    private let sortedByTitle: [Int]
    private let sortedByRecent: [Int]

    public var count: Int { entries.count }

    public init(tracks: [Track] = []) {
        let available = tracks.filter(\.isAvailable)
        var built: [IndexedTrack] = []
        built.reserveCapacity(available.count)
        for t in available {
            let dispArtist = t.artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? t.effectiveArtist : t.artist
            let dispAlbum = t.effectiveAlbum
            built.append(IndexedTrack(
                track: t,
                displayArtist: dispArtist,
                displayAlbum: dispAlbum,
                titleLower: t.title.lowercased(),
                artistLower: dispArtist.lowercased(),
                albumArtistLower: t.albumArtist.lowercased(),
                albumLower: dispAlbum.lowercased(),
                genreLower: (t.genre ?? "").lowercased(),
                yearString: t.year.map(String.init) ?? "",
                arrivalEpoch: t.arrivalDate.timeIntervalSince1970
            ))
        }
        self.entries = built

        let allIndices = Array(built.indices)
        self.sortedByTitle = allIndices.sorted { a, b in
            let ea = built[a]
            let eb = built[b]
            if ea.titleLower != eb.titleLower { return ea.titleLower < eb.titleLower }
            if ea.artistLower != eb.artistLower { return ea.artistLower < eb.artistLower }
            return ea.albumLower < eb.albumLower
        }
        self.sortedByRecent = allIndices.sorted { a, b in
            let ea = built[a]
            let eb = built[b]
            if abs(ea.arrivalEpoch - eb.arrivalEpoch) > 1.0 { return ea.arrivalEpoch > eb.arrivalEpoch }
            return ea.titleLower < eb.titleLower
        }
    }

    public func search(
        query: String,
        scope: PartySearchScope = .all,
        sort: String = "title",
        seed: UInt64 = 0,
        offset: Int = 0,
        limit: Int = 50,
        playlistTrackIDs: Set<String> = [],
        upNextTrackIDs: Set<String> = []
    ) -> PartyTrackSearchResponse {
        let clampedOffset = max(0, offset)
        let clampedLimit = max(1, min(150, limit))
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSort = sort.lowercased()

        let parsed = SearchQueryTerms.parse(trimmed)

        // Empty query (or only standalone operators) -> browsable track list (A-Z, Recently Added, or Deterministic Shuffle)
        if parsed.isEmpty {
            let orderedIndices: [Int]
            switch normalizedSort {
            case "recent":
                orderedIndices = sortedByRecent
            case "shuffle":
                orderedIndices = Array(entries.indices).sorted { a, b in
                    Self.stableMixHash(entries[a].track.id, seed: seed) < Self.stableMixHash(entries[b].track.id, seed: seed)
                }
            default:
                orderedIndices = sortedByTitle
            }

            let total = orderedIndices.count
            let start = min(clampedOffset, total)
            let end = min(start + clampedLimit, total)
            let slice = orderedIndices[start..<end].map { idx -> PartyTrackItem in
                let entry = entries[idx]
                return PartyTrackItem(
                    from: entry.track,
                    resolvedAlbumTitle: entry.displayAlbum,
                    inPlaylist: playlistTrackIDs.contains(entry.track.id),
                    inUpNext: upNextTrackIDs.contains(entry.track.id)
                )
            }
            return PartyTrackSearchResponse(
                query: "",
                scope: scope.rawValue,
                sort: normalizedSort,
                totalMatches: total,
                offset: start,
                limit: clampedLimit,
                hasMore: end < total,
                tracks: slice
            )
        }

        var scored: [(index: Int, score: Int)] = []
        scored.reserveCapacity(min(entries.count, 256))

        for (idx, entry) in entries.enumerated() {
            let score = Self.matchScore(entry: entry, terms: parsed, scope: scope)
            if score > 0 {
                scored.append((idx, score))
            }
        }

        scored.sort { a, b in
            if a.score != b.score { return a.score > b.score }
            let ea = entries[a.index]
            let eb = entries[b.index]
            if ea.titleLower != eb.titleLower { return ea.titleLower < eb.titleLower }
            if ea.artistLower != eb.artistLower { return ea.artistLower < eb.artistLower }
            return ea.albumLower < eb.albumLower
        }

        let total = scored.count
        let start = min(clampedOffset, total)
        let end = min(start + clampedLimit, total)
        let page = scored[start..<end].map { item -> PartyTrackItem in
            let entry = entries[item.index]
            return PartyTrackItem(
                from: entry.track,
                resolvedAlbumTitle: entry.displayAlbum,
                inPlaylist: playlistTrackIDs.contains(entry.track.id),
                inUpNext: upNextTrackIDs.contains(entry.track.id)
            )
        }

        return PartyTrackSearchResponse(
            query: trimmed,
            scope: scope.rawValue,
            sort: normalizedSort,
            totalMatches: total,
            offset: start,
            limit: clampedLimit,
            hasMore: end < total,
            tracks: page
        )
    }

    private static func matchScore(
        entry: IndexedTrack,
        terms: SearchQueryTerms,
        scope: PartySearchScope
    ) -> Int {
        guard !terms.isEmpty else { return 0 }

        let values = SearchFieldValues(
            track: entry.titleLower,
            artist: entry.artistLower,
            albumArtist: entry.albumArtistLower,
            album: entry.albumLower,
            genre: entry.genreLower,
            year: entry.yearString,
            format: entry.track.format.displayBadge.lowercased()
        )

        // Exclude any track matching any "-keyword" or "-field:keyword"
        for ex in terms.excludeClauses {
            if values.contains(ex.text, in: ex.field) {
                return 0
            }
        }

        // Pure exclusion query (e.g. "-live")
        let clauses = terms.includeClauses
        guard !clauses.isEmpty else { return 100 }
        let fullQuery = terms.positivePhrase

        let scopeField: SearchField? = {
            switch scope {
            case .all: return nil
            case .track: return .track
            case .artist: return .artist
            case .album: return .album
            }
        }()

        var titleHits = 0
        var artistHits = 0
        var albumHits = 0
        var metaHits = 0
        var requiredBonus = 0
        var fieldSpecificBonus = 0

        for clause in clauses {
            let targetField = clause.field ?? scopeField
            guard values.contains(clause.text, in: targetField) else { return 0 }

            if clause.field != nil { fieldSpecificBonus += 40 }
            if clause.isRequired { requiredBonus += 25 }

            if let tf = targetField {
                switch tf {
                case .track: titleHits += 1
                case .artist: artistHits += 1
                case .album: albumHits += 1
                case .genre, .year, .format, .rating: metaHits += 1
                }
            } else {
                if entry.titleLower.contains(clause.text) { titleHits += 1 }
                if entry.artistLower.contains(clause.text) || entry.albumArtistLower.contains(clause.text) { artistHits += 1 }
                if entry.albumLower.contains(clause.text) { albumHits += 1 }
                if entry.genreLower.contains(clause.text) || (!entry.yearString.isEmpty && entry.yearString.contains(clause.text)) {
                    metaHits += 1
                }
            }
        }

        // Track-focused relevance ranking: exact/title matches rise above artist & album matches
        if !fullQuery.isEmpty && clauses.allSatisfy({ $0.field == nil }) {
            if entry.titleLower == fullQuery { return 1000 + requiredBonus }
            if entry.titleLower.hasPrefix(fullQuery) { return 860 + requiredBonus }
            if entry.titleLower.contains(fullQuery) { return 720 + requiredBonus }
            if titleHits == clauses.count { return 640 + requiredBonus }
            if entry.artistLower == fullQuery { return 540 + requiredBonus }
            if entry.artistLower.hasPrefix(fullQuery) { return 480 + requiredBonus }
            if entry.artistLower.contains(fullQuery) { return 420 + requiredBonus }
            if entry.albumLower == fullQuery { return 360 + requiredBonus }
            if entry.albumLower.hasPrefix(fullQuery) { return 320 + requiredBonus }
            if entry.albumLower.contains(fullQuery) { return 280 + requiredBonus }
        }

        let crossFieldBonus = (titleHits > 0 && artistHits > 0) ? 140 : 0
        return 220 + crossFieldBonus + fieldSpecificBonus + requiredBonus + titleHits * 35 + artistHits * 20 + albumHits * 10 + metaHits * 5
    }

    private static func stableMixHash(_ id: String, seed: UInt64) -> UInt64 {
        var h: UInt64 = 14695981039346656037 ^ seed
        for byte in id.utf8 {
            h ^= UInt64(byte)
            h = h &* 1099511628211
        }
        return h
    }
}

// MARK: - Party Mode Embedded HTTP/1.1 Web Server (Random Port)

public final class PartyModeServer: @unchecked Sendable {
    private let artworkCache: ArtworkCache
    private let queue = DispatchQueue(label: "com.myecho.party-mode-server", qos: .userInitiated)
    private let lock = NSLock()

    private var listener: NWListener?
    private var httpsListener: NWListener?
    private var catalog = PartyTrackCatalog()
    private var trackFilePathsByID: [String: String] = [:]
    private var playlistState = PartyPlaylistState()
    private var playlistTrackIDs: Set<String> = []
    private var upNextTrackIDs: Set<String> = []

    private struct GuestPresenceRecord {
        var id: String
        var name: String
        var requestCount: Int
        var firstSeenAt: Date
        var lastSeenAt: Date
    }
    private var guestsByID: [String: GuestPresenceRecord] = [:]
    public static let guestActiveWindowSeconds: TimeInterval = 15

    public private(set) var listeningPort: UInt16 = 0
    public private(set) var httpsListeningPort: UInt16 = 0
    public private(set) var isRunning: Bool = false

    public var onStatusChanged: (@Sendable (_ isRunning: Bool, _ port: UInt16, _ lanIP: String?, _ errorMessage: String?) -> Void)?
    public var onAddTrack: (@Sendable (_ trackID: String, _ guestName: String?, _ guestID: String?) async -> PartyAddTrackResponse)?
    public var onRenameGuest: (@Sendable (_ guestID: String, _ guestName: String?) async -> PartyRenameGuestResponse)?
    public var onSendChatMessage: (@Sendable (_ guestID: String?, _ guestName: String?, _ text: String) async -> PartyChatSendResponse)?
    public var onUploadVoiceIntro: (@Sendable (_ trackID: String, _ guestID: String?, _ guestName: String?, _ audioData: Data, _ fileExtension: String) async -> PartyIntroUploadResponse)?
    public var onDeleteVoiceIntro: (@Sendable (_ trackID: String, _ guestID: String?) async -> PartyIntroUploadResponse)?
    public var onFetchTrackInfo: (@Sendable (_ trackID: String) async -> PartyTrackInfoResponse?)?
    public var onGuestsChanged: (@Sendable ([PartyGuestPresence]) -> Void)?

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    public init(artworkCache: ArtworkCache) {
        self.artworkCache = artworkCache
    }

    public func updateLibrary(tracks: [Track]) {
        let newCatalog = PartyTrackCatalog(tracks: tracks)
        var paths: [String: String] = [:]
        paths.reserveCapacity(tracks.count)
        for t in tracks where t.isAvailable {
            paths[t.id] = t.filePath
        }
        lock.lock()
        catalog = newCatalog
        trackFilePathsByID = paths
        playlistState.libraryTotalCount = newCatalog.count
        lock.unlock()
    }

    public func updatePlaylistState(_ state: PartyPlaylistState) {
        let allIDs = Set(state.tracks.map(\.track.id))
        let upcomingIDs = Set(state.tracks.filter { !$0.isPlayed }.map(\.track.id))
        lock.lock()
        var next = state
        if next.libraryTotalCount == 0 {
            next.libraryTotalCount = catalog.count
        }
        playlistState = next
        playlistTrackIDs = allIDs
        upNextTrackIDs = upcomingIDs
        lock.unlock()
    }

    public func currentPlaylistState() -> PartyPlaylistState {
        let now = Date()
        lock.lock()
        var copy = playlistState
        if copy.isPlaying && copy.currentTrackID != nil {
            let elapsed = max(0, now.timeIntervalSince(copy.stateUpdatedAt))
            let ceiling = copy.duration > 0 ? copy.duration : (copy.currentTime + elapsed)
            copy.currentTime = min(ceiling, copy.currentTime + elapsed)
            copy.stateUpdatedAt = now
        }
        copy.guests = buildGuestPresenceLocked(now: now)
        let tlsPort = httpsListeningPort
        copy.httpsPort = tlsPort > 0 ? Int(tlsPort) : nil
        lock.unlock()
        return copy
    }

    public func currentHTTPSPort() -> Int? {
        lock.lock()
        let p = httpsListeningPort
        lock.unlock()
        return p > 0 ? Int(p) : nil
    }

    public func snapshotGuests(now: Date = Date()) -> [PartyGuestPresence] {
        lock.lock()
        defer { lock.unlock() }
        return buildGuestPresenceLocked(now: now)
    }

    public func renameGuestPresence(guestID: String, newName: String) {
        let now = Date()
        let updated: [PartyGuestPresence]
        lock.lock()
        if var existing = guestsByID[guestID] {
            existing.name = newName
            existing.lastSeenAt = now
            guestsByID[guestID] = existing
        } else {
            guestsByID[guestID] = GuestPresenceRecord(
                id: guestID,
                name: newName,
                requestCount: 0,
                firstSeenAt: now,
                lastSeenAt: now
            )
        }
        updated = buildGuestPresenceLocked(now: now)
        lock.unlock()
        onGuestsChanged?(updated)
    }

    public func clearGuestPresence() {
        lock.lock()
        guestsByID.removeAll()
        lock.unlock()
        onGuestsChanged?([])
    }

    @discardableResult
    private func touchGuestPresence(guestID: String?, guestName: String?, incrementRequests: Bool = false) -> [PartyGuestPresence]? {
        guard let id = Self.sanitizeGuestID(guestID) else { return nil }
        let cleanName = Self.sanitizeGuestName(guestName)
        let now = Date()
        var shouldNotify = false
        let snapshot: [PartyGuestPresence]

        lock.lock()
        if var existing = guestsByID[id] {
            let wasActive = now.timeIntervalSince(existing.lastSeenAt) <= Self.guestActiveWindowSeconds
            if let cleanName, existing.name != cleanName {
                existing.name = cleanName
                shouldNotify = true
            }
            if incrementRequests {
                existing.requestCount += 1
                shouldNotify = true
            }
            if !wasActive {
                shouldNotify = true
            }
            existing.lastSeenAt = now
            guestsByID[id] = existing
        } else {
            guestsByID[id] = GuestPresenceRecord(
                id: id,
                name: cleanName ?? "Guest",
                requestCount: incrementRequests ? 1 : 0,
                firstSeenAt: now,
                lastSeenAt: now
            )
            shouldNotify = true
        }
        snapshot = buildGuestPresenceLocked(now: now)
        lock.unlock()

        if shouldNotify {
            onGuestsChanged?(snapshot)
        }
        return snapshot
    }

    private func buildGuestPresenceLocked(now: Date) -> [PartyGuestPresence] {
        guestsByID.values.map { rec in
            let active = now.timeIntervalSince(rec.lastSeenAt) <= Self.guestActiveWindowSeconds
            return PartyGuestPresence(
                id: rec.id,
                name: rec.name,
                isActive: active,
                requestCount: rec.requestCount,
                firstSeenAt: rec.firstSeenAt,
                lastSeenAt: rec.lastSeenAt
            )
        }.sorted { a, b in
            if a.isActive != b.isActive { return a.isActive }
            if abs(a.lastSeenAt.timeIntervalSince(b.lastSeenAt)) > 1.0 {
                return a.lastSeenAt > b.lastSeenAt
            }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    /// Starts the Party Mode web server on a specific preferred port (or a random OS-assigned port when `nil`/0).
    /// When `fallbackToRandomIfBusy` is true, falls back to a free OS port if the remembered port is already in use.
    public func start(preferredPort: UInt16? = nil, fallbackToRandomIfBusy: Bool = false) {
        queue.async { [weak self] in
            guard let self else { return }
            if self.listener != nil {
                if let target = preferredPort, target > 0, self.listeningPort != target {
                    self.stopListenerOnQueue()
                } else {
                    return
                }
            }
            self.startListenerOnQueue(preferredPort: preferredPort, fallbackToRandomIfBusy: fallbackToRandomIfBusy)
        }
    }

    /// Stops any active listener and immediately starts a fresh one on `preferredPort` (or a new random port when `nil`).
    public func restart(preferredPort: UInt16? = nil, fallbackToRandomIfBusy: Bool = false) {
        queue.async { [weak self] in
            guard let self else { return }
            self.stopListenerOnQueue()
            self.startListenerOnQueue(preferredPort: preferredPort, fallbackToRandomIfBusy: fallbackToRandomIfBusy)
        }
    }

    /// Stops any active listener and immediately starts a fresh one on a new random port.
    public func restartOnNewRandomPort() {
        restart(preferredPort: nil)
    }

    public func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.stopListenerOnQueue()
            self.onStatusChanged?(false, 0, nil, nil)
        }
    }

    private func stopListenerOnQueue() {
        self.listener?.stateUpdateHandler = nil
        self.listener?.newConnectionHandler = nil
        self.listener?.cancel()
        self.listener = nil
        self.httpsListener?.stateUpdateHandler = nil
        self.httpsListener?.newConnectionHandler = nil
        self.httpsListener?.cancel()
        self.httpsListener = nil
        self.isRunning = false
        self.listeningPort = 0
        lock.lock()
        self.httpsListeningPort = 0
        lock.unlock()
    }

    private func startListenerOnQueue(preferredPort: UInt16? = nil, fallbackToRandomIfBusy: Bool = false) {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true

        do {
            let nwListener: NWListener
            if let requested = preferredPort, requested > 0,
               let nwPort = NWEndpoint.Port(rawValue: requested) {
                nwListener = try NWListener(using: params, on: nwPort)
            } else {
                // Port omitted => OS assigns a guaranteed-free random ephemeral port
                nwListener = try NWListener(using: params)
            }

            nwListener.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                switch state {
                case .ready:
                    let boundPort = nwListener.port?.rawValue ?? preferredPort ?? 0
                    self.listeningPort = boundPort
                    self.isRunning = boundPort > 0
                    let lanIP = WirelessSyncServer.localLANIPAddress()
                    self.onStatusChanged?(self.isRunning, boundPort, lanIP, nil)
                    if boundPort > 0 {
                        let preferredHTTPSPort: UInt16 = boundPort < 65_535 ? (boundPort + 1) : (boundPort - 1)
                        self.startCompanionHTTPSListenerAsync(preferredPort: preferredHTTPSPort)
                    }
                case .failed(let err):
                    self.isRunning = false
                    self.listeningPort = 0
                    self.listener?.stateUpdateHandler = nil
                    self.listener?.newConnectionHandler = nil
                    self.listener?.cancel()
                    self.listener = nil
                    if fallbackToRandomIfBusy, preferredPort != nil {
                        self.startListenerOnQueue(preferredPort: nil, fallbackToRandomIfBusy: false)
                        return
                    }
                    let detail = preferredPort.map { "Port \($0) unavailable (\(err.localizedDescription))" } ?? err.localizedDescription
                    self.onStatusChanged?(false, 0, nil, detail)
                case .cancelled:
                    self.isRunning = false
                    self.listeningPort = 0
                    self.onStatusChanged?(false, 0, nil, nil)
                default:
                    break
                }
            }

            nwListener.newConnectionHandler = { [weak self] conn in
                self?.handleConnection(conn)
            }

            self.listener = nwListener
            nwListener.start(queue: self.queue)
        } catch {
            self.isRunning = false
            self.listeningPort = 0
            if fallbackToRandomIfBusy, preferredPort != nil {
                self.startListenerOnQueue(preferredPort: nil, fallbackToRandomIfBusy: false)
                return
            }
            let detail = preferredPort.map { "Port \($0) unavailable (\(error.localizedDescription))" } ?? error.localizedDescription
            self.onStatusChanged?(false, 0, nil, detail)
        }
    }

    /// Starts a companion TLS/HTTPS listener (preferring `httpPort + 1` so Safari remembers the local cert across restarts,
    /// falling back to any free port if busy). Allows iPhone / Android Safari & Chrome guests to use live `getUserMedia`
    /// microphone recording for voice intros without breaking the frictionless HTTP QR code URL.
    private func startCompanionHTTPSListenerAsync(preferredPort: UInt16?) {
        let lanIP = WirelessSyncServer.localLANIPAddress()
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let p12Data = Self.loadOrCreateSelfSignedPKCS12Data(lanIP: lanIP) else { return }
            guard let self else { return }
            self.queue.async { [weak self] in
                guard let self, self.listener != nil else { return }
                guard let secIdentity = Self.importPKCS12Identity(data: p12Data, passphrase: Self.tlsPassphrase) else { return }
                self.startHTTPSListenerOnQueue(secIdentity: secIdentity, preferredPort: preferredPort)
            }
        }
    }

    private func startHTTPSListenerOnQueue(secIdentity: sec_identity_t, preferredPort: UInt16?) {
        self.httpsListener?.stateUpdateHandler = nil
        self.httpsListener?.newConnectionHandler = nil
        self.httpsListener?.cancel()
        self.httpsListener = nil

        let tlsOptions = NWProtocolTLS.Options()
        sec_protocol_options_set_min_tls_protocol_version(tlsOptions.securityProtocolOptions, .TLSv12)
        sec_protocol_options_set_local_identity(tlsOptions.securityProtocolOptions, secIdentity)
        let tcpOptions = NWProtocolTCP.Options()
        let params = NWParameters(tls: tlsOptions, tcp: tcpOptions)
        params.allowLocalEndpointReuse = true

        let tlsListener: NWListener?
        if let preferredPort, preferredPort > 0, let nwPort = NWEndpoint.Port(rawValue: preferredPort) {
            tlsListener = try? NWListener(using: params, on: nwPort)
        } else {
            tlsListener = try? NWListener(using: params)
        }
        guard let tlsListener else {
            if preferredPort != nil {
                startHTTPSListenerOnQueue(secIdentity: secIdentity, preferredPort: nil)
            }
            return
        }

        tlsListener.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                let port = tlsListener.port?.rawValue ?? preferredPort ?? 0
                self.lock.lock()
                self.httpsListeningPort = port
                self.lock.unlock()
            case .failed:
                self.lock.lock()
                self.httpsListeningPort = 0
                self.lock.unlock()
                if preferredPort != nil, self.listener != nil {
                    self.startHTTPSListenerOnQueue(secIdentity: secIdentity, preferredPort: nil)
                }
            case .cancelled:
                self.lock.lock()
                self.httpsListeningPort = 0
                self.lock.unlock()
            default:
                break
            }
        }
        tlsListener.newConnectionHandler = { [weak self] conn in
            self?.handleConnection(conn)
        }
        self.httpsListener = tlsListener
        tlsListener.start(queue: self.queue)
    }

    private static let tlsPassphrase = "myecho-party-tls"

    private static func loadOrCreateSelfSignedPKCS12Data(lanIP: String?) -> Data? {
        guard let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        let tlsDir = cachesDir.appendingPathComponent("Echo/PartyTLS", isDirectory: true)
        try? FileManager.default.createDirectory(at: tlsDir, withIntermediateDirectories: true)

        let ipKey = (lanIP ?? "local").replacingOccurrences(of: ":", with: "_")
        let p12URL = tlsDir.appendingPathComponent("party-\(ipKey).p12")

        if let existing = try? Data(contentsOf: p12URL), !existing.isEmpty {
            return existing
        }

        let opensslPath = FileManager.default.isExecutableFile(atPath: "/usr/bin/openssl")
            ? "/usr/bin/openssl"
            : "/opt/homebrew/bin/openssl"
        guard FileManager.default.isExecutableFile(atPath: opensslPath) else { return nil }

        let tmpDir = tlsDir.appendingPathComponent("gen-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let keyURL = tmpDir.appendingPathComponent("key.pem")
        let crtURL = tmpDir.appendingPathComponent("cert.pem")
        let cnfURL = tmpDir.appendingPathComponent("san.cnf")

        var sanEntries = ["IP:127.0.0.1", "DNS:localhost"]
        if let lanIP, !lanIP.isEmpty {
            sanEntries.insert("IP:\(lanIP)", at: 0)
        }
        let conf = """
        [req]
        distinguished_name = dn
        x509_extensions = v3_ext
        prompt = no
        [dn]
        CN = My Echo Partymode
        [v3_ext]
        basicConstraints = CA:FALSE
        keyUsage = digitalSignature, keyEncipherment
        extendedKeyUsage = serverAuth
        subjectAltName = \(sanEntries.joined(separator: ","))
        """
        do {
            try conf.write(to: cnfURL, atomically: true, encoding: .utf8)
        } catch {
            return nil
        }

        func runOpenSSL(_ args: [String]) -> Bool {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: opensslPath)
            proc.arguments = args
            proc.standardOutput = FileHandle.nullDevice
            proc.standardError = FileHandle.nullDevice
            do {
                try proc.run()
                proc.waitUntilExit()
                return proc.terminationStatus == 0
            } catch {
                return false
            }
        }

        guard runOpenSSL([
            "req", "-x509", "-newkey", "rsa:2048", "-sha256",
            "-days", "365", "-nodes",
            "-keyout", keyURL.path,
            "-out", crtURL.path,
            "-config", cnfURL.path
        ]) else { return nil }

        guard runOpenSSL([
            "pkcs12", "-export",
            "-out", p12URL.path,
            "-inkey", keyURL.path,
            "-in", crtURL.path,
            "-passout", "pass:\(tlsPassphrase)"
        ]) else { return nil }

        return try? Data(contentsOf: p12URL)
    }

    private static func importPKCS12Identity(data: Data, passphrase: String) -> sec_identity_t? {
        var items: CFArray?
        let opts: [String: Any] = [kSecImportExportPassphrase as String: passphrase]
        let status = SecPKCS12Import(data as CFData, opts as CFDictionary, &items)
        guard status == errSecSuccess,
              let array = items as? [[String: Any]],
              let rawIdentity = array.first?[kSecImportItemIdentity as String] else {
            return nil
        }
        // CoreFoundation type bridging guarantees SecIdentity for kSecImportItemIdentity
        let secIdentity = unsafeBitCast(rawIdentity as AnyObject, to: SecIdentity.self)
        return sec_identity_create(secIdentity)
    }

    // MARK: - HTTP Connection Handling

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveHTTPRequest(on: connection, buffer: Data())
    }

    private func receiveHTTPRequest(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if error != nil {
                connection.cancel()
                return
            }
            var accumulated = buffer
            if let data { accumulated.append(data) }

            let delimiter = Data("\r\n\r\n".utf8)
            if let range = accumulated.range(of: delimiter) {
                let headerData = accumulated[..<range.lowerBound]
                let bodyStart = range.upperBound
                let headerStr = String(data: headerData, encoding: .utf8) ?? ""
                let parsed = Self.parseHTTPHeaders(headerStr)
                let contentLength = max(0, Int(parsed.headers["content-length"] ?? "0") ?? 0)
                let isIntroUpload = parsed.target.hasPrefix("/api/party/intro")
                let maxAllowedBody = isIntroUpload ? 6_291_456 : 65_536
                if contentLength > maxAllowedBody {
                    self.sendJSONError(connection: connection, status: 413, message: "Request body too large")
                    return
                }
                let currentBodyCount = accumulated.count - bodyStart
                if currentBodyCount >= contentLength || isComplete {
                    let bodyData = accumulated.subdata(in: bodyStart..<min(accumulated.count, bodyStart + contentLength))
                    self.routeRequest(
                        method: parsed.method,
                        rawTarget: parsed.target,
                        headers: parsed.headers,
                        body: bodyData,
                        connection: connection
                    )
                    return
                }
            }

            if isComplete || accumulated.count > 6_500_000 {
                self.sendJSONError(connection: connection, status: 400, message: "Malformed HTTP request")
            } else {
                self.receiveHTTPRequest(on: connection, buffer: accumulated)
            }
        }
    }

    private static func parseHTTPHeaders(_ raw: String) -> (method: String, target: String, headers: [String: String]) {
        let lines = raw.components(separatedBy: "\r\n")
        let reqParts = (lines.first ?? "").split(separator: " ")
        let method = reqParts.first.map(String.init)?.uppercased() ?? "GET"
        let target = reqParts.count > 1 ? String(reqParts[1]) : "/"
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            if let colon = line.firstIndex(of: ":") {
                let key = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
                let val = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                headers[key] = val
            }
        }
        return (method, target, headers)
    }

    private func routeRequest(
        method: String,
        rawTarget: String,
        headers: [String: String],
        body: Data,
        connection: NWConnection
    ) {
        if method == "OPTIONS" {
            sendRawResponse(
                connection: connection,
                status: 204,
                statusText: "No Content",
                contentType: "text/plain; charset=utf-8",
                data: Data()
            )
            return
        }

        let comps = URLComponents(string: "http://localhost" + rawTarget)
        let path = comps?.path ?? "/"
        let queryItems = comps?.queryItems ?? []
        var queryMap: [String: String] = [:]
        for item in queryItems {
            if let value = item.value {
                queryMap[item.name] = value
            }
        }

        // 1. Guest Web UI
        if method == "GET" && (path == "/" || path == "/index.html") {
            let html = PartyModeWebUI.htmlDocument()
            sendRawResponse(
                connection: connection,
                status: 200,
                statusText: "OK",
                contentType: "text/html; charset=utf-8",
                data: Data(html.utf8),
                cacheControl: "no-store"
            )
            return
        }

        // 2. Current Party Mode & Partymode Playlist State (also acts as guest presence heartbeat)
        if method == "GET" && path == "/api/party/state" {
            _ = touchGuestPresence(guestID: queryMap["guestId"], guestName: queryMap["guestName"], incrementRequests: false)
            let state = currentPlaylistState()
            sendJSON(connection: connection, value: state)
            return
        }

        // 3. Search / Browse Track Library
        if method == "GET" && path == "/api/party/tracks" {
            let q = queryMap["q"] ?? ""
            let scope = PartySearchScope(rawQueryValue: queryMap["scope"])
            let sort = queryMap["sort"] ?? "title"
            let seed = UInt64(queryMap["seed"] ?? "0") ?? 0
            let offset = max(0, Int(queryMap["offset"] ?? "0") ?? 0)
            let limit = max(1, min(150, Int(queryMap["limit"] ?? "50") ?? 50))

            lock.lock()
            let currentCatalog = catalog
            let plIDs = playlistTrackIDs
            let upcomingIDs = upNextTrackIDs
            lock.unlock()

            let response = currentCatalog.search(
                query: q,
                scope: scope,
                sort: sort,
                seed: seed,
                offset: offset,
                limit: limit,
                playlistTrackIDs: plIDs,
                upNextTrackIDs: upcomingIDs
            )
            sendJSON(connection: connection, value: response)
            return
        }

        // 4. Add Track to Dynamic "Partymode" Playlist
        if method == "POST" && path == "/api/party/add" {
            guard let req = try? decoder.decode(PartyAddTrackRequest.self, from: body),
                  !req.trackId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                sendJSONError(connection: connection, status: 400, message: "Missing or invalid trackId")
                return
            }
            guard let handler = onAddTrack else {
                sendJSONError(connection: connection, status: 503, message: "Party Mode host handler is not ready")
                return
            }

            let sanitizedGuest = Self.sanitizeGuestName(req.guestName)
            let sanitizedGuestID = Self.sanitizeGuestID(req.guestId)
            _ = touchGuestPresence(guestID: sanitizedGuestID, guestName: sanitizedGuest, incrementRequests: true)
            let trackID = req.trackId
            Task { [weak self] in
                var response = await handler(trackID, sanitizedGuest, sanitizedGuestID)
                guard let server = self else { return }
                if response.state != nil {
                    response.state?.guests = server.snapshotGuests()
                    response.state?.httpsPort = server.currentHTTPSPort()
                }
                let finalResponse = response
                server.queue.async {
                    let status = finalResponse.ok ? 200 : (finalResponse.alreadyQueued ? 200 : 400)
                    server.sendJSON(connection: connection, value: finalResponse, status: status)
                }
            }
            return
        }

        // 4b. Rename Guest (updates all requests & chat messages previously made by this guestId)
        if method == "POST" && path == "/api/party/guest/rename" {
            guard let req = try? decoder.decode(PartyRenameGuestRequest.self, from: body),
                  let guestID = Self.sanitizeGuestID(req.guestId) else {
                sendJSONError(connection: connection, status: 400, message: "Missing or invalid guestId")
                return
            }
            guard let handler = onRenameGuest else {
                sendJSONError(connection: connection, status: 503, message: "Party Mode host handler is not ready")
                return
            }
            let sanitizedName = Self.sanitizeGuestName(req.guestName)
            renameGuestPresence(guestID: guestID, newName: sanitizedName ?? "Guest")
            Task { [weak self] in
                var response = await handler(guestID, sanitizedName)
                guard let server = self else { return }
                if response.state != nil {
                    response.state?.guests = server.snapshotGuests()
                    response.state?.httpsPort = server.currentHTTPSPort()
                }
                let finalResponse = response
                server.queue.async {
                    server.sendJSON(connection: connection, value: finalResponse, status: finalResponse.ok ? 200 : 400)
                }
            }
            return
        }

        // 4c. Optional Party Chat Send
        if method == "POST" && path == "/api/party/chat" {
            guard let req = try? decoder.decode(PartyChatSendRequest.self, from: body),
                  let cleanText = Self.sanitizeChatText(req.text) else {
                sendJSONError(connection: connection, status: 400, message: "Message cannot be empty")
                return
            }
            guard let handler = onSendChatMessage else {
                sendJSONError(connection: connection, status: 503, message: "Party chat handler is not ready")
                return
            }
            let sanitizedGuest = Self.sanitizeGuestName(req.guestName)
            let sanitizedGuestID = Self.sanitizeGuestID(req.guestId)
            _ = touchGuestPresence(guestID: sanitizedGuestID, guestName: sanitizedGuest, incrementRequests: false)
            Task { [weak self] in
                var response = await handler(sanitizedGuestID, sanitizedGuest, cleanText)
                guard let server = self else { return }
                if response.state != nil {
                    response.state?.guests = server.snapshotGuests()
                    response.state?.httpsPort = server.currentHTTPSPort()
                }
                let finalResponse = response
                server.queue.async {
                    server.sendJSON(connection: connection, value: finalResponse, status: finalResponse.ok ? 200 : 403)
                }
            }
            return
        }

        // 4d. Upload Recorded Voice Intro for a Requested Track
        if method == "POST" && path == "/api/party/intro" {
            let trackID = (queryMap["trackId"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trackID.isEmpty, !body.isEmpty else {
                sendJSONError(connection: connection, status: 400, message: "Missing trackId or audio recording data")
                return
            }
            guard let handler = onUploadVoiceIntro else {
                sendJSONError(connection: connection, status: 503, message: "Voice intro handler is not ready")
                return
            }
            let sanitizedGuest = Self.sanitizeGuestName(queryMap["guestName"])
            let sanitizedGuestID = Self.sanitizeGuestID(queryMap["guestId"])
            let rawExt = (queryMap["ext"] ?? "").lowercased()
            let contentType = (headers["content-type"] ?? "").lowercased()
            let fileExt: String = {
                if ["wav", "m4a", "mp3", "aac", "caf"].contains(rawExt) { return rawExt }
                if contentType.contains("wav") { return "wav" }
                if contentType.contains("mp4") || contentType.contains("m4a") || contentType.contains("aac") { return "m4a" }
                if contentType.contains("mpeg") || contentType.contains("mp3") { return "mp3" }
                return "wav"
            }()
            _ = touchGuestPresence(guestID: sanitizedGuestID, guestName: sanitizedGuest, incrementRequests: false)
            Task { [weak self] in
                var response = await handler(trackID, sanitizedGuestID, sanitizedGuest, body, fileExt)
                guard let server = self else { return }
                if response.state != nil {
                    response.state?.guests = server.snapshotGuests()
                    response.state?.httpsPort = server.currentHTTPSPort()
                }
                let finalResponse = response
                server.queue.async {
                    server.sendJSON(connection: connection, value: finalResponse, status: finalResponse.ok ? 200 : 400)
                }
            }
            return
        }

        // 4e. Delete Recorded Voice Intro
        if (method == "DELETE" && path == "/api/party/intro") || (method == "POST" && path == "/api/party/intro/delete") {
            let trackID = (queryMap["trackId"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trackID.isEmpty else {
                sendJSONError(connection: connection, status: 400, message: "Missing trackId")
                return
            }
            guard let handler = onDeleteVoiceIntro else {
                sendJSONError(connection: connection, status: 503, message: "Voice intro handler is not ready")
                return
            }
            let sanitizedGuestID = Self.sanitizeGuestID(queryMap["guestId"])
            Task { [weak self] in
                var response = await handler(trackID, sanitizedGuestID)
                guard let server = self else { return }
                if response.state != nil {
                    response.state?.guests = server.snapshotGuests()
                    response.state?.httpsPort = server.currentHTTPSPort()
                }
                let finalResponse = response
                server.queue.async {
                    server.sendJSON(connection: connection, value: finalResponse, status: finalResponse.ok ? 200 : 400)
                }
            }
            return
        }

        // 5. Optional Remote Listen-Along Audio Stream (HTTP Range / 206 Partial Content for mobile Safari & Chrome)
        if (method == "GET" || method == "HEAD") && path.hasPrefix("/api/party/stream/") {
            let rawTrackID = String(path.dropFirst("/api/party/stream/".count))
            let trackID = rawTrackID.removingPercentEncoding ?? rawTrackID
            lock.lock()
            let allowed = playlistState.streamingEnabled
            let isInParty = playlistTrackIDs.contains(trackID) || playlistState.currentTrackID == trackID
            let filePath = trackFilePathsByID[trackID]
            lock.unlock()

            guard allowed else {
                sendJSONError(connection: connection, status: 403, message: "Remote listen-along streaming is disabled by the host")
                return
            }
            guard isInParty, let filePath, FileManager.default.fileExists(atPath: filePath) else {
                sendJSONError(connection: connection, status: 404, message: "Track audio not available for streaming")
                return
            }
            streamAudioFile(atPath: filePath, rangeHeader: headers["range"], headOnly: method == "HEAD", connection: connection)
            return
        }

        // 5b. Album & Artist Editorial Info for Now Playing Lightbox
        if method == "GET" && path == "/api/party/track-info" {
            let trackID = (queryMap["trackId"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trackID.isEmpty else {
                sendJSONError(connection: connection, status: 400, message: "Missing trackId")
                return
            }
            guard let handler = onFetchTrackInfo else {
                sendJSONError(connection: connection, status: 503, message: "Track info handler is not ready")
                return
            }
            Task { [weak self] in
                let info = await handler(trackID)
                guard let server = self else { return }
                server.queue.async {
                    if let info {
                        server.sendJSON(connection: connection, value: info, status: 200)
                    } else {
                        server.sendJSONError(connection: connection, status: 404, message: "Track not found")
                    }
                }
            }
            return
        }

        // 6. Artwork JPEG (thumbnail by default, or full-resolution original when ?full=1)
        if method == "GET" && path.hasPrefix("/api/party/artwork/") {
            let rawHash = String(path.dropFirst("/api/party/artwork/".count))
            let preferFull = (queryMap["full"] == "1" || queryMap["full"]?.lowercased() == "true")
            let data: Data? = {
                guard Self.isSafeArtworkHash(rawHash) else { return nil }
                if preferFull {
                    return artworkCache.loadOriginalData(for: rawHash) ?? artworkCache.loadThumbnailData(for: rawHash)
                }
                return artworkCache.loadThumbnailData(for: rawHash) ?? artworkCache.loadOriginalData(for: rawHash)
            }()
            guard let data else {
                sendJSONError(connection: connection, status: 404, message: "Artwork not found")
                return
            }
            sendRawResponse(
                connection: connection,
                status: 200,
                statusText: "OK",
                contentType: "image/jpeg",
                data: data,
                cacheControl: "public, max-age=86400"
            )
            return
        }

        sendJSONError(connection: connection, status: 404, message: "Not found: \(path)")
    }

    public static func sanitizeGuestName(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let scalars = raw.unicodeScalars.filter { !$0.properties.isDefaultIgnorableCodePoint && $0.value >= 32 }
        let cleaned = String(String.UnicodeScalarView(scalars)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        return String(cleaned.prefix(32))
    }

    public static func sanitizeGuestID(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 64 else { return nil }
        let allowed = trimmed.unicodeScalars.allSatisfy { s in
            (s.value >= 48 && s.value <= 57)
                || (s.value >= 65 && s.value <= 90)
                || (s.value >= 97 && s.value <= 122)
                || s.value == 45 || s.value == 95
        }
        return allowed ? trimmed : nil
    }

    public static func sanitizeChatText(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let scalars = raw.unicodeScalars.filter { !$0.properties.isDefaultIgnorableCodePoint && $0.value >= 32 }
        let cleaned = String(String.UnicodeScalarView(scalars)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        return String(cleaned.prefix(280))
    }

    private static func isSafeArtworkHash(_ hash: String) -> Bool {
        guard !hash.isEmpty, hash.count <= 128 else { return false }
        return hash.unicodeScalars.allSatisfy { scalar in
            (scalar.value >= 48 && scalar.value <= 57) // 0-9
                || (scalar.value >= 65 && scalar.value <= 90) // A-Z
                || (scalar.value >= 97 && scalar.value <= 122) // a-z
                || scalar.value == 45 || scalar.value == 95 // - _
        }
    }

    private func sendJSON<T: Encodable>(connection: NWConnection, value: T, status: Int = 200) {
        let data = (try? encoder.encode(value)) ?? Data("{}".utf8)
        let text = status == 200 ? "OK" : (status == 400 ? "Bad Request" : "Error")
        sendRawResponse(
            connection: connection,
            status: status,
            statusText: text,
            contentType: "application/json; charset=utf-8",
            data: data,
            cacheControl: "no-store"
        )
    }

    private func sendJSONError(connection: NWConnection, status: Int, message: String) {
        let data = (try? JSONSerialization.data(withJSONObject: ["ok": false, "error": message])) ?? Data()
        let text: String
        switch status {
        case 400: text = "Bad Request"
        case 404: text = "Not Found"
        case 413: text = "Payload Too Large"
        case 503: text = "Service Unavailable"
        default: text = "Error"
        }
        sendRawResponse(
            connection: connection,
            status: status,
            statusText: text,
            contentType: "application/json; charset=utf-8",
            data: data,
            cacheControl: "no-store"
        )
    }

    private func sendRawResponse(
        connection: NWConnection,
        status: Int,
        statusText: String,
        contentType: String,
        data: Data,
        cacheControl: String = "no-store"
    ) {
        var header = "HTTP/1.1 \(status) \(statusText)\r\n"
        header += "Content-Type: \(contentType)\r\n"
        header += "Content-Length: \(data.count)\r\n"
        header += "Cache-Control: \(cacheControl)\r\n"
        header += "Access-Control-Allow-Origin: *\r\n"
        header += "Access-Control-Allow-Methods: GET, POST, DELETE, OPTIONS\r\n"
        header += "Access-Control-Allow-Headers: Content-Type\r\n"
        header += "Connection: close\r\n\r\n"

        var payload = Data(header.utf8)
        payload.append(data)
        connection.send(content: payload, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func streamAudioFile(atPath path: String, rangeHeader: String?, headOnly: Bool, connection: NWConnection) {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let totalSize = (attrs[.size] as? NSNumber)?.int64Value,
              totalSize > 0 else {
            sendJSONError(connection: connection, status: 404, message: "Audio file unreadable")
            return
        }

        var startOffset: Int64 = 0
        var endOffset: Int64 = max(0, totalSize - 1)
        var isPartial = false

        if let rangeHeader, rangeHeader.lowercased().hasPrefix("bytes=") {
            let spec = rangeHeader.dropFirst("bytes=".count)
            let firstRange = spec.split(separator: ",").first.map(String.init) ?? String(spec)
            let parts = firstRange.split(separator: "-", omittingEmptySubsequences: false)
            if parts.count == 2 {
                let startStr = parts[0].trimmingCharacters(in: .whitespaces)
                let endStr = parts[1].trimmingCharacters(in: .whitespaces)
                if startStr.isEmpty, let suffixLen = Int64(endStr), suffixLen > 0 {
                    startOffset = max(0, totalSize - suffixLen)
                    endOffset = totalSize - 1
                    isPartial = true
                } else if let s = Int64(startStr), s >= 0 && s < totalSize {
                    startOffset = s
                    if let e = Int64(endStr), e >= startOffset {
                        endOffset = min(e, totalSize - 1)
                    } else {
                        endOffset = totalSize - 1
                    }
                    isPartial = true
                }
            }
        }

        let lengthToSend = max(0, endOffset - startOffset + 1)
        let mime = Self.audioMimeType(forPath: path)
        var header = isPartial ? "HTTP/1.1 206 Partial Content\r\n" : "HTTP/1.1 200 OK\r\n"
        header += "Content-Type: \(mime)\r\n"
        header += "Accept-Ranges: bytes\r\n"
        header += "Content-Length: \(lengthToSend)\r\n"
        if isPartial {
            header += "Content-Range: bytes \(startOffset)-\(endOffset)/\(totalSize)\r\n"
        }
        header += "Cache-Control: no-store\r\n"
        header += "Access-Control-Allow-Origin: *\r\n"
        header += "Connection: close\r\n\r\n"

        if headOnly {
            connection.send(content: Data(header.utf8), completion: .contentProcessed { _ in
                connection.cancel()
            })
            return
        }

        guard let handle = FileHandle(forReadingAtPath: path) else {
            sendJSONError(connection: connection, status: 404, message: "Audio file unreadable")
            return
        }
        try? handle.seek(toOffset: UInt64(startOffset))

        connection.send(content: Data(header.utf8), completion: .contentProcessed { [weak self] err in
            if err != nil {
                try? handle.close()
                connection.cancel()
                return
            }
            self?.sendAudioChunk(handle: handle, remaining: lengthToSend, connection: connection)
        })
    }

    private func sendAudioChunk(handle: FileHandle, remaining: Int64, connection: NWConnection) {
        if remaining <= 0 {
            try? handle.close()
            connection.cancel()
            return
        }
        let chunkSize = Int(min(131_072, remaining))
        let chunk = (try? handle.read(upToCount: chunkSize)) ?? Data()
        if chunk.isEmpty {
            try? handle.close()
            connection.cancel()
            return
        }
        connection.send(content: chunk, completion: .contentProcessed { [weak self] err in
            if err != nil {
                try? handle.close()
                connection.cancel()
                return
            }
            self?.sendAudioChunk(handle: handle, remaining: remaining - Int64(chunk.count), connection: connection)
        })
    }

    private static func audioMimeType(forPath path: String) -> String {
        switch URL(fileURLWithPath: path).pathExtension.lowercased() {
        case "mp3": return "audio/mpeg"
        case "m4a", "mp4", "aac": return "audio/mp4"
        case "flac": return "audio/flac"
        case "wav", "wave": return "audio/wav"
        case "ogg", "oga": return "audio/ogg"
        case "opus": return "audio/opus"
        case "aif", "aiff": return "audio/aiff"
        default: return "application/octet-stream"
        }
    }
}

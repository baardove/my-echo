import Foundation

public enum SearchField: String, Sendable, Equatable {
    case track
    case artist
    case album
    case genre
    case year
    case format
    case rating

    public static func fromPrefix(_ raw: String) -> SearchField? {
        switch raw.lowercased() {
        case "track", "title", "song": return .track
        case "artist", "by": return .artist
        case "album": return .album
        case "genre": return .genre
        case "year": return .year
        case "format", "codec": return .format
        case "rating", "stars", "star": return .rating
        default: return nil
        }
    }
}

public struct SearchClause: Sendable, Equatable {
    public let text: String
    public let field: SearchField?
    public let isRequired: Bool
    public let isExcluded: Bool

    public init(text: String, field: SearchField? = nil, isRequired: Bool = false, isExcluded: Bool = false) {
        self.text = text
        self.field = field
        self.isRequired = isRequired
        self.isExcluded = isExcluded
    }
}

/// Pre-lowercased metadata fields for fast structured & multi-field search matching.
public struct SearchFieldValues: Sendable {
    public let track: String
    public let artist: String
    public let albumArtist: String
    public let album: String
    public let genre: String
    public let year: String
    public let format: String
    public let rating: Double?

    public init(
        track: String = "",
        artist: String = "",
        albumArtist: String = "",
        album: String = "",
        genre: String = "",
        year: String = "",
        format: String = "",
        rating: Double? = nil
    ) {
        self.track = track
        self.artist = artist
        self.albumArtist = albumArtist
        self.album = album
        self.genre = genre
        self.year = year
        self.format = format
        self.rating = rating
    }

    public init(from trackModel: Track, rating: Int? = nil) {
        let dispArtist = trackModel.artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? trackModel.effectiveArtist
            : trackModel.artist
        self.track = trackModel.title.lowercased()
        self.artist = dispArtist.lowercased()
        self.albumArtist = trackModel.albumArtist.lowercased()
        self.album = trackModel.effectiveAlbum.lowercased()
        self.genre = (trackModel.genre ?? "").lowercased()
        self.year = trackModel.year.map(String.init) ?? ""
        self.format = trackModel.format.displayBadge.lowercased()
        self.rating = rating.map(Double.init)
    }

    public func contains(_ needle: String, in field: SearchField?) -> Bool {
        switch field {
        case .track:
            return track.contains(needle)
        case .artist:
            return artist.contains(needle) || albumArtist.contains(needle)
        case .album:
            return album.contains(needle)
        case .genre:
            return genre.contains(needle)
        case .year:
            return !year.isEmpty && year.contains(needle)
        case .format:
            return !format.isEmpty && format.contains(needle)
        case .rating:
            guard let r = rating, r > 0 else { return false }
            let trimmed = needle.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasSuffix("+"), let minVal = Double(trimmed.dropLast()) {
                return r >= minVal
            }
            if trimmed.hasPrefix(">="), let minVal = Double(trimmed.dropFirst(2)) {
                return r >= minVal
            }
            if trimmed.hasPrefix("<="), let maxVal = Double(trimmed.dropFirst(2)) {
                return r <= maxVal
            }
            if let exact = Double(trimmed) {
                return Int(r.rounded()) == Int(exact.rounded())
            }
            return false
        case nil:
            return track.contains(needle)
                || artist.contains(needle)
                || albumArtist.contains(needle)
                || album.contains(needle)
                || genre.contains(needle)
                || (!year.isEmpty && year.contains(needle))
                || (!format.isEmpty && format.contains(needle))
        }
    }
}

/// Parsed multi-field search query supporting:
/// - Space-separated keywords matched across all fields (e.g. `Bruce Springsteen The River`)
/// - `-keyword` / `-"phrase"` to exclude matches containing that keyword or phrase
/// - `+keyword` / `+"phrase"` to explicitly require that keyword or phrase
/// - Field prefixes with or without space after colon:
///   `Artist: Bruce Track: river`, `artist:bruce album:river`, `-album:live`, `+track:river`
/// - `"quoted phrase"` for exact multi-word phrases
public struct SearchQueryTerms: Sendable, Equatable {
    public let includeClauses: [SearchClause]
    public let excludeClauses: [SearchClause]
    public let positivePhrase: String

    public var include: [String] { includeClauses.map(\.text) }
    public var required: [String] { includeClauses.filter(\.isRequired).map(\.text) }
    public var exclude: [String] { excludeClauses.map(\.text) }

    public var isEmpty: Bool {
        includeClauses.isEmpty && excludeClauses.isEmpty
    }

    public init(includeClauses: [SearchClause], excludeClauses: [SearchClause], positivePhrase: String) {
        self.includeClauses = includeClauses
        self.excludeClauses = excludeClauses
        self.positivePhrase = positivePhrase
    }

    public static func parse(_ rawQuery: String) -> SearchQueryTerms {
        let trimmed = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return SearchQueryTerms(includeClauses: [], excludeClauses: [], positivePhrase: "")
        }

        var includeClauses: [SearchClause] = []
        var excludeClauses: [SearchClause] = []

        // Sticky field context when user writes "Artist: Bruce Springsteen Track: The River" (space after colon)
        var stickyField: SearchField? = nil
        var stickyOp: Character? = nil

        var i = trimmed.startIndex
        let end = trimmed.endIndex

        while i < end {
            while i < end && trimmed[i].isWhitespace {
                i = trimmed.index(after: i)
            }
            guard i < end else { break }

            // Check leading +/- operator
            var explicitOp: Character? = nil
            if trimmed[i] == "-" || trimmed[i] == "+" {
                let next = trimmed.index(after: i)
                if next < end && !trimmed[next].isWhitespace {
                    explicitOp = trimmed[i]
                    i = next
                    // An explicit operator without a new field prefix resets sticky field context
                    stickyField = nil
                    stickyOp = nil
                } else {
                    // Standalone "-" or "+" (e.g. mid-typing or "AC - DC")
                    i = next
                    continue
                }
            }

            // Check for field prefix (e.g. "Artist:", "Track:", "album:") if not starting with a quote
            var explicitField: SearchField? = nil
            if i < end && trimmed[i] != "\"" {
                var scan = i
                while scan < end && trimmed[scan].isLetter {
                    scan = trimmed.index(after: scan)
                }
                if scan > i && scan < end && trimmed[scan] == ":" {
                    let prefixStr = String(trimmed[i..<scan])
                    if let parsedField = SearchField.fromPrefix(prefixStr) {
                        let afterColon = trimmed.index(after: scan)
                        if afterColon >= end {
                            // Trailing "Artist:" with nothing after it yet -> ignore cleanly
                            break
                        }
                        if trimmed[afterColon].isWhitespace {
                            // Space after colon: e.g. "Artist: Bruce Springsteen Track: river"
                            stickyField = parsedField
                            stickyOp = explicitOp
                            i = afterColon
                            continue
                        } else {
                            // Attached immediately: e.g. "artist:bruce" or "artist:\"bruce springsteen\""
                            explicitField = parsedField
                            stickyField = nil
                            stickyOp = nil
                            i = afterColon
                        }
                    }
                }
            }

            // Parse quoted phrase or bare word
            let token: String
            if i < end && trimmed[i] == "\"" {
                i = trimmed.index(after: i)
                let start = i
                while i < end && trimmed[i] != "\"" {
                    i = trimmed.index(after: i)
                }
                token = String(trimmed[start..<i]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if i < end && trimmed[i] == "\"" {
                    i = trimmed.index(after: i)
                }
            } else {
                let start = i
                while i < end && !trimmed[i].isWhitespace {
                    i = trimmed.index(after: i)
                }
                token = String(trimmed[start..<i]).lowercased()
            }

            guard !token.isEmpty else { continue }

            let effectiveField = explicitField ?? stickyField
            let effectiveOp = explicitOp ?? stickyOp

            switch effectiveOp {
            case "-":
                let clause = SearchClause(text: token, field: effectiveField, isRequired: false, isExcluded: true)
                if !excludeClauses.contains(clause) {
                    excludeClauses.append(clause)
                }
            case "+":
                let clause = SearchClause(text: token, field: effectiveField, isRequired: true, isExcluded: false)
                if !includeClauses.contains(clause) {
                    includeClauses.append(clause)
                }
            default:
                let clause = SearchClause(text: token, field: effectiveField, isRequired: false, isExcluded: false)
                if !includeClauses.contains(clause) {
                    includeClauses.append(clause)
                }
            }
        }

        let positivePhrase = includeClauses.filter { $0.field == nil }.map(\.text).joined(separator: " ")
        return SearchQueryTerms(
            includeClauses: includeClauses,
            excludeClauses: excludeClauses,
            positivePhrase: positivePhrase
        )
    }

    public func matches(values: SearchFieldValues) -> Bool {
        if isEmpty { return true }
        for ex in excludeClauses {
            if values.contains(ex.text, in: ex.field) {
                return false
            }
        }
        for inc in includeClauses {
            if !values.contains(inc.text, in: inc.field) {
                return false
            }
        }
        return true
    }

    public func matches(track: Track, rating: Int? = nil) -> Bool {
        if isEmpty { return true }
        return matches(values: SearchFieldValues(from: track, rating: rating))
    }

    /// Fallback matcher for unstructured lists of fields (e.g. podcasts or playlists).
    public func matches(fields: [String]) -> Bool {
        if isEmpty { return true }
        let lowered = fields.compactMap { f -> String? in
            let s = f.trimmingCharacters(in: .whitespacesAndNewlines)
            return s.isEmpty ? nil : s.lowercased()
        }
        for ex in excludeClauses {
            if lowered.contains(where: { $0.contains(ex.text) }) {
                return false
            }
        }
        for inc in includeClauses {
            if !lowered.contains(where: { $0.contains(inc.text) }) {
                return false
            }
        }
        return true
    }
}

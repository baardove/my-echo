import SwiftUI
import AppKit
import ImageIO
import EchoCore

/// Zero-config online fetcher for album & artist editorial info (Deezer + Wikipedia),
/// called by `EchoStore` and persisted locally in SQLite with 14-day refresh TTL.
enum EditorialInfoFetcher {
    static func fetchAlbumEditorial(albumKey: String, artist: String, albumTitle: String) async -> (album: AlbumEditorialInfo, artist: ArtistEditorialInfo?) {
        let cleanArtist = ArtistNameParser.artistNames(artist).first ?? artist
        let isVarious = cleanArtist.lowercased() == "various artists" || cleanArtist.lowercased() == "unknown artist"

        async let deezerTask = fetchDeezerAlbumAndArtist(artist: isVarious ? "" : cleanArtist, album: albumTitle)
        async let albumWikiTask = fetchWikipediaSummary(
            candidates: [
                "\(albumTitle) (\(cleanArtist) album)",
                "\(albumTitle) (album)",
                albumTitle
            ],
            requireMusicHint: true,
            artistHint: isVarious ? nil : cleanArtist
        )
        async let artistWikiTask: String? = isVarious
            ? nil
            : fetchWikipediaSummary(
                candidates: [
                    "\(cleanArtist) (band)",
                    "\(cleanArtist) (musician)",
                    "\(cleanArtist) (singer)",
                    cleanArtist
                ],
                requireMusicHint: true,
                artistHint: nil
            )

        let dz = await deezerTask
        let albumSummary = await albumWikiTask
        let artistSummary = await artistWikiTask
        let now = Date()

        let albumInfo = AlbumEditorialInfo(
            albumKey: albumKey,
            releaseDate: dz.releaseDate,
            label: dz.label,
            genres: dz.genres,
            albumFans: dz.albumFans,
            artistFans: dz.artistFans,
            artistAlbumCount: dz.artistAlbumCount,
            albumSummary: albumSummary,
            artistSummary: artistSummary,
            artistImageURL: dz.artistImageURL,
            fetchedAt: now
        )

        let artistInfo: ArtistEditorialInfo? = isVarious ? nil : ArtistEditorialInfo(
            artistKey: cleanArtist.lowercased(),
            summary: artistSummary,
            fans: dz.artistFans,
            albumCount: dz.artistAlbumCount,
            imageURL: dz.artistImageURL,
            fetchedAt: now
        )

        return (albumInfo, artistInfo)
    }

    static func fetchArtistEditorial(artistKey: String, artistName: String) async -> ArtistEditorialInfo {
        let cleanArtist = ArtistNameParser.artistNames(artistName).first ?? artistName
        async let dzTask = fetchDeezerArtistOnly(artist: cleanArtist)
        async let wikiTask = fetchWikipediaSummary(
            candidates: [
                "\(cleanArtist) (band)",
                "\(cleanArtist) (musician)",
                "\(cleanArtist) (singer)",
                cleanArtist
            ],
            requireMusicHint: true,
            artistHint: nil
        )
        let dz = await dzTask
        let summary = await wikiTask
        return ArtistEditorialInfo(
            artistKey: artistKey.lowercased(),
            summary: summary,
            fans: dz.fans,
            albumCount: dz.albumCount,
            imageURL: dz.imageURL,
            fetchedAt: Date()
        )
    }

    private struct DeezerAlbumBundle: Sendable {
        var releaseDate: String?
        var label: String?
        var genres: [String] = []
        var albumFans: Int?
        var artistFans: Int?
        var artistAlbumCount: Int?
        var artistImageURL: String?
    }

    private static func fetchDeezerAlbumAndArtist(artist: String, album: String) async -> DeezerAlbumBundle {
        var out = DeezerAlbumBundle()
        let queryRaw = artist.isEmpty ? album : "\(artist) \(album)"
        guard let encoded = queryRaw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.deezer.com/search/album?q=\(encoded)&limit=6") else {
            return out
        }

        var req = URLRequest(url: url, timeoutInterval: 8)
        req.setValue("MyEcho/1.0", forHTTPHeaderField: "User-Agent")

        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["data"] as? [[String: Any]] else {
            return out
        }

        let normAlbum = normalize(album)
        let normArtist = normalize(artist)
        let match = results.first { item in
            let t = normalize(item["title"] as? String ?? "")
            let a = normalize((item["artist"] as? [String: Any])?["name"] as? String ?? "")
            let titleOK = t == normAlbum || t.contains(normAlbum) || normAlbum.contains(t)
            let artistOK = normArtist.isEmpty || a == normArtist || a.contains(normArtist) || normArtist.contains(a)
            return titleOK && artistOK
        } ?? results.first

        guard let match, let albumID = match["id"] as? Int else { return out }

        if let detailURL = URL(string: "https://api.deezer.com/album/\(albumID)") {
            var dReq = URLRequest(url: detailURL, timeoutInterval: 8)
            dReq.setValue("MyEcho/1.0", forHTTPHeaderField: "User-Agent")
            if let (dData, dResp) = try? await URLSession.shared.data(for: dReq),
               (dResp as? HTTPURLResponse)?.statusCode == 200,
               let detail = try? JSONSerialization.jsonObject(with: dData) as? [String: Any] {
                if let rd = detail["release_date"] as? String, !rd.isEmpty, rd != "0000-00-00" {
                    out.releaseDate = rd
                }
                if let lbl = detail["label"] as? String, !lbl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    out.label = lbl
                }
                if let fans = detail["fans"] as? Int, fans > 0 {
                    out.albumFans = fans
                }
                if let genresObj = detail["genres"] as? [String: Any],
                   let genreList = genresObj["data"] as? [[String: Any]] {
                    out.genres = genreList.compactMap { $0["name"] as? String }.filter { !$0.isEmpty }
                }
                if let artistObj = detail["artist"] as? [String: Any],
                   let artistID = artistObj["id"] as? Int {
                    if let pic = artistObj["picture_medium"] as? String, !pic.isEmpty {
                        out.artistImageURL = pic
                    }
                    if let aURL = URL(string: "https://api.deezer.com/artist/\(artistID)") {
                        var aReq = URLRequest(url: aURL, timeoutInterval: 8)
                        aReq.setValue("MyEcho/1.0", forHTTPHeaderField: "User-Agent")
                        if let (aData, aResp) = try? await URLSession.shared.data(for: aReq),
                           (aResp as? HTTPURLResponse)?.statusCode == 200,
                           let aDetail = try? JSONSerialization.jsonObject(with: aData) as? [String: Any] {
                            if let nbFan = aDetail["nb_fan"] as? Int, nbFan > 0 {
                                out.artistFans = nbFan
                            }
                            if let nbAlbum = aDetail["nb_album"] as? Int, nbAlbum > 0 {
                                out.artistAlbumCount = nbAlbum
                            }
                        }
                    }
                }
            }
        }
        return out
    }

    private static func fetchDeezerArtistOnly(artist: String) async -> (fans: Int?, albumCount: Int?, imageURL: String?) {
        guard let encoded = artist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.deezer.com/search/artist?q=\(encoded)&limit=5") else {
            return (nil, nil, nil)
        }
        var req = URLRequest(url: url, timeoutInterval: 8)
        req.setValue("MyEcho/1.0", forHTTPHeaderField: "User-Agent")
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["data"] as? [[String: Any]] else {
            return (nil, nil, nil)
        }
        let normArtist = normalize(artist)
        let match = results.first { normalize($0["name"] as? String ?? "") == normArtist } ?? results.first
        let fans = (match?["nb_fan"] as? Int).flatMap { $0 > 0 ? $0 : nil }
        let albums = (match?["nb_album"] as? Int).flatMap { $0 > 0 ? $0 : nil }
        let pic = match?["picture_medium"] as? String
        return (fans, albums, pic)
    }

    private static func fetchWikipediaSummary(candidates: [String], requireMusicHint: Bool, artistHint: String?) async -> String? {
        let musicKeywords = ["album", "band", "singer", "musician", "music", "song", "record", "electronic", "rock", "pop", "hip hop", "jazz", "composer", "dj", "duo", "group", "rapper", "producer", "soundtrack", "ep", "studio", "trance", "house", "metal", "folk", "blues", "classical"]
        let normArtist = artistHint.map(normalize)

        for rawTitle in candidates {
            let trimmed = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let slug = trimmed.replacingOccurrences(of: " ", with: "_")
            guard let encoded = slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                  let url = URL(string: "https://en.wikipedia.org/api/rest_v1/page/summary/\(encoded)") else {
                continue
            }

            var req = URLRequest(url: url, timeoutInterval: 6)
            req.setValue("MyEcho/1.0 (https://github.com/baardove/my-echo)", forHTTPHeaderField: "User-Agent")

            guard let (data, resp) = try? await URLSession.shared.data(for: req),
                  (resp as? HTTPURLResponse)?.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  (json["type"] as? String) != "disambiguation",
                  let extract = json["extract"] as? String else {
                continue
            }

            let clean = extract.trimmingCharacters(in: .whitespacesAndNewlines)
            guard clean.count >= 40 else { continue }
            let lower = clean.lowercased()
            if requireMusicHint && !musicKeywords.contains(where: { lower.contains($0) }) {
                continue
            }
            if let normArtist, !normArtist.isEmpty {
                if !trimmed.lowercased().contains(normArtist) && !normalize(clean).contains(normArtist) {
                    continue
                }
            }
            return clean
        }
        return nil
    }

    private static func normalize(_ str: String) -> String {
        str.lowercased()
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

/// Interactive hero album cover button with subtle hover neon rim + zoom badge that opens the Lightbox.
struct AlbumHeroCoverButton: View {
    let album: AlbumGroup
    let artworkCache: ArtworkCache
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomTrailing) {
                ArtworkView(hash: album.artworkHash, artworkCache: artworkCache, cornerRadius: EchoTheme.radiusCard, iconSize: 50)
                    .frame(width: 174, height: 174)
                    .overlay(
                        RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous)
                            .strokeBorder(isHovered ? EchoTheme.neoMint.opacity(0.85) : Color.clear, lineWidth: 1.5)
                    )
                    .shadow(color: .black.opacity(0.55), radius: 20, y: 10)
                    .shadow(color: isHovered ? EchoTheme.neoMint.opacity(0.28) : .clear, radius: 10)

                if isHovered {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(EchoTheme.neoMint)
                        .frame(width: 26, height: 26)
                        .background(Color.black.opacity(0.76))
                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: EchoTheme.radiusSmall, style: .continuous)
                                .strokeBorder(EchoTheme.neoMint.opacity(0.65), lineWidth: 1)
                        )
                        .padding(8)
                        .transition(.opacity)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.14)) { isHovered = hovering }
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .help("Click to open full-size artwork & album/artist info lightbox")
    }
}

/// Right-hand responsive editorial card displayed inside the Album Detail hero header when horizontal space permits.
struct AlbumHeroEditorialPanel: View {
    @Environment(EchoStore.self) private var store
    let album: AlbumGroup

    private var info: AlbumEditorialInfo? {
        store.albumEditorialByKey[album.id]
    }

    private var isFetching: Bool {
        store.fetchingEditorialKeys.contains("album:\(album.id)")
    }

    private var primaryArtist: String {
        ArtistNameParser.artistNames(album.artist).first ?? album.artist
    }

    private var audioQualityText: String {
        let formats = Array(Set(album.tracks.map { $0.format.displayBadge })).sorted()
        let maxBit = album.tracks.compactMap(\.bitDepth).max()
        let maxSR = album.tracks.compactMap(\.sampleRate).max()
        var parts: [String] = []
        if !formats.isEmpty { parts.append(formats.joined(separator: "/")) }
        if let sr = maxSR, sr > 0 {
            let khz = Double(sr) / 1000.0
            let srStr = khz.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f kHz", khz) : String(format: "%.1f kHz", khz)
            parts.append(maxBit.map { "\($0)-bit / \(srStr)" } ?? srStr)
        }
        return parts.joined(separator: " · ")
    }

    private var genres: [String] {
        let local = Array(Set(album.tracks.compactMap(\.genre).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })).sorted()
        return local.isEmpty ? (info?.genres ?? []) : local
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let urlStr = info?.artistImageURL, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        if case .success(let img) = phase {
                            img.resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 18, height: 18)
                                .clipShape(Circle())
                                .overlay(Circle().strokeBorder(EchoTheme.neoMint.opacity(0.55), lineWidth: 0.8))
                        }
                    }
                }
                Text("ALBUM & ARTIST NOTES")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(EchoTheme.neoMint)

                Spacer()

                if isFetching {
                    ProgressView().controlSize(.mini)
                } else {
                    Button {
                        store.openAlbumLightbox(album)
                    } label: {
                        HStack(spacing: 3.5) {
                            Text("Full Info")
                                .font(.system(size: 10, weight: .bold))
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 8.5, weight: .bold))
                        }
                        .foregroundStyle(EchoTheme.neoMint)
                    }
                    .buttonStyle(.plain)
                    .help("Open full-size artwork & complete album/artist info")
                }
            }

            // Compact meta row: Label · Release Date · Audio Quality · Fans
            HStack(spacing: 6) {
                if let label = info?.label {
                    Text(label)
                        .lineLimit(1)
                }
                if let rd = info?.releaseDate {
                    if info?.label != nil { Text("·").foregroundStyle(EchoTheme.textMuted) }
                    Text(rd)
                        .font(.system(size: 10.5, design: .monospaced))
                }
                if !audioQualityText.isEmpty {
                    if info?.label != nil || info?.releaseDate != nil { Text("·").foregroundStyle(EchoTheme.textMuted) }
                    Text(audioQualityText)
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(EchoTheme.neoMint.opacity(0.9))
                }
            }
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(EchoTheme.textPrimary)
            .lineLimit(1)

            // Editorial summary (Album summary preferred, then Artist bio)
            if let text = info?.albumSummary ?? info?.artistSummary {
                Text(text)
                    .font(.system(size: 11.5))
                    .foregroundStyle(EchoTheme.textSecondary)
                    .lineSpacing(2.5)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if isFetching {
                Text("Fetching album & artist details from online sources...")
                    .font(.system(size: 11.5))
                    .foregroundStyle(EchoTheme.textMuted)
            } else {
                Text("Click the album cover to inspect full-size artwork, audio specs, and details for \(primaryArtist).")
                    .font(.system(size: 11.5))
                    .foregroundStyle(EchoTheme.textMuted)
                    .lineLimit(3)
            }

            // Genre pills + Artist fan count
            HStack(spacing: 5) {
                ForEach(genres.prefix(3), id: \.self) { g in
                    Text(g)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(EchoTheme.neoMint)
                        .padding(.horizontal, 6.5)
                        .padding(.vertical, 2)
                        .background(EchoTheme.neoMint.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(EchoTheme.neoMint.opacity(0.35), lineWidth: 0.8))
                }
                if let fans = info?.artistFans {
                    Spacer(minLength: 4)
                    Text("\(Formatters.compactCount(fans)) fans")
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(EchoTheme.textMuted)
                }
            }
        }
        .padding(13)
        .frame(minWidth: 290, maxWidth: 420, alignment: .leading)
        .background(Color.black.opacity(0.36))
        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous)
                .strokeBorder(EchoTheme.neoMint.opacity(0.32), lineWidth: 1)
        )
        .onTapGesture {
            store.openAlbumLightbox(album)
        }
    }
}

/// Right-hand responsive artist bio panel inside the Artist Detail hero header when horizontal space permits.
struct ArtistHeroEditorialPanel: View {
    @Environment(EchoStore.self) private var store
    let artist: ArtistGroup

    private var info: ArtistEditorialInfo? {
        store.artistEditorialByKey[artist.id]
    }

    private var isFetching: Bool {
        store.fetchingEditorialKeys.contains("artist:\(artist.id)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let urlStr = info?.imageURL, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        if case .success(let img) = phase {
                            img.resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 20, height: 20)
                                .clipShape(Circle())
                                .overlay(Circle().strokeBorder(EchoTheme.neoMint.opacity(0.55), lineWidth: 0.8))
                        }
                    }
                }
                Text("ABOUT \(artist.name.uppercased())")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(EchoTheme.neoMint)
                    .lineLimit(1)

                Spacer()

                if isFetching {
                    ProgressView().controlSize(.mini)
                } else if let count = info?.albumCount {
                    Text("\(count) releases")
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(EchoTheme.textMuted)
                }
            }

            if let summary = info?.summary {
                Text(summary)
                    .font(.system(size: 11.5))
                    .foregroundStyle(EchoTheme.textSecondary)
                    .lineSpacing(2.5)
                    .lineLimit(5)
            } else if isFetching {
                Text("Loading artist bio from online sources...")
                    .font(.system(size: 11.5))
                    .foregroundStyle(EchoTheme.textMuted)
            } else {
                Text("\(artist.albums.count) albums and \(artist.tracks.count) tracks indexed in your local library.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(EchoTheme.textMuted)
            }
        }
        .padding(13)
        .frame(minWidth: 280, maxWidth: 420, alignment: .leading)
        .background(Color.black.opacity(0.36))
        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous)
                .strokeBorder(EchoTheme.neoMint.opacity(0.32), lineWidth: 1)
        )
    }
}

/// Full-window Lightbox overlay showcasing high-resolution album cover art + rich locally-cached album & artist info.
struct AlbumLightboxView: View {
    @Environment(EchoStore.self) private var store
    let album: AlbumGroup

    @State private var fullResImage: NSImage?
    @State private var artworkPixelSize: (width: Int, height: Int)?

    private var onlineInfo: AlbumEditorialInfo? {
        store.albumEditorialByKey[album.id]
    }

    private var isLoadingOnlineInfo: Bool {
        store.fetchingEditorialKeys.contains("album:\(album.id)")
    }

    private var primaryArtistName: String {
        ArtistNameParser.artistNames(album.artist).first ?? album.artist
    }

    private var otherAlbumsByArtist: [AlbumGroup] {
        guard primaryArtistName.lowercased() != "various artists" else { return [] }
        let targetKey = primaryArtistName.lowercased()
        return store.albums.filter {
            $0.id != album.id &&
            ArtistNameParser.artistNames($0.artist).contains(where: { $0.lowercased() == targetKey })
        }
        .prefix(6)
        .map { $0 }
    }

    private var audioSummary: String {
        let formats = Array(Set(album.tracks.map { $0.format.displayBadge })).sorted()
        let maxBit = album.tracks.compactMap(\.bitDepth).max()
        let maxSR = album.tracks.compactMap(\.sampleRate).max()
        let maxBR = album.tracks.compactMap(\.bitrate).max()

        var parts: [String] = []
        if !formats.isEmpty { parts.append(formats.joined(separator: " / ")) }
        if let sr = maxSR, sr > 0 {
            let khz = Double(sr) / 1000.0
            let srStr = khz.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f kHz", khz)
                : String(format: "%.1f kHz", khz)
            if let bit = maxBit, bit > 0 {
                parts.append("\(bit)-bit / \(srStr)")
            } else {
                parts.append(srStr)
            }
        } else if let br = maxBR, br > 0 {
            parts.append("\(br) kbps")
        }
        return parts.joined(separator: " · ")
    }

    private var taggedGenres: [String] {
        let local = Array(Set(
            album.tracks
                .compactMap(\.genre)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )).sorted()
        if !local.isEmpty { return local }
        return onlineInfo?.genres ?? []
    }

    private var discCount: Int {
        Set(album.tracks.compactMap(\.discNumber)).count
    }

    private var folderPath: String? {
        guard let first = album.tracks.first else { return nil }
        return URL(fileURLWithPath: first.filePath).deletingLastPathComponent().path
    }

    private var albumPlays: Int {
        store.totalUserPlays(for: album)
    }

    private var avgPopularity: Int? {
        store.averageOnlinePopularity(for: album)
    }

    private var isAlreadyOnAlbumPage: Bool {
        if case .albumDetail(let key) = store.currentDestination {
            return key == album.id
        }
        return false
    }

    var body: some View {
        ZStack {
            // Dimmed backdrop — click anywhere outside card to close
            Color.black.opacity(0.82)
                .ignoresSafeArea()
                .onTapGesture {
                    store.closeAlbumLightbox()
                }

            // Lightbox Card
            HStack(spacing: 0) {
                artworkPane
                    .frame(width: 452)

                Rectangle()
                    .fill(EchoTheme.neoMint.opacity(0.28))
                    .frame(width: 1)

                infoPane
                    .frame(minWidth: 390, maxWidth: 480)
            }
            .frame(maxWidth: 932, maxHeight: 590)
            .background(
                ZStack {
                    EchoTheme.surface
                    RadialGradient(
                        colors: [EchoTheme.neoMint.opacity(0.09), .clear],
                        center: .topLeading,
                        startRadius: 20,
                        endRadius: 520
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous)
                    .strokeBorder(EchoTheme.neoMint.opacity(0.55), lineWidth: 1.2)
            )
            .shadow(color: .black.opacity(0.75), radius: 36, y: 14)
            .shadow(color: EchoTheme.neoMint.opacity(0.14), radius: 18)
            .padding(28)
        }
        .task(id: album.id) {
            loadFullResArtwork()
            store.ensureEditorialLoaded(forAlbum: album)
        }
    }

    // MARK: - Left Pane: High-Resolution Album Artwork

    private var artworkPane: some View {
        ZStack {
            Color.black.opacity(0.45)

            VStack(spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let img = fullResImage {
                            Image(nsImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } else {
                            ArtworkView(
                                hash: album.artworkHash,
                                artworkCache: store.artworkCache,
                                cornerRadius: EchoTheme.radiusCard,
                                iconSize: 72
                            )
                        }
                    }
                    .frame(width: 404, height: 404)
                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous)
                            .strokeBorder(EchoTheme.neoMint.opacity(0.35), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.65), radius: 22, y: 10)

                    if let px = artworkPixelSize {
                        Text("\(px.width) × \(px.height) px")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(EchoTheme.neoMint)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3.5)
                            .background(Color.black.opacity(0.78))
                            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: EchoTheme.radiusSmall, style: .continuous)
                                    .strokeBorder(EchoTheme.neoMint.opacity(0.45), lineWidth: 0.9)
                            )
                            .padding(10)
                    }
                }

                if let folderPath {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(EchoTheme.neoMint.opacity(0.85))
                        Text(folderPath)
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(EchoTheme.textMuted)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .frame(maxWidth: 404, alignment: .leading)
                }
            }
            .padding(24)
        }
    }

    // MARK: - Right Pane: Album & Artist Information

    private var infoPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ALBUM & ARTIST INFO")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(EchoTheme.neoMint)

                    Text(album.title)
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(EchoTheme.textPrimary)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        if let picStr = onlineInfo?.artistImageURL, let picURL = URL(string: picStr) {
                            AsyncImage(url: picURL) { phase in
                                if case .success(let image) = phase {
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 22, height: 22)
                                        .clipShape(Circle())
                                        .overlay(Circle().strokeBorder(EchoTheme.neoMint.opacity(0.55), lineWidth: 1))
                                }
                            }
                        }

                        ArtistLinksView(
                            rawArtists: album.artist,
                            font: .system(size: 14, weight: .bold),
                            color: EchoTheme.neoMint,
                            hoverColor: EchoTheme.textPrimary
                        ) { artistName in
                            store.closeAlbumLightbox()
                            store.openArtist(name: artistName)
                        }
                    }
                }

                Spacer(minLength: 10)

                HStack(spacing: 6) {
                    Button {
                        store.ensureEditorialLoaded(forAlbum: album, force: true)
                    } label: {
                        Group {
                            if isLoadingOnlineInfo {
                                ProgressView().controlSize(.mini).frame(width: 28, height: 28)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 11, weight: .bold))
                                    .frame(width: 28, height: 28)
                            }
                        }
                        .background(EchoTheme.surfaceElevated)
                        .foregroundStyle(EchoTheme.neoMint)
                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous)
                                .strokeBorder(EchoTheme.neoMint.opacity(0.45), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoadingOnlineInfo)
                    .help(onlineInfo.map { "Refresh online info (cached locally \($0.fetchedAt.formatted(date: .abbreviated, time: .shortened)))" } ?? "Refresh online album & artist info")

                    Button {
                        store.closeAlbumLightbox()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11.5, weight: .bold))
                            .frame(width: 28, height: 28)
                            .background(EchoTheme.surfaceElevated)
                            .foregroundStyle(EchoTheme.textPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous)
                                    .strokeBorder(EchoTheme.neoMint.opacity(0.50), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Close lightbox (Esc)")
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .padding(.bottom, 14)

            Divider().overlay(EchoTheme.border)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        metadataTile(
                            label: "RELEASE",
                            value: onlineInfo?.releaseDate ?? album.year.map(String.init) ?? "Unknown",
                            icon: "calendar"
                        )
                        metadataTile(
                            label: "TRACKS & LENGTH",
                            value: "\(album.tracks.count) tracks\(discCount > 1 ? " · \(discCount) discs" : "") · \(Formatters.duration(album.totalDuration))",
                            icon: "music.note.list"
                        )
                        metadataTile(
                            label: "AUDIO QUALITY",
                            value: audioSummary.isEmpty ? "Audio" : audioSummary,
                            icon: "waveform"
                        )
                        metadataTile(
                            label: "SIZE & PLAYS",
                            value: "\(Formatters.bytes(album.totalSize))\(albumPlays > 0 ? " · \(albumPlays) plays" : "")",
                            icon: "internaldrive"
                        )
                        if let label = onlineInfo?.label {
                            metadataTile(label: "RECORD LABEL", value: label, icon: "opticaldisc")
                        }
                        if let avgPopularity {
                            let fanText = onlineInfo?.albumFans.map { " · \(Formatters.compactCount($0)) fans" } ?? ""
                            metadataTile(label: "POPULARITY", value: "\(avgPopularity)/100\(fanText)", icon: "chart.bar.fill")
                        } else if let albumFans = onlineInfo?.albumFans {
                            metadataTile(label: "DEEZER FANS", value: Formatters.compactCount(albumFans), icon: "heart.fill")
                        }
                    }

                    if !taggedGenres.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(taggedGenres.prefix(5), id: \.self) { genre in
                                Text(genre)
                                    .font(.system(size: 10.5, weight: .semibold))
                                    .foregroundStyle(EchoTheme.neoMint)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3.5)
                                    .background(EchoTheme.neoMint.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: EchoTheme.radiusSmall, style: .continuous)
                                            .strokeBorder(EchoTheme.neoMint.opacity(0.38), lineWidth: 0.9)
                                    )
                            }
                        }
                    }

                    if let albumSummary = onlineInfo?.albumSummary {
                        infoSection(title: "ABOUT THIS ALBUM", bodyText: albumSummary)
                    }

                    if let artistSummary = onlineInfo?.artistSummary {
                        let subtitle: String? = {
                            var bits: [String] = []
                            if let fans = onlineInfo?.artistFans { bits.append("\(Formatters.compactCount(fans)) Deezer fans") }
                            if let count = onlineInfo?.artistAlbumCount { bits.append("\(count) releases") }
                            return bits.isEmpty ? nil : bits.joined(separator: " · ")
                        }()
                        infoSection(title: "ABOUT \(primaryArtistName.uppercased())", subtitle: subtitle, bodyText: artistSummary)
                    } else if isLoadingOnlineInfo {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Loading & caching album and artist details...")
                                .font(.system(size: 11.5))
                                .foregroundStyle(EchoTheme.textMuted)
                        }
                        .padding(.vertical, 4)
                    }

                    if !otherAlbumsByArtist.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("MORE BY \(primaryArtistName.uppercased()) IN YOUR LIBRARY")
                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                .tracking(1.1)
                                .foregroundStyle(EchoTheme.textMuted)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(otherAlbumsByArtist) { other in
                                        Button {
                                            store.openAlbumLightbox(other)
                                        } label: {
                                            HStack(spacing: 7) {
                                                ArtworkView(hash: other.artworkHash, artworkCache: store.artworkCache, cornerRadius: 4, iconSize: 12)
                                                    .frame(width: 28, height: 28)
                                                VStack(alignment: .leading, spacing: 1) {
                                                    Text(other.title)
                                                        .font(.system(size: 11, weight: .semibold))
                                                        .foregroundStyle(EchoTheme.textPrimary)
                                                        .lineLimit(1)
                                                    if let y = other.year {
                                                        Text(String(y))
                                                            .font(.system(size: 9.5, design: .monospaced))
                                                            .foregroundStyle(EchoTheme.textMuted)
                                                    }
                                                }
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 5)
                                            .background(EchoTheme.surfaceElevated)
                                            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous)
                                                    .strokeBorder(EchoTheme.neoMint.opacity(0.35), lineWidth: 1)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .help("View '\(other.title)' in lightbox")
                                    }
                                }
                            }
                        }
                    }

                    if let fetchedAt = onlineInfo?.fetchedAt {
                        Text("Stored locally in SQLite · Synced \(fetchedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(EchoTheme.textMuted.opacity(0.75))
                    }
                }
                .padding(22)
            }

            Divider().overlay(EchoTheme.border)

            HStack(spacing: 10) {
                NeoPrimaryButton(title: "Play Album", icon: "play.fill") {
                    store.player.play(tracks: album.tracks, startingAt: 0)
                }

                if !isAlreadyOnAlbumPage {
                    NeoSecondaryButton(title: "Open Album", icon: "square.stack.fill") {
                        store.closeAlbumLightbox()
                        store.navigate(to: .albumDetail(album.id))
                    }
                }

                NeoSecondaryButton(title: "Artist", icon: "person.fill") {
                    store.closeAlbumLightbox()
                    store.openArtist(name: primaryArtistName)
                }

                Spacer()

                if let firstTrack = album.tracks.first {
                    NeoSecondaryButton(title: "Finder", icon: "folder") {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: firstTrack.filePath)])
                    }
                    .help("Reveal album files in Finder")
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
        }
    }

    private func metadataTile(label: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(EchoTheme.neoMint)
                Text(label)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(EchoTheme.textMuted)
            }
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(EchoTheme.textPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(EchoTheme.surfaceElevated.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous)
                .strokeBorder(EchoTheme.border, lineWidth: 1)
        )
    }

    private func infoSection(title: String, subtitle: String? = nil, bodyText: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(EchoTheme.neoMint)
                if let subtitle {
                    Text("· \(subtitle)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(EchoTheme.textMuted)
                }
            }
            Text(bodyText)
                .font(.system(size: 12))
                .foregroundStyle(EchoTheme.textSecondary)
                .lineSpacing(3.5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EchoTheme.surfaceElevated.opacity(0.52))
        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous)
                .strokeBorder(EchoTheme.border, lineWidth: 1)
        )
    }

    private func loadFullResArtwork() {
        fullResImage = nil
        artworkPixelSize = nil
        guard let hash = album.artworkHash else { return }

        let cache = store.artworkCache
        Task.detached(priority: .userInitiated) {
            guard let data = cache.loadOriginalData(for: hash),
                  let image = NSImage(data: data) else { return }

            var dims: (Int, Int)?
            if let src = CGImageSourceCreateWithData(data as CFData, nil),
               let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
               let w = props[kCGImagePropertyPixelWidth] as? Int,
               let h = props[kCGImagePropertyPixelHeight] as? Int,
               w > 0, h > 0 {
                dims = (w, h)
            } else if let rep = image.representations.first, rep.pixelsWide > 0, rep.pixelsHigh > 0 {
                dims = (rep.pixelsWide, rep.pixelsHigh)
            }

            await MainActor.run {
                self.fullResImage = image
                self.artworkPixelSize = dims
            }
        }
    }
}

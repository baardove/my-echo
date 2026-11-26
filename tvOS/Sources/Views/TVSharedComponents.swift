import SwiftUI
import UIKit

@MainActor
final class TVImageCache {
    static let shared = TVImageCache()

    private let cache: NSCache<NSURL, UIImage> = {
        let c = NSCache<NSURL, UIImage>()
        c.countLimit = 250
        c.totalCostLimit = 80 * 1024 * 1024
        return c
    }()

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.requestCachePolicy = .returnCacheDataElseLoad
        cfg.urlCache = URLCache(
            memoryCapacity: 40 * 1024 * 1024,
            diskCapacity: 150 * 1024 * 1024
        )
        cfg.timeoutIntervalForRequest = 15
        return URLSession(configuration: cfg)
    }()

    private var inFlight: [URL: Task<UIImage?, Never>] = [:]

    func cachedImage(for url: URL?) -> UIImage? {
        guard let url else { return nil }
        return cache.object(forKey: url as NSURL)
    }

    func loadImage(for url: URL) async -> UIImage? {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }
        if let existing = inFlight[url] {
            return await existing.value
        }

        let urlSession = session
        let task = Task<UIImage?, Never> {
            do {
                let (data, response) = try await urlSession.data(from: url)
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    return nil
                }
                return await Task.detached(priority: .userInitiated) {
                    UIImage(data: data)
                }.value
            } catch {
                return nil
            }
        }
        inFlight[url] = task
        let image = await task.value
        inFlight[url] = nil
        if let image {
            let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
            cache.setObject(image, forKey: url as NSURL, cost: max(1, cost))
        }
        return image
    }
}

struct TVArtworkView: View {
    let url: URL?
    var cornerRadius: CGFloat = EchoTVTheme.radiusCard
    var fallbackIcon: String = "music.note"
    var preservePreviousWhileLoading: Bool = false

    @State private var loadedImage: UIImage?
    @State private var loadedURL: URL?

    var body: some View {
        let displayImage: UIImage? = {
            if let cached = TVImageCache.shared.cachedImage(for: url) {
                return cached
            }
            if url == nil {
                return nil
            }
            if loadedURL == url {
                return loadedImage
            }
            return preservePreviousWhileLoading ? loadedImage : nil
        }()

        ZStack {
            EchoTVTheme.surfaceElevated
            if let displayImage {
                Image(uiImage: displayImage)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(EchoTVTheme.border, lineWidth: 1)
        )
        .task(id: url) {
            guard let url else {
                loadedImage = nil
                loadedURL = nil
                return
            }
            if let cached = TVImageCache.shared.cachedImage(for: url) {
                loadedImage = cached
                loadedURL = url
                return
            }
            let fetched = await TVImageCache.shared.loadImage(for: url)
            guard !Task.isCancelled else { return }
            if let fetched {
                loadedImage = fetched
                loadedURL = url
            } else if !preservePreviousWhileLoading {
                loadedImage = nil
                loadedURL = url
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [EchoTVTheme.surfaceElevated, EchoTVTheme.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: fallbackIcon)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(EchoTVTheme.neoMint.opacity(0.65))
        }
    }
}

struct TVBackdropArtworkView: View {
    let url: URL?
    var opacity: Double = 0.28

    @State private var loadedImage: UIImage?

    var body: some View {
        let displayImage = TVImageCache.shared.cachedImage(for: url) ?? (url == nil ? nil : loadedImage)

        ZStack {
            EchoTVTheme.canvas
            if let displayImage {
                GeometryReader { bgGeo in
                    Image(uiImage: displayImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: bgGeo.size.width, height: bgGeo.size.height)
                        .clipped()
                        .blur(radius: 90)
                        .opacity(opacity)
                }
            }
        }
        .ignoresSafeArea()
        .task(id: url) {
            guard let url else {
                loadedImage = nil
                return
            }
            if let cached = TVImageCache.shared.cachedImage(for: url) {
                if loadedImage !== cached {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        loadedImage = cached
                    }
                }
                return
            }
            let fetched = await TVImageCache.shared.loadImage(for: url)
            guard !Task.isCancelled, let fetched else { return }
            withAnimation(.easeInOut(duration: 0.35)) {
                loadedImage = fetched
            }
        }
    }
}

struct TVQualityBadge: View {
    let primary: String
    let detail: String?
    let isHiRes: Bool
    let isLossless: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(primary)
                .font(.system(size: 16, weight: .black, design: .monospaced))
            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .opacity(0.85)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(badgeColor.opacity(0.20))
        .foregroundStyle(badgeColor)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(badgeColor.opacity(0.55), lineWidth: 1.5)
        )
    }

    private var badgeColor: Color {
        if isHiRes { return EchoTVTheme.hiResGold }
        if isLossless { return EchoTVTheme.neoMint }
        return EchoTVTheme.neoCyan
    }
}

struct TVSectionHeader: View {
    let eyebrow: String
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(eyebrow.uppercased())
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(EchoTVTheme.neoMint)
                Text(title)
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(EchoTVTheme.textPrimary)
            }
            Spacer()
            if let trailing, !trailing.isEmpty {
                Text(trailing)
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundStyle(EchoTVTheme.textMuted)
            }
        }
    }
}

struct TVProgressBar: View {
    let progress: Double
    var tint: Color = EchoTVTheme.neoMint
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.14))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [tint, EchoTVTheme.neoCyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, geo.size.width * min(1, max(0, progress))))
            }
        }
        .frame(height: height)
    }
}

struct EchoTVButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 12
    var accent: Color = EchoTVTheme.neoMint

    func makeBody(configuration: Configuration) -> some View {
        EchoTVButtonBody(
            configuration: configuration,
            cornerRadius: cornerRadius,
            accent: accent
        )
    }
}

private struct EchoTVButtonBody: View {
    @Environment(\.isFocused) private var isFocused
    let configuration: ButtonStyle.Configuration
    let cornerRadius: CGFloat
    let accent: Color

    var body: some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : (isFocused ? 1.02 : 1.0))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        isFocused ? accent.opacity(0.95) : Color.clear,
                        lineWidth: 2.5
                    )
            )
            .shadow(
                color: isFocused ? accent.opacity(0.26) : .clear,
                radius: 8,
                y: 3
            )
            .focusEffectDisabled()
            .animation(.easeOut(duration: 0.14), value: isFocused)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

struct TVLibraryModeToggle: View {
    @Environment(TVEchoStore.self) private var store

    var body: some View {
        HStack(spacing: 6) {
            ForEach(TVLibraryTapMode.allCases) { mode in
                let selected = store.libraryTapMode == mode
                let accent = mode == .playNow ? EchoTVTheme.neoMint : EchoTVTheme.neoCyan
                Button {
                    if store.libraryTapMode != mode {
                        store.libraryTapMode = mode
                        store.showToast(
                            mode == .playNow
                                ? "Library Mode: Play Now"
                                : "Library Mode: Add to Queue"
                        )
                    }
                } label: {
                    Label(
                        mode.rawValue,
                        systemImage: mode == .playNow ? "play.fill" : "text.badge.plus"
                    )
                    .font(.system(size: 17, weight: .bold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(selected ? accent : Color.clear)
                    .foregroundStyle(selected ? Color.black : EchoTVTheme.textSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(EchoTVButtonStyle(cornerRadius: 8, accent: accent))
            }
        }
        .padding(4)
        .background(EchoTVTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    (store.libraryTapMode == .addToQueue ? EchoTVTheme.neoCyan : EchoTVTheme.border).opacity(0.6),
                    lineWidth: 1.5
                )
        )
    }
}

struct TVAlbumCardTile: View {
    let title: String
    let subtitle: String
    let year: Int?
    let artworkURL: URL?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                TVArtworkView(url: artworkURL, cornerRadius: 12)
                    .frame(width: 260, height: 260)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(EchoTVTheme.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(subtitle)
                            .lineLimit(1)
                        if let year, year > 0 {
                            Text("· \(String(year))")
                        }
                    }
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(EchoTVTheme.textSecondary)
                }
                .frame(width: 260, alignment: .leading)
                .padding(.horizontal, 4)
                .padding(.bottom, 8)
            }
            .padding(10)
            .background(EchoTVTheme.surface)
        }
        .buttonStyle(.card)
    }
}

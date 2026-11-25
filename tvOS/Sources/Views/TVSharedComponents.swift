import SwiftUI

struct TVArtworkView: View {
    let url: URL?
    var cornerRadius: CGFloat = EchoTVTheme.radiusCard
    var fallbackIcon: String = "music.note"

    var body: some View {
        ZStack {
            EchoTVTheme.surfaceElevated
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty:
                        placeholder
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(EchoTVTheme.border, lineWidth: 1)
        )
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

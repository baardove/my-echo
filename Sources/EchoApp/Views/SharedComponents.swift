import SwiftUI
import AppKit
import EchoCore

/// Interactive hover-underlined link for Artist and Album names across tables, cards, and player chrome
struct HoverLinkText: View {
    let text: String
    var font: Font = .system(size: 11.5)
    var color: Color = EchoTheme.textSecondary
    var hoverColor: Color = EchoTheme.neoMint
    var tip: String? = nil
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(font)
                .foregroundStyle(isHovered ? hoverColor : color)
                .underline(isHovered)
                .lineLimit(1)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .help(tip ?? "Open \(text)")
    }
}

/// Splits multi-artist credit strings ("Alan Walker, Noah Cyrus, Digital Farm Animals, Juliander")
/// and renders each artist as its own independently hoverable & clickable link.
struct ArtistLinksView: View {
    let rawArtists: String
    var font: Font = .system(size: 11.5)
    var color: Color = EchoTheme.textSecondary
    var hoverColor: Color = EchoTheme.neoMint
    var separatorColor: Color = EchoTheme.textMuted
    let onSelectArtist: (String) -> Void

    var body: some View {
        let segments = ArtistNameParser.splitSegments(rawArtists)
        if segments.count <= 1 {
            let name = segments.first?.name ?? rawArtists
            HoverLinkText(
                text: name,
                font: font,
                color: color,
                hoverColor: hoverColor,
                tip: "Go to artist '\(name)'"
            ) {
                onSelectArtist(name)
            }
        } else {
            HStack(spacing: 0) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                    HoverLinkText(
                        text: seg.name,
                        font: font,
                        color: color,
                        hoverColor: hoverColor,
                        tip: "Go to artist '\(seg.name)'"
                    ) {
                        onSelectArtist(seg.name)
                    }
                    if !seg.trailingSeparator.isEmpty {
                        Text(seg.trailingSeparator)
                            .font(font)
                            .foregroundStyle(separatorColor)
                            .lineLimit(1)
                            .fixedSize()
                    }
                }
            }
            .lineLimit(1)
        }
    }
}

struct ArtworkView: View {
    let hash: String?
    let artworkCache: ArtworkCache
    var cornerRadius: CGFloat = 6
    var iconSize: CGFloat = 28

    var body: some View {
        let r = min(cornerRadius, 8)
        Group {
            if let img = ArtworkImageLoader.shared.image(forHash: hash, artworkCache: artworkCache) {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    LinearGradient(
                        colors: [EchoTheme.surfaceElevated, EchoTheme.surface],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "waveform")
                        .font(.system(size: iconSize, weight: .light))
                        .foregroundStyle(EchoTheme.neoMint.opacity(0.45))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: r, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: r, style: .continuous)
                .strokeBorder(EchoTheme.border, lineWidth: 1)
        )
    }
}

struct PlaylistMosaicArtwork: View {
    let tracks: [Track]
    let artworkCache: ArtworkCache
    var cornerRadius: CGFloat = 6

    private var uniqueHashes: [String] {
        var seen: Set<String> = []
        var out: [String] = []
        for t in tracks {
            if let h = t.artworkHash, seen.insert(h).inserted {
                out.append(h)
                if out.count == 4 { break }
            }
        }
        return out
    }

    var body: some View {
        let r = min(cornerRadius, 8)
        let hashes = uniqueHashes
        Group {
            if hashes.count >= 4 {
                VStack(spacing: 1) {
                    HStack(spacing: 1) {
                        ArtworkView(hash: hashes[0], artworkCache: artworkCache, cornerRadius: 0, iconSize: 16)
                        ArtworkView(hash: hashes[1], artworkCache: artworkCache, cornerRadius: 0, iconSize: 16)
                    }
                    HStack(spacing: 1) {
                        ArtworkView(hash: hashes[2], artworkCache: artworkCache, cornerRadius: 0, iconSize: 16)
                        ArtworkView(hash: hashes[3], artworkCache: artworkCache, cornerRadius: 0, iconSize: 16)
                    }
                }
            } else if let first = hashes.first {
                ArtworkView(hash: first, artworkCache: artworkCache, cornerRadius: 0, iconSize: 28)
            } else {
                ZStack {
                    LinearGradient(
                        colors: [EchoTheme.neoMint.opacity(0.22), EchoTheme.neoMagenta.opacity(0.16), EchoTheme.surface],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "music.note.list")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(EchoTheme.neoMint)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: r, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: r, style: .continuous)
                .strokeBorder(EchoTheme.borderStrong, lineWidth: 1)
        )
    }
}

/// Crisp retro tags showing which destinations a track or podcast episode is synced/assigned to
struct DestinationBadgeStrip: View {
    let badges: [DestinationBadgeInfo]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(badges.prefix(3)) { b in
                let col = EchoTheme.color(for: b.accent)
                HStack(spacing: 3) {
                    if b.isSynced {
                        Image(systemName: "checkmark")
                            .font(.system(size: 7, weight: .black))
                    }
                    Text(b.name)
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .lineLimit(1)
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(b.isSynced ? col.opacity(0.22) : Color.clear)
                .foregroundStyle(col)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(col.opacity(b.isSynced ? 0.65 : 0.45), style: StrokeStyle(lineWidth: 0.9, dash: b.isSynced ? [] : [2, 1.5]))
                )
                .help(b.isSynced
                      ? "Synced to '\(b.name)'\(b.isAssigned ? " (and active in its sync selection)" : " (previously synced)")"
                      : "Queued to sync to '\(b.name)' on next sync")
            }
            if badges.count > 3 {
                Text("+\(badges.count - 3)")
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(EchoTheme.textMuted)
            }
        }
    }
}

struct FormatBadge: View {
    let track: Track
    var isUnsupported: Bool = false
    var compact: Bool = false

    var body: some View {
        Group {
            if compact {
                HStack(alignment: .firstTextBaseline, spacing: 3.5) {
                    if isUnsupported {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 8))
                    }
                    Text(track.formatPrimaryLabel)
                        .font(.system(size: 9.5, weight: .black, design: .monospaced))
                        .tracking(0.4)
                    if let detail = track.formatDetailLabel {
                        Text(detail)
                            .font(.system(size: 7.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(foregroundColor.opacity(0.82))
                    }
                }
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
            } else {
                VStack(alignment: .center, spacing: 0.5) {
                    HStack(spacing: 3) {
                        if isUnsupported {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 8))
                        }
                        Text(track.formatPrimaryLabel)
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .tracking(0.6)
                    }
                    if let detail = track.formatDetailLabel {
                        Text(detail)
                            .font(.system(size: 7.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(foregroundColor.opacity(0.82))
                            .lineLimit(1)
                    }
                }
                .fixedSize()
                .padding(.horizontal, 6.5)
                .padding(.vertical, 2.5)
            }
        }
        .background(backgroundColor)
        .foregroundStyle(foregroundColor)
        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: EchoTheme.radiusSmall)
                .strokeBorder(foregroundColor.opacity(0.42), lineWidth: 0.85)
        )
        .help(isUnsupported
              ? "Format \(track.format.displayBadge) is not supported by the selected destination profile and will be skipped on sync."
              : "Audio format & resolution: \(track.qualityLabel)")
    }

    private var foregroundColor: Color {
        if isUnsupported { return EchoTheme.warningAmber }
        if track.isHiRes { return EchoTheme.hiResGold }
        if track.format.isLossless { return EchoTheme.neoCyan }
        return EchoTheme.textSecondary
    }

    private var backgroundColor: Color {
        foregroundColor.opacity(0.12)
    }
}

/// Compact 5-bar online popularity equalizer + numeric score (0–100) with rich tooltip
struct OnlinePopularityMeter: View {
    let stats: TrackStats
    var compact: Bool = false

    var body: some View {
        let filled = stats.popularityBars
        let score = stats.onlinePopularity

        HStack(spacing: 5) {
            // 5-bar ascending retro LED popularity meter
            HStack(alignment: .bottom, spacing: 1.5) {
                ForEach(1...5, id: \.self) { level in
                    let isLit = score != nil && level <= filled
                    RoundedRectangle(cornerRadius: 1)
                        .fill(isLit ? barColor(for: score ?? 0) : EchoTheme.textMuted.opacity(0.22))
                        .frame(width: 2.5, height: CGFloat(4 + level * 2))
                }
            }
            .frame(height: 14, alignment: .bottom)

            if !compact {
                if let score {
                    Text("\(score)")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(barColor(for: score))
                        .frame(minWidth: 20, alignment: .trailing)
                } else {
                    Text("—")
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(EchoTheme.textMuted.opacity(0.5))
                        .frame(minWidth: 20, alignment: .trailing)
                }
            }
        }
        .help(tooltipText)
    }

    private func barColor(for score: Int) -> Color {
        if score >= 75 { return EchoTheme.neoMint }
        if score >= 50 { return EchoTheme.neoCyan }
        if score >= 25 { return EchoTheme.hiResGold }
        return EchoTheme.textSecondary
    }

    private var tooltipText: String {
        guard let score = stats.onlinePopularity else {
            return "Online popularity not fetched yet. Open the album or click 'Fetch Online Popularity' in the menu."
        }
        var parts = ["Online popularity: \(score)/100"]
        if let src = stats.onlineSource {
            if src.contains("lastfm"), let plays = stats.onlinePlayCount {
                parts.append("Last.fm global plays: \(Formatters.compactCount(plays))")
                if let listeners = stats.onlineListeners, listeners > 0 {
                    parts.append("\(Formatters.compactCount(listeners)) listeners")
                }
            } else if let rank = stats.onlinePlayCount {
                parts.append("Deezer rank: \(Formatters.compactCount(rank))")
            }
        }
        return parts.joined(separator: " · ")
    }
}

/// Compact personal play counter badge for TrackRowView
struct UserPlayCountBadge: View {
    let stats: TrackStats

    var body: some View {
        HStack(spacing: 3) {
            if stats.userPlayCount > 0 {
                Image(systemName: "play.fill")
                    .font(.system(size: 7.5))
                    .foregroundStyle(EchoTheme.neoMint.opacity(0.85))
                Text(Formatters.compactCount(stats.userPlayCount))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(EchoTheme.textPrimary)
            } else {
                Text("0")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(EchoTheme.textMuted.opacity(0.45))
            }
        }
        .help(tooltipText)
    }

    private var tooltipText: String {
        if stats.userPlayCount == 0 {
            return "Your plays: 0 (counts automatically after listening to 30s or half the track)."
        }
        let base = "Your plays: \(stats.userPlayCount)"
        if let last = stats.lastPlayedAt {
            return "\(base) · Last played \(last.formatted(date: .abbreviated, time: .shortened))"
        }
        return base
    }
}

struct SyncStatePillButton: View {
    let state: SyncSelectionState
    var compact: Bool = false
    var label: String = "Sync"
    var tooltip: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if compact {
                Text("S")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .frame(width: 24, height: 24)
                    .background(compactBackground)
                    .foregroundStyle(foreground)
                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: EchoTheme.radiusSmall, style: .continuous)
                            .strokeBorder(borderColor, lineWidth: state == .none ? 0.9 : 1.15)
                    )
                    .shadow(color: state == .full ? EchoTheme.neoMint.opacity(0.38) : Color.black.opacity(0.35), radius: 4)
            } else {
                HStack(spacing: 5) {
                    Image(systemName: iconName)
                        .font(.system(size: 12.5, weight: .semibold))
                    Text(buttonTitle)
                        .font(.system(size: 12, weight: .bold))
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 6.5)
                .background(background)
                .foregroundStyle(foreground)
                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: 1)
                )
            }
        }
        .buttonStyle(.plain)
        .help(tooltip ?? defaultTooltip)
    }

    private var compactBackground: Color {
        switch state {
        case .full: return EchoTheme.neoMint.opacity(0.28)
        case .partial: return EchoTheme.neoCyan.opacity(0.24)
        case .none: return Color.black.opacity(0.68)
        }
    }

    private var defaultTooltip: String {
        switch state {
        case .full: return "Included in the selected destination's sync list. Click to remove."
        case .partial: return "Partially included in the selected destination's sync list. Click to include all tracks."
        case .none: return "Include in the selected destination's sync list."
        }
    }

    private var iconName: String {
        switch state {
        case .full: return "checkmark.square.fill"
        case .partial: return "minus.square.fill"
        case .none: return "plus.square"
        }
    }

    private var buttonTitle: String {
        switch state {
        case .full: return "Synced"
        case .partial: return "Partial"
        case .none: return label
        }
    }

    private var background: Color {
        switch state {
        case .full: return EchoTheme.neoMint.opacity(0.20)
        case .partial: return EchoTheme.neoCyan.opacity(0.18)
        case .none: return EchoTheme.surfaceElevated.opacity(0.88)
        }
    }

    private var foreground: Color {
        switch state {
        case .full: return EchoTheme.neoMint
        case .partial: return EchoTheme.neoCyan
        case .none: return EchoTheme.textPrimary
        }
    }

    private var borderColor: Color {
        switch state {
        case .full: return EchoTheme.neoMint.opacity(0.60)
        case .partial: return EchoTheme.neoCyan.opacity(0.55)
        case .none: return EchoTheme.borderStrong
        }
    }
}

/// Matching top-right corner `P` (Playlist) + `S` (Sync / Subscription) badge strip for Album and Artist cards.
struct CardPSBadgeStrip: View {
    let playlistState: SyncSelectionState
    let syncState: SyncSelectionState
    let isCardHovered: Bool
    let playlistTooltip: String
    let syncTooltip: String
    let onTogglePlaylist: () -> Void
    let onToggleSync: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            if playlistState != .none || isCardHovered {
                Button(action: onTogglePlaylist) {
                    Text("P")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .frame(width: 24, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: EchoTheme.radiusSmall, style: .continuous)
                                .fill(playlistBg)
                        )
                        .foregroundStyle(playlistFg)
                        .overlay(
                            RoundedRectangle(cornerRadius: EchoTheme.radiusSmall, style: .continuous)
                                .strokeBorder(playlistBorder, lineWidth: playlistState == .none ? 0.9 : 1.15)
                        )
                        .shadow(color: playlistState == .full ? EchoTheme.neoCyan.opacity(0.38) : Color.black.opacity(0.35), radius: 4)
                }
                .buttonStyle(.plain)
                .help(playlistTooltip)
            }

            if syncState != .none || isCardHovered {
                SyncStatePillButton(
                    state: syncState,
                    compact: true,
                    tooltip: syncTooltip,
                    action: onToggleSync
                )
            }
        }
    }

    private var playlistBg: Color {
        switch playlistState {
        case .full: return EchoTheme.neoCyan.opacity(0.28)
        case .partial: return EchoTheme.neoCyan.opacity(0.16)
        case .none: return Color.black.opacity(0.68)
        }
    }

    private var playlistFg: Color {
        switch playlistState {
        case .full: return EchoTheme.neoCyan
        case .partial: return EchoTheme.neoCyan.opacity(0.85)
        case .none: return EchoTheme.textPrimary.opacity(0.85)
        }
    }

    private var playlistBorder: Color {
        switch playlistState {
        case .full: return EchoTheme.neoCyan.opacity(0.8)
        case .partial: return EchoTheme.neoCyan.opacity(0.5)
        case .none: return EchoTheme.borderStrong
        }
    }
}

struct NeoPrimaryButton: View {
    let title: String
    var icon: String? = nil
    var disabled: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11.5, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 12, weight: .bold))
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 6.5)
            .background(
                ZStack {
                    EchoTheme.surfaceElevated.opacity(0.85)
                    if !disabled {
                        EchoTheme.neoMint.opacity(isHovered ? 0.26 : 0.18)
                    }
                }
            )
            .foregroundStyle(disabled ? EchoTheme.textMuted : EchoTheme.neoMint)
            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous)
                    .strokeBorder(
                        disabled ? EchoTheme.border : EchoTheme.neoMint.opacity(isHovered ? 0.90 : 0.65),
                        lineWidth: 1
                    )
            )
            .shadow(color: disabled ? .clear : EchoTheme.neoMint.opacity(isHovered ? 0.28 : 0.14), radius: 5, y: 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .onHover { isHovered = $0 }
    }
}

/// Matching dark-emerald + neon green outline label for primary action `Menu` controls.
struct NeoPrimaryMenuLabel: View {
    let title: String
    let icon: String
    var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 5.5) {
            Image(systemName: icon)
                .font(.system(size: 11.5, weight: .bold))
            Text(title)
                .font(.system(size: 12, weight: .bold))
            Image(systemName: "chevron.down")
                .font(.system(size: 8.5, weight: .bold))
                .opacity(0.85)
        }
        .padding(.horizontal, 12.5)
        .padding(.vertical, 6.5)
        .background(
            ZStack {
                EchoTheme.surfaceElevated.opacity(0.85)
                EchoTheme.neoMint.opacity(isHovered ? 0.26 : 0.18)
            }
        )
        .foregroundStyle(EchoTheme.neoMint)
        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous)
                .strokeBorder(EchoTheme.neoMint.opacity(isHovered ? 0.90 : 0.65), lineWidth: 1)
        )
        .shadow(color: EchoTheme.neoMint.opacity(isHovered ? 0.28 : 0.14), radius: 5, y: 1)
    }
}

// MARK: - AppKit-Proof Dark Neon Dropdowns, Pickers, Segmented Controls & Text Fields

enum NeoMenuItem {
    case action(
        title: String,
        icon: String? = nil,
        isSelected: Bool = false,
        isDestructive: Bool = false,
        action: @MainActor () -> Void
    )
    case divider
}

@MainActor
private final class NeoMenuItemTarget: NSObject {
    let handler: @MainActor () -> Void

    init(_ handler: @escaping @MainActor () -> Void) {
        self.handler = handler
    }

    @objc func invoke(_ sender: Any?) {
        handler()
    }
}

private final class NeoMenuAnchorNSView: NSView {
    override var isFlipped: Bool { true }
}

private struct NeoMenuAnchorRepresentable: NSViewRepresentable {
    let onView: (NSView) -> Void

    func makeNSView(context: Context) -> NSView {
        let v = NeoMenuAnchorNSView(frame: .zero)
        DispatchQueue.main.async { onView(v) }
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { onView(nsView) }
    }
}

/// Pure SwiftUI trigger + native macOS `NSMenu` popup anchored cleanly below the control.
/// Unlike SwiftUI `.menuStyle(.borderlessButton)`, AppKit never strips backgrounds, neon borders,
/// status dots, or custom icon colors from the trigger label, and never injects a duplicate chevron.
struct NeoMenuButton<Label: View>: View {
    let items: () -> [NeoMenuItem]
    let label: (_ isHovered: Bool) -> Label

    @State private var isHovered = false
    @State private var anchorView: NSView?

    init(
        items: @escaping () -> [NeoMenuItem],
        @ViewBuilder label: @escaping (_ isHovered: Bool) -> Label
    ) {
        self.items = items
        self.label = label
    }

    var body: some View {
        Button {
            presentMenu()
        } label: {
            label(isHovered)
        }
        .buttonStyle(.plain)
        .background(
            NeoMenuAnchorRepresentable { view in
                anchorView = view
            }
            .allowsHitTesting(false)
        )
        .onHover { isHovered = $0 }
    }

    @MainActor
    private func presentMenu() {
        guard let view = anchorView else { return }
        let menu = NSMenu()
        menu.appearance = NSAppearance(named: .darkAqua)
        menu.minimumWidth = max(view.bounds.width, 150)

        for entry in items() {
            switch entry {
            case .divider:
                menu.addItem(.separator())
            case .action(let title, let icon, let isSelected, _, let handler):
                let target = NeoMenuItemTarget(handler)
                let item = NSMenuItem(
                    title: title,
                    action: #selector(NeoMenuItemTarget.invoke(_:)),
                    keyEquivalent: ""
                )
                item.target = target
                item.representedObject = target // keep target strongly retained while menu is open
                item.state = isSelected ? .on : .off
                if let icon, let img = NSImage(systemSymbolName: icon, accessibilityDescription: title) {
                    img.isTemplate = true
                    item.image = img
                }
                menu.addItem(item)
            }
        }

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: view.bounds.height + 4), in: view)
    }
}

/// Primary emerald-neon dropdown menu button (used for `Sync to`, `Sync Podcasts`, `Order Artist`, etc.).
struct NeoPrimaryMenuButton: View {
    let title: String
    let icon: String
    let items: () -> [NeoMenuItem]

    var body: some View {
        NeoMenuButton(items: items) { isHovered in
            NeoPrimaryMenuLabel(title: title, icon: icon, isHovered: isHovered)
        }
    }
}

/// Dark-slate + neon-green-outlined dropdown button for toolbars, pickers, and selectors.
struct NeoPickerDropdown<Selection: Hashable>: View {
    var prefix: String? = nil
    var icon: String? = nil
    var accent: Color = EchoTheme.neoMint
    var fullWidth: Bool = false
    @Binding var selection: Selection
    let options: [(value: Selection, title: String)]

    private var currentTitle: String {
        options.first(where: { $0.value == selection })?.title ?? ""
    }

    var body: some View {
        HStack(spacing: 7) {
            if let prefix, !prefix.isEmpty {
                Text(prefix)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(EchoTheme.textSecondary)
            }

            NeoMenuButton {
                options.map { opt in
                    .action(
                        title: opt.title,
                        isSelected: opt.value == selection
                    ) {
                        selection = opt.value
                    }
                }
            } label: { isHovered in
                HStack(spacing: 6) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(accent)
                    }
                    Text(currentTitle)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(EchoTheme.textPrimary)
                        .lineLimit(1)
                    if fullWidth {
                        Spacer(minLength: 4)
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(accent.opacity(isHovered ? 0.95 : 0.75))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: fullWidth ? .infinity : nil, alignment: .leading)
                .background(
                    ZStack {
                        EchoTheme.surfaceElevated
                        accent.opacity(isHovered ? 0.14 : 0.05)
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous)
                        .strokeBorder(accent.opacity(isHovered ? 0.90 : 0.55), lineWidth: 1)
                )
                .shadow(color: accent.opacity(isHovered ? 0.20 : 0.08), radius: 4, y: 1)
            }
        }
    }
}

/// Compact square icon menu trigger with dark background and crisp neon border.
struct NeoIconMenuButton: View {
    let icon: String
    var accent: Color = EchoTheme.neoMint
    var size: CGFloat = 30
    var iconSize: CGFloat = 12.5
    let items: () -> [NeoMenuItem]

    var body: some View {
        NeoMenuButton(items: items) { isHovered in
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .semibold))
                .frame(width: size, height: size)
                .background(
                    ZStack {
                        EchoTheme.surfaceElevated
                        accent.opacity(isHovered ? 0.16 : 0.06)
                    }
                )
                .foregroundStyle(isHovered ? accent : EchoTheme.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous)
                        .strokeBorder(accent.opacity(isHovered ? 0.90 : 0.50), lineWidth: 1)
                )
        }
    }
}

/// Dark + neon-green segmented control replacing native macOS gray `.pickerStyle(.segmented)`.
struct NeoSegmentedControl<Selection: Hashable>: View {
    @Binding var selection: Selection
    let options: [(value: Selection, title: String)]
    var accent: Color = EchoTheme.neoMint

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, opt in
                let isSelected = selection == opt.value
                Button {
                    selection = opt.value
                } label: {
                    Text(opt.title)
                        .font(.system(size: 11.5, weight: isSelected ? .bold : .semibold))
                        .foregroundStyle(isSelected ? accent : EchoTheme.textSecondary)
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: EchoTheme.radiusSmall, style: .continuous)
                                .fill(isSelected ? accent.opacity(0.20) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: EchoTheme.radiusSmall, style: .continuous)
                                .strokeBorder(isSelected ? accent.opacity(0.68) : Color.clear, lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(EchoTheme.surfaceElevated.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous)
                .strokeBorder(accent.opacity(0.42), lineWidth: 1)
        )
    }
}

/// Secondary dark-slate button with crisp green-neon rim (matches `Add Folder / NAS` / `Home` pill style).
struct NeoSecondaryButton: View {
    let title: String
    var icon: String? = nil
    var accent: Color = EchoTheme.neoMint
    var disabled: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5.5) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(disabled ? EchoTheme.textMuted : accent)
                }
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(disabled ? EchoTheme.textMuted : EchoTheme.textPrimary)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(
                ZStack {
                    EchoTheme.surfaceElevated
                    if !disabled {
                        accent.opacity(isHovered ? 0.14 : 0.05)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous)
                    .strokeBorder(
                        disabled ? EchoTheme.border : accent.opacity(isHovered ? 0.90 : 0.52),
                        lineWidth: 1
                    )
            )
            .shadow(color: disabled ? .clear : accent.opacity(isHovered ? 0.18 : 0.06), radius: 4, y: 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .onHover { isHovered = $0 }
    }
}

/// Dark + neon-green text field chrome replacing native macOS `.textFieldStyle(.roundedBorder)`.
extension View {
    func neoTextField(accent: Color = EchoTheme.neoMint) -> some View {
        self
            .textFieldStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(EchoTheme.textPrimary)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(EchoTheme.surfaceElevated.opacity(0.88))
            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous)
                    .strokeBorder(accent.opacity(0.45), lineWidth: 1)
            )
    }
}

struct DragPreviewPill: View {
    let title: String
    let subtitle: String
    let artworkHash: String?
    let artworkCache: ArtworkCache
    var badge: String? = nil

    var body: some View {
        HStack(spacing: 10) {
            ArtworkView(hash: artworkHash, artworkCache: artworkCache, cornerRadius: 4, iconSize: 14)
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(EchoTheme.textPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(EchoTheme.textSecondary)
                    .lineLimit(1)
            }
            if let badge {
                Text(badge)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(EchoTheme.neoMint.opacity(0.22))
                    .foregroundStyle(EchoTheme.neoMint)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(EchoTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous)
                .strokeBorder(EchoTheme.neoMint.opacity(0.75), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.55), radius: 10, y: 3)
    }
}

struct TrackRowView: View {
    @Environment(EchoStore.self) private var store
    let track: Track
    let index: Int
    var showAlbumColumn: Bool = true
    var playlistContext: (id: UUID, rowIndex: Int)? = nil
    let onPlay: () -> Void

    @State private var isHovered = false
    @State private var isReorderDropTargeted = false

    private var isCurrentlyPlaying: Bool {
        store.player.currentTrack?.id == track.id
    }

    private var syncReason: String? {
        store.trackSyncReason(track)
    }

    private var isInFocusedPlaylist: Bool {
        store.isTrackInFocusedPlaylist(track)
    }

    private var isUnsupported: Bool {
        guard let dev = store.activeDevice else { return false }
        return !dev.supports(track.format)
    }

    private var dragPayloadString: String {
        if let ctx = playlistContext {
            return EchoDragPayload.reorder(playlistID: ctx.id, sourceIndex: ctx.rowIndex).encode()
        }
        return EchoDragPayload.tracks([track.id]).encode()
    }

    var body: some View {
        rowContent
            .draggable(dragPayloadString) {
                DragPreviewPill(
                    title: track.title,
                    subtitle: track.artist,
                    artworkHash: track.artworkHash,
                    artworkCache: store.artworkCache,
                    badge: track.format.displayBadge
                )
            }
            .dropDestination(for: String.self) { items, _ in
                guard let ctx = playlistContext else { return false }
                return store.handlePlaylistReorderDrop(items: items, playlistID: ctx.id, targetIndex: ctx.rowIndex)
            } isTargeted: { targeted in
                if playlistContext != nil {
                    isReorderDropTargeted = targeted
                }
            }
    }

    private var rowContent: some View {
        let destBadges = store.destinations(forTrack: track)

        return HStack(spacing: 12) {
            // Index or Play button
            ZStack {
                if isHovered {
                    Button(action: onPlay) {
                        Image(systemName: isCurrentlyPlaying && store.player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(EchoTheme.neoMint)
                    }
                    .buttonStyle(.plain)
                    .help("Play '\(track.title)' in the bottom audio player.")
                } else if isCurrentlyPlaying {
                    Image(systemName: store.player.isPlaying ? "waveform" : "pause.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(EchoTheme.neoMint)
                } else {
                    Text("\(playlistContext != nil ? index + 1 : (track.trackNumber ?? index + 1))")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(EchoTheme.textMuted)
                }
            }
            .frame(width: 26)

            // Mini artwork + title + artist + remembered destination badges
            HStack(spacing: 10) {
                ArtworkView(hash: track.artworkHash, artworkCache: store.artworkCache, cornerRadius: EchoTheme.radiusSmall, iconSize: 13)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2.5) {
                    HStack(spacing: 6) {
                        Text(track.title)
                            .font(.system(size: 13, weight: isCurrentlyPlaying ? .bold : .medium))
                            .foregroundStyle(isCurrentlyPlaying ? EchoTheme.neoMint : EchoTheme.textPrimary)
                            .lineLimit(1)

                        if !track.isAvailable {
                            Text("OFFLINE")
                                .font(.system(size: 8.5, weight: .black, design: .monospaced))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(EchoTheme.dangerCoral.opacity(0.2))
                                .foregroundStyle(EchoTheme.dangerCoral)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                        if track.lyricsPath != nil {
                            Text("LRC")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.white.opacity(0.08))
                                .foregroundStyle(EchoTheme.textSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                                .help("Synced .lrc lyrics file detected — will copy alongside this track.")
                        }
                    }

                    HStack(spacing: 6) {
                        ArtistLinksView(
                            rawArtists: track.artist,
                            font: .system(size: 11.5),
                            color: EchoTheme.textSecondary,
                            hoverColor: EchoTheme.neoMint
                        ) { artistName in
                            store.openArtist(name: artistName)
                        }

                        if (store.destinationMode == .multi || destBadges.count > 1 || destBadges.contains(where: \.isSynced)) && !destBadges.isEmpty {
                            DestinationBadgeStrip(badges: destBadges)
                        }
                    }
                }
            }
            .frame(minWidth: 180, maxWidth: .infinity, alignment: .leading)

            if showAlbumColumn {
                HoverLinkText(
                    text: track.effectiveAlbum,
                    font: .system(size: 12),
                    color: EchoTheme.textSecondary,
                    hoverColor: EchoTheme.neoCyan,
                    tip: "Go to album '\(track.effectiveAlbum)'"
                ) {
                    store.openAlbum(forTrack: track)
                }
                .frame(width: 150, alignment: .leading)
            }

            let trackStat = store.stats(for: track)

            UserPlayCountBadge(stats: trackStat)
                .frame(width: 44, alignment: .trailing)

            OnlinePopularityMeter(stats: trackStat)
                .frame(width: 50, alignment: .trailing)

            FormatBadge(track: track, isUnsupported: isUnsupported)
                .frame(width: 86, alignment: .center)

            // Compact "P" badge to add/toggle song in focused playlist (grey when off, neon cyan when in playlist)
            if playlistContext == nil {
                Button {
                    store.toggleTrackInFocusedPlaylist(track)
                } label: {
                    Text("P")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .frame(width: 24, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: EchoTheme.radiusSmall)
                                .fill(isInFocusedPlaylist
                                      ? EchoTheme.neoCyan.opacity(0.24)
                                      : (isHovered ? EchoTheme.surfaceElevated : EchoTheme.surfaceElevated.opacity(0.45)))
                        )
                        .foregroundStyle(isInFocusedPlaylist ? EchoTheme.neoCyan : (isHovered ? EchoTheme.textSecondary : EchoTheme.textMuted.opacity(0.55)))
                        .overlay(
                            RoundedRectangle(cornerRadius: EchoTheme.radiusSmall).strokeBorder(
                                isInFocusedPlaylist ? EchoTheme.neoCyan.opacity(0.75) : EchoTheme.border,
                                lineWidth: isInFocusedPlaylist ? 1.1 : 0.85
                            )
                        )
                        .shadow(color: isInFocusedPlaylist ? EchoTheme.neoCyan.opacity(0.35) : .clear, radius: 4)
                }
                .buttonStyle(.plain)
                .frame(width: 30)
                .help(focusedPlaylistButtonTooltip)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 10.5))
                        .foregroundStyle(isHovered ? EchoTheme.textSecondary : EchoTheme.textMuted.opacity(0.45))
                        .help("Drag this row up or down to reorder inside the playlist, or drag onto another playlist/device in the sidebar.")
                }
                .frame(width: 30)
            }

            // Compact "S" badge for sync inclusion (grey when off, neon mint when included in sync)
            let isSyncedOnTarget = syncReason != nil
            Button {
                store.toggleTrackSync(track)
            } label: {
                Text("S")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: EchoTheme.radiusSmall)
                            .fill(isSyncedOnTarget
                                  ? EchoTheme.neoMint.opacity(0.24)
                                  : (isHovered ? EchoTheme.surfaceElevated : EchoTheme.surfaceElevated.opacity(0.45)))
                    )
                    .foregroundStyle(isSyncedOnTarget ? EchoTheme.neoMint : (isHovered ? EchoTheme.textSecondary : EchoTheme.textMuted.opacity(0.55)))
                    .overlay(
                        RoundedRectangle(cornerRadius: EchoTheme.radiusSmall).strokeBorder(
                            isSyncedOnTarget ? EchoTheme.neoMint.opacity(0.8) : EchoTheme.border,
                            lineWidth: isSyncedOnTarget ? 1.1 : 0.85
                        )
                    )
                    .shadow(color: isSyncedOnTarget ? EchoTheme.neoMint.opacity(0.38) : .clear, radius: 4)
            }
            .buttonStyle(.plain)
            .frame(width: 30)
            .help(syncToggleTooltip)

            Text(Formatters.duration(track.duration))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(EchoTheme.textMuted)
                .frame(width: 44, alignment: .trailing)

            // Quick Actions Menu (includes Multi-Destination submenu)
            Menu {
                Button("Play Now") { onPlay() }
                Button("Play Next") { store.player.enqueueNext(track) }
                Button("Add to Queue") { store.player.addToQueue(track) }
                Divider()
                let parsedArtists = ArtistNameParser.artistNames(track.artist)
                if parsedArtists.count > 1 {
                    Menu("Go to Artist") {
                        ForEach(parsedArtists, id: \.self) { name in
                            Button(name) {
                                store.openArtist(name: name)
                            }
                        }
                    }
                } else {
                    Button("Go to Artist (\(parsedArtists.first ?? track.effectiveArtist))") {
                        store.openArtist(name: parsedArtists.first ?? track.effectiveArtist)
                    }
                }
                Button("Go to Album (\(track.effectiveAlbum))") {
                    store.openAlbum(forTrack: track)
                }
                Divider()
                if let focused = store.focusedPlaylist {
                    Button(isInFocusedPlaylist ? "Remove from '\(focused.name)'" : "Add to '\(focused.name)' (+)") {
                        store.toggleTrackInFocusedPlaylist(track)
                    }
                }
                if !store.devices.isEmpty {
                    Menu("Sync Destinations") {
                        ForEach(store.devices) { dev in
                            let assigned = store.isTrackAssigned(track, to: dev)
                            let synced = dev.syncedTrackIDs.contains(track.id)
                            Button {
                                store.toggleTrackSync(track, onDeviceID: dev.id)
                            } label: {
                                HStack {
                                    Text("\(dev.name)\(synced ? " (Synced)" : "")")
                                    if assigned { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    }
                }
                Menu("Add to Playlist") {
                    if store.playlists.isEmpty {
                        Button("Create New Playlist...") {
                            let pl = store.createPlaylist(name: "My Playlist", initialTrackIDs: [track.id])
                            store.navigate(to: .playlist(pl.id))
                        }
                    } else {
                        ForEach(store.playlists) { pl in
                            Button(pl.name) {
                                store.addTracks([track], toPlaylistID: pl.id)
                            }
                        }
                    }
                }
                if let ctx = playlistContext {
                    Divider()
                    Button("Remove from Playlist", role: .destructive) {
                        store.removeTrack(at: ctx.rowIndex, fromPlaylistID: ctx.id)
                    }
                }
                Divider()
                Button("Fetch Online Popularity") {
                    store.fetchPopularity(forTrack: track)
                }
                if store.userPlayCount(for: track) > 0 {
                    Button("Reset Play Count (\(store.userPlayCount(for: track)))") {
                        store.resetUserPlayCount(for: track)
                    }
                }
                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: track.filePath)])
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12))
                    .foregroundStyle(isHovered ? EchoTheme.textPrimary : EchoTheme.textMuted)
                    .frame(width: 24, height: 24)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 24)
            .help("More actions: queue playback, add to any playlist, toggle across specific sync destinations, or reveal file in Finder.")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous)
                .fill(isHovered ? EchoTheme.surfaceElevated.opacity(0.78) : (isCurrentlyPlaying ? EchoTheme.neoMint.opacity(0.07) : Color.clear))
        )
        .overlay(alignment: .top) {
            if isReorderDropTargeted {
                Rectangle()
                    .fill(EchoTheme.neoMint)
                    .frame(height: 2.5)
                    .padding(.horizontal, 8)
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture(count: 2) { onPlay() }
    }

    private var focusedPlaylistButtonTooltip: String {
        if let pl = store.focusedPlaylist {
            return isInFocusedPlaylist
                ? "Already in focused playlist '\(pl.name)'. Click to remove it."
                : "Add '\(track.title)' directly to focused playlist '\(pl.name)'."
        }
        return "Create a new playlist and add '\(track.title)' to it."
    }

    private var syncToggleTooltip: String {
        guard let dev = store.activeDevice else {
            return "Select a sync destination first (top bar or sidebar TARGET button) to toggle syncing for this track."
        }
        if let reason = syncReason {
            return "Included in '\(dev.name)' sync via \(reason). Click to exclude this track from '\(dev.name)'."
        }
        return "Include '\(track.title)' in '\(dev.name)' sync (maintains ARTIST/ALBUM/TRACK path)."
    }
}

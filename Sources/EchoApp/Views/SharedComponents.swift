import SwiftUI
import EchoCore

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

    var body: some View {
        HStack(spacing: 3) {
            if isUnsupported {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 8))
            }
            Text(track.qualityLabel)
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
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

struct SyncStatePillButton: View {
    let state: SyncSelectionState
    var compact: Bool = false
    var label: String = "Sync"
    var tooltip: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: iconName)
                    .font(.system(size: compact ? 12 : 12.5, weight: .semibold))
                if !compact {
                    Text(buttonTitle)
                        .font(.system(size: 12, weight: .bold))
                }
            }
            .padding(.horizontal, compact ? 6 : 11)
            .padding(.vertical, compact ? 4.5 : 6.5)
            .background(background)
            .foregroundStyle(foreground)
            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(tooltip ?? defaultTooltip)
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

struct NeoPrimaryButton: View {
    let title: String
    var icon: String? = nil
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11.5, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 12, weight: .black))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7.5)
            .background(
                Group {
                    if disabled {
                        EchoTheme.surfaceElevated
                    } else {
                        EchoTheme.accentGradient
                    }
                }
            )
            .foregroundStyle(disabled ? EchoTheme.textMuted : Color.black)
            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous)
                    .strokeBorder(disabled ? EchoTheme.border : EchoTheme.neoMint.opacity(0.8), lineWidth: 1)
            )
            .shadow(color: disabled ? .clear : EchoTheme.neoMint.opacity(0.25), radius: 6, y: 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
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
                        Text(track.artist)
                            .font(.system(size: 11.5))
                            .foregroundStyle(EchoTheme.textSecondary)
                            .lineLimit(1)

                        if (store.destinationMode == .multi || destBadges.count > 1 || destBadges.contains(where: \.isSynced)) && !destBadges.isEmpty {
                            DestinationBadgeStrip(badges: destBadges)
                        }
                    }
                }
            }
            .frame(minWidth: 180, maxWidth: .infinity, alignment: .leading)

            if showAlbumColumn {
                Text(track.effectiveAlbum)
                    .font(.system(size: 12))
                    .foregroundStyle(EchoTheme.textSecondary)
                    .lineLimit(1)
                    .frame(width: 165, alignment: .leading)
            }

            FormatBadge(track: track, isUnsupported: isUnsupported)
                .frame(width: 124, alignment: .trailing)

            // Dedicated "+" button to add/toggle song in focused playlist
            if playlistContext == nil {
                Button {
                    store.toggleTrackInFocusedPlaylist(track)
                } label: {
                    Image(systemName: isInFocusedPlaylist ? "checkmark" : "plus")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 24, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: EchoTheme.radiusSmall)
                                .fill(isInFocusedPlaylist
                                      ? EchoTheme.neoCyan.opacity(0.24)
                                      : (isHovered ? EchoTheme.neoMint.opacity(0.22) : EchoTheme.surfaceElevated.opacity(0.75)))
                        )
                        .foregroundStyle(isInFocusedPlaylist ? EchoTheme.neoCyan : (isHovered ? EchoTheme.neoMint : EchoTheme.textSecondary))
                        .overlay(
                            RoundedRectangle(cornerRadius: EchoTheme.radiusSmall).strokeBorder(
                                isInFocusedPlaylist ? EchoTheme.neoCyan.opacity(0.6) : EchoTheme.border,
                                lineWidth: 1
                            )
                        )
                }
                .buttonStyle(.plain)
                .frame(width: 34)
                .help(focusedPlaylistButtonTooltip)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 10.5))
                        .foregroundStyle(isHovered ? EchoTheme.textSecondary : EchoTheme.textMuted.opacity(0.45))
                        .help("Drag this row up or down to reorder inside the playlist, or drag onto another playlist/device in the sidebar.")
                }
                .frame(width: 34)
            }

            // Sync toggle for currently selected destination
            Button {
                store.toggleTrackSync(track)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: syncReason != nil ? "checkmark.square.fill" : "square")
                        .font(.system(size: 14))
                        .foregroundStyle(syncReason != nil ? EchoTheme.neoMint : EchoTheme.textMuted)
                    if let reason = syncReason, reason != "Track" {
                        Text(reason)
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(EchoTheme.neoCyan)
                    }
                }
                .frame(width: 72, alignment: .trailing)
            }
            .buttonStyle(.plain)
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

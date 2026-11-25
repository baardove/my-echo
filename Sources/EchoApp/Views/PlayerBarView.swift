import SwiftUI
import EchoCore

struct PlayerBarView: View {
    @Environment(EchoStore.self) private var store
    @Environment(\.openWindow) private var openWindow
    @State private var showQueuePopover = false
    @State private var showCrossfadePopover = false
    @State private var isScrubbing = false
    @State private var scrubValue: Double = 0
    @State private var isQueueDropTargeted = false

    var body: some View {
        let player = store.player
        let track = player.currentTrack

        HStack(spacing: 18) {
            // Left: Now Playing Track Info (Draggable onto playlists!)
            HStack(spacing: 12) {
                Button {
                    if let track { store.openAlbumLightbox(forTrack: track) }
                } label: {
                    ArtworkView(hash: track?.artworkHash, artworkCache: store.artworkCache, cornerRadius: 8, iconSize: 18)
                        .frame(width: 52, height: 52)
                        .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
                }
                .buttonStyle(.plain)
                .disabled(track == nil)
                .help(track.map { "View full-size artwork & info for '\($0.effectiveAlbum)'" } ?? "")

                if let track {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 7) {
                            HoverLinkText(
                                text: track.title,
                                font: .system(size: 13.5, weight: .bold),
                                color: EchoTheme.textPrimary,
                                hoverColor: EchoTheme.neoMint,
                                tip: "Open album '\(track.effectiveAlbum)'"
                            ) {
                                store.openAlbum(forTrack: track)
                            }
                            FormatBadge(track: track, compact: true)
                        }
                        HStack(spacing: 6) {
                            let curStats = store.stats(for: track)
                            ArtistLinksView(
                                rawArtists: track.artist,
                                font: .system(size: 11.5),
                                color: EchoTheme.textSecondary,
                                hoverColor: EchoTheme.neoMint
                            ) { artistName in
                                store.openArtist(name: artistName)
                            }

                            Text("·")
                                .foregroundStyle(EchoTheme.textMuted)

                            HoverLinkText(
                                text: track.effectiveAlbum,
                                font: .system(size: 11.5),
                                color: EchoTheme.textMuted,
                                hoverColor: EchoTheme.neoCyan,
                                tip: "Go to album '\(track.effectiveAlbum)'"
                            ) {
                                store.openAlbum(forTrack: track)
                            }

                            if curStats.userPlayCount > 0 {
                                Text("·")
                                    .foregroundStyle(EchoTheme.textMuted)
                                UserPlayCountBadge(stats: curStats)
                            }

                            if curStats.hasOnlinePopularity {
                                Text("·")
                                    .foregroundStyle(EchoTheme.textMuted)
                                OnlinePopularityMeter(stats: curStats, compact: true)
                            }

                            if let err = player.playbackError {
                                Text("· \(err)")
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(EchoTheme.warningAmber)
                                    .lineLimit(1)
                            }
                        }
                    }

                    Spacer(minLength: 4)

                    // Quick "+" add current track to focused playlist
                    Button {
                        store.toggleTrackInFocusedPlaylist(track)
                    } label: {
                        let inFocused = store.isTrackInFocusedPlaylist(track)
                        Image(systemName: inFocused ? "checkmark.square.fill" : "plus.square")
                            .font(.system(size: 15))
                            .foregroundStyle(inFocused ? EchoTheme.neoCyan : EchoTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                    .help(store.focusedPlaylist.map { "Add or remove '\(track.title)' in focused playlist '\($0.name)'." } ?? "Create a playlist and add the currently playing track.")

                    Button {
                        store.toggleTrackSync(track)
                    } label: {
                        Image(systemName: store.trackSyncReason(track) != nil ? "arrow.triangle.2.circlepath.circle.fill" : "arrow.triangle.2.circlepath.circle")
                            .font(.system(size: 15))
                            .foregroundStyle(store.trackSyncReason(track) != nil ? EchoTheme.neoMint : EchoTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                    .help("Include or exclude the currently playing track from the selected sync destination.")
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isQueueDropTargeted ? "Drop to Add to Queue" : "Not Playing")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isQueueDropTargeted ? EchoTheme.neoMint : EchoTheme.textSecondary)
                        Text("Double-click or drop tracks here")
                            .font(.system(size: 11))
                            .foregroundStyle(EchoTheme.textMuted)
                    }
                }
            }
            .frame(width: 330, alignment: .leading)
            .draggable(track.map { EchoDragPayload.tracks([$0.id]).encode() } ?? "") {
                if let track {
                    DragPreviewPill(
                        title: track.title,
                        subtitle: track.artist,
                        artworkHash: track.artworkHash,
                        artworkCache: store.artworkCache,
                        badge: track.format.displayBadge
                    )
                }
            }

            // Center: Spotify Transport Controls + Scrubber
            VStack(spacing: 6) {
                HStack(spacing: 20) {
                    Button {
                        player.isShuffled.toggle()
                    } label: {
                        Image(systemName: "shuffle")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(player.isShuffled ? EchoTheme.neoMint : EchoTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .help(player.isShuffled ? "Shuffle is ON. Click to restore original track order." : "Shuffle the playback queue randomly.")

                    Button {
                        player.previousTrack()
                    } label: {
                        Image(systemName: "backward.end.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(EchoTheme.textPrimary)
                    }
                    .buttonStyle(.plain)
                    .disabled(track == nil)
                    .help("Restart current track (or skip to previous track within the first 3 seconds) (⌘←).")

                    Button {
                        player.togglePlayPause()
                    } label: {
                        RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous)
                            .fill(EchoTheme.surfaceElevated)
                            .overlay(
                                RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous)
                                    .fill(track != nil ? EchoTheme.neoMint.opacity(0.10) : Color.clear)
                            )
                            .frame(width: 38, height: 34)
                            .overlay(
                                RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous)
                                    .strokeBorder(track != nil ? EchoTheme.neoMint.opacity(0.80) : EchoTheme.border, lineWidth: 1.15)
                            )
                            .overlay(
                                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(track != nil ? EchoTheme.neoMint : EchoTheme.textMuted)
                                    .offset(x: player.isPlaying ? 0 : 1)
                            )
                            .shadow(color: track != nil ? EchoTheme.neoMint.opacity(0.24) : .clear, radius: 6)
                    }
                    .buttonStyle(.plain)
                    .disabled(track == nil)
                    .help(player.isPlaying ? "Pause audio playback (⌘P)." : "Resume audio playback (⌘P).")

                    Button {
                        player.nextTrack()
                    } label: {
                        Image(systemName: "forward.end.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(EchoTheme.textPrimary)
                    }
                    .buttonStyle(.plain)
                    .disabled(track == nil)
                    .help("Skip to the next track in the playback queue (⌘→).")

                    Button {
                        player.cycleRepeatMode()
                    } label: {
                        Image(systemName: player.repeatMode == .one ? "repeat.1" : "repeat")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(player.repeatMode == .off ? EchoTheme.textSecondary : EchoTheme.neoMint)
                    }
                    .buttonStyle(.plain)
                    .help("Cycle repeat mode (Off → Repeat All → Repeat One). Current: \(player.repeatMode.rawValue).")
                }

                HStack(spacing: 8) {
                    Text(Formatters.duration(isScrubbing ? scrubValue : player.currentTime))
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(EchoTheme.textMuted)
                        .frame(width: 40, alignment: .trailing)

                    Slider(
                        value: Binding(
                            get: { isScrubbing ? scrubValue : player.currentTime },
                            set: { val in
                                isScrubbing = true
                                scrubValue = val
                            }
                        ),
                        in: 0...max(1, player.duration),
                        onEditingChanged: { editing in
                            if !editing {
                                player.seek(to: scrubValue)
                                isScrubbing = false
                            }
                        }
                    )
                    .tint(EchoTheme.neoMint)
                    .disabled(track == nil)

                    Text(Formatters.duration(player.duration))
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(EchoTheme.textMuted)
                        .frame(width: 40, alignment: .leading)
                }
            }
            .frame(maxWidth: 500)

            Spacer(minLength: 10)

            // Right: Harmonized Crossfade, Mini Player, Queue & Volume Controls
            HStack(spacing: 8) {
                Button {
                    showCrossfadePopover.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 10.5, weight: .bold))
                        Text(player.crossfadeEnabled ? "XF \(Int(player.crossfadeDuration.rounded()))s" : "XF")
                            .font(.system(size: 9.5, weight: .black, design: .monospaced))
                            .lineLimit(1)
                    }
                    .fixedSize()
                    .padding(.horizontal, 8)
                    .frame(height: 26)
                    .background(
                        player.isCrossfading
                            ? EchoTheme.neoMint.opacity(0.28)
                            : (player.crossfadeEnabled ? EchoTheme.neoCyan.opacity(0.18) : EchoTheme.surfaceElevated)
                    )
                    .foregroundStyle(
                        player.isCrossfading
                            ? EchoTheme.neoMint
                            : (player.crossfadeEnabled ? EchoTheme.neoCyan : EchoTheme.textMuted)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                    .overlay(
                        RoundedRectangle(cornerRadius: EchoTheme.radiusSmall).strokeBorder(
                            player.isCrossfading
                                ? EchoTheme.neoMint
                                : (player.crossfadeEnabled ? EchoTheme.neoCyan.opacity(0.55) : EchoTheme.border),
                            lineWidth: 1
                        )
                    )
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showCrossfadePopover, arrowEdge: .top) {
                    crossfadePopoverView
                }
                .help(player.crossfadeEnabled
                      ? "Mac playback Crossfade is ON (\(Int(player.crossfadeDuration.rounded()))s equal-power blend). Click to adjust duration or turn off."
                      : "Enable smooth equal-power Crossfade between tracks during Mac playback.")

                Button {
                    openWindow(id: "mini-player")
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "rectangle.compress.vertical")
                            .font(.system(size: 10.5, weight: .bold))
                        Text("MINI")
                            .font(.system(size: 9.5, weight: .black, design: .monospaced))
                            .lineLimit(1)
                    }
                    .fixedSize()
                    .padding(.horizontal, 8)
                    .frame(height: 26)
                    .background(EchoTheme.surfaceElevated)
                    .foregroundStyle(EchoTheme.neoMint)
                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                    .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall).strokeBorder(EchoTheme.neoMint.opacity(0.45), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .help("Open the compact floating Winamp-style Mini Player deck with live spectrum analyzer, Windowshade mode, and PL drawer (⌘⇧M).")

                Button {
                    showQueuePopover.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 10.5, weight: .bold))
                        if !player.queue.isEmpty {
                            Text("\(player.queue.count)")
                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                .lineLimit(1)
                        }
                    }
                    .fixedSize()
                    .padding(.horizontal, 8)
                    .frame(height: 26)
                    .background(showQueuePopover ? EchoTheme.neoMint.opacity(0.18) : EchoTheme.surfaceElevated)
                    .foregroundStyle(showQueuePopover ? EchoTheme.neoMint : EchoTheme.textSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                    .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall).strokeBorder(showQueuePopover ? EchoTheme.neoMint.opacity(0.55) : EchoTheme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showQueuePopover, arrowEdge: .top) {
                    queuePopoverView
                }
                .help("Open the Up Next playback queue to jump to or remove queued tracks.")

                Button {
                    player.isMuted.toggle()
                } label: {
                    Image(systemName: volumeIcon(player: player))
                        .font(.system(size: 13))
                        .foregroundStyle(EchoTheme.textSecondary)
                        .frame(width: 20, height: 26)
                }
                .buttonStyle(.plain)
                .help(player.isMuted ? "Unmute playback audio." : "Mute playback audio.")

                Slider(
                    value: Binding(
                        get: { player.isMuted ? 0 : player.volume },
                        set: { newVal in
                            player.isMuted = false
                            player.volume = newVal
                        }
                    ),
                    in: 0...1
                )
                .tint(EchoTheme.neoMint)
                .frame(width: 88)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 18)
        .frame(height: 82)
        .background(isQueueDropTargeted ? EchoTheme.neoMint.opacity(0.12) : EchoTheme.playerBar)
        .overlay(alignment: .top) {
            Rectangle().fill(isQueueDropTargeted ? EchoTheme.neoMint : EchoTheme.borderStrong).frame(height: isQueueDropTargeted ? 2 : 1)
        }
        .dropDestination(for: String.self) { items, _ in
            let (tracks, _) = store.resolveTracks(fromDragStrings: items)
            guard !tracks.isEmpty else { return false }
            for t in tracks { store.player.addToQueue(t) }
            store.showToast("Added \(tracks.count) track\(tracks.count == 1 ? "" : "s") to queue")
            return true
        } isTargeted: { targeted in
            isQueueDropTargeted = targeted
        }
    }

    private func volumeIcon(player: AudioPlayerEngine) -> String {
        if player.isMuted || player.volume <= 0.01 { return "speaker.slash.fill" }
        if player.volume < 0.4 { return "speaker.wave.1.fill" }
        if player.volume < 0.75 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    private var queuePopoverView: some View {
        let player = store.player
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Play Queue")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(EchoTheme.textPrimary)
                Spacer()
                Text("\(player.queue.count) tracks")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(EchoTheme.textMuted)
            }
            Divider()
            if player.queue.isEmpty {
                Text("Queue is empty")
                    .font(.system(size: 12))
                    .foregroundStyle(EchoTheme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(24)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(Array(player.queue.enumerated()), id: \.offset) { idx, t in
                            let isCurrent = idx == player.currentIndex
                            HStack(spacing: 8) {
                                ArtworkView(hash: t.artworkHash, artworkCache: store.artworkCache, cornerRadius: 4, iconSize: 10)
                                    .frame(width: 28, height: 28)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(t.title)
                                        .font(.system(size: 12, weight: isCurrent ? .bold : .medium))
                                        .foregroundStyle(isCurrent ? EchoTheme.neoMint : EchoTheme.textPrimary)
                                        .lineLimit(1)
                                    HStack(spacing: 4) {
                                        ArtistLinksView(
                                            rawArtists: t.artist,
                                            font: .system(size: 10.5),
                                            color: EchoTheme.textSecondary,
                                            hoverColor: EchoTheme.neoMint
                                        ) { artistName in
                                            showQueuePopover = false
                                            store.openArtist(name: artistName)
                                        }
                                        Text("·")
                                            .font(.system(size: 10))
                                            .foregroundStyle(EchoTheme.textMuted)
                                        HoverLinkText(
                                            text: t.effectiveAlbum,
                                            font: .system(size: 10.5),
                                            color: EchoTheme.textMuted,
                                            hoverColor: EchoTheme.neoCyan,
                                            tip: "Go to album '\(t.effectiveAlbum)'"
                                        ) {
                                            showQueuePopover = false
                                            store.openAlbum(forTrack: t)
                                        }
                                    }
                                }
                                Spacer()
                                Button {
                                    player.removeFromQueue(at: idx)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10))
                                        .foregroundStyle(EchoTheme.textMuted)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(isCurrent ? EchoTheme.neoMint.opacity(0.12) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                player.jumpToQueueIndex(idx)
                            }
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
        }
        .padding(14)
        .frame(width: 310)
        .background(EchoTheme.surface)
    }

    private var crossfadePopoverView: some View {
        let player = store.player
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(player.crossfadeEnabled ? EchoTheme.neoCyan : EchoTheme.textMuted)
                    Text("Mac Playback Crossfade")
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundStyle(EchoTheme.textPrimary)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { player.crossfadeEnabled },
                    set: { player.crossfadeEnabled = $0 }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
                .tint(EchoTheme.neoMint)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Fade Duration")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(EchoTheme.textSecondary)
                    Spacer()
                    Text(String(format: "%.0f sec", player.crossfadeDuration.rounded()))
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(player.crossfadeEnabled ? EchoTheme.neoCyan : EchoTheme.textMuted)
                }

                Slider(
                    value: Binding(
                        get: { player.crossfadeDuration },
                        set: { player.crossfadeDuration = $0.rounded() }
                    ),
                    in: 1...12,
                    step: 1
                )
                .tint(EchoTheme.neoCyan)
                .disabled(!player.crossfadeEnabled)

                HStack(spacing: 6) {
                    ForEach([2, 4, 6, 8, 12], id: \.self) { secs in
                        let selected = Int(player.crossfadeDuration.rounded()) == secs
                        Button("\(secs)s") {
                            player.crossfadeEnabled = true
                            player.crossfadeDuration = Double(secs)
                        }
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(selected && player.crossfadeEnabled ? EchoTheme.neoCyan.opacity(0.22) : EchoTheme.surfaceElevated)
                        .foregroundStyle(selected && player.crossfadeEnabled ? EchoTheme.neoCyan : EchoTheme.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                        .overlay(
                            RoundedRectangle(cornerRadius: EchoTheme.radiusSmall)
                                .strokeBorder(selected && player.crossfadeEnabled ? EchoTheme.neoCyan.opacity(0.6) : EchoTheme.border, lineWidth: 1)
                        )
                        .buttonStyle(.plain)
                    }
                }
            }

            Text("Equal-power dual-deck blend on Mac playback (also applies a quick 1.5s fade on manual skips). Synced FiiO/SD audio files stay untouched.")
                .font(.system(size: 10.5))
                .foregroundStyle(EchoTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(width: 280)
        .background(EchoTheme.surface)
    }
}

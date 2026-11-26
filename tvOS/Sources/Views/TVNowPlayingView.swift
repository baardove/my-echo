import SwiftUI

struct TVNowPlayingView: View {
    @Environment(TVEchoStore.self) private var store

    var body: some View {
        GeometryReader { geo in
            let artSize = min(480, max(320, geo.size.height * 0.56))

            Group {
                if store.player.hasCurrentItem {
                    HStack(alignment: .center, spacing: 56) {
                        // Left: Huge Cover Art + Quality Badges
                        TVNowPlayingArtworkColumn(artSize: artSize)

                        // Right: Track Meta, Timeline, Transport & Expanded Queue
                        VStack(alignment: .leading, spacing: 20) {
                            TVNowPlayingMetaHeader()
                            TVNowPlayingProgressSection()
                            TVNowPlayingTransportDeck()
                            TVNowPlayingLinerNote()
                            TVNowPlayingQueueSection()
                                .frame(maxHeight: .infinity, alignment: .top)
                        }
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: max(540, geo.size.height - 64),
                            alignment: .topLeading
                        )
                    }
                    .padding(.horizontal, 72)
                    .padding(.vertical, 32)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
                } else {
                    VStack(spacing: 22) {
                        Image(systemName: "hifispeaker.2.fill")
                            .font(.system(size: 76))
                            .foregroundStyle(EchoTVTheme.neoMint.opacity(0.75))
                        Text("Nothing Playing on Apple TV")
                            .font(.system(size: 40, weight: .black, design: .rounded))
                            .foregroundStyle(EchoTVTheme.textPrimary)
                        Text("Pick an album, playlist, or podcast from Home or Library to start lossless living-room playback.")
                            .font(.system(size: 22))
                            .foregroundStyle(EchoTVTheme.textSecondary)
                        Button {
                            store.isNowPlayingPresented = false
                            store.selectedTab = .home
                        } label: {
                            Text("Browse Music")
                                .font(.system(size: 22, weight: .bold))
                                .padding(.horizontal, 32)
                                .padding(.vertical, 16)
                                .background(EchoTVTheme.neoMint)
                                .foregroundStyle(Color.black)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(EchoTVButtonStyle(cornerRadius: 14))
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
            }
        }
        .background {
            TVNowPlayingBackdropLayer()
        }
    }
}

private struct TVNowPlayingBackdropLayer: View {
    @Environment(TVEchoStore.self) private var store

    var body: some View {
        TVBackdropArtworkView(url: store.player.currentItem?.artworkURL, opacity: 0.28)
    }
}

private struct TVNowPlayingArtworkColumn: View {
    @Environment(TVEchoStore.self) private var store
    let artSize: CGFloat

    var body: some View {
        if let item = store.player.currentItem {
            VStack(spacing: 20) {
                TVArtworkView(
                    url: item.artworkURL,
                    cornerRadius: 24,
                    preservePreviousWhileLoading: true
                )
                .frame(width: artSize, height: artSize)
                .shadow(color: .black.opacity(0.65), radius: 36, y: 18)

                HStack(spacing: 14) {
                    TVQualityBadge(
                        primary: item.formatPrimary,
                        detail: item.formatDetail,
                        isHiRes: item.isHiRes,
                        isLossless: item.isLossless
                    )
                    Text(item.sourceBadge)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(EchoTVTheme.surfaceElevated)
                        .foregroundStyle(EchoTVTheme.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

private struct TVNowPlayingMetaHeader: View {
    @Environment(TVEchoStore.self) private var store

    var body: some View {
        if let item = store.player.currentItem {
            VStack(alignment: .leading, spacing: 8) {
                Text(item.album.uppercased())
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(EchoTVTheme.neoMint)
                    .lineLimit(1)
                Text(item.title)
                    .font(.system(size: 50, weight: .black, design: .rounded))
                    .foregroundStyle(EchoTVTheme.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                Text(item.artist)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(EchoTVTheme.textSecondary)
                    .lineLimit(1)
            }
        }
    }
}

private struct TVNowPlayingProgressSection: View {
    @Environment(TVEchoStore.self) private var store

    var body: some View {
        VStack(spacing: 10) {
            let progress = store.player.duration > 0 ? (store.player.currentTime / store.player.duration) : 0
            TVProgressBar(progress: progress, tint: EchoTVTheme.neoMint, height: 12)
            HStack {
                Text(TVFormatters.duration(store.player.currentTime))
                Spacer()
                if store.player.isBuffering {
                    Text("BUFFERING...")
                        .foregroundStyle(EchoTVTheme.neoCyan)
                } else if let err = store.player.playbackError {
                    Text(err)
                        .foregroundStyle(EchoTVTheme.dangerCoral)
                        .lineLimit(1)
                }
                Spacer()
                Text("-\(TVFormatters.duration(max(0, store.player.duration - store.player.currentTime)))")
            }
            .font(.system(size: 18, weight: .bold, design: .monospaced))
            .foregroundStyle(EchoTVTheme.textSecondary)
        }
    }
}

private struct TVNowPlayingTransportDeck: View {
    @Environment(TVEchoStore.self) private var store

    var body: some View {
        HStack(spacing: 16) {
            transportButton(icon: "backward.end.fill", label: "Prev") {
                store.player.previousTrack()
            }
            transportButton(icon: "gobackward.15", label: "-15s") {
                store.player.skip(by: -15)
            }
            Button {
                store.player.togglePlayPause()
            } label: {
                Image(systemName: store.player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 34, weight: .bold))
                    .frame(width: 96, height: 76)
                    .background(EchoTVTheme.neoMint)
                    .foregroundStyle(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(EchoTVButtonStyle(cornerRadius: 14))
            transportButton(icon: "goforward.15", label: "+15s") {
                store.player.skip(by: 15)
            }
            transportButton(icon: "forward.end.fill", label: "Next") {
                store.player.nextTrack()
            }

            Spacer()

            togglePill(
                icon: "shuffle",
                active: store.player.isShuffled
            ) {
                store.player.isShuffled.toggle()
            }
            togglePill(
                icon: store.player.repeatMode == .one ? "repeat.1" : "repeat",
                active: store.player.repeatMode != .off
            ) {
                store.player.cycleRepeatMode()
            }
        }
    }

    private func transportButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .bold))
                Text(label)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
            }
            .frame(width: 78, height: 76)
            .background(EchoTVTheme.surfaceElevated)
            .foregroundStyle(EchoTVTheme.textPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(EchoTVButtonStyle(cornerRadius: 14))
    }

    private func togglePill(icon: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .bold))
                .frame(width: 68, height: 68)
                .background(active ? EchoTVTheme.neoCyan.opacity(0.25) : EchoTVTheme.surfaceElevated)
                .foregroundStyle(active ? EchoTVTheme.neoCyan : EchoTVTheme.textSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(active ? EchoTVTheme.neoCyan : Color.clear, lineWidth: 2)
                )
        }
        .buttonStyle(EchoTVButtonStyle(cornerRadius: 14))
    }
}

private struct TVNowPlayingLinerNote: View {
    @Environment(TVEchoStore.self) private var store

    var body: some View {
        if let key = store.player.currentItem?.albumKey,
           let note = store.albumEditorialByKey[key]?.albumSummary, !note.isEmpty {
            Text(note)
                .font(.system(size: 18))
                .foregroundStyle(EchoTVTheme.textSecondary)
                .lineLimit(3)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(EchoTVTheme.surface.opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

private struct TVNowPlayingQueueSection: View {
    @Environment(TVEchoStore.self) private var store

    var body: some View {
        let queue = store.player.queue
        let currentIndex = store.player.currentIndex
        let isCustomQueue = store.player.isCustomQueue || store.libraryTapMode == .addToQueue

        if !queue.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Text(isCustomQueue ? "PLAY QUEUE (\(queue.count) \(queue.count == 1 ? "TRACK" : "TRACKS"))" : "UP NEXT (\(queue.count) \(queue.count == 1 ? "TRACK" : "TRACKS"))")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .tracking(1.6)
                        .foregroundStyle(EchoTVTheme.neoCyan)

                    if isCustomQueue {
                        Text("QUEUE MODE")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(EchoTVTheme.neoCyan.opacity(0.2))
                            .foregroundStyle(EchoTVTheme.neoCyan)
                            .clipShape(Capsule())
                    }
                }

                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(queue.enumerated()), id: \.offset) { idx, qItem in
                            TVNowPlayingQueueRow(
                                item: qItem,
                                isCurrent: idx == currentIndex
                            ) {
                                store.player.jumpToQueueIndex(idx)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct TVNowPlayingQueueRow: View {
    let item: TVPlayableItem
    let isCurrent: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: isCurrent ? "waveform" : "music.note")
                    .foregroundStyle(isCurrent ? EchoTVTheme.neoMint : EchoTVTheme.textMuted)
                    .frame(width: 28)
                Text(item.title)
                    .font(.system(size: 20, weight: isCurrent ? .black : .semibold))
                    .foregroundStyle(isCurrent ? EchoTVTheme.neoMint : EchoTVTheme.textPrimary)
                    .lineLimit(1)
                Text("· \(item.artist)")
                    .font(.system(size: 18))
                    .foregroundStyle(EchoTVTheme.textSecondary)
                    .lineLimit(1)
                Spacer()
                Text(TVFormatters.duration(item.duration))
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundStyle(EchoTVTheme.textMuted)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(isCurrent ? EchoTVTheme.neoMint.opacity(0.14) : EchoTVTheme.surface.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(EchoTVButtonStyle(cornerRadius: 14))
    }
}

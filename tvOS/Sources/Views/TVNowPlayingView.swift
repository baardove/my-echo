import SwiftUI

struct TVNowPlayingView: View {
    @Environment(TVEchoStore.self) private var store

    var body: some View {
        ZStack {
            EchoTVTheme.canvas.ignoresSafeArea()

            // Ambient Blurred Artwork Backdrop
            if let artURL = store.player.currentItem?.artworkURL {
                AsyncImage(url: artURL) { phase in
                    if case .success(let img) = phase {
                        img
                            .resizable()
                            .scaledToFill()
                            .blur(radius: 90)
                            .opacity(0.28)
                            .ignoresSafeArea()
                    }
                }
            }

            if let item = store.player.currentItem {
                HStack(alignment: .center, spacing: 64) {
                    // Left: Huge Cover Art + Quality Badges
                    VStack(spacing: 24) {
                        TVArtworkView(url: item.artworkURL, cornerRadius: 24)
                            .frame(width: 540, height: 540)
                            .shadow(color: .black.opacity(0.65), radius: 40, y: 20)

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

                    // Right: Track Meta, Timeline, Transport & Up Next
                    VStack(alignment: .leading, spacing: 26) {
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
                            Text(item.artist)
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundStyle(EchoTVTheme.textSecondary)
                                .lineLimit(1)
                        }

                        // Progress Bar & Clocks
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

                        // Transport Deck
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
                            .buttonStyle(.plain)
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

                        // Album Editorial Liner Note (if cached from Mac)
                        if let key = item.albumKey,
                           let note = store.albumEditorialByKey[key]?.albumSummary, !note.isEmpty {
                            Text(note)
                                .font(.system(size: 18))
                                .foregroundStyle(EchoTVTheme.textSecondary)
                                .lineLimit(3)
                                .padding(16)
                                .background(EchoTVTheme.surface.opacity(0.75))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        // Up Next Queue
                        if store.player.queue.count > 1 {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("UP NEXT (\(store.player.queue.count) TRACKS)")
                                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                                    .tracking(1.6)
                                    .foregroundStyle(EchoTVTheme.neoCyan)

                                ScrollView {
                                    LazyVStack(spacing: 8) {
                                        ForEach(Array(store.player.queue.enumerated()), id: \.offset) { idx, qItem in
                                            let isCurrent = idx == store.player.currentIndex
                                            Button {
                                                store.player.jumpToQueueIndex(idx)
                                            } label: {
                                                HStack(spacing: 14) {
                                                    Image(systemName: isCurrent ? "waveform" : "music.note")
                                                        .foregroundStyle(isCurrent ? EchoTVTheme.neoMint : EchoTVTheme.textMuted)
                                                        .frame(width: 28)
                                                    Text(qItem.title)
                                                        .font(.system(size: 20, weight: isCurrent ? .black : .semibold))
                                                        .foregroundStyle(isCurrent ? EchoTVTheme.neoMint : EchoTVTheme.textPrimary)
                                                        .lineLimit(1)
                                                    Text("· \(qItem.artist)")
                                                        .font(.system(size: 18))
                                                        .foregroundStyle(EchoTVTheme.textSecondary)
                                                        .lineLimit(1)
                                                    Spacer()
                                                    Text(TVFormatters.duration(qItem.duration))
                                                        .font(.system(size: 16, design: .monospaced))
                                                        .foregroundStyle(EchoTVTheme.textMuted)
                                                }
                                                .padding(.horizontal, 18)
                                                .padding(.vertical, 12)
                                                .background(isCurrent ? EchoTVTheme.neoMint.opacity(0.14) : EchoTVTheme.surface.opacity(0.7))
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                                .frame(maxHeight: 240)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 80)
                .padding(.vertical, 48)
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
                    .buttonStyle(.plain)
                }
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
        .buttonStyle(.plain)
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
        .buttonStyle(.plain)
    }
}

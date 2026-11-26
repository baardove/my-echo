import SwiftUI

struct TVMacRemoteView: View {
    @Environment(TVEchoStore.self) private var store

    var body: some View {
        ZStack {
            EchoTVTheme.canvas.ignoresSafeArea()

            if let state = store.remoteState {
                HStack(alignment: .top, spacing: 56) {
                    // Left: Live Mac Playback Deck
                    VStack(alignment: .leading, spacing: 26) {
                        HStack(spacing: 14) {
                            Image(systemName: "desktopcomputer")
                                .font(.system(size: 24))
                                .foregroundStyle(EchoTVTheme.neoCyan)
                            Text("CONTROLLING: \(state.serverName.uppercased())")
                                .font(.system(size: 17, weight: .black, design: .monospaced))
                                .tracking(1.6)
                                .foregroundStyle(EchoTVTheme.neoCyan)
                            Spacer()
                            Label(state.outputDeviceName, systemImage: "hifispeaker.fill")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(EchoTVTheme.surfaceElevated)
                                .foregroundStyle(EchoTVTheme.neoMint)
                                .clipShape(Capsule())
                        }

                        HStack(spacing: 32) {
                            TVArtworkView(
                                url: store.macArtworkURL(for: state.currentTrack?.artworkHash),
                                cornerRadius: 18,
                                preservePreviousWhileLoading: true
                            )
                                .frame(width: 280, height: 280)

                            VStack(alignment: .leading, spacing: 10) {
                                if let cur = state.currentTrack {
                                    Text(cur.effectiveAlbum.uppercased())
                                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                                        .foregroundStyle(EchoTVTheme.neoMint)
                                        .lineLimit(1)
                                    Text(cur.title)
                                        .font(.system(size: 38, weight: .black, design: .rounded))
                                        .foregroundStyle(EchoTVTheme.textPrimary)
                                        .lineLimit(2)
                                    Text(cur.artist)
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundStyle(EchoTVTheme.textSecondary)
                                        .lineLimit(1)
                                    TVQualityBadge(
                                        primary: cur.formatPrimaryLabel,
                                        detail: cur.formatDetailLabel,
                                        isHiRes: cur.isHiRes,
                                        isLossless: cur.isLossless
                                    )
                                    .padding(.top, 4)
                                } else {
                                    Text("Mac Player Idle")
                                        .font(.system(size: 34, weight: .bold))
                                        .foregroundStyle(EchoTVTheme.textSecondary)
                                    Text("Open any album in Library and choose 'Play on Mac', or tap Play below.")
                                        .font(.system(size: 19))
                                        .foregroundStyle(EchoTVTheme.textMuted)
                                }
                            }
                        }

                        // Mac Timeline
                        VStack(spacing: 8) {
                            let pct = state.duration > 0 ? (state.currentTime / state.duration) : 0
                            TVProgressBar(progress: pct, tint: EchoTVTheme.neoCyan, height: 11)
                            HStack {
                                Text(TVFormatters.duration(state.currentTime))
                                Spacer()
                                Text(TVFormatters.duration(state.duration))
                            }
                            .font(.system(size: 17, weight: .bold, design: .monospaced))
                            .foregroundStyle(EchoTVTheme.textSecondary)
                        }

                        // Primary Transport Controls
                        HStack(spacing: 16) {
                            remoteButton(icon: "backward.end.fill", label: "Prev") {
                                await store.sendRemoteCommand("previous")
                            }
                            remoteButton(icon: "gobackward.15", label: "-15s") {
                                await store.sendRemoteCommand("seek", seconds: max(0, state.currentTime - 15))
                            }
                            Button {
                                Task { await store.sendRemoteCommand("togglePlayPause") }
                            } label: {
                                Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 32, weight: .bold))
                                    .frame(width: 96, height: 76)
                                    .background(EchoTVTheme.neoCyan)
                                    .foregroundStyle(Color.black)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(EchoTVButtonStyle(cornerRadius: 14, accent: EchoTVTheme.neoCyan))
                            remoteButton(icon: "goforward.15", label: "+15s") {
                                await store.sendRemoteCommand("seek", seconds: min(state.duration, state.currentTime + 15))
                            }
                            remoteButton(icon: "forward.end.fill", label: "Next") {
                                await store.sendRemoteCommand("next")
                            }
                        }

                        // Volume, Shuffle, Repeat & Party Toggle
                        HStack(spacing: 16) {
                            remoteButton(icon: "speaker.minus.fill", label: "Vol -") {
                                await store.sendRemoteCommand("setVolume", volume: max(0, state.volume - 0.1))
                            }
                            remoteButton(
                                icon: state.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                                label: state.isMuted ? "Muted" : "\(Int((state.volume * 100).rounded()))%",
                                active: state.isMuted
                            ) {
                                await store.sendRemoteCommand("toggleMute")
                            }
                            remoteButton(icon: "speaker.plus.fill", label: "Vol +") {
                                await store.sendRemoteCommand("setVolume", volume: min(1, state.volume + 0.1))
                            }
                            remoteButton(icon: "shuffle", label: "Shuffle", active: state.isShuffled) {
                                await store.sendRemoteCommand("toggleShuffle")
                            }
                            remoteButton(
                                icon: state.repeatMode == "one" ? "repeat.1" : "repeat",
                                label: state.repeatMode.uppercased(),
                                active: state.repeatMode != "off"
                            ) {
                                await store.sendRemoteCommand("cycleRepeat")
                            }
                        }

                        // Party Mode Remote Switch
                        HStack(spacing: 16) {
                            Button {
                                Task {
                                    await store.sendRemoteCommand(state.partyStatus.isLive ? "stopPartyMode" : "startPartyMode")
                                }
                            } label: {
                                Label(
                                    state.partyStatus.isLive ? "Stop Party Mode on Mac" : "Start Party Mode on Mac",
                                    systemImage: "sparkles.tv.fill"
                                )
                                .font(.system(size: 20, weight: .bold))
                                .padding(.horizontal, 26)
                                .padding(.vertical, 14)
                                .background(state.partyStatus.isLive ? EchoTVTheme.dangerCoral.opacity(0.25) : EchoTVTheme.partyMagenta.opacity(0.25))
                                .foregroundStyle(state.partyStatus.isLive ? EchoTVTheme.dangerCoral : EchoTVTheme.partyMagenta)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(EchoTVButtonStyle(cornerRadius: 14, accent: EchoTVTheme.neoCyan))

                            if state.partyStatus.isLive {
                                Button {
                                    store.selectedTab = .partyTV
                                } label: {
                                    Label("Open Party TV Display", systemImage: "tv.fill")
                                        .font(.system(size: 20, weight: .bold))
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 14)
                                        .background(EchoTVTheme.neoMint)
                                        .foregroundStyle(Color.black)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(EchoTVButtonStyle(cornerRadius: 14, accent: EchoTVTheme.neoCyan))
                            }
                        }
                    }
                    .frame(maxWidth: 880, alignment: .leading)

                    // Right: Live Mac Queue
                    VStack(alignment: .leading, spacing: 16) {
                        Text("MAC PLAYBACK QUEUE (\(state.queue.count))")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .tracking(1.6)
                            .foregroundStyle(EchoTVTheme.neoMint)

                        if state.queue.isEmpty {
                            Text("Queue is empty on Mac.")
                                .font(.system(size: 21))
                                .foregroundStyle(EchoTVTheme.textMuted)
                                .padding(24)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(EchoTVTheme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 10) {
                                    ForEach(Array(state.queue.enumerated()), id: \.offset) { idx, track in
                                        let isCurrent = idx == state.currentIndex
                                        Button {
                                            Task { await store.sendRemoteCommand("jumpToQueueIndex", queueIndex: idx) }
                                        } label: {
                                            HStack(spacing: 14) {
                                                Image(systemName: isCurrent ? "waveform" : "music.note")
                                                    .foregroundStyle(isCurrent ? EchoTVTheme.neoCyan : EchoTVTheme.textMuted)
                                                    .frame(width: 26)
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(track.title)
                                                        .font(.system(size: 20, weight: isCurrent ? .black : .bold))
                                                        .foregroundStyle(isCurrent ? EchoTVTheme.neoCyan : EchoTVTheme.textPrimary)
                                                        .lineLimit(1)
                                                    Text(track.artist)
                                                        .font(.system(size: 16))
                                                        .foregroundStyle(EchoTVTheme.textSecondary)
                                                        .lineLimit(1)
                                                }
                                                Spacer()
                                                Text(TVFormatters.duration(track.duration))
                                                    .font(.system(size: 16, design: .monospaced))
                                                    .foregroundStyle(EchoTVTheme.textMuted)
                                            }
                                            .padding(.horizontal, 18)
                                            .padding(.vertical, 12)
                                            .background(isCurrent ? EchoTVTheme.neoCyan.opacity(0.16) : EchoTVTheme.surface)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                        }
                                        .buttonStyle(EchoTVButtonStyle(cornerRadius: 14, accent: EchoTVTheme.neoCyan))
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.horizontal, 68)
                .padding(.vertical, 44)
            } else {
                VStack(spacing: 22) {
                    Image(systemName: "desktopcomputer")
                        .font(.system(size: 76))
                        .foregroundStyle(EchoTVTheme.neoCyan)
                    Text("Mac Remote Control")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(EchoTVTheme.textPrimary)
                    Text("Pair with My Echo on Mac to control playback, volume, queue, and Party Mode from your couch.")
                        .font(.system(size: 22))
                        .foregroundStyle(EchoTVTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 760)
                    if let err = store.remoteError {
                        Text(err)
                            .font(.system(size: 18, design: .monospaced))
                            .foregroundStyle(EchoTVTheme.dangerCoral)
                    }
                    Button {
                        store.selectedTab = .servers
                    } label: {
                        Label("Pair My Echo on Mac", systemImage: "server.rack")
                            .font(.system(size: 22, weight: .bold))
                            .padding(.horizontal, 30)
                            .padding(.vertical, 16)
                            .background(EchoTVTheme.neoCyan)
                            .foregroundStyle(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(EchoTVButtonStyle(cornerRadius: 14, accent: EchoTVTheme.neoCyan))
                }
            }
        }
        .onAppear { store.startRemotePolling() }
        .onDisappear { store.stopRemotePolling() }
    }

    private func remoteButton(icon: String, label: String, active: Bool = false, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .bold))
                Text(label)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
            }
            .frame(width: 92, height: 76)
            .background(active ? EchoTVTheme.neoCyan.opacity(0.24) : EchoTVTheme.surfaceElevated)
            .foregroundStyle(active ? EchoTVTheme.neoCyan : EchoTVTheme.textPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(EchoTVButtonStyle(cornerRadius: 14, accent: EchoTVTheme.neoCyan))
    }
}

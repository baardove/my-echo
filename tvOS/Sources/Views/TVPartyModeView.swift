import SwiftUI

struct TVPartyModeView: View {
    @Environment(TVEchoStore.self) private var store

    var body: some View {
        ZStack {
            EchoTVTheme.canvas.ignoresSafeArea()

            if let state = store.partyState, store.partyStatus.isLive {
                let currentEntry = state.tracks.first(where: \.isCurrent)
                let upNextEntries = state.tracks.filter { !$0.isPlayed && !$0.isCurrent }

                // Subtle blurred backdrop of current Party Mode song
                if let artURL = store.partyArtworkURL(for: currentEntry?.track.artworkHash) {
                    AsyncImage(url: artURL) { phase in
                        if case .success(let img) = phase {
                            img
                                .resizable()
                                .scaledToFill()
                                .blur(radius: 100)
                                .opacity(0.24)
                                .ignoresSafeArea()
                        }
                    }
                }

                VStack(spacing: 28) {
                    // Top Party Header Bar
                    HStack(spacing: 20) {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(EchoTVTheme.partyMagenta)
                                .frame(width: 16, height: 16)
                            Text("MY ECHO · PARTY MODE LIVE")
                                .font(.system(size: 18, weight: .black, design: .monospaced))
                                .tracking(2)
                                .foregroundStyle(EchoTVTheme.partyMagenta)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(EchoTVTheme.partyMagenta.opacity(0.16))
                        .clipShape(Capsule())

                        Text(state.playlistName)
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundStyle(EchoTVTheme.textPrimary)

                        Spacer()

                        let activeGuests = state.guests.filter(\.isActive)
                        HStack(spacing: 10) {
                            Image(systemName: "person.3.fill")
                                .foregroundStyle(EchoTVTheme.neoMint)
                            Text("\(max(activeGuests.count, state.guests.count)) Guests · \(upNextEntries.count) Up Next")
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundStyle(EchoTVTheme.textPrimary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(EchoTVTheme.surfaceElevated)
                        .clipShape(Capsule())

                        if store.isConnectedToMac {
                            Button {
                                Task { await store.sendRemoteCommand("togglePlayPause") }
                            } label: {
                                Label(state.isPlaying ? "Pause Mac" : "Play Mac", systemImage: state.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 19, weight: .bold))
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(EchoTVTheme.neoMint)
                                    .foregroundStyle(Color.black)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)

                            Button {
                                Task { await store.sendRemoteCommand("next") }
                            } label: {
                                Image(systemName: "forward.end.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 10)
                                    .background(EchoTVTheme.surfaceElevated)
                                    .foregroundStyle(EchoTVTheme.textPrimary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Main 3-Column Living-Room Party Dashboard
                    HStack(alignment: .top, spacing: 36) {
                        // Left: Huge Now Playing Stage
                        VStack(alignment: .leading, spacing: 22) {
                            if let cur = currentEntry {
                                TVArtworkView(url: store.partyArtworkURL(for: cur.track.artworkHash), cornerRadius: 22)
                                    .frame(width: 440, height: 440)
                                    .shadow(color: .black.opacity(0.6), radius: 36, y: 18)

                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 12) {
                                        if state.isPlayingVoiceIntro {
                                            Text("VOICE INTRO PLAYING")
                                                .font(.system(size: 15, weight: .black, design: .monospaced))
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 5)
                                                .background(EchoTVTheme.hiResGold.opacity(0.24))
                                                .foregroundStyle(EchoTVTheme.hiResGold)
                                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                        }
                                        if let requester = cur.addedBy, !requester.isEmpty {
                                            Label("Requested by \(requester)", systemImage: "person.fill")
                                                .font(.system(size: 17, weight: .bold))
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 6)
                                                .background(EchoTVTheme.partyMagenta.opacity(0.22))
                                                .foregroundStyle(EchoTVTheme.partyMagenta)
                                                .clipShape(Capsule())
                                        }
                                    }

                                    Text(cur.track.title)
                                        .font(.system(size: 38, weight: .black, design: .rounded))
                                        .foregroundStyle(EchoTVTheme.textPrimary)
                                        .lineLimit(2)

                                    Text("\(cur.track.artist) · \(cur.track.album)")
                                        .font(.system(size: 22, weight: .semibold))
                                        .foregroundStyle(EchoTVTheme.textSecondary)
                                        .lineLimit(1)
                                }
                                .frame(width: 440, alignment: .leading)

                                VStack(spacing: 8) {
                                    let pct = state.duration > 0 ? (state.currentTime / state.duration) : 0
                                    TVProgressBar(progress: pct, tint: EchoTVTheme.partyMagenta, height: 10)
                                    HStack {
                                        Text(TVFormatters.duration(state.currentTime))
                                        Spacer()
                                        Text(TVFormatters.duration(state.duration))
                                    }
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                                    .foregroundStyle(EchoTVTheme.textMuted)
                                }
                                .frame(width: 440)
                            } else {
                                VStack(spacing: 18) {
                                    Image(systemName: "music.quarternote.3")
                                        .font(.system(size: 72))
                                        .foregroundStyle(EchoTVTheme.partyMagenta)
                                    Text("Queue is Ready!")
                                        .font(.system(size: 32, weight: .bold))
                                    Text("Scan the QR code to request the first song.")
                                        .font(.system(size: 20))
                                        .foregroundStyle(EchoTVTheme.textSecondary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(width: 440, height: 520)
                                .background(EchoTVTheme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 22))
                            }
                        }

                        // Center: Up Next Queue
                        VStack(alignment: .leading, spacing: 16) {
                            Text("UP NEXT QUEUE")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .tracking(1.8)
                                .foregroundStyle(EchoTVTheme.neoMint)

                            if upNextEntries.isEmpty {
                                VStack(spacing: 12) {
                                    Text("No upcoming tracks yet")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundStyle(EchoTVTheme.textSecondary)
                                    Text("Guests can scan the QR code to add tracks from the Mac library.")
                                        .font(.system(size: 18))
                                        .foregroundStyle(EchoTVTheme.textMuted)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding(30)
                                .background(EchoTVTheme.surface.opacity(0.75))
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                            } else {
                                ScrollView {
                                    LazyVStack(spacing: 12) {
                                        ForEach(upNextEntries) { entry in
                                            HStack(spacing: 16) {
                                                TVArtworkView(url: store.partyArtworkURL(for: entry.track.artworkHash), cornerRadius: 8)
                                                    .frame(width: 68, height: 68)
                                                VStack(alignment: .leading, spacing: 4) {
                                                    HStack(spacing: 8) {
                                                        Text(entry.track.title)
                                                            .font(.system(size: 22, weight: .bold))
                                                            .foregroundStyle(EchoTVTheme.textPrimary)
                                                            .lineLimit(1)
                                                        if entry.hasVoiceIntro {
                                                            Image(systemName: "mic.badge.plus")
                                                                .font(.system(size: 16))
                                                                .foregroundStyle(EchoTVTheme.hiResGold)
                                                        }
                                                    }
                                                    Text(entry.track.artist)
                                                        .font(.system(size: 18))
                                                        .foregroundStyle(EchoTVTheme.textSecondary)
                                                        .lineLimit(1)
                                                }
                                                Spacer()
                                                VStack(alignment: .trailing, spacing: 4) {
                                                    if let by = entry.addedBy, !by.isEmpty {
                                                        Text(by)
                                                            .font(.system(size: 15, weight: .bold))
                                                            .foregroundStyle(EchoTVTheme.partyMagenta)
                                                    }
                                                    if let eta = entry.plannedPlayAt {
                                                        Text(TVFormatters.shortTime(eta))
                                                            .font(.system(size: 15, design: .monospaced))
                                                            .foregroundStyle(EchoTVTheme.textMuted)
                                                    }
                                                }
                                            }
                                            .padding(14)
                                            .background(EchoTVTheme.surface.opacity(0.86))
                                            .clipShape(RoundedRectangle(cornerRadius: 14))
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        // Right: Guest Join QR Code + Live Party Chat
                        VStack(spacing: 24) {
                            if let joinURL = store.partyStatus.joinURL,
                               let qrImage = QRCodeGenerator.generate(from: joinURL, scale: 12) {
                                VStack(spacing: 14) {
                                    Text("SCAN TO REQUEST SONGS")
                                        .font(.system(size: 15, weight: .black, design: .monospaced))
                                        .tracking(1.6)
                                        .foregroundStyle(EchoTVTheme.neoMint)

                                    Image(uiImage: qrImage)
                                        .interpolation(.none)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 230, height: 230)
                                        .padding(16)
                                        .background(Color.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))

                                    Text(joinURL)
                                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                                        .foregroundStyle(EchoTVTheme.neoCyan)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)
                                }
                                .padding(22)
                                .frame(width: 390)
                                .background(EchoTVTheme.surface.opacity(0.92))
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .strokeBorder(EchoTVTheme.neoMint.opacity(0.45), lineWidth: 1.5)
                                )
                            }

                            if state.chatEnabled {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("PARTY CHAT")
                                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                                        .tracking(1.6)
                                        .foregroundStyle(EchoTVTheme.neoCyan)

                                    if state.chatMessages.isEmpty {
                                        Text("Messages from guests appear here live.")
                                            .font(.system(size: 17))
                                            .foregroundStyle(EchoTVTheme.textMuted)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                    } else {
                                        ScrollView {
                                            LazyVStack(alignment: .leading, spacing: 10) {
                                                ForEach(state.chatMessages.suffix(12)) { msg in
                                                    VStack(alignment: .leading, spacing: 3) {
                                                        HStack {
                                                            Text(msg.isHost ? "\(msg.senderName) (HOST)" : msg.senderName)
                                                                .font(.system(size: 15, weight: .black))
                                                                .foregroundStyle(msg.isHost ? EchoTVTheme.neoMint : EchoTVTheme.partyMagenta)
                                                            Spacer()
                                                            Text(TVFormatters.shortTime(msg.sentAt))
                                                                .font(.system(size: 13, design: .monospaced))
                                                                .foregroundStyle(EchoTVTheme.textMuted)
                                                        }
                                                        Text(msg.text)
                                                            .font(.system(size: 18))
                                                            .foregroundStyle(EchoTVTheme.textPrimary)
                                                    }
                                                    .padding(12)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .background(EchoTVTheme.surfaceElevated.opacity(0.85))
                                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(20)
                                .frame(width: 390)
                                .frame(maxHeight: .infinity)
                                .background(EchoTVTheme.surface.opacity(0.9))
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                            }
                        }
                    }
                }
                .padding(.horizontal, 64)
                .padding(.vertical, 40)
            } else {
                // Party Mode Inactive State (with 1-click Start Party Mode on Mac!)
                VStack(spacing: 26) {
                    Image(systemName: "sparkles.tv.fill")
                        .font(.system(size: 86))
                        .foregroundStyle(EchoTVTheme.partyMagenta)
                    Text("Party Mode Big-Screen Display")
                        .font(.system(size: 46, weight: .black, design: .rounded))
                        .foregroundStyle(EchoTVTheme.textPrimary)
                    Text("Turn your TV into a live jukebox dashboard showing Now Playing, who requested each song, Up Next queue, live guest chat, and a scannable QR code.")
                        .font(.system(size: 22))
                        .foregroundStyle(EchoTVTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 880)

                    HStack(spacing: 20) {
                        if store.isConnectedToMac {
                            Button {
                                Task {
                                    await store.sendRemoteCommand("startPartyMode")
                                    await store.refreshPartyStateOnce()
                                }
                            } label: {
                                Label("Start Party Mode on Mac", systemImage: "play.circle.fill")
                                    .font(.system(size: 24, weight: .bold))
                                    .padding(.horizontal, 34)
                                    .padding(.vertical, 18)
                                    .background(EchoTVTheme.partyMagenta)
                                    .foregroundStyle(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button {
                                store.selectedTab = .servers
                            } label: {
                                Label("Pair Mac or Enter Party URL", systemImage: "server.rack")
                                    .font(.system(size: 22, weight: .bold))
                                    .padding(.horizontal, 30)
                                    .padding(.vertical, 16)
                                    .background(EchoTVTheme.neoMint)
                                    .foregroundStyle(Color.black)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            Task { await store.refreshPartyStateOnce() }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                                .font(.system(size: 22, weight: .semibold))
                                .padding(.horizontal, 26)
                                .padding(.vertical, 16)
                                .background(EchoTVTheme.surfaceElevated)
                                .foregroundStyle(EchoTVTheme.textPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }

                    if let err = store.partyError {
                        Text(err)
                            .font(.system(size: 18, design: .monospaced))
                            .foregroundStyle(EchoTVTheme.dangerCoral)
                    }
                }
                .padding(60)
            }
        }
        .onAppear { store.startPartyPolling() }
        .onDisappear { store.stopPartyPolling() }
    }
}

import SwiftUI

struct TVPartyModeView: View {
    @Environment(TVEchoStore.self) private var store

    var body: some View {
        let currentEntry = store.partyState?.tracks.first(where: \.isCurrent)
        let backdropURL = (store.partyStatus.isLive ? store.partyArtworkURL(for: currentEntry?.track.artworkHash) : nil)

        GeometryReader { geo in
            let usableHeight = max(560, geo.size.height - 44)
            let headerHeight: CGFloat = 68
            let columnsHeight = max(460, usableHeight - headerHeight - 24)
            let artSize = min(380, max(280, columnsHeight * 0.55))
            let qrSize: CGFloat = min(190, max(150, columnsHeight * 0.27))

            Group {
                if let state = store.partyState, store.partyStatus.isLive {
                    let upNextEntries = state.tracks.filter { !$0.isPlayed && !$0.isCurrent }

                    VStack(alignment: .leading, spacing: 20) {
                        // Top Party Header Bar
                        HStack(spacing: 18) {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(EchoTVTheme.partyMagenta)
                                    .frame(width: 14, height: 14)
                                Text("MY ECHO · PARTY MODE LIVE")
                                    .font(.system(size: 16, weight: .black, design: .monospaced))
                                    .tracking(1.8)
                                    .foregroundStyle(EchoTVTheme.partyMagenta)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(EchoTVTheme.partyMagenta.opacity(0.16))
                            .clipShape(Capsule())

                            Text(state.playlistName)
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundStyle(EchoTVTheme.textPrimary)
                                .lineLimit(1)

                            Spacer()

                            let activeGuests = state.guests.filter(\.isActive)
                            HStack(spacing: 8) {
                                Image(systemName: "person.3.fill")
                                    .foregroundStyle(EchoTVTheme.neoMint)
                                Text("\(max(activeGuests.count, state.guests.count)) · \(upNextEntries.count) Next")
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                                    .foregroundStyle(EchoTVTheme.textPrimary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(EchoTVTheme.surfaceElevated)
                            .clipShape(Capsule())

                            // Audio Output Switcher: Mac | TV | Both
                            HStack(spacing: 6) {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(EchoTVTheme.neoCyan)
                                    .padding(.leading, 8)
                                ForEach(TVPartyAudioOutput.allCases) { mode in
                                    let selected = store.partyAudioOutput == mode
                                    Button {
                                        store.setPartyAudioOutput(mode)
                                    } label: {
                                        Text(mode.rawValue)
                                            .font(.system(size: 15, weight: .black, design: .monospaced))
                                            .padding(.horizontal, 13)
                                            .padding(.vertical, 6)
                                            .background(selected ? EchoTVTheme.neoCyan : Color.clear)
                                            .foregroundStyle(selected ? Color.black : EchoTVTheme.textSecondary)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(EchoTVButtonStyle(cornerRadius: 14, accent: EchoTVTheme.partyMagenta))
                                }
                            }
                            .padding(4)
                            .background(EchoTVTheme.surfaceElevated)
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(EchoTVTheme.neoCyan.opacity(0.45), lineWidth: 1))

                            if store.isConnectedToMac {
                                Button {
                                    Task { await store.sendPartyTransportCommand("togglePlayPause") }
                                } label: {
                                    Label(state.isPlaying ? "Pause" : "Play", systemImage: state.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 16, weight: .bold))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(EchoTVTheme.neoMint)
                                        .foregroundStyle(Color.black)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(EchoTVButtonStyle(cornerRadius: 14, accent: EchoTVTheme.partyMagenta))

                                Button {
                                    Task { await store.sendPartyTransportCommand("next") }
                                } label: {
                                    Image(systemName: "forward.end.fill")
                                        .font(.system(size: 17, weight: .bold))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(EchoTVTheme.surfaceElevated)
                                        .foregroundStyle(EchoTVTheme.textPrimary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(EchoTVButtonStyle(cornerRadius: 14, accent: EchoTVTheme.partyMagenta))
                            }
                        }
                        .frame(height: headerHeight)

                        // Main 3-Column Living-Room Party Dashboard (strictly bounded to TV canvas)
                        HStack(alignment: .top, spacing: 32) {
                            // Left: Now Playing Stage
                            VStack(alignment: .leading, spacing: 18) {
                                if let cur = currentEntry {
                                    TVArtworkView(
                                        url: store.partyArtworkURL(for: cur.track.artworkHash),
                                        cornerRadius: 20,
                                        preservePreviousWhileLoading: true
                                    )
                                        .frame(width: artSize, height: artSize)
                                        .shadow(color: .black.opacity(0.6), radius: 28, y: 14)

                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack(spacing: 10) {
                                            if state.isPlayingVoiceIntro {
                                                Text("VOICE INTRO LIVE")
                                                    .font(.system(size: 14, weight: .black, design: .monospaced))
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 4)
                                                    .background(EchoTVTheme.hiResGold.opacity(0.24))
                                                    .foregroundStyle(EchoTVTheme.hiResGold)
                                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                            }
                                            if let requester = cur.addedBy, !requester.isEmpty {
                                                Label("Requested by \(requester)", systemImage: "person.fill")
                                                    .font(.system(size: 16, weight: .bold))
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 5)
                                                    .background(EchoTVTheme.partyMagenta.opacity(0.22))
                                                    .foregroundStyle(EchoTVTheme.partyMagenta)
                                                    .clipShape(Capsule())
                                                    .lineLimit(1)
                                            }
                                        }

                                        Text(cur.track.title)
                                            .font(.system(size: 34, weight: .black, design: .rounded))
                                            .foregroundStyle(EchoTVTheme.textPrimary)
                                            .lineLimit(2)

                                        Text("\(cur.track.artist) · \(cur.track.album)")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundStyle(EchoTVTheme.textSecondary)
                                            .lineLimit(1)
                                    }
                                    .frame(width: artSize, alignment: .leading)

                                    VStack(spacing: 6) {
                                        let pct = state.duration > 0 ? (state.currentTime / state.duration) : 0
                                        TVProgressBar(progress: pct, tint: EchoTVTheme.partyMagenta, height: 9)
                                        HStack {
                                            Text(TVFormatters.duration(state.currentTime))
                                            Spacer()
                                            Text(TVFormatters.duration(state.duration))
                                        }
                                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                                        .foregroundStyle(EchoTVTheme.textMuted)
                                    }
                                    .frame(width: artSize)
                                } else {
                                    VStack(spacing: 18) {
                                        Image(systemName: "music.quarternote.3")
                                            .font(.system(size: 68))
                                            .foregroundStyle(EchoTVTheme.partyMagenta)
                                        Text("Queue is Ready!")
                                            .font(.system(size: 30, weight: .bold))
                                        Text("Scan the QR code to request the first song.")
                                            .font(.system(size: 19))
                                            .foregroundStyle(EchoTVTheme.textSecondary)
                                            .multilineTextAlignment(.center)
                                    }
                                    .frame(width: artSize, height: min(460, columnsHeight))
                                    .background(EchoTVTheme.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                                }
                                Spacer(minLength: 0)
                            }
                            .frame(width: artSize, height: columnsHeight, alignment: .topLeading)

                            // Center: Up Next Queue
                            VStack(alignment: .leading, spacing: 14) {
                                Text("UP NEXT QUEUE")
                                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                                    .tracking(1.6)
                                    .foregroundStyle(EchoTVTheme.neoMint)

                                if upNextEntries.isEmpty {
                                    VStack(spacing: 12) {
                                        Text("No upcoming tracks yet")
                                            .font(.system(size: 23, weight: .bold))
                                            .foregroundStyle(EchoTVTheme.textSecondary)
                                        Text("Guests can scan the QR code to add tracks from the Mac library.")
                                            .font(.system(size: 17))
                                            .foregroundStyle(EchoTVTheme.textMuted)
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .padding(28)
                                    .background(EchoTVTheme.surface.opacity(0.75))
                                    .clipShape(RoundedRectangle(cornerRadius: 18))
                                } else {
                                    ScrollView {
                                        LazyVStack(spacing: 10) {
                                            ForEach(upNextEntries) { entry in
                                                HStack(spacing: 14) {
                                                    TVArtworkView(url: store.partyArtworkURL(for: entry.track.artworkHash), cornerRadius: 8)
                                                        .frame(width: 60, height: 60)
                                                    VStack(alignment: .leading, spacing: 3) {
                                                        HStack(spacing: 8) {
                                                            Text(entry.track.title)
                                                                .font(.system(size: 20, weight: .bold))
                                                                .foregroundStyle(EchoTVTheme.textPrimary)
                                                                .lineLimit(1)
                                                            if entry.hasVoiceIntro {
                                                                Image(systemName: "mic.badge.plus")
                                                                    .font(.system(size: 15))
                                                                    .foregroundStyle(EchoTVTheme.hiResGold)
                                                            }
                                                        }
                                                        Text(entry.track.artist)
                                                            .font(.system(size: 17))
                                                            .foregroundStyle(EchoTVTheme.textSecondary)
                                                            .lineLimit(1)
                                                    }
                                                    Spacer()
                                                    VStack(alignment: .trailing, spacing: 3) {
                                                        if let by = entry.addedBy, !by.isEmpty {
                                                            Text(by)
                                                                .font(.system(size: 14, weight: .bold))
                                                                .foregroundStyle(EchoTVTheme.partyMagenta)
                                                        }
                                                        if let eta = entry.plannedPlayAt {
                                                            Text(TVFormatters.shortTime(eta))
                                                                .font(.system(size: 14, design: .monospaced))
                                                                .foregroundStyle(EchoTVTheme.textMuted)
                                                        }
                                                    }
                                                }
                                                .padding(12)
                                                .background(EchoTVTheme.surface.opacity(0.86))
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                            }
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: columnsHeight, alignment: .topLeading)

                            // Right: Guest Join QR Code + Live Party Chat (strictly fits columnsHeight)
                            VStack(spacing: 16) {
                                if let joinURL = store.partyStatus.joinURL,
                                   let qrImage = QRCodeGenerator.generate(from: joinURL, scale: 12) {
                                    VStack(spacing: 10) {
                                        Text("SCAN TO REQUEST SONGS")
                                            .font(.system(size: 14, weight: .black, design: .monospaced))
                                            .tracking(1.4)
                                            .foregroundStyle(EchoTVTheme.neoMint)

                                        Image(uiImage: qrImage)
                                            .interpolation(.none)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: qrSize, height: qrSize)
                                            .padding(12)
                                            .background(Color.white)
                                            .clipShape(RoundedRectangle(cornerRadius: 14))

                                        Text(joinURL)
                                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                                            .foregroundStyle(EchoTVTheme.neoCyan)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.75)
                                    }
                                    .padding(16)
                                    .frame(width: 370)
                                    .background(EchoTVTheme.surface.opacity(0.92))
                                    .clipShape(RoundedRectangle(cornerRadius: 18))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18)
                                            .strokeBorder(EchoTVTheme.neoMint.opacity(0.45), lineWidth: 1.5)
                                    )
                                }

                                if state.chatEnabled {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("PARTY CHAT")
                                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                                            .tracking(1.5)
                                            .foregroundStyle(EchoTVTheme.neoCyan)

                                        if state.chatMessages.isEmpty {
                                            Text("Messages from guests appear here live.")
                                                .font(.system(size: 16))
                                                .foregroundStyle(EchoTVTheme.textMuted)
                                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                        } else {
                                            ScrollView {
                                                LazyVStack(alignment: .leading, spacing: 8) {
                                                    ForEach(state.chatMessages.suffix(12).reversed()) { msg in
                                                        VStack(alignment: .leading, spacing: 2) {
                                                            HStack {
                                                                Text(msg.isHost ? "\(msg.senderName) (HOST)" : msg.senderName)
                                                                    .font(.system(size: 14, weight: .black))
                                                                    .foregroundStyle(msg.isHost ? EchoTVTheme.neoMint : EchoTVTheme.partyMagenta)
                                                                Spacer()
                                                                Text(TVFormatters.shortTime(msg.sentAt))
                                                                    .font(.system(size: 12, design: .monospaced))
                                                                    .foregroundStyle(EchoTVTheme.textMuted)
                                                            }
                                                            Text(msg.text)
                                                                .font(.system(size: 16))
                                                                .foregroundStyle(EchoTVTheme.textPrimary)
                                                                .lineLimit(3)
                                                        }
                                                        .padding(10)
                                                        .frame(maxWidth: .infinity, alignment: .leading)
                                                        .background(EchoTVTheme.surfaceElevated.opacity(0.85))
                                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                                    }
                                                }
                                            }
                                            .clipped()
                                        }
                                    }
                                    .padding(16)
                                    .frame(width: 370)
                                    .frame(maxHeight: .infinity, alignment: .topLeading)
                                    .background(EchoTVTheme.surface.opacity(0.9))
                                    .clipShape(RoundedRectangle(cornerRadius: 18))
                                    .clipped()
                                }
                            }
                            .frame(width: 370, height: columnsHeight, alignment: .top)
                        }
                        .frame(height: columnsHeight, alignment: .top)
                    }
                    .padding(.horizontal, 56)
                    .padding(.top, 18)
                    .padding(.bottom, 24)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
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
                                        await store.startPartyMode()
                                    }
                                } label: {
                                    Label(
                                        store.isConnectedToEchoServer ? "Start Party Mode on Echo Server" : "Start Party Mode on Mac",
                                        systemImage: "play.circle.fill"
                                    )
                                        .font(.system(size: 24, weight: .bold))
                                        .padding(.horizontal, 34)
                                        .padding(.vertical, 18)
                                        .background(EchoTVTheme.partyMagenta)
                                        .foregroundStyle(Color.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                                .buttonStyle(EchoTVButtonStyle(cornerRadius: 14, accent: EchoTVTheme.partyMagenta))
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
                                .buttonStyle(EchoTVButtonStyle(cornerRadius: 14, accent: EchoTVTheme.partyMagenta))
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
                            .buttonStyle(EchoTVButtonStyle(cornerRadius: 14, accent: EchoTVTheme.partyMagenta))
                        }

                        if let err = store.partyError {
                            Text(err)
                                .font(.system(size: 18, design: .monospaced))
                                .foregroundStyle(EchoTVTheme.dangerCoral)
                        }
                    }
                    .padding(60)
                    .frame(width: geo.size.width, height: geo.size.height)
                }
            }
        }
        .background {
            TVBackdropArtworkView(url: backdropURL, opacity: 0.24)
        }
        .onAppear { store.startPartyPolling() }
        .onDisappear { store.stopPartyPolling() }
    }
}

import SwiftUI
import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import EchoCore

struct PartyModeView: View {
    @Environment(EchoStore.self) private var store
    @State private var quickSearchQuery: String = ""
    @State private var isDropTargeted: Bool = false
    @State private var showPartySettingsLightbox: Bool = false
    @State private var isEditingPort: Bool = false
    @State private var portDraft: String = ""
    @State private var hostChatDraft: String = ""
    @State private var selectedRowIndex: Int? = nil
    @FocusState private var focusedRowIndex: Int?

    private static let hhmmFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        let playlist = store.partyPlaylist
        let partyTracks = playlist.map { store.tracks(for: $0) } ?? []
        let currentIndex = (store.player.currentTrack != nil && store.isPartyModeEnabled)
            ? store.player.currentIndex
            : nil
        let plannedTimes = store.plannedPlayTimesForPartymode()

        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    heroControlCard(playlist: playlist, trackCount: partyTracks.count)

                    HStack(alignment: .top, spacing: 20) {
                        // Left: Live Dynamic "Partymode" Playlist Queue
                        livePartymodeQueueCard(
                            playlist: playlist,
                            tracks: partyTracks,
                            currentIndex: currentIndex,
                            plannedTimes: plannedTimes
                        )
                        .frame(maxWidth: .infinity)

                        // Right: Activated Guests, Optional Chat, Quick Add & Activity Feed
                        VStack(spacing: 16) {
                            activatedGuestsCard
                            if store.partyChatEnabled {
                                partyChatCard
                            }
                            quickTrackSearchCard
                            guestActivityCard
                        }
                        .frame(width: 350)
                    }
                }
                .padding(26)
            }

            if showPartySettingsLightbox {
                partySettingsLightbox
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    .zIndex(50)
            }
        }
        .animation(.easeOut(duration: 0.16), value: showPartySettingsLightbox)
        .onKeyPress(.escape) {
            if showPartySettingsLightbox {
                showPartySettingsLightbox = false
                isEditingPort = false
                return .handled
            }
            return .ignored
        }
    }

    // MARK: - Hero Control Card (Start/Stop, Random/Custom Port URL, QR Code, Host Toggles)

    private func openPartySettings(focusPort: Bool = false) {
        if let pref = store.partyPreferredPort {
            portDraft = String(pref)
        } else if store.partyServerPort > 0 {
            portDraft = String(store.partyServerPort)
        } else {
            portDraft = String(EchoStore.defaultPartyPort)
        }
        isEditingPort = focusPort
        showPartySettingsLightbox = true
    }

    private func heroControlCard(playlist: Playlist?, trackCount: Int) -> some View {
        let isLive = store.isPartyModeEnabled
        let accent = isLive ? EchoTheme.neoMagenta : EchoTheme.neoMint
        let playingTrack = isLive ? store.player.currentTrack : nil

        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 16) {
                // Dedicated Party Mode Emblem Symbol (never duplicates the larger Now Playing album art below)
                ZStack {
                    RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.24), Color.black.opacity(0.45)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 58, height: 58)
                        .overlay(
                            RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous)
                                .strokeBorder(accent.opacity(0.75), lineWidth: 1.5)
                        )
                    Image(systemName: "party.popper.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(isLive ? EchoTheme.retroNeonGradient : EchoTheme.accentGradient)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(isLive ? EchoTheme.neoMint : EchoTheme.textMuted)
                            .frame(width: 8, height: 8)
                            .shadow(color: isLive ? EchoTheme.neoMint : .clear, radius: 5)
                        Text(isLive ? "PARTY MODE LIVE · LOCKED TO \"PARTYMODE\"" : "PARTY MODE STANDBY")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .tracking(1.3)
                            .foregroundStyle(isLive ? EchoTheme.neoMint : EchoTheme.textMuted)
                        if isLive && store.partyServerPort > 0 {
                            Button {
                                openPartySettings(focusPort: true)
                            } label: {
                                HStack(spacing: 4) {
                                    Text("PORT \(String(store.partyServerPort))")
                                    Image(systemName: "pencil")
                                        .font(.system(size: 8, weight: .bold))
                                }
                                .font(.system(size: 9.5, weight: .black, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(EchoTheme.neoCyan.opacity(0.18))
                                .foregroundStyle(EchoTheme.neoCyan)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                            .buttonStyle(.plain)
                            .help("Click to open Party Mode settings and edit the web server port.")
                        } else if let preferred = store.partyPreferredPort {
                            Button {
                                openPartySettings(focusPort: true)
                            } label: {
                                HStack(spacing: 4) {
                                    Text("PORT \(String(preferred))")
                                    Image(systemName: "pencil")
                                        .font(.system(size: 8, weight: .bold))
                                }
                                .font(.system(size: 9.5, weight: .black, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(EchoTheme.surfaceElevated)
                                .foregroundStyle(EchoTheme.textSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                            .buttonStyle(.plain)
                            .help("Custom port configured for next Party Mode launch. Click to edit in Party Mode settings.")
                        }
                    }

                    Text("Partymode Jukebox")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(EchoTheme.textPrimary)
                }

                Spacer(minLength: 12)

                HStack(spacing: 10) {
                    NeoSecondaryButton(title: "Settings", icon: "gearshape.fill") {
                        openPartySettings(focusPort: false)
                    }
                    .help("Party Mode Settings: Auto-play, re-requests, Party Chat, Listen-Along Stream, server port, and max voice intro length.")

                    if let pl = playlist {
                        NeoSecondaryButton(title: "Open Playlist View", icon: "music.note.list") {
                            store.navigate(to: .playlist(pl.id))
                        }
                    }

                    if isLive {
                        Button {
                            store.stopPartyMode()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 11, weight: .bold))
                                Text("Exit Party Mode")
                                    .font(.system(size: 12.5, weight: .bold))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(EchoTheme.dangerCoral.opacity(0.20))
                            .foregroundStyle(EchoTheme.dangerCoral)
                            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                            .overlay(
                                RoundedRectangle(cornerRadius: EchoTheme.radiusControl)
                                    .strokeBorder(EchoTheme.dangerCoral.opacity(0.75), lineWidth: 1.2)
                            )
                        }
                        .buttonStyle(.plain)
                        .help("Unlock playback and shut down the guest web server.")
                    } else {
                        NeoPrimaryButton(title: "Start Party Mode", icon: "play.circle.fill") {
                            store.startPartyMode(navigateToView: false)
                        }
                        .help("Lock playback onto the dynamic 'Partymode' playlist and launch the guest web server on a random port.")
                    }
                }
            }

            if let err = store.partyServerLastError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(EchoTheme.warningAmber)
                    Text("Web server error: \(err)")
                        .font(.system(size: 12))
                        .foregroundStyle(EchoTheme.warningAmber)
                }
                .padding(10)
                .background(EchoTheme.warningAmber.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
            }

            // Live Banner: Larger Equal-Sized Album Art (Left) & QR Code (Right)
            if isLive, let urlStr = store.partyServerURLString {
                let heroSquareSize: CGFloat = 164
                HStack(alignment: .center, spacing: 20) {
                    // LEFT: Currently Playing Song Album Art + Title
                    HStack(spacing: 16) {
                        if let playingTrack {
                            ArtworkView(hash: playingTrack.artworkHash, artworkCache: store.artworkCache, cornerRadius: EchoTheme.radiusControl, iconSize: 36)
                                .frame(width: heroSquareSize, height: heroSquareSize)
                                .overlay(
                                    RoundedRectangle(cornerRadius: EchoTheme.radiusControl)
                                        .strokeBorder(EchoTheme.neoMint.opacity(0.65), lineWidth: 1.5)
                                )
                                .shadow(color: .black.opacity(0.5), radius: 12, y: 5)
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: EchoTheme.radiusControl)
                                    .fill(EchoTheme.surfaceElevated.opacity(0.8))
                                    .frame(width: heroSquareSize, height: heroSquareSize)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: EchoTheme.radiusControl)
                                            .strokeBorder(EchoTheme.border, lineWidth: 1)
                                    )
                                Image(systemName: "music.note")
                                    .font(.system(size: 38, weight: .semibold))
                                    .foregroundStyle(EchoTheme.textMuted)
                            }
                        }

                        VStack(alignment: .leading, spacing: 7) {
                            HStack(spacing: 6) {
                                Image(systemName: store.player.isPlayingVoiceIntro ? "mic.fill" : (store.player.isPlaying ? "waveform" : "pause.fill"))
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(store.player.isPlayingVoiceIntro ? EchoTheme.neoMagenta : (playingTrack != nil ? EchoTheme.neoMint : EchoTheme.textMuted))
                                Text(store.player.isPlayingVoiceIntro
                                     ? "VOICE INTRO LIVE (MUSIC DUCKED 40%)"
                                     : (playingTrack != nil
                                        ? (store.player.isPlaying ? "NOW PLAYING" : "PAUSED · PARTYMODE")
                                        : "WAITING FOR TRACKS"))
                                    .font(.system(size: 9.5, weight: .black, design: .monospaced))
                                    .tracking(1.1)
                                    .foregroundStyle(store.player.isPlayingVoiceIntro ? EchoTheme.neoMagenta : (playingTrack != nil ? EchoTheme.neoMint : EchoTheme.textMuted))
                            }

                            Text(playingTrack?.title ?? "No Track Playing Yet")
                                .font(.system(size: 23, weight: .black, design: .rounded))
                                .foregroundStyle(EchoTheme.textPrimary)
                                .lineLimit(2)

                            if let playingTrack {
                                Text("\(playingTrack.artist.isEmpty ? playingTrack.effectiveArtist : playingTrack.artist) · \(playingTrack.effectiveAlbum)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(EchoTheme.textSecondary)
                                    .lineLimit(1)
                            } else {
                                Text("Add songs below or scan the QR code to start the party")
                                    .font(.system(size: 12))
                                    .foregroundStyle(EchoTheme.textMuted)
                                    .lineLimit(1)
                            }

                            HStack(spacing: 14) {
                                statPill(label: "LIBRARY", value: "\(store.tracks.filter(\.isAvailable).count)", color: EchoTheme.textPrimary)
                                statPill(label: "PARTYMODE", value: "\(trackCount)", color: EchoTheme.neoMint)
                                statPill(label: "GUEST ADDS", value: "\(store.partyGuestActivity.count)", color: EchoTheme.neoCyan)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Divider()
                        .frame(height: 148)
                        .overlay(EchoTheme.border)

                    // RIGHT: Guest Web Address + Port + Buttons + Same-Sized Scannable QR Code
                    HStack(spacing: 16) {
                        VStack(alignment: .trailing, spacing: 8) {
                            Text("GUEST WEB JUKEBOX (SAME WI-FI)")
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .tracking(1.1)
                                .foregroundStyle(EchoTheme.neoCyan)

                            Text(urlStr)
                                .font(.system(size: 18, weight: .black, design: .monospaced))
                                .foregroundStyle(EchoTheme.neoMint)
                                .textSelection(.enabled)
                                .lineLimit(1)

                            HStack(spacing: 8) {
                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(urlStr, forType: .string)
                                    store.showToast("Copied \(urlStr)")
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "doc.on.doc")
                                        Text("Copy")
                                    }
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .background(EchoTheme.neoMint.opacity(0.16))
                                    .foregroundStyle(EchoTheme.neoMint)
                                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                                    .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall).strokeBorder(EchoTheme.neoMint.opacity(0.55), lineWidth: 1))
                                }
                                .buttonStyle(.plain)

                                if let shareURL = URL(string: urlStr) {
                                    NeoShareButton(
                                        items: [shareURL],
                                        title: "Share",
                                        accent: EchoTheme.neoMint,
                                        fontSize: 11,
                                        horizontalPadding: 9,
                                        verticalPadding: 5,
                                        helpText: "Share the Guest Web Jukebox link via AirDrop, Messages, Mail, or other macOS apps."
                                    )
                                }

                                Button {
                                    if let url = URL(string: urlStr) {
                                        NSWorkspace.shared.open(url)
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "safari")
                                        Text("Open in Browser")
                                    }
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .background(EchoTheme.neoCyan.opacity(0.15))
                                    .foregroundStyle(EchoTheme.neoCyan)
                                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                                    .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall).strokeBorder(EchoTheme.neoCyan.opacity(0.5), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if let qr = PartyQRCodeGenerator.makeImage(from: urlStr) {
                            Image(nsImage: qr)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .padding(10)
                                .frame(width: heroSquareSize, height: heroSquareSize)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                                .overlay(
                                    RoundedRectangle(cornerRadius: EchoTheme.radiusControl)
                                        .strokeBorder(EchoTheme.neoMint.opacity(0.65), lineWidth: 1.5)
                                )
                                .shadow(color: .black.opacity(0.45), radius: 12, y: 5)
                                .help("Guests can scan this QR code with their phone camera to open the Partymode track search.")
                        }
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
                .padding(16)
                .background(Color.black.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard))
                .overlay(
                    RoundedRectangle(cornerRadius: EchoTheme.radiusCard)
                        .strokeBorder(EchoTheme.neoMint.opacity(0.35), lineWidth: 1)
                )
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [
                    accent.opacity(isLive ? 0.16 : 0.08),
                    EchoTheme.neoCyan.opacity(0.06),
                    EchoTheme.surface
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous)
                .strokeBorder(isLive ? accent.opacity(0.55) : EchoTheme.borderStrong, lineWidth: 1)
        )
    }

    // MARK: - Party Mode Settings Lightbox

    private var partySettingsLightbox: some View {
        @Bindable var bindableStore = store
        let isLive = store.isPartyModeEnabled

        return ZStack {
            Color.black.opacity(0.78)
                .ignoresSafeArea()
                .onTapGesture {
                    showPartySettingsLightbox = false
                    isEditingPort = false
                }

            VStack(alignment: .leading, spacing: 18) {
                // Header
                HStack(alignment: .center) {
                    HStack(spacing: 10) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(EchoTheme.neoCyan)
                            .frame(width: 32, height: 32)
                            .background(EchoTheme.neoCyan.opacity(0.16))
                            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("PARTY MODE SETTINGS")
                                .font(.system(size: 9.5, weight: .black, design: .monospaced))
                                .tracking(1.3)
                                .foregroundStyle(EchoTheme.neoCyan)
                            Text("Partymode Jukebox Controls")
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundStyle(EchoTheme.textPrimary)
                        }
                    }

                    Spacer()

                    Button {
                        showPartySettingsLightbox = false
                        isEditingPort = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .frame(width: 28, height: 28)
                            .background(EchoTheme.surfaceElevated)
                            .foregroundStyle(EchoTheme.textSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                    }
                    .buttonStyle(.plain)
                    .help("Close Party Mode Settings (Esc)")
                }

                Divider().overlay(EchoTheme.border)

                // Behavior Switches
                VStack(spacing: 10) {
                    partySettingToggleRow(
                        title: "Auto-play on request",
                        subtitle: "Start playing automatically when a guest queues a track while idle.",
                        isOn: $bindableStore.partyAutoPlayOnRequest,
                        tint: EchoTheme.neoMint
                    )

                    partySettingToggleRow(
                        title: "Allow re-request played",
                        subtitle: "Let guests queue songs that were already played earlier in the party.",
                        isOn: $bindableStore.partyAllowReRequestPlayed,
                        tint: EchoTheme.neoCyan
                    )
                    .onChange(of: store.partyAllowReRequestPlayed) { _, _ in
                        store.pushPartyModeStateToServer()
                    }

                    partySettingToggleRow(
                        title: "Party Chat",
                        subtitle: "Enable live chat between guests and host on the web jukebox.",
                        isOn: Binding(
                            get: { store.partyChatEnabled },
                            set: { store.setPartyChatEnabled($0) }
                        ),
                        tint: EchoTheme.neoMagenta
                    )

                    partySettingToggleRow(
                        title: "Listen-Along Stream",
                        subtitle: "Allow remote guests on the web page to stream and listen along in sync.",
                        isOn: Binding(
                            get: { store.partyStreamingEnabled },
                            set: { store.setPartyStreamingEnabled($0) }
                        ),
                        tint: EchoTheme.neoMint
                    )
                }

                Divider().overlay(EchoTheme.border)

                // Server Port & Voice Intro Length
                VStack(alignment: .leading, spacing: 12) {
                    // Port row
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("WEB SERVER PORT")
                                .font(.system(size: 9.5, weight: .black, design: .monospaced))
                                .tracking(1.1)
                                .foregroundStyle(EchoTheme.neoCyan)
                            Text("Custom port (1024–65535) or default 53333")
                                .font(.system(size: 11))
                                .foregroundStyle(EchoTheme.textMuted)
                        }

                        Spacer()

                        if isEditingPort {
                            HStack(spacing: 6) {
                                TextField("53333", text: $portDraft)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(EchoTheme.textPrimary)
                                    .frame(width: 72)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 4.5)
                                    .background(EchoTheme.surfaceElevated)
                                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                                    .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall).strokeBorder(EchoTheme.neoCyan.opacity(0.7), lineWidth: 1))
                                    .onSubmit {
                                        if store.setPartyPort(portDraft) {
                                            isEditingPort = false
                                        }
                                    }

                                Button("Apply") {
                                    if store.setPartyPort(portDraft) {
                                        isEditingPort = false
                                    }
                                }
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4.5)
                                .background(EchoTheme.neoMint.opacity(0.20))
                                .foregroundStyle(EchoTheme.neoMint)
                                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                                .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall).strokeBorder(EchoTheme.neoMint.opacity(0.6), lineWidth: 1))
                                .buttonStyle(.plain)

                                Button("Default") {
                                    portDraft = String(EchoStore.defaultPartyPort)
                                    _ = store.setPartyPort("")
                                    isEditingPort = false
                                }
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4.5)
                                .background(EchoTheme.surfaceElevated)
                                .foregroundStyle(EchoTheme.textSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                                .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall).strokeBorder(EchoTheme.border, lineWidth: 1))
                                .buttonStyle(.plain)
                                .help("Reset to default Party Mode port 53333.")
                            }
                        } else {
                            HStack(spacing: 8) {
                                NeoSecondaryButton(
                                    title: store.partyServerPort > 0
                                        ? "Edit Port (\(String(store.partyServerPort)))"
                                        : (store.partyPreferredPort.map { "Edit Port (\(String($0)))" } ?? "Edit Port (53333)"),
                                    icon: "network",
                                    accent: EchoTheme.neoCyan
                                ) {
                                    if let pref = store.partyPreferredPort {
                                        portDraft = String(pref)
                                    } else if store.partyServerPort > 0 {
                                        portDraft = String(store.partyServerPort)
                                    } else {
                                        portDraft = String(EchoStore.defaultPartyPort)
                                    }
                                    isEditingPort = true
                                }

                                if isLive {
                                    NeoSecondaryButton(title: "Random", icon: "arrow.triangle.2.circlepath", accent: EchoTheme.neoCyan) {
                                        store.restartPartyServerOnNewPort()
                                    }
                                    .help("Restart the guest web server on a fresh random port.")
                                }
                            }
                        }
                    }

                    // Max Voice Intro row
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("MAX VOICE INTRO")
                                .font(.system(size: 9.5, weight: .black, design: .monospaced))
                                .tracking(1.1)
                                .foregroundStyle(EchoTheme.neoMagenta)
                            Text("Maximum guest intro clip duration (5s–60s)")
                                .font(.system(size: 11))
                                .foregroundStyle(EchoTheme.textMuted)
                        }

                        Spacer()

                        HStack(spacing: 6) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundStyle(EchoTheme.neoMagenta)
                            Button {
                                store.setPartyMaxIntroSeconds(store.partyMaxIntroSeconds - 5)
                            } label: {
                                Image(systemName: "minus")
                                    .font(.system(size: 9.5, weight: .bold))
                                    .frame(width: 22, height: 22)
                                    .background(EchoTheme.surfaceElevated)
                                    .foregroundStyle(EchoTheme.textPrimary)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                            .buttonStyle(.plain)
                            .disabled(store.partyMaxIntroSeconds <= 5)

                            Text("\(store.partyMaxIntroSeconds)s")
                                .font(.system(size: 12, weight: .black, design: .monospaced))
                                .foregroundStyle(EchoTheme.neoMagenta)
                                .frame(minWidth: 32)

                            Button {
                                store.setPartyMaxIntroSeconds(store.partyMaxIntroSeconds + 5)
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 9.5, weight: .bold))
                                    .frame(width: 22, height: 22)
                                    .background(EchoTheme.surfaceElevated)
                                    .foregroundStyle(EchoTheme.textPrimary)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                            .buttonStyle(.plain)
                            .disabled(store.partyMaxIntroSeconds >= 60)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(EchoTheme.surfaceElevated.opacity(0.65))
                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                        .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusControl).strokeBorder(EchoTheme.neoMagenta.opacity(0.45), lineWidth: 1))
                    }
                }

                HStack {
                    Spacer()
                    NeoPrimaryButton(title: "Done", icon: "checkmark") {
                        showPartySettingsLightbox = false
                        isEditingPort = false
                    }
                }
                .padding(.top, 4)
            }
            .padding(22)
            .frame(width: 520)
            .background(EchoTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous)
                    .strokeBorder(EchoTheme.neoCyan.opacity(0.5), lineWidth: 1.2)
            )
            .shadow(color: .black.opacity(0.75), radius: 28, y: 12)
        }
    }

    private func partySettingToggleRow(
        title: String,
        subtitle: String,
        isOn: Binding<Bool>,
        tint: Color
    ) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(EchoTheme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(EchoTheme.textMuted)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(tint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(EchoTheme.surfaceElevated.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
        .overlay(
            RoundedRectangle(cornerRadius: EchoTheme.radiusControl)
                .strokeBorder(EchoTheme.border.opacity(0.75), lineWidth: 1)
        )
    }

    private func statPill(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                .foregroundStyle(EchoTheme.textMuted)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
        }
    }

    // MARK: - Live Partymode Queue Card

    private func livePartymodeQueueCard(
        playlist: Playlist?,
        tracks: [Track],
        currentIndex: Int?,
        plannedTimes: [Int: Date]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("DYNAMIC PLAYLIST · \"PARTYMODE\"")
                            .font(.system(size: 10.5, weight: .black, design: .monospaced))
                            .tracking(1.2)
                            .foregroundStyle(EchoTheme.neoMint)
                        if store.isPartyModeEnabled {
                            Label("LOCKED", systemImage: "lock.fill")
                                .font(.system(size: 8.5, weight: .black, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(EchoTheme.neoMagenta.opacity(0.2))
                                .foregroundStyle(EchoTheme.neoMagenta)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }
                    Text("\(tracks.count) track\(tracks.count == 1 ? "" : "s") · \(Formatters.duration(tracks.reduce(0) { $0 + $1.duration }))")
                        .font(.system(size: 11.5))
                        .foregroundStyle(EchoTheme.textMuted)
                }

                Spacer()

                HStack(spacing: 8) {
                    if !tracks.isEmpty {
                        NeoPrimaryButton(title: "Play", icon: "play.fill") {
                            store.playPartyModeTrack(at: max(0, currentIndex ?? 0))
                        }
                    } else if !store.player.queue.isEmpty && !store.isPartyModeEnabled {
                        NeoSecondaryButton(title: "Seed from Current Queue", icon: "tray.and.arrow.down") {
                            store.seedPartyModeWithCurrentQueue()
                        }
                    }

                    if let cur = currentIndex, cur > 0 {
                        NeoSecondaryButton(title: "Clear Played", icon: "sparkles") {
                            store.clearPlayedPartyTracks()
                        }
                        .help("Remove already-played tracks from Partymode while keeping Now Playing and Up Next.")
                    }

                    if !tracks.isEmpty {
                        Button {
                            store.clearAllPartyTracks()
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 11.5, weight: .semibold))
                                .frame(width: 28, height: 28)
                                .background(EchoTheme.dangerCoral.opacity(0.15))
                                .foregroundStyle(EchoTheme.dangerCoral)
                                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                        }
                        .buttonStyle(.plain)
                        .help("Clear all tracks from Partymode.")
                    }
                }
            }

            Divider().overlay(EchoTheme.border)

            if tracks.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: isDropTargeted ? "tray.and.arrow.down.fill" : "music.note.list")
                        .font(.system(size: 32))
                        .foregroundStyle(isDropTargeted ? EchoTheme.neoMint : EchoTheme.textMuted)
                    Text(isDropTargeted ? "Drop tracks to queue into Partymode" : "Partymode is empty")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(EchoTheme.textPrimary)
                    Text("Use Quick Add on the right, drag songs from your library here, or let party guests queue songs from the web URL.")
                        .font(.system(size: 12))
                        .foregroundStyle(EchoTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                }
                .frame(maxWidth: .infinity)
                .padding(36)
                .background(isDropTargeted ? EchoTheme.neoMint.opacity(0.12) : EchoTheme.canvas.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                .overlay(
                    RoundedRectangle(cornerRadius: EchoTheme.radiusControl)
                        .strokeBorder(isDropTargeted ? EchoTheme.neoMint : EchoTheme.border, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                )
            } else if let pl = playlist {
                LazyVStack(spacing: 4) {
                    ForEach(Array(tracks.enumerated()), id: \.offset) { idx, track in
                        let isCurrent = currentIndex == idx
                        let isPlayed = currentIndex.map { idx < $0 } ?? false
                        let requester = store.partyRequesterName(for: track.id)

                        HStack(spacing: 10) {
                            ZStack {
                                if isCurrent {
                                    Image(systemName: store.player.isPlaying ? "waveform" : "pause.fill")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(EchoTheme.neoMint)
                                } else {
                                    Text("\(idx + 1)")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(isPlayed ? EchoTheme.textMuted.opacity(0.5) : EchoTheme.textMuted)
                                }
                            }
                            .frame(width: 24)

                            ArtworkView(hash: track.artworkHash, artworkCache: store.artworkCache, cornerRadius: EchoTheme.radiusSmall, iconSize: 12)
                                .frame(width: 34, height: 34)
                                .opacity(isPlayed ? 0.55 : 1)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(track.title)
                                        .font(.system(size: 13, weight: isCurrent ? .bold : .semibold))
                                        .foregroundStyle(isCurrent ? EchoTheme.neoMint : (isPlayed ? EchoTheme.textMuted : EchoTheme.textPrimary))
                                        .lineLimit(1)

                                    if isCurrent {
                                        Text("PLAYING")
                                            .font(.system(size: 8, weight: .black, design: .monospaced))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1.5)
                                            .background(EchoTheme.neoMint.opacity(0.20))
                                            .foregroundStyle(EchoTheme.neoMint)
                                            .clipShape(RoundedRectangle(cornerRadius: 3))
                                    } else if isPlayed {
                                        Text("PLAYED")
                                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                                            .foregroundStyle(EchoTheme.textMuted.opacity(0.7))
                                    }
                                }

                                Text("\(track.artist.isEmpty ? track.effectiveArtist : track.artist) · \(track.effectiveAlbum)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(isPlayed ? EchoTheme.textMuted.opacity(0.65) : EchoTheme.textSecondary)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 6)

                            if let intro = store.partyVoiceIntrosByTrackID[track.id] {
                                Button {
                                    store.deletePartyVoiceIntro(trackID: track.id, fromHost: true)
                                } label: {
                                    HStack(spacing: 3) {
                                        Image(systemName: "mic.fill")
                                            .font(.system(size: 8.5, weight: .bold))
                                        Text("\(Int(intro.duration.rounded()))s")
                                            .font(.system(size: 9.5, weight: .black, design: .monospaced))
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(EchoTheme.neoMagenta.opacity(0.20))
                                    .foregroundStyle(EchoTheme.neoMagenta)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(EchoTheme.neoMagenta.opacity(0.55), lineWidth: 0.9))
                                }
                                .buttonStyle(.plain)
                                .help("Recorded \(Int(intro.duration.rounded()))s voice intro by \(intro.guestName). Click to remove intro.")
                            }

                            if let requester {
                                Text(requester)
                                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(EchoTheme.neoCyan.opacity(0.14))
                                    .foregroundStyle(EchoTheme.neoCyan)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                    .lineLimit(1)
                            }

                            if let plannedDate = plannedTimes[idx], !isCurrent && !isPlayed {
                                Text(Self.hhmmFormatter.string(from: plannedDate))
                                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 5.5)
                                    .padding(.vertical, 2)
                                    .background(EchoTheme.neoMint.opacity(0.14))
                                    .foregroundStyle(EchoTheme.neoMint)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                    .help("Planned start time")
                            }

                            Text(Formatters.duration(track.duration))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(EchoTheme.textMuted)
                                .frame(width: 40, alignment: .trailing)

                            Button {
                                store.removeTrack(at: idx, fromPlaylistID: pl.id)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(EchoTheme.textMuted)
                                    .frame(width: 24, height: 24)
                            }
                            .buttonStyle(.plain)
                            .help("Remove '\(track.title)' from Partymode.")
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: EchoTheme.radiusControl)
                                .fill(
                                    (selectedRowIndex == idx || focusedRowIndex == idx)
                                        ? EchoTheme.neoMint.opacity(0.18)
                                        : (isCurrent ? EchoTheme.neoMint.opacity(0.10) : EchoTheme.surfaceElevated.opacity(0.45))
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: EchoTheme.radiusControl)
                                .strokeBorder(
                                    (selectedRowIndex == idx || focusedRowIndex == idx)
                                        ? EchoTheme.neoMint.opacity(0.75)
                                        : (isCurrent ? EchoTheme.neoMint.opacity(0.45) : EchoTheme.border.opacity(0.6)),
                                    lineWidth: (selectedRowIndex == idx || focusedRowIndex == idx) ? 1.2 : 1
                                )
                        )
                        .contentShape(Rectangle())
                        .focusable()
                        .focusEffectDisabled()
                        .focused($focusedRowIndex, equals: idx)
                        .onTapGesture(count: 2) {
                            selectedRowIndex = idx
                            focusedRowIndex = idx
                            store.playPartyModeTrack(at: idx)
                        }
                        .simultaneousGesture(
                            TapGesture(count: 1).onEnded {
                                selectedRowIndex = idx
                                focusedRowIndex = idx
                            }
                        )
                        .contextMenu {
                            Button("Play Now") {
                                store.playPartyModeTrack(at: idx)
                            }
                            let otherPlaylists = store.playlists.filter { $0.id != pl.id }
                            Menu("Add to Another Playlist") {
                                ForEach(otherPlaylists) { targetPl in
                                    Button(targetPl.name) {
                                        store.addTracks([track], toPlaylistID: targetPl.id)
                                    }
                                }
                                if !otherPlaylists.isEmpty {
                                    Divider()
                                }
                                Button("Create New Playlist...") {
                                    let created = store.createPlaylist(name: "My Playlist", initialTrackIDs: [track.id])
                                    store.navigate(to: .playlist(created.id))
                                }
                            }
                            Divider()
                            Button("Remove from Partymode", role: .destructive) {
                                store.removeTrack(at: idx, fromPlaylistID: pl.id)
                            }
                        }
                        .draggable(EchoDragPayload.reorder(playlistID: pl.id, sourceIndex: idx).encode()) {
                            DragPreviewPill(
                                title: track.title,
                                subtitle: track.artist,
                                artworkHash: track.artworkHash,
                                artworkCache: store.artworkCache,
                                badge: "#\(idx + 1)"
                            )
                        }
                        .dropDestination(for: String.self) { items, _ in
                            store.handlePlaylistReorderDrop(items: items, playlistID: pl.id, targetIndex: idx)
                        }
                    }
                }
                .background(
                    WindowKeyDownMonitor { event in
                        guard store.lightboxAlbum == nil && !showPartySettingsLightbox else { return false }
                        switch event.keyCode {
                        case 51, 117: // Delete or Forward Delete
                            guard let targetIdx = selectedRowIndex ?? focusedRowIndex,
                                  targetIdx >= 0 && targetIdx < tracks.count else {
                                return false
                            }
                            store.removeTrack(at: targetIdx, fromPlaylistID: pl.id)
                            let remaining = tracks.count - 1
                            let nextSel: Int? = remaining > 0 ? min(targetIdx, remaining - 1) : nil
                            selectedRowIndex = nextSel
                            focusedRowIndex = nextSel
                            return true
                        case 125: // Down
                            guard !tracks.isEmpty, let cur = selectedRowIndex ?? focusedRowIndex else { return false }
                            let next = min(tracks.count - 1, cur + 1)
                            selectedRowIndex = next
                            focusedRowIndex = next
                            return true
                        case 126: // Up
                            guard !tracks.isEmpty, let cur = selectedRowIndex ?? focusedRowIndex else { return false }
                            let prev = max(0, cur - 1)
                            selectedRowIndex = prev
                            focusedRowIndex = prev
                            return true
                        case 36, 76: // Return
                            guard let targetIdx = selectedRowIndex ?? focusedRowIndex,
                                  targetIdx >= 0 && targetIdx < tracks.count else {
                                return false
                            }
                            store.playPartyModeTrack(at: targetIdx)
                            return true
                        case 53: // Escape
                            guard selectedRowIndex != nil || focusedRowIndex != nil else { return false }
                            selectedRowIndex = nil
                            focusedRowIndex = nil
                            return true
                        default:
                            return false
                        }
                    }
                )
            }
        }
        .padding(16)
        .background(EchoTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous)
                .strokeBorder(isDropTargeted ? EchoTheme.neoMint : EchoTheme.border, lineWidth: isDropTargeted ? 1.5 : 1)
        )
        .dropDestination(for: String.self) { items, _ in
            let pl = store.ensurePartyPlaylist()
            return store.handleDropOntoPlaylist(items: items, playlistID: pl.id)
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
    }

    // MARK: - Activated Guests Presence Card

    private var activatedGuestsCard: some View {
        let activeCount = store.partyGuests.filter(\.isActive).count
        let totalCount = store.partyGuests.count

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ACTIVATED USERS")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(EchoTheme.neoMint)
                Spacer()
                HStack(spacing: 6) {
                    Text("\(activeCount) ACTIVE")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(EchoTheme.neoMint.opacity(activeCount > 0 ? 0.18 : 0.06))
                        .foregroundStyle(activeCount > 0 ? EchoTheme.neoMint : EchoTheme.textMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                    Text("\(totalCount) TOTAL")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(EchoTheme.textMuted)
                }
            }

            if store.partyGuests.isEmpty {
                Text("Guests who open the Party Mode web link will appear here (active users glow mint, idle users appear muted).")
                    .font(.system(size: 11.5))
                    .foregroundStyle(EchoTheme.textMuted)
                    .padding(.vertical, 4)
            } else {
                LazyVStack(spacing: 5) {
                    ForEach(store.partyGuests) { guest in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(guest.isActive ? EchoTheme.neoMint : EchoTheme.textMuted.opacity(0.45))
                                .frame(width: 7.5, height: 7.5)
                                .shadow(color: guest.isActive ? EchoTheme.neoMint : .clear, radius: 4)

                            Text(guest.name)
                                .font(.system(size: 12, weight: guest.isActive ? .bold : .medium))
                                .foregroundStyle(guest.isActive ? EchoTheme.neoMint : EchoTheme.textSecondary.opacity(0.75))
                                .lineLimit(1)

                            Spacer()

                            if guest.requestCount > 0 {
                                Text("\(guest.requestCount) req")
                                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(guest.isActive ? EchoTheme.neoCyan : EchoTheme.textMuted)
                            }

                            Text(guest.isActive ? "ACTIVE" : "AWAY")
                                .font(.system(size: 8.5, weight: .black, design: .monospaced))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(guest.isActive ? EchoTheme.neoMint.opacity(0.18) : Color.white.opacity(0.05))
                                .foregroundStyle(guest.isActive ? EchoTheme.neoMint : EchoTheme.textMuted)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(guest.isActive ? EchoTheme.neoMint.opacity(0.07) : EchoTheme.surfaceElevated.opacity(0.35))
                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                        .overlay(
                            RoundedRectangle(cornerRadius: EchoTheme.radiusSmall)
                                .strokeBorder(guest.isActive ? EchoTheme.neoMint.opacity(0.40) : EchoTheme.border.opacity(0.55), lineWidth: 1)
                        )
                    }
                }
            }
        }
        .padding(14)
        .background(EchoTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous).strokeBorder(EchoTheme.border, lineWidth: 1))
    }

    // MARK: - Optional Party Chat Card (Host + Guests)

    private var partyChatCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("PARTY CHAT")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(EchoTheme.neoCyan)
                Spacer()
                if !store.partyChatMessages.isEmpty {
                    Button("Clear") {
                        store.clearPartyChat()
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(EchoTheme.textMuted)
                    .buttonStyle(.plain)
                }
            }

            if store.partyChatMessages.isEmpty {
                Text("No chat messages yet. Guests can chat from the Party Mode web page, or send a note below as Host.")
                    .font(.system(size: 11))
                    .foregroundStyle(EchoTheme.textMuted)
                    .padding(.vertical, 4)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(store.partyChatMessages.suffix(40)) { msg in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(msg.senderName)
                                        .font(.system(size: 9.5, weight: .black, design: .monospaced))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1.5)
                                        .background((msg.isHost ? EchoTheme.neoMagenta : EchoTheme.neoCyan).opacity(0.18))
                                        .foregroundStyle(msg.isHost ? EchoTheme.neoMagenta : EchoTheme.neoCyan)
                                        .clipShape(RoundedRectangle(cornerRadius: 3))
                                    Spacer()
                                    Text(Self.hhmmFormatter.string(from: msg.sentAt))
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(EchoTheme.textMuted)
                                }
                                Text(msg.text)
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(EchoTheme.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(EchoTheme.surfaceElevated.opacity(0.45))
                            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                        }
                    }
                }
                .frame(maxHeight: 200)
            }

            HStack(spacing: 6) {
                TextField("Message party as Host...", text: $hostChatDraft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11.5))
                    .foregroundStyle(EchoTheme.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(EchoTheme.surfaceElevated.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                    .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall).strokeBorder(EchoTheme.neoCyan.opacity(0.45), lineWidth: 1))
                    .onSubmit {
                        submitHostChat()
                    }

                Button("Send") {
                    submitHostChat()
                }
                .font(.system(size: 11, weight: .bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(EchoTheme.neoCyan.opacity(0.18))
                .foregroundStyle(EchoTheme.neoCyan)
                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall).strokeBorder(EchoTheme.neoCyan.opacity(0.55), lineWidth: 1))
                .buttonStyle(.plain)
                .disabled(hostChatDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(14)
        .background(EchoTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous).strokeBorder(EchoTheme.border, lineWidth: 1))
    }

    private func submitHostChat() {
        let trimmed = hostChatDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let res = store.sendPartyChatMessage(text: trimmed, isHost: true)
        if res.ok {
            hostChatDraft = ""
        } else if let err = res.message {
            store.showToast(err, isError: true)
        }
    }

    // MARK: - Quick Host Track Search Card (Track-Focused)

    private var quickTrackSearchCard: some View {
        let query = quickSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches: [Track] = {
            let terms = SearchQueryTerms.parse(query)
            guard !terms.isEmpty else { return [] }
            return store.tracks
                .filter { t in
                    guard t.isAvailable else { return false }
                    return terms.matches(track: t)
                }
                .prefix(25)
                .map { $0 }
        }()

        return VStack(alignment: .leading, spacing: 10) {
            Text("HOST QUICK ADD TRACK")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(EchoTheme.neoCyan)

            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11.5))
                    .foregroundStyle(EchoTheme.neoMint)
                TextField("Search track, artist, or album...", text: $quickSearchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(EchoTheme.textPrimary)
                if !quickSearchQuery.isEmpty {
                    Button {
                        quickSearchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(EchoTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(EchoTheme.surfaceElevated.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
            .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusControl).strokeBorder(EchoTheme.neoMint.opacity(0.45), lineWidth: 1))

            if query.isEmpty {
                Text("Type any artist, album, or track title to queue directly into Partymode.")
                    .font(.system(size: 11))
                    .foregroundStyle(EchoTheme.textMuted)
            } else if matches.isEmpty {
                Text("No library tracks matched \"\(query)\".")
                    .font(.system(size: 11.5))
                    .foregroundStyle(EchoTheme.textMuted)
            } else {
                ScrollView {
                    LazyVStack(spacing: 5) {
                        ForEach(matches) { track in
                            HStack(spacing: 8) {
                                ArtworkView(hash: track.artworkHash, artworkCache: store.artworkCache, cornerRadius: 4, iconSize: 10)
                                    .frame(width: 30, height: 30)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(track.title)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(EchoTheme.textPrimary)
                                        .lineLimit(1)
                                    Text("\(track.artist.isEmpty ? track.effectiveArtist : track.artist) · \(track.effectiveAlbum)")
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(EchoTheme.textMuted)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 4)
                                Button {
                                    let resp = store.addTrackToPartyMode(trackID: track.id, guestName: "Host", fromHost: true)
                                    store.showToast(resp.message, isError: !resp.ok)
                                } label: {
                                    Text("+ Add")
                                        .font(.system(size: 10.5, weight: .bold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(EchoTheme.neoMint.opacity(0.18))
                                        .foregroundStyle(EchoTheme.neoMint)
                                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                                        .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall).strokeBorder(EchoTheme.neoMint.opacity(0.55), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(6)
                            .background(EchoTheme.surfaceElevated.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                        }
                    }
                }
                .frame(maxHeight: 260)
            }
        }
        .padding(14)
        .background(EchoTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous).strokeBorder(EchoTheme.border, lineWidth: 1))
    }

    // MARK: - Live Guest Activity Feed

    private var guestActivityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("RECENT REQUESTS")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(EchoTheme.neoMagenta)
                Spacer()
                if !store.partyGuestActivity.isEmpty {
                    Text("\(store.partyGuestActivity.count)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(EchoTheme.textMuted)
                }
            }

            if store.partyGuestActivity.isEmpty {
                Text("Guest track requests will appear here live as friends add songs from the web app.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(EchoTheme.textMuted)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(store.partyGuestActivity.prefix(30)) { item in
                            HStack(alignment: .top, spacing: 8) {
                                Text(item.guestName)
                                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(EchoTheme.neoCyan.opacity(0.15))
                                    .foregroundStyle(EchoTheme.neoCyan)
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                                    .lineLimit(1)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.trackTitle)
                                        .font(.system(size: 11.5, weight: .semibold))
                                        .foregroundStyle(EchoTheme.textPrimary)
                                        .lineLimit(1)
                                    Text(item.artist)
                                        .font(.system(size: 10))
                                        .foregroundStyle(EchoTheme.textMuted)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Text(item.addedAt, style: .time)
                                    .font(.system(size: 9.5, design: .monospaced))
                                    .foregroundStyle(EchoTheme.textMuted)
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }
                .frame(maxHeight: 240)
            }
        }
        .padding(14)
        .background(EchoTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous).strokeBorder(EchoTheme.border, lineWidth: 1))
    }
}

// MARK: - Native CoreImage QR Code Generator

enum PartyQRCodeGenerator {
    static func makeImage(from string: String) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage else { return nil }
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: scaled.extent.width, height: scaled.extent.height))
    }
}

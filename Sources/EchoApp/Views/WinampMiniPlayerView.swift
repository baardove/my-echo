import SwiftUI
import AppKit
import EchoCore

/// Bridges NSWindow properties (floating always-on-top level & flexible vertical resize bounds)
private struct MiniPlayerWindowConfigurator: NSViewRepresentable {
    let alwaysOnTop: Bool
    let isShadeMode: Bool
    let showPlaylistDrawer: Bool

    final class Coordinator {
        var lastLayoutMode: String = ""
        var savedExpandedHeight: CGFloat = 400
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            apply(to: view.window, coordinator: context.coordinator)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            apply(to: nsView.window, coordinator: context.coordinator)
        }
    }

    private func apply(to window: NSWindow?, coordinator: Coordinator) {
        guard let window else { return }
        window.level = alwaysOnTop ? .floating : .normal
        window.isMovableByWindowBackground = true
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none
        window.styleMask.remove(.fullSizeContentView)
        window.standardWindowButton(.closeButton)?.isHidden = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = false
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.backgroundColor = NSColor(red: 0.105, green: 0.120, blue: 0.160, alpha: 1)

        let modeKey = isShadeMode ? "shade" : (showPlaylistDrawer ? "expanded" : "deck")

        // Save user's custom dragged height before leaving expanded playlist mode
        if coordinator.lastLayoutMode == "expanded" && modeKey != "expanded" {
            let currentH = window.contentRect(forFrameRect: window.frame).height
            if currentH >= 290 {
                coordinator.savedExpandedHeight = currentH
            }
        }

        let minH: CGFloat
        let maxH: CGFloat
        let targetH: CGFloat?

        if isShadeMode {
            minH = 62
            maxH = 62
            targetH = 62
        } else if !showPlaylistDrawer {
            minH = 196
            maxH = 196
            targetH = 196
        } else {
            minH = 300
            maxH = 4000
            targetH = (coordinator.lastLayoutMode != "expanded") ? max(300, coordinator.savedExpandedHeight) : nil
        }

        window.contentMinSize = NSSize(width: 396, height: minH)
        window.contentMaxSize = NSSize(width: 480, height: maxH)

        if let targetH, coordinator.lastLayoutMode != modeKey {
            // Keep top edge anchored just like classic Winamp Windowshade / PL toggle
            let currentFrame = window.frame
            let targetFrameSize = window.frameRect(forContentRect: NSRect(x: 0, y: 0, width: currentFrame.width, height: targetH)).size
            var nextFrame = currentFrame
            let deltaH = targetFrameSize.height - currentFrame.height
            nextFrame.origin.y -= deltaH
            nextFrame.size.height = targetFrameSize.height
            window.setFrame(nextFrame, display: true, animate: !coordinator.lastLayoutMode.isEmpty)
        }

        coordinator.lastLayoutMode = modeKey
    }
}

struct WinampMiniPlayerView: View {
    @Environment(EchoStore.self) private var store
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    @State private var alwaysOnTop: Bool = true
    @State private var isShadeMode: Bool = false
    @State private var showPlaylistDrawer: Bool = true
    @State private var showRemainingTime: Bool = false
    @State private var useClassicWinampSkin: Bool = true
    @State private var isScrubbing: Bool = false
    @State private var scrubValue: Double = 0
    @State private var isDropTargeted: Bool = false

    // Classic Winamp 2.x palette (or active Echo theme when skin toggle is switched)
    private var chassisBG: Color {
        useClassicWinampSkin ? Color(red: 0.145, green: 0.165, blue: 0.215) : EchoTheme.sidebar
    }
    private var chassisPanel: Color {
        useClassicWinampSkin ? Color(red: 0.105, green: 0.120, blue: 0.160) : EchoTheme.surface
    }
    private var lcdBG: Color {
        useClassicWinampSkin ? Color(red: 0.025, green: 0.038, blue: 0.025) : Color(red: 0.028, green: 0.032, blue: 0.055)
    }
    private var lcdPrimary: Color {
        useClassicWinampSkin ? Color(red: 0.00, green: 1.00, blue: 0.255) : EchoTheme.neoMint
    }
    private var lcdSecondary: Color {
        useClassicWinampSkin ? Color(red: 1.00, green: 0.82, blue: 0.00) : EchoTheme.neoCyan
    }
    private var lcdPeak: Color {
        useClassicWinampSkin ? Color(red: 1.00, green: 0.28, blue: 0.12) : EchoTheme.neoMagenta
    }
    private var bevelLight: Color { Color.white.opacity(0.22) }
    private var bevelDark: Color { Color.black.opacity(0.65) }

    var body: some View {
        let player = store.player
        let track = player.currentTrack

        VStack(spacing: 0) {
            winampTitleBar(track: track)

            if isShadeMode {
                windowShadeBar(player: player, track: track)
            } else {
                mainDeckBody(player: player, track: track)

                if showPlaylistDrawer {
                    winampPlaylistDrawer(player: player)
                        .frame(maxHeight: .infinity)
                }
            }
        }
        .frame(
            minWidth: 396,
            maxWidth: 480,
            minHeight: isShadeMode ? 62 : (showPlaylistDrawer ? 300 : 196),
            maxHeight: isShadeMode ? 62 : (showPlaylistDrawer ? .infinity : 196),
            alignment: .top
        )
        .background(chassisBG)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(isDropTargeted ? lcdPrimary : bevelLight, lineWidth: isDropTargeted ? 2 : 1)
        )
        .background(MiniPlayerWindowConfigurator(
            alwaysOnTop: alwaysOnTop,
            isShadeMode: isShadeMode,
            showPlaylistDrawer: showPlaylistDrawer
        ))
        .preferredColorScheme(.dark)
        .dropDestination(for: String.self) { items, _ in
            let (dropped, _) = store.resolveTracks(fromDragStrings: items)
            guard !dropped.isEmpty else { return false }
            if store.player.queue.isEmpty {
                store.player.play(tracks: dropped, startingAt: 0)
            } else {
                for t in dropped { store.player.addToQueue(t) }
            }
            store.showToast("Queued \(dropped.count) track\(dropped.count == 1 ? "" : "s") in Mini Player")
            return true
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
    }

    // MARK: - Authentic Winamp 2.x Classic Top Bar (Replaces macOS Titlebar)

    private func winampTitleBar(track: Track?) -> some View {
        HStack(spacing: 6) {
            // Classic Winamp top-left bolt/waveform emblem box
            ZStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.black.opacity(0.45))
                    .frame(width: 18, height: 16)
                    .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(bevelLight, lineWidth: 0.8))
                Image(systemName: "waveform")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(lcdPrimary)
            }

            winampGrillLines
                .frame(width: 28)

            // Classic embossed Winamp center-left wordmark
            Text("MY ECHO")
                .font(.system(size: 10.5, weight: .black, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(Color.white.opacity(0.95))
                .shadow(color: .black.opacity(0.8), radius: 0, x: 0, y: 1)
                .lineLimit(1)
                .fixedSize()

            winampGrillLines
                .frame(maxWidth: .infinity)

            // Skin Toggle (Classic Winamp 99 vs Active Echo Theme)
            titleMicroButton(
                label: useClassicWinampSkin ? "99" : "THM",
                active: useClassicWinampSkin,
                tip: useClassicWinampSkin
                    ? "Classic Winamp 99 phosphor green skin active. Click to match your active My Echo theme."
                    : "Matching active My Echo theme. Click to switch to the classic 1999 Winamp phosphor skin."
            ) {
                useClassicWinampSkin.toggle()
            }

            // Always-on-Top Pin
            titleMicroButton(
                icon: alwaysOnTop ? "pin.fill" : "pin",
                active: alwaysOnTop,
                tip: alwaysOnTop
                    ? "Always-on-Top is ON (floating above other apps). Click to allow normal window stacking."
                    : "Pin the Mini Player to float above all other macOS windows."
            ) {
                alwaysOnTop.toggle()
            }

            // Windowshade Mode Toggle
            titleMicroButton(
                icon: isShadeMode ? "chevron.down" : "minus",
                active: isShadeMode,
                tip: isShadeMode
                    ? "Expand back from Winamp Windowshade strip to the full Mini Player deck."
                    : "Collapse into ultra-compact Winamp Windowshade bar."
            ) {
                withAnimation(.easeInOut(duration: 0.16)) {
                    isShadeMode.toggle()
                }
            }

            // Return / Focus Full My Echo Window
            titleMicroButton(
                icon: "arrow.up.left.and.arrow.down.right",
                active: false,
                tip: "Focus or reopen the full My Echo Studio window."
            ) {
                focusMainWindow()
            }

            // Classic Winamp Top-Right Beveled Close Button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8.5, weight: .black))
                    .foregroundStyle(EchoTheme.dangerCoral)
                    .frame(width: 20, height: 16)
                    .background(
                        LinearGradient(
                            colors: [EchoTheme.dangerCoral.opacity(0.28), Color.black.opacity(0.45)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                    .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(EchoTheme.dangerCoral.opacity(0.65), lineWidth: 0.9))
            }
            .buttonStyle(.plain)
            .help("Close the Mini Player window (music keeps playing in My Echo).")
        }
        .padding(.horizontal, 12)
        .frame(height: 28)
        .background(
            LinearGradient(
                colors: useClassicWinampSkin
                    ? [Color(red: 0.23, green: 0.27, blue: 0.38), Color(red: 0.12, green: 0.15, blue: 0.22), Color(red: 0.08, green: 0.10, blue: 0.15)]
                    : [EchoTheme.surfaceElevated, EchoTheme.sidebar],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(alignment: .top) {
            Rectangle().fill(Color.white.opacity(0.28)).frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(bevelDark).frame(height: 1.5)
        }
    }

    private var winampGrillLines: some View {
        VStack(spacing: 2) {
            Rectangle().fill(lcdSecondary.opacity(0.75)).frame(height: 1)
            Rectangle().fill(Color.black.opacity(0.65)).frame(height: 1)
            Rectangle().fill(lcdSecondary.opacity(0.50)).frame(height: 1)
            Rectangle().fill(Color.white.opacity(0.16)).frame(height: 1)
        }
    }

    private func titleMicroButton(label: String? = nil, icon: String? = nil, active: Bool, tip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 8.5, weight: .bold))
                } else if let label {
                    Text(label)
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                }
            }
            .foregroundStyle(active ? lcdPrimary : Color.white.opacity(0.75))
            .frame(minWidth: 20, minHeight: 16)
            .padding(.horizontal, label != nil ? 4 : 0)
            .background(active ? lcdPrimary.opacity(0.18) : Color.black.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(active ? lcdPrimary.opacity(0.7) : bevelLight, lineWidth: 0.8))
        }
        .buttonStyle(.plain)
        .help(tip)
    }

    // MARK: - Windowshade Ultra-Compact Bar

    private func windowShadeBar(player: AudioPlayerEngine, track: Track?) -> some View {
        HStack(spacing: 8) {
            Text(formattedClock(player: player))
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(lcdPrimary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(lcdBG)
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(bevelDark, lineWidth: 1))
                .onTapGesture { showRemainingTime.toggle() }
                .help("Click to toggle Elapsed vs Remaining time.")

            Text(track.map { "\($0.artist) - \($0.title)" } ?? "DROP TRACKS OR PLAY FROM LIBRARY")
                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                .foregroundStyle(lcdPrimary.opacity(0.92))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(lcdBG)
                .clipShape(RoundedRectangle(cornerRadius: 2))

            HStack(spacing: 3) {
                winampButton("backward.end.fill", tip: "Previous track") { player.previousTrack() }
                winampButton(player.isPlaying ? "pause.fill" : "play.fill", accent: true, tip: player.isPlaying ? "Pause" : "Play") { player.togglePlayPause() }
                winampButton("stop.fill", tip: "Stop") { player.stopPlaybackKeepTrack() }
                winampButton("forward.end.fill", tip: "Next track") { player.nextTrack() }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(chassisPanel)
    }

    // MARK: - Main Winamp Deck Body

    private func mainDeckBody(player: AudioPlayerEngine, track: Track?) -> some View {
        VStack(spacing: 8) {
            // Top LCD Display Area: Time + Spectrum on left, Track Marquee + Bitrate/kHz/Stereo on right
            HStack(spacing: 8) {
                // Left LCD Box: Play glyph, Digital Timer, 16-Band Spectrum Analyzer
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .center, spacing: 6) {
                        Image(systemName: player.isPlaying ? "play.fill" : (track != nil ? "pause.fill" : "stop.fill"))
                            .font(.system(size: 9))
                            .foregroundStyle(player.isPlaying ? lcdPrimary : lcdSecondary)

                        Text(formattedClock(player: player))
                            .font(.system(size: 20, weight: .black, design: .monospaced))
                            .foregroundStyle(lcdPrimary)
                            .shadow(color: lcdPrimary.opacity(0.5), radius: 4)
                            .onTapGesture { showRemainingTime.toggle() }
                            .help("Click LCD clock to toggle Elapsed / Remaining time.")
                    }

                    // 16-band real-time Winamp Spectrum Visualizer with peak-hold dots
                    WinampSpectrumView(
                        bands: player.spectrumBands,
                        peaks: player.peakHolds,
                        lowColor: lcdPrimary,
                        midColor: lcdSecondary,
                        highColor: lcdPeak
                    )
                    .frame(width: 112, height: 32)
                }
                .padding(7)
                .background(lcdBG)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(bevelDark, lineWidth: 1.2))

                // Right LCD Box: Track Ticker, Artwork, KBPS / KHZ / STEREO badges
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 7) {
                        ArtworkView(hash: track?.artworkHash, artworkCache: store.artworkCache, cornerRadius: 3, iconSize: 12)
                            .frame(width: 34, height: 34)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.map { "\(player.currentIndex + 1). \($0.title)" } ?? "MY ECHO READY")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(lcdPrimary)
                                .lineLimit(1)
                            if let track {
                                HStack(spacing: 4) {
                                    ArtistLinksView(
                                        rawArtists: track.artist,
                                        font: .system(size: 9.5, design: .monospaced),
                                        color: lcdPrimary.opacity(0.76),
                                        hoverColor: lcdPrimary,
                                        separatorColor: lcdPrimary.opacity(0.45)
                                    ) { artistName in
                                        focusMainWindow()
                                        store.openArtist(name: artistName)
                                    }
                                    Text("·")
                                        .font(.system(size: 9.5, design: .monospaced))
                                        .foregroundStyle(lcdPrimary.opacity(0.45))
                                    HoverLinkText(
                                        text: track.effectiveAlbum,
                                        font: .system(size: 9.5, design: .monospaced),
                                        color: lcdPrimary.opacity(0.68),
                                        hoverColor: lcdSecondary,
                                        tip: "Open album '\(track.effectiveAlbum)' in My Echo"
                                    ) {
                                        focusMainWindow()
                                        store.openAlbum(forTrack: track)
                                    }
                                }
                            } else {
                                Text("Drop songs or double-click any track")
                                    .font(.system(size: 9.5, design: .monospaced))
                                    .foregroundStyle(lcdPrimary.opacity(0.72))
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(lcdBG)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(bevelDark, lineWidth: 1))

                    // Classic Winamp KBPS / KHZ / STEREO Telemetry Strip
                    HStack(spacing: 6) {
                        lcdBadge(bitrateLabel(track), unit: "KBPS")
                        lcdBadge(sampleRateLabel(track), unit: "KHZ")
                        Spacer()
                        Text(track?.format.displayBadge ?? "IDLE")
                            .font(.system(size: 8.5, weight: .black, design: .monospaced))
                            .foregroundStyle(track?.isHiRes == true ? EchoTheme.hiResGold : lcdSecondary)
                        Text("STEREO")
                            .font(.system(size: 8.5, weight: .black, design: .monospaced))
                            .foregroundStyle(track != nil ? lcdPrimary : Color.white.opacity(0.25))
                    }
                }
            }

            // Recessed Seek Scrubber Bar
            HStack(spacing: 8) {
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
                .tint(lcdPrimary)
                .disabled(track == nil)
                .help("Drag to seek position within the current track.")
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(lcdBG.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(bevelDark, lineWidth: 1))

            // Volume + Quick Focused-Playlist (+), Sync, and PL Drawer Toggle Row
            HStack(spacing: 8) {
                Button {
                    player.isMuted.toggle()
                } label: {
                    Image(systemName: player.isMuted || player.volume <= 0.01 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 10.5))
                        .foregroundStyle(lcdSecondary)
                        .frame(width: 16)
                }
                .buttonStyle(.plain)
                .help(player.isMuted ? "Unmute audio output." : "Mute audio output.")

                Slider(
                    value: Binding(
                        get: { player.isMuted ? 0 : player.volume },
                        set: { val in
                            player.isMuted = false
                            player.volume = val
                        }
                    ),
                    in: 0...1
                )
                .tint(lcdSecondary)
                .frame(width: 112)
                .help("Adjust playback volume.")

                Spacer()

                if let track {
                    let inFocused = store.isTrackInFocusedPlaylist(track)
                    miniPillToggle(
                        title: inFocused ? "✓ PL" : "+ PL",
                        active: inFocused,
                        tip: store.focusedPlaylist.map { "Add or remove '\(track.title)' in focused playlist '\($0.name)'." } ?? "Add track to a new playlist."
                    ) {
                        store.toggleTrackInFocusedPlaylist(track)
                    }

                    let isSynced = store.trackSyncReason(track) != nil
                    miniPillToggle(
                        title: "SYNC",
                        active: isSynced,
                        tip: "Include or exclude '\(track.title)' in the active sync destination."
                    ) {
                        store.toggleTrackSync(track)
                    }
                }

                miniPillToggle(
                    title: "PL",
                    active: showPlaylistDrawer,
                    tip: showPlaylistDrawer ? "Hide the Winamp Play Queue drawer." : "Show the Winamp Play Queue (PL) drawer."
                ) {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        showPlaylistDrawer.toggle()
                    }
                }
            }

            // Classic Winamp 5-Button Beveled Transport Bar + Shuffle + Repeat
            HStack(spacing: 5) {
                winampButton("backward.end.fill", tip: "Previous track (⌘←)") { player.previousTrack() }
                winampButton("play.fill", accent: player.isPlaying, tip: "Play current track") { player.resumeOrPlay() }
                winampButton("pause.fill", accent: !player.isPlaying && track != nil, tip: "Pause playback") { player.pause() }
                winampButton("stop.fill", tip: "Stop playback and reset to 0:00") { player.stopPlaybackKeepTrack() }
                winampButton("forward.end.fill", tip: "Next track (⌘→)") { player.nextTrack() }

                winampButton("eject.fill", tip: "Jump back to the full My Echo library to pick music or playlists") {
                    if let mainWin = NSApp.windows.first(where: { $0.title == "My Echo" }) {
                        mainWin.makeKeyAndOrderFront(nil)
                        NSApp.activate(ignoringOtherApps: true)
                    } else {
                        openWindow(id: "main-studio")
                    }
                }
                .padding(.leading, 4)

                Spacer()

                miniPillToggle(
                    title: "SHUF",
                    active: player.isShuffled,
                    tip: player.isShuffled ? "Shuffle is ON. Click to restore queue order." : "Shuffle playback queue."
                ) {
                    player.isShuffled.toggle()
                }

                miniPillToggle(
                    title: player.repeatMode == .one ? "REP 1" : "REP",
                    active: player.repeatMode != .off,
                    tip: "Cycle repeat mode (Off → Repeat All → Repeat One). Current: \(player.repeatMode.rawValue)."
                ) {
                    player.cycleRepeatMode()
                }
            }
        }
        .padding(10)
        .background(chassisPanel)
    }

    // MARK: - Expandable Classic Winamp PL (Playlist / Queue) Drawer

    private func winampPlaylistDrawer(player: AudioPlayerEngine) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("WINAMP PLAYLIST · \(player.queue.count) TRACKS")
                    .font(.system(size: 8.5, weight: .black, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(lcdSecondary)
                Spacer()
                if !player.queue.isEmpty {
                    let totalDur = player.queue.reduce(0) { $0 + $1.duration }
                    Text(Formatters.duration(totalDur))
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(lcdPrimary.opacity(0.8))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(chassisBG)
            .overlay(alignment: .top) { Rectangle().fill(bevelLight.opacity(0.6)).frame(height: 1) }

            if player.queue.isEmpty {
                VStack(spacing: 4) {
                    Text("PLAYLIST QUEUE EMPTY")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(lcdPrimary.opacity(0.75))
                    Text("Drag songs/albums here or play from Echo")
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(lcdPrimary.opacity(0.45))
                }
                .frame(maxWidth: .infinity, minHeight: 80, maxHeight: .infinity)
                .background(lcdBG)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(Array(player.queue.enumerated()), id: \.offset) { idx, t in
                            let isCurrent = idx == player.currentIndex
                            HStack(spacing: 6) {
                                Text("\(idx + 1). \(t.artist) - \(t.title)")
                                    .font(.system(size: 10.5, weight: isCurrent ? .bold : .regular, design: .monospaced))
                                    .foregroundStyle(isCurrent ? Color.white : lcdPrimary.opacity(0.88))
                                    .lineLimit(1)
                                Spacer(minLength: 6)
                                Text(Formatters.duration(t.duration))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(isCurrent ? Color.white : lcdPrimary.opacity(0.65))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3.5)
                            .background(isCurrent ? Color(red: 0.05, green: 0.25, blue: 0.55) : Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) {
                                player.jumpToQueueIndex(idx)
                            }
                            .contextMenu {
                                Button("Play Track") { player.jumpToQueueIndex(idx) }
                                Button("Remove from Queue") { player.removeFromQueue(at: idx) }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(minHeight: 80, maxHeight: .infinity)
                .background(lcdBG)
            }
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 6)
        .background(chassisBG)
    }

    // MARK: - Helper Subviews & Formatting

    private func lcdBadge(_ value: String, unit: String) -> some View {
        HStack(spacing: 3) {
            Text(value)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(lcdPrimary)
                .padding(.horizontal, 4)
                .padding(.vertical, 1.5)
                .background(lcdBG)
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(bevelDark, lineWidth: 0.8))
            Text(unit)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.6))
        }
    }

    private func winampButton(_ icon: String, accent: Bool = false, tip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(accent ? lcdPrimary : Color.white.opacity(0.88))
                .frame(width: 28, height: 22)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.25, green: 0.28, blue: 0.36), Color(red: 0.14, green: 0.16, blue: 0.22)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(accent ? lcdPrimary.opacity(0.75) : bevelLight, lineWidth: 0.9)
                )
        }
        .buttonStyle(.plain)
        .help(tip)
    }

    private func miniPillToggle(title: String, active: Bool, tip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Circle()
                    .fill(active ? lcdPrimary : Color.white.opacity(0.2))
                    .frame(width: 4.5, height: 4.5)
                Text(title)
                    .font(.system(size: 8.5, weight: .black, design: .monospaced))
                    .foregroundStyle(active ? lcdPrimary : Color.white.opacity(0.72))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(active ? lcdPrimary.opacity(0.14) : Color.black.opacity(0.32))
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(active ? lcdPrimary.opacity(0.65) : bevelLight.opacity(0.6), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
        .help(tip)
    }

    private func focusMainWindow() {
        if let mainWin = NSApp.windows.first(where: { $0.title == "My Echo" }) {
            mainWin.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            openWindow(id: "main-studio")
        }
    }

    private func formattedClock(player: AudioPlayerEngine) -> String {
        if showRemainingTime && player.duration > 0 {
            let rem = max(0, player.duration - player.currentTime)
            return "-\(Formatters.duration(rem))"
        }
        return Formatters.duration(player.currentTime)
    }

    private func bitrateLabel(_ track: Track?) -> String {
        guard let track else { return "---" }
        if let br = track.bitrate, br > 0 { return "\(br)" }
        if track.format.isLossless { return "LOSSLESS" }
        return "320"
    }

    private func sampleRateLabel(_ track: Track?) -> String {
        guard let sr = track?.sampleRate, sr > 0 else { return "44" }
        let khz = Double(sr) / 1000.0
        return khz.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(khz))" : String(format: "%.1f", khz)
    }
}

/// 16-Band Segmented Classic Winamp Spectrum Analyzer with Falling Peak Hold LEDs
private struct WinampSpectrumView: View {
    let bands: [Double]
    let peaks: [Double]
    let lowColor: Color
    let midColor: Color
    let highColor: Color

    var body: some View {
        GeometryReader { geo in
            let count = max(1, bands.count)
            let gap: CGFloat = 2
            let barW = max(2, (geo.size.width - CGFloat(count - 1) * gap) / CGFloat(count))
            let segCount = 10
            let segGap: CGFloat = 1
            let segH = max(1.5, (geo.size.height - CGFloat(segCount - 1) * segGap) / CGFloat(segCount))

            HStack(alignment: .bottom, spacing: gap) {
                ForEach(0..<count, id: \.self) { i in
                    let val = bands[i]
                    let peak = i < peaks.count ? peaks[i] : val
                    let litSegs = Int((val * Double(segCount)).rounded())
                    let peakSeg = Int((peak * Double(segCount)).rounded()) - 1

                    VStack(spacing: segGap) {
                        ForEach((0..<segCount).reversed(), id: \.self) { s in
                            let isLit = s < litSegs
                            let isPeak = s == peakSeg && peak > 0.05
                            let segColor: Color = s >= 8 ? highColor : (s >= 5 ? midColor : lowColor)

                            Rectangle()
                                .fill(isPeak ? Color.white : (isLit ? segColor : Color.white.opacity(0.05)))
                                .frame(width: barW, height: segH)
                        }
                    }
                }
            }
        }
    }
}

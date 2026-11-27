import SwiftUI
import AppKit

/// Extensive Dark-Neon About page for the My Echo ecosystem (macOS app first, mirroring the Web UI About page).
struct AboutView: View {
    @Environment(EchoStore.self) private var store

    private let macRepoURL = URL(string: "https://github.com/baardove/my-echo")!
    private let macReleasesURL = URL(string: "https://github.com/baardove/my-echo/releases")!
    private let serverRepoURL = URL(string: "https://github.com/baardove/my-echo-server")!

    private var appVersionLabel: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        if let short, !short.isEmpty {
            return "v\(short)"
        }
        return "macOS Studio"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                heroCard
                ecosystemFlowCard

                // App Spotlights — macOS App First
                VStack(spacing: 14) {
                    appSpotlightCard(
                        icon: "desktopcomputer",
                        accent: EchoTheme.neoMint,
                        title: "My Echo for macOS",
                        badge: "THIS APP · \(appVersionLabel.uppercased())",
                        role: "Native Swift 6 / SwiftUI Audiophile Player, Library Manager & Multi-Device DAP Sync Studio",
                        repoLabel: "baardove/my-echo",
                        repoURL: macRepoURL,
                        summary: "The flagship desktop studio for audiophiles, portable Digital Audio Player (DAP) owners, and self-hosted collectors. Scales smoothly from a classic offline iTunes-style MP3/SD card sync station all the way up to a NAS-backed multi-device hub paired natively with My Echo Server.",
                        features: [
                            ("Pure-Swift Hi-Fi Metadata Engine", "Zero native third-party dependencies — parses FLAC, MP3, M4A/ALAC, WAV, OGG, APE, DSD (.dsf/.dff), AIFF, OPUS & WMA with bit-depth/sample-rate badges and .lrc synced lyrics."),
                            ("FiiO / Snowsky & DAP Sync Studio", "Preserves strict ARTIST/ALBUM/TRACK folders, optimizes cover art on the fly (sRGB Baseline JPEG + ID3v2.3) without touching originals, exports .m3u/.m3u8, tracks 8,191-file hardware caps, and purges macOS ._* junk on Clean & Eject."),
                            ("Echo Server Delta Sync & Two-Way State", "Pairs natively with My Echo Server to fetch compressed library deltas in milliseconds instead of walking SMB over Wi-Fi, with bidirectional playlists, Spotify imports, and 1–5 star ratings."),
                            ("Built-In Player & Winamp Mini Player", "CoreAudio output device hot-switching, equal-power crossfade, call/mic auto-pause & auto-resume, macOS media keys, plus the floating resizable EchoAmp Mini (⌘⇧M) with live 16-band spectrum analyzer."),
                            ("Multi-Destination & Wi-Fi iOS Sync", "Manage FiiO Echo, Nano, Disc, SD cards, iPhone & iPad side by side — each remembers its own independent selection of artists, albums, tracks, playlists, and podcast feeds."),
                            ("Podcasts, Lidarr & Party Mode Host", "Search Apple Podcasts & gPodder, import RSS/OPML with per-show Keep Latest N rotation, order albums in Lidarr, and host local LAN Party Mode (⌘⇧P) with QR code & voice intros.")
                        ],
                        tags: ["Swift 6 & SwiftUI", "CoreAudio", "FiiO / Snowsky DAP", "Winamp Mini Player", "Bonjour Wi-Fi Sync", "5 Live Themes"]
                    )

                    appSpotlightCard(
                        icon: "server.rack",
                        accent: EchoTheme.neoCyan,
                        title: "My Echo Server",
                        badge: "NAS / DOCKER / UNRAID",
                        role: "Self-Hosted Go + Docker Music Server, Dark-Neon Web Player, AI Radio DJ & Companion Hub",
                        repoLabel: "baardove/my-echo-server",
                        repoURL: serverRepoURL,
                        summary: "A lightweight, single-binary Go + Docker server built for Unraid, NAS boxes, and Linux homelabs. Works completely standalone in any desktop or mobile browser and on LAN DLNA speakers/TVs, while acting as the high-speed always-on indexing and sync backend for My Echo on macOS and Apple TV.",
                        features: [
                            ("Zero-Overhead Local NAS Indexing", "Scans /music directly off local storage into SQLite WAL + 16 gzip-compressed NDJSON shards and incremental delta changelogs so Mac & Apple TV sync in milliseconds."),
                            ("Standalone Dark-Neon Web Player", "Streams lossless FLAC, ALAC, WAV, DSD, MP3, M4A, OGG, OPUS, APE & AIFF with HTTP 206 byte-range seeking, 320k browser fallback, dual-deck crossfade, and 5 live themes."),
                            ("AI Radio DJ (Google Gemini)", "Curates personalized radio shows from your own library with fact-grounded banter, Gemini TTS voices, multi-language personas, drag-and-drop live rundown, and BPM/loudness (-14 dBFS) normalization."),
                            ("24/7 Party Mode Jukebox", "Zero-install guest web app (:53333) with QR code, live play schedule, party chat, listen-along streaming, and HTTPS mobile DJ voice intros (:53334) with broadcast EQ & ducking."),
                            ("Spotify Import & Lidarr Auto-Order", "Import public Spotify playlists, retain missing tracks in place, order missing albums automatically through Lidarr, and resolve them automatically when Lidarr webhooks fire."),
                            ("DLNA Casting & Remote Access", "Native UPnP/DLNA MediaServer + one-click casting to Sonos, Denon/HEOS, WiiM, AVRs & smart TVs (0% idle CPU), plus Cloudflare Tunnel & UPnP/NAT-PMP behind multi-user & PIN auth.")
                        ],
                        tags: ["Go 1.24", "Docker & Unraid", "SQLite WAL + Gzip Shards", "Gemini AI DJ + TTS", "DLNA / UPnP", "Cloudflare Tunnel", "Lidarr & Spotify"]
                    )

                    appSpotlightCard(
                        icon: "iphone",
                        accent: EchoTheme.neoMagenta,
                        title: "My Echo for iPhone & iPad",
                        badge: "UNIVERSAL IOS / IPADOS",
                        role: "Native Offline Hi-Fi Player, Wireless Mac Sync Companion & Navidrome On-the-Go Client",
                        repoLabel: "baardove/my-echo (iOS/)",
                        repoURL: macRepoURL,
                        summary: "A Universal SwiftUI companion app for iPhone and iPad built for flights, commutes, and lossless listening anywhere. Pair once with My Echo on Mac over Wi-Fi for automatic offline sync, or connect to your NAS over Home LAN / Tailscale to stream and save tracks on the move.",
                        features: [
                            ("Zero-Cable Bonjour Wi-Fi Sync", "Pairs automatically with My Echo on Mac using a 6-digit PIN to sync your chosen lossless FLAC, ALAC & MP3 tracks, playlists, and podcast episodes straight to local device storage."),
                            ("True Offline Hi-Fi Playback", "Full-featured mobile player with scrubbable timeline, elapsed/remaining clocks, equal-power crossfade, lock-screen & Control Center controls, call interruption handling, and editorial album lightbox."),
                            ("Navidrome Streaming & Save Offline", "Connect to your NAS Navidrome server with 1-tap Home LAN ↔ Tailscale URL switching to browse artists, albums & playlists, stream audio, and save favorites offline."),
                            ("Remote Library Picks & Lidarr Orders", "Search your entire Mac library from your phone to toggle single tracks or full albums into your sync queue, or order missing albums into NAS Lidarr relayed securely through Mac."),
                            ("Independent Podcasts with Two-Way Sync", "Flip the Podcasts Offline / Online switch to search Apple Podcasts & gPodder on the go, refresh RSS feeds without duplicating Mac-synced episodes, and sync new shows back to Mac.")
                        ],
                        tags: ["iOS & iPadOS", "Offline FLAC / ALAC", "Bonjour Wi-Fi Auto-Sync", "Navidrome + Tailscale", "Remote Lidarr"]
                    )

                    appSpotlightCard(
                        icon: "appletv.fill",
                        accent: EchoTheme.warningAmber,
                        title: "My Echo for Apple TV (MyEchoTV)",
                        badge: "TVOS LIVING ROOM",
                        role: "Native 10-Foot Living-Room Hi-Fi Player, Server Streamer & Big-Screen Party Mode Display",
                        repoLabel: "baardove/my-echo (tvOS/)",
                        repoURL: macRepoURL,
                        summary: "Brings your entire self-hosted music library and Party Mode onto the big screen with a native SwiftUI tvOS interface designed for the Siri Remote and living-room sound systems.",
                        features: [
                            ("Direct My Echo Server Streaming", "Pair directly with My Echo Server on Unraid/Docker to browse and stream your full lossless library, artwork, editorial liner notes, and playlists 24/7 — even when your Mac is asleep or powered off."),
                            ("Mac Catalog & Remote Control", "Also pairs over LAN with My Echo on Mac using a dedicated 6-digit Apple TV PIN to stream from Mac or remotely control Mac playback (play/pause, skip, seek, and volume)."),
                            ("Big-Screen Party Mode Dashboard", "Turns your TV into the centerpiece of the party with bold Now Playing cover art, live upcoming queue & play schedule, guest activity, and a scannable QR code for song requests & DJ voice intros."),
                            ("Navidrome & Podcasts on TV", "Switch cleanly between My Echo Server, Mac, and Navidrome libraries, and listen to your subscribed podcast feeds right from the couch.")
                        ],
                        tags: ["tvOS / SwiftUI", "Direct Echo Server", "Big-Screen Party Mode", "Mac Remote Control", "Navidrome & Podcasts"]
                    )
                }

                footerLinksCard
            }
            .padding(24)
            .frame(maxWidth: 1240, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(EchoTheme.canvas)
    }

    // MARK: - Hero Banner

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 18) {
                EchoBrandLogo(size: 52, animate: store.player.isPlaying)
                    .padding(10)
                    .background(EchoTheme.surfaceElevated.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous)
                            .strokeBorder(EchoTheme.neoMint.opacity(0.45), lineWidth: 1)
                    )
                    .shadow(color: EchoTheme.neoMint.opacity(0.18), radius: 10, y: 2)

                VStack(alignment: .leading, spacing: 5) {
                    Text("OPEN-SOURCE SELF-HOSTED HI-FI MUSIC ECOSYSTEM")
                        .font(.system(size: 10.5, weight: .black, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(EchoTheme.neoCyan)

                    HStack(spacing: 6) {
                        Text("MY ECHO")
                            .foregroundStyle(EchoTheme.textPrimary)
                        Text("STUDIO")
                            .foregroundStyle(EchoTheme.neoMint)
                        Text("& ECOSYSTEM")
                            .foregroundStyle(EchoTheme.textPrimary)
                    }
                    .font(.system(size: 26, weight: .black, design: .rounded))

                    Text("My Echo is a self-hosted Hi-Fi music, podcast, AI Radio DJ, Party Jukebox, and portable DAP sync ecosystem spanning your macOS studio, NAS / Unraid server, iPhone & iPad, and Apple TV. Own your lossless library with zero subscriptions — start with any single app or pair all four together seamlessly.")
                        .font(.system(size: 13.5))
                        .foregroundStyle(EchoTheme.textSecondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Two GitHub Repository Cards (macOS / Apple Apps Repo first)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 340), spacing: 12)], spacing: 12) {
                repoCard(
                    title: "github.com/baardove/my-echo",
                    subtitle: "Native Swift 6 / SwiftUI apps · macOS Studio & FiiO/DAP Sync · Universal iPhone & iPad Player · Apple TV (MyEchoTV)",
                    badge: "APPLE APPS REPO ↗",
                    accent: EchoTheme.neoMint,
                    url: macRepoURL
                )

                repoCard(
                    title: "github.com/baardove/my-echo-server",
                    subtitle: "Go + Docker / Unraid companion server · Dark-Neon Web App · AI Radio DJ · Party Mode · DLNA Casting · Delta Index",
                    badge: "SERVER REPO ↗",
                    accent: EchoTheme.neoCyan,
                    url: serverRepoURL
                )
            }
        }
        .padding(22)
        .background(
            ZStack {
                EchoTheme.surface
                LinearGradient(
                    colors: [EchoTheme.neoMint.opacity(0.11), EchoTheme.neoCyan.opacity(0.07), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous)
                .strokeBorder(EchoTheme.borderStrong, lineWidth: 1)
        )
    }

    private func repoCard(title: String, subtitle: String, badge: String, accent: Color, url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundStyle(accent)
                        Text(title)
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundStyle(accent)
                            .lineLimit(1)
                    }
                    Text(subtitle)
                        .font(.system(size: 11.8))
                        .foregroundStyle(EchoTheme.textSecondary)
                        .lineSpacing(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Text(badge)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: EchoTheme.radiusSmall, style: .continuous)
                            .strokeBorder(accent.opacity(0.45), lineWidth: 1)
                    )
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(EchoTheme.surfaceElevated.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous)
                    .strokeBorder(accent.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Ecosystem Flow Strip

    private var ecosystemFlowCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HOW THE MY ECHO ECOSYSTEM WORKS TOGETHER")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .tracking(1.1)
                .foregroundStyle(EchoTheme.neoCyan)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], spacing: 10) {
                flowNode(
                    step: "01 · DESKTOP STUDIO",
                    title: "My Echo for macOS",
                    detail: "Indexes local/NAS folders or syncs deltas from Server in ms, manages playlists, podcasts & Lidarr, and syncs USB/SD DAPs & Wi-Fi iOS devices.",
                    accent: EchoTheme.neoMint
                )
                flowNode(
                    step: "02 · ALWAYS-ON CORE",
                    title: "My Echo Server",
                    detail: "Runs 24/7 on Unraid/Docker, builds gzip delta shards, streams to browsers & DLNA speakers, and hosts Gemini AI Radio DJ & Party Mode.",
                    accent: EchoTheme.neoCyan
                )
                flowNode(
                    step: "03 · MOBILE & OFFLINE",
                    title: "My Echo for iPhone & iPad",
                    detail: "Pulls lossless music, playlists & podcasts over Wi-Fi for offline Hi-Fi playback, streams via Navidrome/Tailscale, and queues picks on the go.",
                    accent: EchoTheme.neoMagenta
                )
                flowNode(
                    step: "04 · LIVING ROOM",
                    title: "My Echo for Apple TV",
                    detail: "Streams lossless audio & artwork directly from My Echo Server (or Mac) with a 10-foot UI and big-screen Party Mode QR dashboard.",
                    accent: EchoTheme.warningAmber
                )
            }
        }
        .padding(18)
        .background(EchoTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous)
                .strokeBorder(EchoTheme.border, lineWidth: 1)
        )
    }

    private func flowNode(step: String, title: String, detail: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(step)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(accent)
            Text(title)
                .font(.system(size: 13.5, weight: .bold))
                .foregroundStyle(EchoTheme.textPrimary)
            Text(detail)
                .font(.system(size: 11.8))
                .foregroundStyle(EchoTheme.textSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(EchoTheme.surfaceElevated.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous)
                .strokeBorder(EchoTheme.border, lineWidth: 1)
        )
    }

    // MARK: - App Spotlight Card

    private func appSpotlightCard(
        icon: String,
        accent: Color,
        title: String,
        badge: String,
        role: String,
        repoLabel: String,
        repoURL: URL,
        summary: String,
        features: [(String, String)],
        tags: [String]
    ) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(accent)
                .frame(width: 3.5)

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accent)
                        .frame(width: 42, height: 42)
                        .background(EchoTheme.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous)
                                .strokeBorder(accent.opacity(0.45), lineWidth: 1)
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(title)
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundStyle(EchoTheme.textPrimary)
                            Text(badge)
                                .font(.system(size: 9.5, weight: .black, design: .monospaced))
                                .foregroundStyle(accent)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(accent.opacity(0.14))
                                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: EchoTheme.radiusSmall, style: .continuous)
                                        .strokeBorder(accent.opacity(0.42), lineWidth: 1)
                                )
                        }
                        Text(role)
                            .font(.system(size: 12))
                            .foregroundStyle(EchoTheme.textSecondary)
                    }

                    Spacer(minLength: 10)

                    Link(destination: repoURL) {
                        HStack(spacing: 5) {
                            Text(repoLabel)
                            Text("↗")
                        }
                        .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(EchoTheme.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(EchoTheme.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous)
                                .strokeBorder(accent.opacity(0.40), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }

                Text(summary)
                    .font(.system(size: 13))
                    .foregroundStyle(EchoTheme.textPrimary.opacity(0.92))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 10)], spacing: 10) {
                    ForEach(Array(features.enumerated()), id: \.offset) { _, feat in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(feat.0)
                                .font(.system(size: 12.2, weight: .bold))
                                .foregroundStyle(EchoTheme.textPrimary)
                            Text(feat.1)
                                .font(.system(size: 11.8))
                                .foregroundStyle(EchoTheme.textSecondary)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(11)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .background(Color.black.opacity(0.24))
                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous)
                                .strokeBorder(EchoTheme.border, lineWidth: 1)
                        )
                    }
                }

                FlowTagsView(tags: tags)
            }
            .padding(18)
        }
        .background(EchoTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous)
                .strokeBorder(EchoTheme.borderStrong, lineWidth: 1)
        )
    }

    // MARK: - Open Source Footer Card

    private var footerLinksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("OPEN SOURCE & QUICK LINKS")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .tracking(1.1)
                .foregroundStyle(EchoTheme.neoMint)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("MY ECHO (MAC / IOS / TVOS)")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(EchoTheme.neoMint)
                    Text("Prebuilt macOS Apple Silicon releases, HOW-TO-INSTALL.md sideloading guide, and full Swift 6 source for macOS, iPhone/iPad, and Apple TV.")
                        .font(.system(size: 11.8))
                        .foregroundStyle(EchoTheme.textSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        smallLinkPill("Open Apple Apps Repo ↗", accent: EchoTheme.neoMint, url: macRepoURL)
                        smallLinkPill("Releases ↗", accent: EchoTheme.neoCyan, url: macReleasesURL)
                    }
                }
                .padding(13)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(EchoTheme.surfaceElevated.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous)
                        .strokeBorder(EchoTheme.border, lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("MY ECHO SERVER")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(EchoTheme.neoCyan)
                    Text("Docker image ghcr.io/baardove/my-echo-server:latest · Unraid XML template · Ports :48721 (Web/API/DLNA), :53333 (Party HTTP), :53334 (Voice Intro HTTPS).")
                        .font(.system(size: 11.8))
                        .foregroundStyle(EchoTheme.textSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                    smallLinkPill("Open Server Repository ↗", accent: EchoTheme.neoCyan, url: serverRepoURL)
                }
                .padding(13)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(EchoTheme.surfaceElevated.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous)
                        .strokeBorder(EchoTheme.border, lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("LICENSE & PHILOSOPHY")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(EchoTheme.warningAmber)
                    Text("Released under the MIT License. Built for people who love owning their music files, lossless formats, real hardware players, and local-first software with zero cloud lock-in.")
                        .font(.system(size: 11.8))
                        .foregroundStyle(EchoTheme.textSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(13)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(EchoTheme.surfaceElevated.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous)
                        .strokeBorder(EchoTheme.border, lineWidth: 1)
                )
            }
        }
        .padding(18)
        .background(EchoTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: EchoTheme.radiusCard, style: .continuous)
                .strokeBorder(EchoTheme.border, lineWidth: 1)
        )
    }

    private func smallLinkPill(_ label: String, accent: Color, url: URL) -> some View {
        Link(destination: url) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(EchoTheme.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(EchoTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: EchoTheme.radiusSmall, style: .continuous)
                        .strokeBorder(accent.opacity(0.42), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

/// Simple wrapping tag strip for AboutView tech-stack badges.
private struct FlowTagsView: View {
    let tags: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), alignment: .leading)], alignment: .leading, spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(EchoTheme.textSecondary)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(EchoTheme.surfaceElevated.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: EchoTheme.radiusSmall, style: .continuous)
                            .strokeBorder(EchoTheme.border, lineWidth: 1)
                    )
            }
        }
    }
}

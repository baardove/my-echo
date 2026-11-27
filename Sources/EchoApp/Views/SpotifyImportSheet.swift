import SwiftUI
import AppKit
import EchoCore

struct SpotifyImportSheet: View {
    @Environment(EchoStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var urlInput: String = ""
    @State private var isFetching: Bool = false
    @State private var errorMessage: String? = nil
    @State private var report: SpotifyPlaylistMatchReport? = nil
    @State private var playlistNameDraft: String = ""
    @State private var autoSearchLidarr: Bool = false
    @State private var previewFilter: PreviewFilter = .all

    private enum PreviewFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case matched = "Matched"
        case missing = "Missing"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: EchoTheme.radiusCard)
                        .fill(EchoTheme.neoMint.opacity(0.16))
                        .frame(width: 40, height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: EchoTheme.radiusCard)
                                .strokeBorder(EchoTheme.neoMint.opacity(0.45), lineWidth: 1)
                        )
                    Image(systemName: "waveform.badge.plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(EchoTheme.neoMint)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("SPOTIFY PLAYLIST IMPORTER")
                        .font(.system(size: 9.5, weight: .black, design: .monospaced))
                        .tracking(1.3)
                        .foregroundStyle(EchoTheme.neoMint)
                    Text("Import Public Spotify Playlist")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(EchoTheme.textPrimary)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11.5, weight: .bold))
                        .frame(width: 26, height: 26)
                        .background(EchoTheme.surfaceElevated)
                        .foregroundStyle(EchoTheme.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                }
                .buttonStyle(.plain)
            }

            // URL Input Row
            VStack(alignment: .leading, spacing: 6) {
                Text("Spotify Playlist Link or URI (no API key required)")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(EchoTheme.textSecondary)

                HStack(spacing: 8) {
                    HStack(spacing: 7) {
                        Image(systemName: "link")
                            .font(.system(size: 11.5))
                            .foregroundStyle(EchoTheme.neoMint)
                        TextField("https://open.spotify.com/playlist/...", text: $urlInput)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12.5, design: .monospaced))
                            .foregroundStyle(EchoTheme.textPrimary)
                            .onSubmit { fetchPlaylist() }
                        if !urlInput.isEmpty {
                            Button {
                                urlInput = ""
                                report = nil
                                errorMessage = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(EchoTheme.textMuted)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7.5)
                    .background(EchoTheme.canvas)
                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                    .overlay(
                        RoundedRectangle(cornerRadius: EchoTheme.radiusControl)
                            .strokeBorder(EchoTheme.borderStrong, lineWidth: 1)
                    )

                    Button {
                        if let clip = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
                           !clip.isEmpty {
                            urlInput = clip
                            if SpotifyPlaylistImporter.parsePlaylistID(from: clip) != nil || SpotifyPlaylistImporter.isShortSpotifyLink(clip) {
                                fetchPlaylist()
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.clipboard")
                            Text("Paste")
                        }
                        .font(.system(size: 11.5, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7.5)
                        .background(EchoTheme.surfaceElevated)
                        .foregroundStyle(EchoTheme.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                        .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusControl).strokeBorder(EchoTheme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .help("Paste a Spotify playlist URL from the clipboard.")

                    NeoPrimaryButton(
                        title: isFetching ? "Loading..." : "Fetch",
                        icon: "arrow.down.circle.fill",
                        disabled: isFetching || urlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ) {
                        fetchPlaylist()
                    }
                }
            }

            if let err = errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(EchoTheme.warningAmber)
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundStyle(EchoTheme.textSecondary)
                    Spacer()
                }
                .padding(10)
                .background(EchoTheme.warningAmber.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusControl).strokeBorder(EchoTheme.warningAmber.opacity(0.4), lineWidth: 1))
            }

            if isFetching {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Fetching Spotify playlist & matching against your \(store.tracks.count) local tracks...")
                        .font(.system(size: 12.5))
                        .foregroundStyle(EchoTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 240)
                .background(EchoTheme.canvas.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard))
                .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusCard).strokeBorder(EchoTheme.border, lineWidth: 1))
            } else if let report {
                previewSection(report)
            } else {
                // Empty state guidance
                VStack(spacing: 10) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 32))
                        .foregroundStyle(EchoTheme.textMuted)
                    Text("Match Spotify Tracks to Your Local Library")
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundStyle(EchoTheme.textPrimary)
                    Text("Paste any public Spotify playlist URL (e.g. open.spotify.com/playlist/...). Matched tracks are added immediately; missing tracks are retained in order as muted/skipped placeholders and can be searched in Lidarr automatically.")
                        .font(.system(size: 12))
                        .foregroundStyle(EchoTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 460)
                }
                .frame(maxWidth: .infinity, minHeight: 220)
                .padding(24)
                .background(EchoTheme.canvas.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard))
                .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusCard).strokeBorder(EchoTheme.border, lineWidth: 1))
            }

            // Footer Actions
            HStack(spacing: 10) {
                if let report, report.missingCount > 0 {
                    if store.lidarrConfig.isConfigured {
                        Toggle(isOn: $autoSearchLidarr) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.down.to.line.compact")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(EchoTheme.neoMint)
                                Text("Auto-search \(report.missingCount) missing track\(report.missingCount == 1 ? "" : "s") in Lidarr")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(EchoTheme.textPrimary)
                            }
                        }
                        .toggleStyle(.checkbox)
                        .help("Automatically resolve parent albums and order missing tracks in Lidarr right after importing.")
                    } else {
                        Button {
                            dismiss()
                            store.navigate(to: .settings)
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "gearshape")
                                Text("Configure Lidarr in Settings to auto-search missing tracks")
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(EchoTheme.neoCyan)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                if let report {
                    NeoPrimaryButton(
                        title: autoSearchLidarr && report.missingCount > 0
                            ? "Import & Search Lidarr"
                            : "Import Playlist",
                        icon: autoSearchLidarr && report.missingCount > 0
                            ? "arrow.down.to.line.compact"
                            : "checkmark"
                    ) {
                        store.importSpotifyPlaylist(
                            report: report,
                            customName: playlistNameDraft,
                            autoSearchLidarr: autoSearchLidarr && store.lidarrConfig.isConfigured
                        )
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(22)
        .frame(width: 620)
        .background(EchoTheme.surface)
        .onAppear {
            autoSearchLidarr = store.lidarrConfig.isEnabled && store.lidarrConfig.isConfigured
            // Pre-fill if clipboard already contains a Spotify playlist URL
            if urlInput.isEmpty,
               let clip = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
               (SpotifyPlaylistImporter.parsePlaylistID(from: clip) != nil || SpotifyPlaylistImporter.isShortSpotifyLink(clip)),
               clip.lowercased().contains("spotify") {
                urlInput = clip
                fetchPlaylist()
            }
        }
    }

    @ViewBuilder
    private func previewSection(_ report: SpotifyPlaylistMatchReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Playlist Metadata Card
            HStack(spacing: 14) {
                Group {
                    if let cover = report.payload.coverURL, let url = URL(string: cover) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable().aspectRatio(contentMode: .fill)
                            default:
                                placeholderCover
                            }
                        }
                    } else {
                        placeholderCover
                    }
                }
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusControl).strokeBorder(EchoTheme.borderStrong, lineWidth: 1))

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        TextField("Playlist Name", text: $playlistNameDraft)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(EchoTheme.textPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(EchoTheme.canvas)
                            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                            .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall).strokeBorder(EchoTheme.border, lineWidth: 1))
                    }

                    HStack(spacing: 8) {
                        if let owner = report.payload.ownerName, !owner.isEmpty {
                            Text("by \(owner)")
                                .font(.system(size: 11.5))
                                .foregroundStyle(EchoTheme.textSecondary)
                        }
                        summaryPill("\(report.matchedCount) MATCHED", color: EchoTheme.neoMint)
                        if report.missingCount > 0 {
                            summaryPill("\(report.missingCount) MISSING (MUTED)", color: EchoTheme.warningAmber)
                        }
                    }
                }
            }
            .padding(12)
            .background(EchoTheme.canvas.opacity(0.75))
            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard))
            .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusCard).strokeBorder(EchoTheme.border, lineWidth: 1))

            if report.payload.hitPublicEmbedCap {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(EchoTheme.neoCyan)
                    Text("Spotify's public playlist preview returns up to the first 100 tracks without OAuth.")
                        .font(.system(size: 11))
                        .foregroundStyle(EchoTheme.textSecondary)
                }
            }

            // Filter Pills
            HStack(spacing: 6) {
                ForEach(PreviewFilter.allCases) { f in
                    let active = previewFilter == f
                    let count: Int = {
                        switch f {
                        case .all: return report.totalCount
                        case .matched: return report.matchedCount
                        case .missing: return report.missingCount
                        }
                    }()
                    Button {
                        previewFilter = f
                    } label: {
                        Text("\(f.rawValue) (\(count))")
                            .font(.system(size: 10.5, weight: .bold))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(active ? EchoTheme.neoCyan.opacity(0.22) : EchoTheme.surfaceElevated)
                            .foregroundStyle(active ? EchoTheme.neoCyan : EchoTheme.textSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                            .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall).strokeBorder(active ? EchoTheme.neoCyan.opacity(0.55) : EchoTheme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Text("Missing tracks are kept in order, muted & skipped on play/sync")
                    .font(.system(size: 10.5))
                    .foregroundStyle(EchoTheme.textMuted)
            }

            // Track Preview List
            let indexedEntries = Array(report.entries.enumerated()).filter { _, entry in
                switch previewFilter {
                case .all: return true
                case .matched: return !entry.isMissing
                case .missing: return entry.isMissing
                }
            }

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(indexedEntries, id: \.offset) { origIdx, entry in
                        HStack(spacing: 10) {
                            Text("\(origIdx + 1)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(entry.isMissing ? EchoTheme.textMuted.opacity(0.45) : EchoTheme.textMuted)
                                .frame(width: 24, alignment: .trailing)

                            switch entry {
                            case .matched(_, let local, _):
                                ArtworkView(hash: local.artworkHash, artworkCache: store.artworkCache, cornerRadius: 4, iconSize: 11)
                                    .frame(width: 28, height: 28)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(local.title)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(EchoTheme.textPrimary)
                                        .lineLimit(1)
                                    Text(local.artist)
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(EchoTheme.textSecondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Text(local.formatPrimaryLabel)
                                    .font(.system(size: 8.5, weight: .black, design: .monospaced))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1.5)
                                    .background(EchoTheme.neoMint.opacity(0.16))
                                    .foregroundStyle(EchoTheme.neoMint)
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(EchoTheme.neoMint)

                            case .missing(let sp):
                                ZStack {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(EchoTheme.surfaceElevated.opacity(0.4))
                                    Image(systemName: "music.note")
                                        .font(.system(size: 10))
                                        .foregroundStyle(EchoTheme.textMuted.opacity(0.45))
                                }
                                .frame(width: 28, height: 28)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(sp.title)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(EchoTheme.textMuted.opacity(0.65))
                                        .lineLimit(1)
                                    Text(sp.artist)
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(EchoTheme.textMuted.opacity(0.48))
                                        .lineLimit(1)
                                }
                                Spacer()
                                Text("MISSING")
                                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1.5)
                                    .background(Color.white.opacity(0.05))
                                    .foregroundStyle(EchoTheme.textMuted.opacity(0.65))
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(entry.isMissing ? Color.clear : EchoTheme.surfaceElevated.opacity(0.32))
                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                    }
                }
                .padding(6)
            }
            .frame(height: 245)
            .background(EchoTheme.canvas.opacity(0.75))
            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard))
            .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusCard).strokeBorder(EchoTheme.border, lineWidth: 1))
        }
    }

    private var placeholderCover: some View {
        ZStack {
            EchoTheme.surfaceElevated
            Image(systemName: "music.note.list")
                .font(.system(size: 22))
                .foregroundStyle(EchoTheme.neoMint)
        }
    }

    private func summaryPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .black, design: .monospaced))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.16))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    private func fetchPlaylist() {
        let trimmed = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isFetching else { return }
        isFetching = true
        errorMessage = nil
        report = nil
        previewFilter = .all

        let librarySnapshot = store.tracks
        Task {
            do {
                let payload = try await store.spotifyImporter.fetchPlaylist(from: trimmed)
                let matched = SpotifyPlaylistImporter.matchTracks(payload.tracks, against: librarySnapshot)
                let builtReport = SpotifyPlaylistMatchReport(payload: payload, entries: matched)
                await MainActor.run {
                    self.report = builtReport
                    self.playlistNameDraft = payload.name
                    self.isFetching = false
                }
            } catch {
                await MainActor.run {
                    self.isFetching = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

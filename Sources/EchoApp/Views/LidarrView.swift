import SwiftUI
import EchoCore

enum LidarrTab: String, CaseIterable, Identifiable {
    case search = "Search & Order"
    case queue = "Queue"
    case wanted = "Wanted / Missing"
    var id: String { rawValue }
}

enum LidarrQueueFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case downloading = "Downloading"
    case queued = "Queued"
    case importing = "Importing"
    case warnings = "Warnings"
    case completed = "Completed"
    var id: String { rawValue }
}

struct LidarrView: View {
    @Environment(EchoStore.self) private var store
    @State private var selectedTab: LidarrTab = .search
    @State private var queueFilter: LidarrQueueFilter = .all

    var body: some View {
        @Bindable var bindableStore = store

        VStack(alignment: .leading, spacing: 0) {
            // Header Banner
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: EchoTheme.radiusCard)
                        .fill(EchoTheme.neoMint.opacity(0.14))
                        .frame(width: 44, height: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: EchoTheme.radiusCard)
                                .strokeBorder(EchoTheme.neoMint.opacity(0.45), lineWidth: 1)
                        )
                    Image(systemName: "arrow.down.to.line.compact")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(EchoTheme.neoMint)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text("Lidarr Downloads")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(EchoTheme.textPrimary)

                        if let status = store.lidarrStatus {
                            Text("CONNECTED · v\(status.version)")
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2.5)
                                .background(EchoTheme.neoMint.opacity(0.18))
                                .foregroundStyle(EchoTheme.neoMint)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        } else if store.isTestingLidarrConnection {
                            HStack(spacing: 4) {
                                ProgressView().controlSize(.mini)
                                Text("CONNECTING")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(EchoTheme.neoCyan)
                            }
                        } else {
                            Text(store.lidarrConfig.isConfigured ? "DISCONNECTED" : "NOT CONFIGURED")
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2.5)
                                .background(EchoTheme.warningAmber.opacity(0.18))
                                .foregroundStyle(EchoTheme.warningAmber)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }

                    HStack(spacing: 10) {
                        if !store.lidarrConfig.baseURL.isEmpty {
                            Text(store.lidarrConfig.baseURL)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(EchoTheme.textMuted)
                        }
                        if !store.lidarrConfig.rootFolderPath.isEmpty {
                            Text("· Root: \(store.lidarrConfig.rootFolderPath)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(EchoTheme.textSecondary)
                                .lineLimit(1)
                        }
                        if let qID = store.lidarrConfig.qualityProfileId,
                           let qp = store.lidarrQualityProfiles.first(where: { $0.id == qID }) {
                            Text("· Quality: \(qp.name)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(EchoTheme.neoCyan)
                        }
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        store.refreshLidarrQueueAndWanted()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 30, height: 30)
                            .background(EchoTheme.surfaceElevated)
                            .foregroundStyle(EchoTheme.textPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                            .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusControl).strokeBorder(EchoTheme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(store.isLoadingLidarrQueue || !store.lidarrConfig.isConfigured)
                    .help("Refresh Lidarr download queue and wanted albums list.")

                    Button {
                        store.indexAllSources()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 11, weight: .bold))
                            Text("Re-Index Library")
                                .font(.system(size: 11.5, weight: .semibold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6.5)
                        .background(EchoTheme.surfaceElevated)
                        .foregroundStyle(EchoTheme.neoCyan)
                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                        .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusControl).strokeBorder(EchoTheme.borderStrong, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(store.isIndexing || store.sources.isEmpty)
                    .help("Re-scan your local/NAS library folders so newly completed Lidarr downloads appear in New Arrivals.")

                    Button {
                        store.navigate(to: .settings)
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 12.5, weight: .semibold))
                            .frame(width: 30, height: 30)
                            .background(EchoTheme.surfaceElevated)
                            .foregroundStyle(EchoTheme.textSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                            .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusControl).strokeBorder(EchoTheme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .help("Configure Lidarr Server URL, API Key, Root Folder, and Quality Profile in Settings.")
                }
            }
            .padding(.horizontal, 26)
            .padding(.top, 22)
            .padding(.bottom, 14)

            // Tab Strip
            HStack(spacing: 8) {
                ForEach(LidarrTab.allCases) { tab in
                    let active = selectedTab == tab
                    let badgeCount: Int? = {
                        switch tab {
                        case .queue: return store.lidarrQueue.isEmpty ? nil : store.lidarrQueue.count
                        case .wanted: return store.lidarrWantedMissing.isEmpty ? nil : store.lidarrWantedMissing.count
                        case .search: return nil
                        }
                    }()
                    Button {
                        selectedTab = tab
                        if tab == .queue || tab == .wanted {
                            store.refreshLidarrQueueAndWanted(silent: true)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(tab.rawValue)
                                .font(.system(size: 12, weight: .bold))
                            if let badgeCount {
                                Text("\(badgeCount)")
                                    .font(.system(size: 10, weight: .black, design: .monospaced))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(active ? Color.black.opacity(0.22) : EchoTheme.neoMint.opacity(0.2))
                                    .foregroundStyle(active ? Color.black : EchoTheme.neoMint)
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6.5)
                        .background(active ? EchoTheme.neoMint : EchoTheme.surface)
                        .foregroundStyle(active ? Color.black : EchoTheme.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                        .overlay(
                            RoundedRectangle(cornerRadius: EchoTheme.radiusControl)
                                .strokeBorder(active ? EchoTheme.neoMint : EchoTheme.border, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 14)

            Divider().overlay(EchoTheme.border)

            if !store.lidarrConfig.isConfigured {
                unconfiguredPrompt
            } else {
                switch selectedTab {
                case .search:
                    searchAndOrderSection(searchBinding: $bindableStore.lidarrSearchQuery)
                case .queue:
                    queueSection
                case .wanted:
                    wantedSection
                }
            }
        }
        .task {
            if store.lidarrConfig.isConfigured && store.lidarrStatus == nil {
                store.testLidarrConnection(silent: true)
            } else if store.lidarrConfig.isConfigured {
                store.refreshLidarrQueueAndWanted(silent: true)
            }
        }
    }

    // MARK: - Unconfigured Setup Callout

    private var unconfiguredPrompt: some View {
        VStack(spacing: 14) {
            Image(systemName: "server.rack")
                .font(.system(size: 38))
                .foregroundStyle(EchoTheme.neoMint)
            Text("Connect Your Lidarr Instance")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(EchoTheme.textPrimary)
            Text("Add your Lidarr Server URL (e.g. http://nas.local:8686) and API Key in Settings to search albums, tracks, or artists and order lossless downloads directly from My Echo.")
                .font(.system(size: 13))
                .foregroundStyle(EchoTheme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 500)
            NeoPrimaryButton(title: "Open Lidarr Settings", icon: "gearshape.fill") {
                store.navigate(to: .settings)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    // MARK: - Search & Order Tab

    private func searchAndOrderSection(searchBinding: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Search Controls Bar
            HStack(spacing: 10) {
                // Mode pills: Albums / Tracks / Artists
                HStack(spacing: 3) {
                    ForEach(LidarrSearchMode.allCases) { mode in
                        let selected = store.lidarrSearchMode == mode
                        Button {
                            store.lidarrSearchMode = mode
                            if !store.lidarrSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                store.searchLidarr()
                            }
                        } label: {
                            Text(mode.rawValue)
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(selected ? EchoTheme.neoCyan.opacity(0.22) : Color.clear)
                                .foregroundStyle(selected ? EchoTheme.neoCyan : EchoTheme.textSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(EchoTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusControl).strokeBorder(EchoTheme.border, lineWidth: 1))

                // Query Field
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(EchoTheme.textMuted)
                    TextField(searchPlaceholder, text: searchBinding)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundStyle(EchoTheme.textPrimary)
                        .onSubmit { store.searchLidarr() }
                    if !store.lidarrSearchQuery.isEmpty {
                        Button {
                            store.lidarrSearchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(EchoTheme.textMuted)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(EchoTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusControl).strokeBorder(EchoTheme.borderStrong, lineWidth: 1))

                NeoPrimaryButton(
                    title: store.isSearchingLidarr ? "Searching..." : "Search",
                    icon: "magnifyingglass",
                    disabled: store.isSearchingLidarr || store.lidarrSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ) {
                    store.searchLidarr()
                }
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 14)

            if let err = store.lidarrSearchError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(EchoTheme.warningAmber)
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundStyle(EchoTheme.textSecondary)
                }
                .padding(.horizontal, 26)
                .padding(.bottom, 10)
            }

            if store.lidarrMarkedCount > 0 {
                LidarrMarkedDownloadsBar()
                    .padding(.horizontal, 26)
                    .padding(.bottom, 10)
            }

            if store.isSearchingLidarr {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Searching \(store.lidarrSearchMode == .tracks ? "catalog for tracks & albums" : "Lidarr metadata")...")
                        .font(.system(size: 12.5))
                        .foregroundStyle(EchoTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        switch store.lidarrSearchMode {
                        case .albums:
                            if store.lidarrAlbumResults.isEmpty {
                                emptySearchHint(
                                    icon: "opticaldisc",
                                    title: "Search Albums to Order",
                                    detail: "Type an album or artist name (e.g. \"Pink Floyd Dark Side\" or \"Daft Punk Random Access Memories\") to look it up in Lidarr and order a download in one click."
                                )
                            } else {
                                ForEach(store.lidarrAlbumResults) { album in
                                    LidarrAlbumResultRow(album: album)
                                }
                            }
                        case .tracks:
                            if store.lidarrTrackResults.isEmpty {
                                emptySearchHint(
                                    icon: "music.note",
                                    title: "Search by Song / Track Name",
                                    detail: "Lidarr downloads full albums. Type any song title and My Echo finds the track's album so you can mark it or order it into Lidarr in one click."
                                )
                            } else {
                                ForEach(store.lidarrTrackResults) { track in
                                    LidarrTrackResultRow(track: track)
                                }
                            }
                        case .artists:
                            if store.lidarrArtistResults.isEmpty {
                                emptySearchHint(
                                    icon: "person.2",
                                    title: "Search Artists",
                                    detail: "Find an artist in Lidarr to monitor their discography or browse their individual albums."
                                )
                            } else {
                                ForEach(store.lidarrArtistResults) { artist in
                                    LidarrArtistResultRow(artist: artist)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 26)
                    .padding(.vertical, 12)
                }
            }
        }
    }

    private var searchPlaceholder: String {
        switch store.lidarrSearchMode {
        case .albums: return "Search albums in Lidarr (artist or album title)..."
        case .tracks: return "Search a song title to find & order its album in Lidarr..."
        case .artists: return "Search artists in Lidarr..."
        }
    }

    private func emptySearchHint(icon: String, title: String, detail: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundStyle(EchoTheme.textMuted)
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(EchoTheme.textPrimary)
            Text(detail)
                .font(.system(size: 12.5))
                .foregroundStyle(EchoTheme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 480)
        }
        .frame(maxWidth: .infinity)
        .padding(44)
        .background(EchoTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard))
        .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusCard).strokeBorder(EchoTheme.border, lineWidth: 1))
    }

    // MARK: - Live Download Queue Tab (Maintained via Lidarr Status & History Polling)

    private var queueSection: some View {
        let pendingOrders = store.lidarrTrackedOrders.filter { $0.phase == .searching }
        let completedOrders = store.lidarrTrackedOrders.filter { $0.phase == .completed }

        let filteredQueue: [LidarrQueueItem] = store.lidarrQueue.filter { item in
            switch queueFilter {
            case .all: return true
            case .downloading: return item.phase == .downloading
            case .queued: return item.phase == .queued || item.phase == .paused
            case .importing: return item.phase == .importing
            case .warnings: return item.phase == .warning || item.phase == .failed
            case .completed: return false
            }
        }

        let showPending = (queueFilter == .all || queueFilter == .queued) && !pendingOrders.isEmpty
        let showCompleted = (queueFilter == .all || queueFilter == .completed) && (!completedOrders.isEmpty || !store.lidarrRecentImports.isEmpty)

        return VStack(alignment: .leading, spacing: 0) {
            // Live Polling Status & Filter Bar
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(store.lidarrAutoPollEnabled ? EchoTheme.neoMint : EchoTheme.textMuted)
                            .frame(width: 7, height: 7)
                        Text(store.lidarrAutoPollEnabled ? "LIVE QUEUE SYNC (5s)" : "AUTO-SYNC PAUSED")
                            .font(.system(size: 9.5, weight: .black, design: .monospaced))
                            .foregroundStyle(store.lidarrAutoPollEnabled ? EchoTheme.neoMint : EchoTheme.textMuted)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(store.lidarrAutoPollEnabled ? EchoTheme.neoMint.opacity(0.14) : EchoTheme.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))

                    if let updated = store.lidarrQueueLastUpdatedAt {
                        Text("Updated \(updated.formatted(date: .omitted, time: .standard))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(EchoTheme.textMuted)
                    }

                    Spacer()

                    Toggle("Auto-Sync", isOn: Binding(
                        get: { store.lidarrAutoPollEnabled },
                        set: { store.setLidarrAutoPollEnabled($0) }
                    ))
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11.5))
                    .foregroundStyle(EchoTheme.textSecondary)
                    .help("Automatically poll Lidarr every 5 seconds while active downloads are running (20s when idle).")

                    Toggle("Auto Re-Index on Import", isOn: Binding(
                        get: { store.lidarrConfig.autoReindexOnImport },
                        set: { val in
                            var cfg = store.lidarrConfig
                            cfg.autoReindexOnImport = val
                            store.saveLidarrConfig(cfg)
                        }
                    ))
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11.5))
                    .foregroundStyle(EchoTheme.textSecondary)
                    .help("Automatically re-scan your local/NAS library folders when Lidarr finishes importing a download so it appears in New Arrivals.")
                }

                // Filter Pills with Live Counts
                HStack(spacing: 6) {
                    ForEach(LidarrQueueFilter.allCases) { f in
                        let active = queueFilter == f
                        let count = queueFilterCount(f, pendingCount: pendingOrders.count)
                        Button {
                            queueFilter = f
                        } label: {
                            HStack(spacing: 4) {
                                Text(f.rawValue)
                                    .font(.system(size: 11, weight: .bold))
                                if count > 0 {
                                    Text("\(count)")
                                        .font(.system(size: 9.5, weight: .black, design: .monospaced))
                                        .foregroundStyle(active ? Color.black : (f == .warnings ? EchoTheme.warningAmber : EchoTheme.neoCyan))
                                }
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4.5)
                            .background(active ? (f == .warnings ? EchoTheme.warningAmber : EchoTheme.neoCyan) : EchoTheme.surface)
                            .foregroundStyle(active ? Color.black : EchoTheme.textSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                            .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall).strokeBorder(active ? Color.clear : EchoTheme.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 12)
            .background(EchoTheme.surface.opacity(0.45))

            Divider().overlay(EchoTheme.border)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // 1. Pending Orders (Just ordered from My Echo, waiting on Lidarr indexer grab)
                    if showPending {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("PENDING ORDERS · SEARCHING LIDARR INDEXERS (\(pendingOrders.count))")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .tracking(1.1)
                                .foregroundStyle(EchoTheme.neoCyan)

                            ForEach(pendingOrders) { order in
                                HStack(spacing: 12) {
                                    ProgressView().controlSize(.small)
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 8) {
                                            Text(order.albumTitle)
                                                .font(.system(size: 13.5, weight: .bold))
                                                .foregroundStyle(EchoTheme.textPrimary)
                                            statusTag(order.phase.displayLabel, color: EchoTheme.neoCyan)
                                        }
                                        Text("\(order.artistName) · \(order.statusDetail ?? "Waiting for Lidarr grab") · ordered \(order.orderedAt.formatted(date: .omitted, time: .shortened))")
                                            .font(.system(size: 11.5))
                                            .foregroundStyle(EchoTheme.textSecondary)
                                    }
                                    Spacer()
                                    if let albumID = order.lidarrAlbumID {
                                        Button("Search Again") {
                                            Task {
                                                try? await store.lidarrClient.triggerAlbumSearch(albumID: albumID, config: store.lidarrConfig)
                                                await MainActor.run {
                                                    store.showToast("Re-triggered Lidarr search for '\(order.albumTitle)'")
                                                }
                                            }
                                        }
                                        .font(.system(size: 11, weight: .semibold))
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 5)
                                        .background(EchoTheme.surfaceElevated)
                                        .foregroundStyle(EchoTheme.neoCyan)
                                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                                        .buttonStyle(.plain)
                                    }
                                    Button {
                                        store.dismissLidarrTrackedOrder(id: order.id)
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(EchoTheme.textMuted)
                                            .frame(width: 24, height: 24)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Dismiss this tracked order from My Echo's pending list (does not remove it from Lidarr).")
                                }
                                .padding(12)
                                .background(EchoTheme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard))
                                .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusCard).strokeBorder(EchoTheme.neoCyan.opacity(0.35), lineWidth: 1))
                            }
                        }
                    }

                    // 2. Active Lidarr Download Queue
                    if queueFilter != .completed {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ACTIVE LIDARR QUEUE (\(filteredQueue.count))")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .tracking(1.1)
                                .foregroundStyle(EchoTheme.neoMint)

                            if filteredQueue.isEmpty {
                                emptySearchHint(
                                    icon: "tray",
                                    title: store.lidarrQueue.isEmpty ? "Lidarr Download Queue is Empty" : "No items match '\(queueFilter.rawValue)'",
                                    detail: store.lidarrQueue.isEmpty
                                        ? "Order albums from Search & Order (or switch Active Library Scope to Lidarr) to monitor live downloads, progress, and import status here."
                                        : "Try switching the status filter above to see other active downloads."
                                )
                            } else {
                                ForEach(filteredQueue) { item in
                                    lidarrQueueRow(item)
                                }
                            }
                        }
                    }

                    // 3. Recently Completed / Imported by Lidarr
                    if showCompleted {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("RECENTLY IMPORTED BY LIDARR (\(store.lidarrRecentImports.count))")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .tracking(1.1)
                                    .foregroundStyle(EchoTheme.neoMint)
                                Spacer()
                                if !completedOrders.isEmpty {
                                    Button("Clear Tracked") {
                                        store.clearCompletedLidarrOrders()
                                    }
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(EchoTheme.textMuted)
                                    .buttonStyle(.plain)
                                }
                            }

                            ForEach(store.lidarrRecentImports.prefix(12)) { hist in
                                HStack(spacing: 12) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 15))
                                        .foregroundStyle(EchoTheme.neoMint)
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 8) {
                                            Text(hist.albumTitle ?? hist.sourceTitle)
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundStyle(EchoTheme.textPrimary)
                                                .lineLimit(1)
                                            if let q = hist.qualityName {
                                                statusTag(q.uppercased(), color: EchoTheme.neoCyan)
                                            }
                                            statusTag("IMPORTED", color: EchoTheme.neoMint)
                                        }
                                        HStack(spacing: 6) {
                                            if let artist = hist.artistName {
                                                Text(artist)
                                                    .font(.system(size: 11.5))
                                                    .foregroundStyle(EchoTheme.textSecondary)
                                            }
                                            Text("· \(hist.date.formatted(date: .abbreviated, time: .shortened))")
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundStyle(EchoTheme.textMuted)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(11)
                                .background(EchoTheme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard))
                                .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusCard).strokeBorder(EchoTheme.border, lineWidth: 1))
                            }
                        }
                    }
                }
                .padding(26)
            }
        }
    }

    private func queueFilterCount(_ filter: LidarrQueueFilter, pendingCount: Int) -> Int {
        switch filter {
        case .all: return store.lidarrQueue.count + pendingCount
        case .downloading: return store.lidarrQueue.filter { $0.phase == .downloading }.count
        case .queued: return store.lidarrQueue.filter { $0.phase == .queued || $0.phase == .paused }.count + pendingCount
        case .importing: return store.lidarrQueue.filter { $0.phase == .importing }.count
        case .warnings: return store.lidarrQueue.filter { $0.phase == .warning || $0.phase == .failed }.count
        case .completed: return store.lidarrRecentImports.count
        }
    }

    private func phaseColor(_ phase: LidarrDownloadPhase) -> Color {
        switch phase {
        case .downloading, .completed: return EchoTheme.neoMint
        case .importing, .searching: return EchoTheme.neoCyan
        case .queued, .paused: return EchoTheme.textSecondary
        case .warning: return EchoTheme.warningAmber
        case .failed: return EchoTheme.dangerCoral
        }
    }

    private func lidarrQueueRow(_ item: LidarrQueueItem) -> some View {
        let color = phaseColor(item.phase)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(item.albumTitle ?? item.title)
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundStyle(EchoTheme.textPrimary)
                            .lineLimit(1)
                        if let q = item.qualityName {
                            statusTag(q.uppercased(), color: EchoTheme.neoCyan)
                        }
                        statusTag(item.phase.displayLabel, color: color)
                    }
                    HStack(spacing: 8) {
                        if let artist = item.artistName {
                            Text(artist)
                                .font(.system(size: 12))
                                .foregroundStyle(EchoTheme.textSecondary)
                        }
                        if item.totalBytes > 0 {
                            Text("· \(Formatters.bytes(item.downloadedBytes)) / \(Formatters.bytes(item.totalBytes))")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(EchoTheme.textMuted)
                        }
                        if let client = item.downloadClient {
                            let proto = item.protocolName.map { " (\($0))" } ?? ""
                            Text("· \(client)\(proto)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(EchoTheme.textMuted)
                        }
                        if let eta = item.timeleft, !eta.isEmpty, item.phase == .downloading {
                            Text("· ETA \(eta)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(EchoTheme.neoMint)
                        }
                    }
                }
                Spacer()
                Text("\(Int((item.progress * 100).rounded()))%")
                    .font(.system(size: 12.5, weight: .black, design: .monospaced))
                    .foregroundStyle(color)

                Button(role: .destructive) {
                    store.removeLidarrQueueItem(item)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11.5))
                        .frame(width: 28, height: 28)
                        .background(EchoTheme.dangerCoral.opacity(0.16))
                        .foregroundStyle(EchoTheme.dangerCoral)
                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                }
                .buttonStyle(.plain)
                .help("Remove this item from Lidarr's download queue.")
            }

            ProgressView(value: item.progress)
                .tint(color)

            if let diag = item.primaryDiagnostic {
                HStack(spacing: 6) {
                    Image(systemName: item.phase == .failed ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 10.5))
                        .foregroundStyle(item.phase == .failed ? EchoTheme.dangerCoral : EchoTheme.warningAmber)
                    Text(diag)
                        .font(.system(size: 11))
                        .foregroundStyle(EchoTheme.textSecondary)
                        .lineLimit(2)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background((item.phase == .failed ? EchoTheme.dangerCoral : EchoTheme.warningAmber).opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
            }
        }
        .padding(14)
        .background(EchoTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard))
        .overlay(
            RoundedRectangle(cornerRadius: EchoTheme.radiusCard)
                .strokeBorder(item.phase == .warning || item.phase == .failed ? color.opacity(0.55) : EchoTheme.border, lineWidth: 1)
        )
    }

    // MARK: - Wanted / Missing Tab

    private var wantedSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if store.lidarrWantedMissing.isEmpty {
                    emptySearchHint(
                        icon: "checkmark.seal",
                        title: "No Missing Monitored Albums",
                        detail: "All monitored albums in Lidarr are either downloaded or currently in the download queue."
                    )
                } else {
                    ForEach(store.lidarrWantedMissing) { album in
                        let isSearching = store.lidarrOrderingIDs.contains(album.id)
                        HStack(spacing: 14) {
                            remoteCover(album.coverURL, size: 48, icon: "opticaldisc")
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 8) {
                                    Text(album.title)
                                        .font(.system(size: 13.5, weight: .bold))
                                        .foregroundStyle(EchoTheme.textPrimary)
                                        .lineLimit(1)
                                    if let y = album.releaseYear {
                                        Text(String(y))
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(EchoTheme.textMuted)
                                    }
                                }
                                Text(album.artistName)
                                    .font(.system(size: 12))
                                    .foregroundStyle(EchoTheme.textSecondary)
                            }
                            Spacer()
                            if isSearching {
                                ProgressView().controlSize(.small).frame(width: 90)
                            } else {
                                Button {
                                    store.triggerLidarrWantedSearch(album)
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: "magnifyingglass")
                                        Text("Search Now")
                                    }
                                    .font(.system(size: 11.5, weight: .bold))
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 6.5)
                                    .background(EchoTheme.neoCyan.opacity(0.18))
                                    .foregroundStyle(EchoTheme.neoCyan)
                                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                                    .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusControl).strokeBorder(EchoTheme.neoCyan.opacity(0.45), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .help("Trigger an immediate Lidarr indexer search for '\(album.title)'.")
                            }
                        }
                        .padding(12)
                        .background(EchoTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard))
                        .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusCard).strokeBorder(EchoTheme.border, lineWidth: 1))
                    }
                }
            }
            .padding(26)
        }
    }

    // MARK: - Helpers

    private func remoteCover(_ urlString: String?, size: CGFloat, icon: String) -> some View {
        Group {
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        placeholderCover(icon: icon)
                    }
                }
            } else {
                placeholderCover(icon: icon)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
        .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall).strokeBorder(EchoTheme.border, lineWidth: 1))
    }

    private func placeholderCover(icon: String) -> some View {
        ZStack {
            EchoTheme.surfaceElevated
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(EchoTheme.textMuted)
        }
    }

    private func statusTag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 8.5, weight: .black, design: .monospaced))
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(color.opacity(0.16))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

// MARK: - Shared Lidarr Result Rows & Batch Mark-for-Download Bar (Used by LidarrView & Global Search)

struct LidarrMarkedDownloadsBar: View {
    @Environment(EchoStore.self) private var store

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.square.fill")
                .font(.system(size: 14))
                .foregroundStyle(EchoTheme.neoMint)

            VStack(alignment: .leading, spacing: 1) {
                Text("\(store.lidarrMarkedCount) item\(store.lidarrMarkedCount == 1 ? "" : "s") marked for Lidarr download")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(EchoTheme.textPrimary)
                Text("Marked albums and track albums will be added to Lidarr and searched on your indexers.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(EchoTheme.textSecondary)
            }

            Spacer()

            Button("Clear") {
                store.clearLidarrMarks()
            }
            .font(.system(size: 11.5, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(EchoTheme.surfaceElevated)
            .foregroundStyle(EchoTheme.textSecondary)
            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
            .buttonStyle(.plain)
            .disabled(store.isOrderingMarkedLidarr)

            NeoPrimaryButton(
                title: store.isOrderingMarkedLidarr ? "Ordering..." : "Download Marked (\(store.lidarrMarkedCount))",
                icon: "arrow.down.circle.fill",
                disabled: store.isOrderingMarkedLidarr
            ) {
                store.orderAllMarkedLidarrItems()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(EchoTheme.neoMint.opacity(0.11))
        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard))
        .overlay(
            RoundedRectangle(cornerRadius: EchoTheme.radiusCard)
                .strokeBorder(EchoTheme.neoMint.opacity(0.5), lineWidth: 1)
        )
    }
}

struct LidarrAlbumResultRow: View {
    @Environment(EchoStore.self) private var store
    let album: LidarrAlbumSearchResult

    var body: some View {
        let isOrdering = store.lidarrOrderingIDs.contains(album.id)
        let wasOrdered = store.lidarrOrderedIDs.contains(album.id)
        let isMarked = store.isAlbumMarkedForLidarr(album)
        let inLocalLibrary = store.albums.contains {
            OnlinePopularityService.normalizeTitleForMatching($0.title) == OnlinePopularityService.normalizeTitleForMatching(album.title)
                && OnlinePopularityService.normalizeTitleForMatching($0.artist) == OnlinePopularityService.normalizeTitleForMatching(album.artistName)
        }

        HStack(spacing: 12) {
            // Mark for Download Checkbox
            Button {
                store.toggleMarkForLidarrDownload(album)
            } label: {
                Image(systemName: isMarked ? "checkmark.square.fill" : "square")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isMarked ? EchoTheme.neoMint : EchoTheme.textMuted)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .disabled(isOrdering || wasOrdered)
            .help(isMarked
                  ? "Unmark '\(album.title)' from batch Lidarr download."
                  : "Mark '\(album.title)' for batch download in Lidarr.")

            lidarrRemoteCover(album.coverURL, size: 52, icon: "opticaldisc")

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(album.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(EchoTheme.textPrimary)
                        .lineLimit(1)

                    if let year = album.releaseYear {
                        Text(String(year))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(EchoTheme.textMuted)
                    }

                    if let type = album.albumType, !type.isEmpty {
                        Text(type.uppercased())
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.white.opacity(0.08))
                            .foregroundStyle(EchoTheme.textSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }

                HStack(spacing: 8) {
                    Text(album.artistName)
                        .font(.system(size: 12.5))
                        .foregroundStyle(EchoTheme.textSecondary)
                        .lineLimit(1)

                    if inLocalLibrary {
                        lidarrStatusTag("IN MY ECHO", color: EchoTheme.neoMint)
                    }
                    if album.isDownloaded {
                        lidarrStatusTag("DOWNLOADED (\(album.trackFileCount)/\(max(album.trackCount, album.trackFileCount)))", color: EchoTheme.neoMint)
                    } else if album.isInLidarr {
                        lidarrStatusTag(album.monitored ? "MONITORED IN LIDARR" : "IN LIDARR", color: EchoTheme.neoCyan)
                    }
                }
            }

            Spacer()

            if isOrdering {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Ordering...")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(EchoTheme.neoMint)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(EchoTheme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
            } else if wasOrdered {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.square.fill")
                    Text("Ordered")
                }
                .font(.system(size: 11.5, weight: .bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(EchoTheme.neoMint.opacity(0.18))
                .foregroundStyle(EchoTheme.neoMint)
                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusControl).strokeBorder(EchoTheme.neoMint.opacity(0.55), lineWidth: 1))
            } else {
                NeoPrimaryButton(
                    title: album.isInLidarr ? "Search Download" : "Order Album",
                    icon: album.isInLidarr ? "magnifyingglass" : "arrow.down.circle.fill"
                ) {
                    store.orderLidarrAlbum(album)
                }
                .help(album.isInLidarr
                      ? "Monitor and trigger an immediate Lidarr download search for '\(album.title)'."
                      : "Add '\(album.title)' to Lidarr and immediately search indexers to download it.")
            }
        }
        .padding(12)
        .background(isMarked ? EchoTheme.neoMint.opacity(0.07) : EchoTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard))
        .overlay(
            RoundedRectangle(cornerRadius: EchoTheme.radiusCard)
                .strokeBorder(isMarked ? EchoTheme.neoMint.opacity(0.55) : EchoTheme.border, lineWidth: 1)
        )
    }
}

struct LidarrTrackResultRow: View {
    @Environment(EchoStore.self) private var store
    let track: LidarrTrackMatch

    var body: some View {
        let isOrdering = store.lidarrOrderingIDs.contains(track.id)
        let wasOrdered = store.lidarrOrderedIDs.contains(track.id)
        let isMarked = store.isTrackMarkedForLidarr(track)

        HStack(spacing: 12) {
            // Mark Track's Album for Download Checkbox
            Button {
                store.toggleMarkForLidarrDownload(track)
            } label: {
                Image(systemName: isMarked ? "checkmark.square.fill" : "square")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isMarked ? EchoTheme.neoMint : EchoTheme.textMuted)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .disabled(isOrdering || wasOrdered)
            .help(isMarked
                  ? "Unmark '\(track.albumTitle)' from batch Lidarr download."
                  : "Mark album '\(track.albumTitle)' (contains '\(track.title)') for batch download in Lidarr.")

            lidarrRemoteCover(track.coverURL, size: 48, icon: "music.note")

            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(EchoTheme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(track.artistName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(EchoTheme.textSecondary)
                    Text("· Album:")
                        .font(.system(size: 11.5))
                        .foregroundStyle(EchoTheme.textMuted)
                    Text(track.albumTitle)
                        .font(.system(size: 12))
                        .foregroundStyle(EchoTheme.neoCyan)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(Formatters.duration(TimeInterval(track.duration)))
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(EchoTheme.textMuted)

            Button {
                store.openLidarrSearch(query: "\(track.artistName) \(track.albumTitle)", mode: .albums)
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11.5, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .background(EchoTheme.surfaceElevated)
                    .foregroundStyle(EchoTheme.textSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
            }
            .buttonStyle(.plain)
            .help("Inspect matching editions of '\(track.albumTitle)' in Lidarr Album search.")

            if isOrdering {
                ProgressView().controlSize(.small).frame(width: 110)
            } else if wasOrdered {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.square.fill")
                    Text("Album Ordered")
                }
                .font(.system(size: 11.5, weight: .bold))
                .padding(.horizontal, 11)
                .padding(.vertical, 6.5)
                .background(EchoTheme.neoMint.opacity(0.18))
                .foregroundStyle(EchoTheme.neoMint)
                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
            } else {
                NeoPrimaryButton(title: "Order Album", icon: "arrow.down.circle.fill") {
                    store.orderLidarrAlbumForTrack(track)
                }
                .help("Look up '\(track.albumTitle)' by \(track.artistName) in Lidarr and order it immediately.")
            }
        }
        .padding(12)
        .background(isMarked ? EchoTheme.neoMint.opacity(0.07) : EchoTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard))
        .overlay(
            RoundedRectangle(cornerRadius: EchoTheme.radiusCard)
                .strokeBorder(isMarked ? EchoTheme.neoMint.opacity(0.55) : EchoTheme.border, lineWidth: 1)
        )
    }
}

struct LidarrArtistResultRow: View {
    @Environment(EchoStore.self) private var store
    let artist: LidarrArtistSearchResult

    var body: some View {
        let isOrdering = store.lidarrOrderingIDs.contains(artist.id)
        let wasOrdered = store.lidarrOrderedIDs.contains(artist.id)

        HStack(spacing: 14) {
            lidarrRemoteCover(artist.coverURL, size: 52, icon: "person.fill")

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(artist.artistName)
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundStyle(EchoTheme.textPrimary)
                    if artist.isInLidarr {
                        lidarrStatusTag(artist.monitored ? "MONITORED IN LIDARR" : "IN LIDARR", color: EchoTheme.neoCyan)
                    }
                }
                if let overview = artist.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.system(size: 11.5))
                        .foregroundStyle(EchoTheme.textSecondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Button {
                store.openLidarrSearch(query: artist.artistName, mode: .albums)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "square.stack")
                    Text("Browse Albums")
                }
                .font(.system(size: 11.5, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(EchoTheme.surfaceElevated)
                .foregroundStyle(EchoTheme.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusControl).strokeBorder(EchoTheme.borderStrong, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .help("List albums by '\(artist.artistName)' in Lidarr so you can mark or order individual releases.")

            if isOrdering {
                ProgressView().controlSize(.small).frame(width: 110)
            } else if wasOrdered {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.square.fill")
                    Text("Ordered")
                }
                .font(.system(size: 11.5, weight: .bold))
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(EchoTheme.neoMint.opacity(0.18))
                .foregroundStyle(EchoTheme.neoMint)
                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
            } else {
                NeoPrimaryMenuButton(
                    title: artist.isInLidarr ? "Search Artist" : "Order Artist",
                    icon: "plus.circle.fill"
                ) {
                    [
                        .action(title: "Monitor All Albums & Search Now", icon: "arrow.down.circle.fill") {
                            store.orderLidarrArtist(artist, monitorMode: "all", searchMissing: true)
                        },
                        .action(title: "Monitor Future Releases Only", icon: "calendar.badge.plus") {
                            store.orderLidarrArtist(artist, monitorMode: "future", searchMissing: false)
                        },
                        .action(title: "Add Artist (Don't Auto-Download Yet)", icon: "plus") {
                            store.orderLidarrArtist(artist, monitorMode: "none", searchMissing: false)
                        }
                    ]
                }
                .fixedSize()
                .help("Add '\(artist.artistName)' to Lidarr with your choice of monitoring policy.")
            }
        }
        .padding(12)
        .background(EchoTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard))
        .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusCard).strokeBorder(EchoTheme.border, lineWidth: 1))
    }
}

@MainActor
private func lidarrRemoteCover(_ urlString: String?, size: CGFloat, icon: String) -> some View {
    Group {
        if let urlString, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    ZStack {
                        EchoTheme.surfaceElevated
                        Image(systemName: icon)
                            .font(.system(size: 18))
                            .foregroundStyle(EchoTheme.textMuted)
                    }
                }
            }
        } else {
            ZStack {
                EchoTheme.surfaceElevated
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(EchoTheme.textMuted)
            }
        }
    }
    .frame(width: size, height: size)
    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
    .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall).strokeBorder(EchoTheme.border, lineWidth: 1))
}

@MainActor
private func lidarrStatusTag(_ text: String, color: Color) -> some View {
    Text(text)
        .font(.system(size: 8.5, weight: .black, design: .monospaced))
        .padding(.horizontal, 5)
        .padding(.vertical, 1.5)
        .background(color.opacity(0.16))
        .foregroundStyle(color)
        .clipShape(RoundedRectangle(cornerRadius: 3))
}

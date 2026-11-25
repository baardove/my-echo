import SwiftUI
import EchoCore

struct PodcastsView: View {
    @Environment(EchoStore.self) private var store
    @State private var directRSSURL: String = ""
    @State private var showRSSPopover = false

    var body: some View {
        @Bindable var bindableStore = store

        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // Header + Compact Icon Toolbar
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("PODCASTS & RSS DIRECTORIES")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .tracking(1.4)
                                .foregroundStyle(EchoTheme.neoMint)
                            Text("Podcasts")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundStyle(EchoTheme.textPrimary)
                        }
                        Spacer()

                        HStack(spacing: 8) {
                            compactIconButton(
                                icon: "square.and.arrow.down",
                                color: EchoTheme.textPrimary,
                                tip: "Import podcast subscriptions in bulk from an .opml or .xml file."
                            ) {
                                store.importOPMLViaPanel()
                            }

                            compactIconButton(
                                icon: "link.badge.plus",
                                color: EchoTheme.neoCyan,
                                tip: "Subscribe directly to a podcast by pasting its RSS / XML feed URL."
                            ) {
                                showRSSPopover.toggle()
                            }
                            .popover(isPresented: $showRSSPopover) {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Subscribe via RSS Feed URL")
                                        .font(.system(size: 13.5, weight: .bold))
                                        .foregroundStyle(EchoTheme.textPrimary)
                                    TextField("https://feeds.example.com/podcast.xml", text: $directRSSURL)
                                        .neoTextField()
                                        .frame(width: 320)
                                        .onSubmit { submitDirectRSS() }
                                    HStack {
                                        Spacer()
                                        NeoPrimaryButton(title: "Subscribe", icon: "plus", disabled: directRSSURL.trimmingCharacters(in: .whitespaces).isEmpty) {
                                            submitDirectRSS()
                                        }
                                    }
                                }
                                .padding(14)
                                .background(EchoTheme.surface)
                            }

                            if !store.podcasts.isEmpty {
                                compactIconButton(
                                    icon: "arrow.clockwise",
                                    color: EchoTheme.neoMint,
                                    tip: "Refresh all subscribed podcast RSS feeds to check for new episodes."
                                ) {
                                    store.refreshAllPodcasts()
                                }

                                podcastSyncActionButton
                            }
                        }
                    }

                    // Live Multi-Directory Podcast Search Bar
                    HStack(spacing: 8) {
                        NeoPickerDropdown(
                            icon: "globe",
                            selection: $bindableStore.selectedPodcastDirectory,
                            options: PodcastDirectory.allCases.map { ($0, $0.displayName) }
                        )
                        .fixedSize()
                        .help("Choose which podcast directory to search: All Directories (Apple + gPodder combined), Apple Podcasts, gPodder Open Directory, or Featured Picks.")

                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(EchoTheme.neoMint)
                            TextField("Search podcasts, hosts, or genres (e.g. True Crime, Tech, Sports)...", text: $bindableStore.podcastSearchQuery)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13))
                                .onSubmit { store.searchPodcasts() }
                            if !store.podcastSearchQuery.isEmpty {
                                Button {
                                    store.podcastSearchQuery = ""
                                    store.browsePodcastCategory(.featured)
                                } label: {
                                    Image(systemName: "xmark.square.fill")
                                        .foregroundStyle(EchoTheme.textMuted)
                                }
                                .buttonStyle(.plain)
                                .help("Clear search query and show Featured Picks.")
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(EchoTheme.surfaceElevated.opacity(0.88))
                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous).strokeBorder(EchoTheme.neoMint.opacity(0.45), lineWidth: 1))

                        Button {
                            store.searchPodcasts()
                        } label: {
                            Group {
                                if store.isSearchingPodcasts {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 13, weight: .bold))
                                }
                            }
                            .frame(width: 38, height: 34)
                            .background(
                                ZStack {
                                    EchoTheme.surfaceElevated
                                    EchoTheme.neoMint.opacity(0.10)
                                }
                            )
                            .foregroundStyle(EchoTheme.neoMint)
                            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                            .overlay(
                                RoundedRectangle(cornerRadius: EchoTheme.radiusControl)
                                    .strokeBorder(EchoTheme.neoMint.opacity(0.75), lineWidth: 1.1)
                            )
                            .shadow(color: EchoTheme.neoMint.opacity(0.18), radius: 5, y: 1)
                        }
                        .buttonStyle(.plain)
                        .disabled(store.isSearchingPodcasts || store.podcastSearchQuery.trimmingCharacters(in: .whitespaces).isEmpty)
                        .help("Search \(store.selectedPodcastDirectory.displayName) by podcast title, host, or topic.")
                    }

                    // Quick Browse Directory Category Chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 7) {
                            ForEach(PodcastBrowseCategory.allCases) { category in
                                let isActive = store.activePodcastCategory == category
                                Button {
                                    store.browsePodcastCategory(category)
                                } label: {
                                    Text(category.rawValue)
                                        .font(.system(size: 11, weight: isActive ? .black : .semibold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(isActive ? EchoTheme.neoMint.opacity(0.20) : EchoTheme.surface)
                                        .foregroundStyle(isActive ? EchoTheme.neoMint : EchoTheme.textSecondary)
                                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: EchoTheme.radiusSmall)
                                                .strokeBorder(isActive ? EchoTheme.neoMint.opacity(0.65) : EchoTheme.border, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                                .help("Browse '\(category.rawValue)' podcasts from \(store.selectedPodcastDirectory.displayName).")
                            }
                        }
                    }
                }

                let hasSearchResults = !store.podcastSearchResults.isEmpty

                // Search / Directory Results Section (Large Cover-Art Cards)
                if store.isSearchingPodcasts {
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        Text("Searching \(store.selectedPodcastDirectory.displayName)...")
                            .font(.system(size: 12.5))
                            .foregroundStyle(EchoTheme.textSecondary)
                    }
                    .padding(14)
                } else if let err = store.podcastSearchError {
                    Text(err)
                        .font(.system(size: 12.5))
                        .foregroundStyle(EchoTheme.warningAmber)
                        .padding(12)
                        .background(EchoTheme.warningAmber.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                } else if hasSearchResults {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("\(store.activePodcastCategory?.rawValue.uppercased() ?? "SEARCH RESULTS") (\(store.podcastSearchResults.count))")
                                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(EchoTheme.neoCyan)
                            Spacer()
                            Button {
                                store.podcastSearchResults = []
                                store.activePodcastCategory = nil
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(EchoTheme.textMuted)
                            }
                            .buttonStyle(.plain)
                            .help("Hide directory results.")
                        }

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 185, maximum: 220), spacing: 16)], spacing: 16) {
                            ForEach(store.podcastSearchResults) { result in
                                let isSubscribed = store.podcasts.contains { $0.feedURL.caseInsensitiveCompare(result.feedURL) == .orderedSame }
                                VStack(alignment: .leading, spacing: 10) {
                                    ZStack(alignment: .topTrailing) {
                                        AsyncImage(url: result.artworkURL.flatMap(URL.init(string:))) { phase in
                                            switch phase {
                                            case .success(let image):
                                                image.resizable().aspectRatio(contentMode: .fill)
                                            default:
                                                ZStack {
                                                    EchoTheme.surfaceElevated
                                                    Image(systemName: "mic.fill")
                                                        .font(.system(size: 34))
                                                        .foregroundStyle(EchoTheme.neoCyan.opacity(0.55))
                                                }
                                            }
                                        }
                                        .aspectRatio(1, contentMode: .fit)
                                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                                        .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusControl).strokeBorder(EchoTheme.border, lineWidth: 1))

                                        Button {
                                            store.subscribeToPodcast(feedURL: result.feedURL, fallbackArtworkURL: result.artworkURL)
                                        } label: {
                                            Image(systemName: isSubscribed ? "checkmark" : "plus")
                                                .font(.system(size: 13, weight: .black))
                                                .frame(width: 30, height: 30)
                                                .background(isSubscribed ? EchoTheme.neoMint : EchoTheme.neoCyan)
                                                .foregroundStyle(.black)
                                                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                                                .shadow(color: .black.opacity(0.45), radius: 4, y: 2)
                                        }
                                        .buttonStyle(.plain)
                                        .padding(6)
                                        .help(isSubscribed
                                              ? "Already subscribed to '\(result.title)'. Click to open its episode list."
                                              : "Subscribe to '\(result.title)' and fetch its RSS episodes for playback and syncing.")
                                    }

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(result.title)
                                            .font(.system(size: 13.5, weight: .bold))
                                            .foregroundStyle(EchoTheme.textPrimary)
                                            .lineLimit(2)
                                        Text(result.author)
                                            .font(.system(size: 11.5))
                                            .foregroundStyle(EchoTheme.textSecondary)
                                            .lineLimit(1)
                                    }

                                    HStack(spacing: 5) {
                                        Text(result.directorySource)
                                            .font(.system(size: 8.5, weight: .black, design: .monospaced))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1.5)
                                            .background(EchoTheme.neoCyan.opacity(0.16))
                                            .foregroundStyle(EchoTheme.neoCyan)
                                            .clipShape(RoundedRectangle(cornerRadius: 3))
                                        if let count = result.episodeCount {
                                            Text("\(count) eps")
                                                .font(.system(size: 9.5, design: .monospaced))
                                                .foregroundStyle(EchoTheme.textMuted)
                                        }
                                        if let genre = result.genre {
                                            Text("· \(genre)")
                                                .font(.system(size: 9.5, design: .monospaced))
                                                .foregroundStyle(EchoTheme.textMuted)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                                .padding(10)
                                .background(EchoTheme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard))
                                .overlay(
                                    RoundedRectangle(cornerRadius: EchoTheme.radiusCard)
                                        .strokeBorder(isSubscribed ? EchoTheme.neoMint.opacity(0.5) : EchoTheme.neoCyan.opacity(0.3), lineWidth: 1)
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    store.openPodcastSearchPreview(result)
                                }
                            }
                        }
                    }
                }

                // Dedicated EnkeltEpisoder Section (Single Episodes downloaded without subscribing)
                if !store.singleEpisodes.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(EchoTheme.hiResGold)
                            Text("ENKELTEPISODER (\(store.singleEpisodes.count))")
                                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(EchoTheme.hiResGold)
                            Text("· Lastet ned uten abonnement")
                                .font(.system(size: 10.5))
                                .foregroundStyle(EchoTheme.textMuted)
                            Spacer()
                        }

                        LazyVStack(spacing: 6) {
                            ForEach(store.singleEpisodes) { ep in
                                SingleEpisodeRowView(episode: ep)
                            }
                        }
                    }
                }

                // Subscribed Shows Grid (Compact Small Cards while searching; Large Cover Cards normally)
                VStack(alignment: .leading, spacing: 14) {
                    Text("SUBSCRIBED SHOWS (\(store.subscribedPodcasts.count))")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(EchoTheme.neoMint)

                    if store.subscribedPodcasts.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "mic.badge.plus")
                                .font(.system(size: 36))
                                .foregroundStyle(EchoTheme.accentGradient)
                            Text("No Subscribed Podcasts Yet")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(EchoTheme.textPrimary)
                            Text("Click any show above to preview & download single episodes into EnkeltEpisoder, click + to subscribe, paste an RSS URL, or import an OPML file.")
                                .font(.system(size: 12.5))
                                .foregroundStyle(EchoTheme.textSecondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 480)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(36)
                        .background(EchoTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard))
                        .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusCard).strokeBorder(EchoTheme.border, lineWidth: 1))
                    } else if hasSearchResults {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 255, maximum: 340), spacing: 10)], spacing: 10) {
                            ForEach(store.subscribedPodcasts) { show in
                                CompactPodcastShowCardView(show: show)
                            }
                        }
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 185, maximum: 220), spacing: 16)], spacing: 16) {
                            ForEach(store.subscribedPodcasts) { show in
                                PodcastShowCardView(show: show)
                            }
                        }
                    }
                }
            }
            .padding(26)
        }
        .sheet(item: Binding(
            get: { store.previewingPodcastResult },
            set: { if $0 == nil { store.closePodcastSearchPreview() } }
        )) { result in
            PodcastSearchPreviewSheet(result: result)
                .environment(store)
        }
    }

    private func submitDirectRSS() {
        let url = directRSSURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return }
        showRSSPopover = false
        directRSSURL = ""
        store.subscribeToPodcast(feedURL: url)
    }

    @ViewBuilder
    private var podcastSyncActionButton: some View {
        let pendingEpisodes = (store.activeSyncPlan?.episodesToCopy.count ?? 0) + (store.activeSyncPlan?.episodesToRemove.count ?? 0)
        if let dev = store.activeDevice, dev.isConnected {
            NeoPrimaryButton(
                title: pendingEpisodes > 0 ? "Sync Podcasts (\(pendingEpisodes))" : "Sync Podcasts",
                icon: "arrow.triangle.2.circlepath",
                disabled: store.isSyncing
            ) {
                store.startSync(for: dev)
            }
            .help("Download any queued podcast episodes and sync them to '\(dev.name)' (rotating out older episodes beyond each show's Keep limit).")
        } else {
            let connected = store.devices.filter(\.isConnected)
            if !connected.isEmpty {
                NeoPrimaryMenuButton(title: "Sync Podcasts", icon: "arrow.triangle.2.circlepath") {
                    connected.map { dev in
                        .action(title: "Sync Podcasts to \(dev.name)", icon: dev.isVirtualWireless ? "iphone" : "sdcard.fill") {
                            store.selectActiveDevice(dev.id)
                            store.startSync(for: dev)
                        }
                    }
                }
                .fixedSize()
                .help("Pick a connected destination and sync your selected podcasts immediately.")
            } else {
                NeoPrimaryButton(title: "Sync Podcasts", icon: "arrow.triangle.2.circlepath", disabled: true) {}
                    .help("Plug in a FiiO player or SD card to sync podcasts.")
            }
        }
    }

    private func compactIconButton(icon: String, color: Color, tip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 32, height: 32)
                .background(
                    ZStack {
                        EchoTheme.surfaceElevated
                        EchoTheme.neoMint.opacity(0.06)
                    }
                )
                .foregroundStyle(color)
                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous)
                        .strokeBorder(EchoTheme.neoMint.opacity(0.50), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(tip)
    }
}

struct SingleEpisodeRowView: View {
    @Environment(EchoStore.self) private var store
    let episode: PodcastEpisode
    @State private var isHovered = false

    var body: some View {
        let syncReason = store.episodeSyncReason(episode)
        let destBadges = store.destinations(forEpisode: episode)

        HStack(spacing: 12) {
            ZStack {
                ArtworkView(hash: episode.artworkHash, artworkCache: store.artworkCache, cornerRadius: EchoTheme.radiusSmall, iconSize: 16)
                    .frame(width: 40, height: 40)
                if isHovered {
                    RoundedRectangle(cornerRadius: EchoTheme.radiusSmall)
                        .fill(Color.black.opacity(0.55))
                        .frame(width: 40, height: 40)
                    Image(systemName: "play.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(EchoTheme.neoMint)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { store.playEpisode(episode) }
            .help("Play '\(episode.title)' immediately.")

            VStack(alignment: .leading, spacing: 2.5) {
                HStack(spacing: 6) {
                    Text(episode.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(EchoTheme.textPrimary)
                        .lineLimit(1)
                    Text("ENKELT")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .padding(.horizontal, 4.5)
                        .padding(.vertical, 1.5)
                        .background(EchoTheme.hiResGold.opacity(0.18))
                        .foregroundStyle(EchoTheme.hiResGold)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                HStack(spacing: 6) {
                    Text(episode.showTitle)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(EchoTheme.neoCyan)
                        .lineLimit(1)
                    if let pub = episode.publishedAt {
                        Text("· \(pub.formatted(date: .abbreviated, time: .omitted))")
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(EchoTheme.textMuted)
                    }
                    if episode.duration > 0 {
                        Text("· \(Formatters.duration(episode.duration))")
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(EchoTheme.textMuted)
                    }
                    if !destBadges.isEmpty {
                        DestinationBadgeStrip(badges: destBadges)
                    }
                }
            }

            Spacer(minLength: 8)

            // Compact S sync toggle (same style as tracks)
            Button {
                store.toggleEpisodeSync(episode)
            } label: {
                Text("S")
                    .font(.system(size: 10.5, weight: .black, design: .monospaced))
                    .frame(width: 24, height: 24)
                    .background(syncReason != nil ? EchoTheme.neoMint.opacity(0.22) : EchoTheme.surfaceElevated)
                    .foregroundStyle(syncReason != nil ? EchoTheme.neoMint : EchoTheme.textMuted)
                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                    .overlay(
                        RoundedRectangle(cornerRadius: EchoTheme.radiusSmall)
                            .strokeBorder(syncReason != nil ? EchoTheme.neoMint.opacity(0.7) : EchoTheme.border, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .help(syncReason != nil
                  ? "Pinned for sync to active destination. Click to unpin."
                  : "Pin this single episode to sync to the active destination (FiiO, SD card, iPhone/iPad).")

            if !store.devices.isEmpty {
                Menu {
                    ForEach(store.devices) { dev in
                        let assigned = store.episodeSyncReason(episode, on: dev) != nil
                        Button {
                            store.toggleEpisodeSync(episode, onDeviceID: dev.id)
                        } label: {
                            HStack {
                                Text(dev.name)
                                if assigned { Image(systemName: "checkmark") }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12))
                        .foregroundStyle(EchoTheme.textMuted)
                        .frame(width: 24, height: 24)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 24)
                .help("Assign this single episode to any destination.")
            }

            Button(role: .destructive) {
                store.removeSingleEpisode(episode)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11.5))
                    .foregroundStyle(EchoTheme.dangerCoral.opacity(0.85))
                    .frame(width: 26, height: 26)
                    .background(EchoTheme.dangerCoral.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
            }
            .buttonStyle(.plain)
            .help("Remove '\(episode.title)' from EnkeltEpisoder and delete local audio file.")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHovered ? EchoTheme.surfaceElevated : EchoTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
        .overlay(
            RoundedRectangle(cornerRadius: EchoTheme.radiusControl)
                .strokeBorder(syncReason != nil ? EchoTheme.neoMint.opacity(0.35) : EchoTheme.hiResGold.opacity(0.25), lineWidth: 1)
        )
        .onHover { isHovered = $0 }
    }
}

struct PodcastSearchPreviewSheet: View {
    @Environment(EchoStore.self) private var store
    let result: PodcastSearchResult

    var body: some View {
        let isSubscribed = store.subscribedPodcasts.contains { $0.feedURL.caseInsensitiveCompare(result.feedURL) == .orderedSame }

        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .top, spacing: 16) {
                AsyncImage(url: result.artworkURL.flatMap(URL.init(string:))) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        ZStack {
                            EchoTheme.surfaceElevated
                            Image(systemName: "mic.fill").font(.system(size: 28)).foregroundStyle(EchoTheme.neoCyan)
                        }
                    }
                }
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard))
                .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusCard).strokeBorder(EchoTheme.borderStrong, lineWidth: 1))

                VStack(alignment: .leading, spacing: 5) {
                    Text("FORHÅNDSVISNING · LAST NED ENKELTEPISODER UTEN ABONNEMENT")
                        .font(.system(size: 9.5, weight: .black, design: .monospaced))
                        .foregroundStyle(EchoTheme.hiResGold)
                    Text(store.previewingPodcastShow?.title ?? result.title)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(EchoTheme.textPrimary)
                        .lineLimit(2)
                    Text(store.previewingPodcastShow?.author ?? result.author)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(EchoTheme.neoCyan)

                    HStack(spacing: 8) {
                        Button {
                            store.subscribeToPodcast(feedURL: result.feedURL, fallbackArtworkURL: result.artworkURL)
                            store.closePodcastSearchPreview()
                        } label: {
                            Label(isSubscribed ? "Subscribed" : "Subscribe to Full Show", systemImage: isSubscribed ? "checkmark" : "plus")
                                .font(.system(size: 12, weight: .bold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6.5)
                                .background(isSubscribed ? EchoTheme.neoMint.opacity(0.22) : EchoTheme.neoMint)
                                .foregroundStyle(isSubscribed ? EchoTheme.neoMint : .black)
                                .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                        }
                        .buttonStyle(.plain)

                        Button("Close") {
                            store.closePodcastSearchPreview()
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6.5)
                        .background(EchoTheme.surfaceElevated)
                        .foregroundStyle(EchoTheme.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                }
                Spacer()
            }
            .padding(20)
            .background(EchoTheme.surface)

            Divider().overlay(EchoTheme.border)

            if store.isLoadingPodcastPreview {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Henter episoder fra RSS-feed...")
                        .font(.system(size: 12.5))
                        .foregroundStyle(EchoTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = store.podcastPreviewError {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 28))
                        .foregroundStyle(EchoTheme.warningAmber)
                    Text("Kunne ikke hente episoder: \(err)")
                        .font(.system(size: 12.5))
                        .foregroundStyle(EchoTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let previewShow = store.previewingPodcastShow {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(previewShow.episodes) { ep in
                            let isSaved = store.isSavedAsSingleEpisode(ep)
                            let isDownloading = store.downloadingEpisodeIDs.contains(ep.id)

                            HStack(spacing: 12) {
                                Button {
                                    store.downloadSingleEpisode(ep, autoPlay: true)
                                } label: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: EchoTheme.radiusSmall)
                                            .fill(EchoTheme.neoMint.opacity(0.16))
                                            .frame(width: 30, height: 30)
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 10.5, weight: .bold))
                                            .foregroundStyle(EchoTheme.neoMint)
                                    }
                                }
                                .buttonStyle(.plain)
                                .help("Last ned til EnkeltEpisoder og spill av.")

                                VStack(alignment: .leading, spacing: 2.5) {
                                    Text(ep.title)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(EchoTheme.textPrimary)
                                        .lineLimit(2)
                                    HStack(spacing: 6) {
                                        if let pub = ep.publishedAt {
                                            Text(pub.formatted(date: .abbreviated, time: .omitted))
                                                .font(.system(size: 10.5, design: .monospaced))
                                                .foregroundStyle(EchoTheme.textMuted)
                                        }
                                        if ep.duration > 0 {
                                            Text("· \(Formatters.duration(ep.duration))")
                                                .font(.system(size: 10.5, design: .monospaced))
                                                .foregroundStyle(EchoTheme.textMuted)
                                        }
                                    }
                                }

                                Spacer(minLength: 8)

                                if isDownloading {
                                    ProgressView().controlSize(.small).frame(width: 28)
                                } else if isSaved {
                                    Label("EnkeltEpisoder", systemImage: "checkmark.circle.fill")
                                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
                                        .background(EchoTheme.hiResGold.opacity(0.18))
                                        .foregroundStyle(EchoTheme.hiResGold)
                                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                                } else {
                                    Button {
                                        store.downloadSingleEpisode(ep, autoPlay: false, pinToActiveDevice: false)
                                    } label: {
                                        Label("Last ned", systemImage: "arrow.down.circle")
                                            .font(.system(size: 11, weight: .bold))
                                            .padding(.horizontal, 9)
                                            .padding(.vertical, 5)
                                            .background(EchoTheme.surfaceElevated)
                                            .foregroundStyle(EchoTheme.neoCyan)
                                            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                                            .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall).strokeBorder(EchoTheme.neoCyan.opacity(0.45), lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Last ned denne episoden til EnkeltEpisoder uten å abonnere på showet.")

                                    Button {
                                        store.downloadSingleEpisode(ep, autoPlay: false, pinToActiveDevice: true)
                                    } label: {
                                        Text("S")
                                            .font(.system(size: 10.5, weight: .black, design: .monospaced))
                                            .frame(width: 26, height: 26)
                                            .background(EchoTheme.neoMint.opacity(0.18))
                                            .foregroundStyle(EchoTheme.neoMint)
                                            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall))
                                            .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusSmall).strokeBorder(EchoTheme.neoMint.opacity(0.55), lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Last ned til EnkeltEpisoder og merk for sync til valgt enhet.")
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(EchoTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                            .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusControl).strokeBorder(EchoTheme.border, lineWidth: 1))
                        }
                    }
                    .padding(16)
                }
                .background(EchoTheme.canvas)
            }
        }
        .frame(minWidth: 660, minHeight: 520)
        .background(EchoTheme.canvas)
    }
}

struct CompactPodcastShowCardView: View {
    @Environment(EchoStore.self) private var store
    let show: PodcastShow

    var body: some View {
        let isSyncedOnActive = store.isPodcastShowSelected(show)

        HStack(spacing: 10) {
            ArtworkView(hash: show.artworkHash, artworkCache: store.artworkCache, cornerRadius: EchoTheme.radiusSmall, iconSize: 18)
                .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 2.5) {
                Text(show.title)
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(EchoTheme.textPrimary)
                    .lineLimit(1)
                Text(show.author)
                    .font(.system(size: 11))
                    .foregroundStyle(EchoTheme.textSecondary)
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Text("\(show.episodes.count) eps")
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(EchoTheme.textMuted)
                    Text(show.episodesToKeep == 0 ? "KEEP ALL" : "KEEP \(show.episodesToKeep)")
                        .font(.system(size: 8.5, weight: .black, design: .monospaced))
                        .padding(.horizontal, 4.5)
                        .padding(.vertical, 1)
                        .background(EchoTheme.neoCyan.opacity(0.14))
                        .foregroundStyle(EchoTheme.neoCyan)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }
            Spacer(minLength: 4)

            SyncStatePillButton(
                state: isSyncedOnActive ? .full : .none,
                compact: true,
                tooltip: isSyncedOnActive
                    ? "Remove '\(show.title)' from active destination's auto-sync."
                    : "Include latest \(show.episodesToKeep == 0 ? "all" : "\(show.episodesToKeep)") episodes of '\(show.title)' when syncing."
            ) {
                store.togglePodcastShowSync(show)
            }
        }
        .padding(8)
        .background(EchoTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard))
        .overlay(
            RoundedRectangle(cornerRadius: EchoTheme.radiusCard)
                .strokeBorder(isSyncedOnActive ? EchoTheme.neoMint.opacity(0.45) : EchoTheme.border, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { store.navigate(to: .podcastDetail(show.id)) }
    }
}

struct PodcastShowCardView: View {
    @Environment(EchoStore.self) private var store
    let show: PodcastShow
    @State private var isHovered = false

    var body: some View {
        let isSyncedOnActive = store.isPodcastShowSelected(show)
        let badges = store.destinations(forPodcastShow: show)

        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                ArtworkView(hash: show.artworkHash, artworkCache: store.artworkCache, cornerRadius: EchoTheme.radiusControl, iconSize: 34)
                    .aspectRatio(1, contentMode: .fit)
                    .contentShape(Rectangle())
                    .onTapGesture { store.navigate(to: .podcastDetail(show.id)) }

                SyncStatePillButton(
                    state: isSyncedOnActive ? .full : .none,
                    compact: true,
                    tooltip: isSyncedOnActive
                        ? "Remove '\(show.title)' from active destination's auto-sync."
                        : "Include latest \(show.episodesToKeep == 0 ? "all" : "\(show.episodesToKeep)") episodes of '\(show.title)' when syncing to the selected destination."
                ) {
                    store.togglePodcastShowSync(show)
                }
                .padding(6)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(show.title)
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(EchoTheme.textPrimary)
                    .lineLimit(1)
                Text(show.author)
                    .font(.system(size: 11.5))
                    .foregroundStyle(EchoTheme.textSecondary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("\(show.episodes.count) eps")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(EchoTheme.textMuted)
                    Text(show.episodesToKeep == 0 ? "KEEP ALL" : "KEEP \(show.episodesToKeep)")
                        .font(.system(size: 8.5, weight: .black, design: .monospaced))
                        .padding(.horizontal, 4.5)
                        .padding(.vertical, 1)
                        .background(EchoTheme.neoCyan.opacity(0.15))
                        .foregroundStyle(EchoTheme.neoCyan)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }

                if !badges.isEmpty {
                    DestinationBadgeStrip(badges: badges)
                        .padding(.top, 2)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { store.navigate(to: .podcastDetail(show.id)) }
        }
        .padding(11)
        .background(isHovered ? EchoTheme.surfaceElevated : EchoTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusCard))
        .overlay(
            RoundedRectangle(cornerRadius: EchoTheme.radiusCard)
                .strokeBorder(isSyncedOnActive ? EchoTheme.neoMint.opacity(0.45) : EchoTheme.border, lineWidth: 1)
        )
        .onHover { isHovered = $0 }
        .draggable(EchoDragPayload.podcastShow(show.id).encode()) {
            DragPreviewPill(
                title: show.title,
                subtitle: "Podcast Show",
                artworkHash: show.artworkHash,
                artworkCache: store.artworkCache,
                badge: show.episodesToKeep == 0 ? "ALL EPS" : "KEEP \(show.episodesToKeep)"
            )
        }
        .contextMenu {
            Button("Open Show") { store.navigate(to: .podcastDetail(show.id)) }
            Button("Refresh Feed") { store.refreshPodcast(show) }
            Menu("Episodes to Keep on Sync") {
                ForEach([1, 2, 3, 5, 10, 15, 25, 0], id: \.self) { count in
                    Button {
                        store.setPodcastEpisodesToKeep(show, count: count)
                    } label: {
                        HStack {
                            Text(count == 0 ? "Keep All Episodes" : "Keep Latest \(count)")
                            if show.episodesToKeep == count { Image(systemName: "checkmark") }
                        }
                    }
                }
            }
            if !store.devices.isEmpty {
                Menu("Sync to Destinations") {
                    ForEach(store.devices) { dev in
                        let onDev = store.isPodcastShowSelected(show, on: dev)
                        Button {
                            store.togglePodcastShowSync(show, onDeviceID: dev.id)
                        } label: {
                            HStack {
                                Text(dev.name)
                                if onDev { Image(systemName: "checkmark") }
                            }
                        }
                    }
                }
            }
            Divider()
            Button("Unsubscribe", role: .destructive) { store.unsubscribePodcast(show) }
        }
    }
}

struct PodcastDetailView: View {
    @Environment(EchoStore.self) private var store
    let showID: UUID

    var body: some View {
        if let show = store.podcasts.first(where: { $0.id == showID }) {
            let glow = ArtworkImageLoader.shared.dominantColor(forHash: show.artworkHash, artworkCache: store.artworkCache)
            let isSynced = store.isPodcastShowSelected(show)
            let isRefreshing = store.refreshingPodcastIDs.contains(show.id)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Clean Show Hero
                    ZStack(alignment: .bottomLeading) {
                        LinearGradient(colors: [glow.opacity(0.55), EchoTheme.canvas], startPoint: .top, endPoint: .bottom)
                            .frame(height: 240)

                        HStack(alignment: .bottom, spacing: 20) {
                            ArtworkView(hash: show.artworkHash, artworkCache: store.artworkCache, cornerRadius: EchoTheme.radiusCard, iconSize: 48)
                                .frame(width: 164, height: 164)
                                .shadow(color: .black.opacity(0.5), radius: 14, y: 6)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("PODCAST")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .tracking(1.4)
                                    .foregroundStyle(EchoTheme.neoMint)

                                Text(show.title)
                                    .font(.system(size: 30, weight: .black, design: .rounded))
                                    .foregroundStyle(EchoTheme.textPrimary)
                                    .lineLimit(2)

                                Text(show.author)
                                    .font(.system(size: 13.5, weight: .semibold))
                                    .foregroundStyle(EchoTheme.textSecondary)

                                if !show.description.isEmpty {
                                    Text(show.description)
                                        .font(.system(size: 11.5))
                                        .foregroundStyle(EchoTheme.textMuted)
                                        .lineLimit(2)
                                }

                                // Compact Action Bar: Sync Toggle + Per-Podcast Keep Limit + Icon Buttons
                                HStack(spacing: 8) {
                                    SyncStatePillButton(
                                        state: isSynced ? .full : .none,
                                        label: "Auto-Sync",
                                        tooltip: isSynced
                                            ? "Auto-sync is ON for '\(show.title)' on the selected destination. Click to disable."
                                            : "Enable auto-sync for '\(show.title)' on the selected destination (syncs newest episodes and rotates out older ones)."
                                    ) {
                                        store.togglePodcastShowSync(show)
                                    }

                                    // Per-Podcast Episodes-to-Keep Picker (auto-throws out old episodes when new ones sync!)
                                    NeoMenuButton {
                                        [1, 2, 3, 5, 10, 15, 25, 0].map { count in
                                            .action(
                                                title: count == 0 ? "Keep All Episodes" : "Keep Latest \(count) Episode\(count == 1 ? "" : "s")",
                                                isSelected: show.episodesToKeep == count
                                            ) {
                                                store.setPodcastEpisodesToKeep(show, count: count)
                                            }
                                        }
                                    } label: { isHovered in
                                        HStack(spacing: 5.5) {
                                            Image(systemName: "clock.arrow.2.circlepath")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundStyle(EchoTheme.neoMint)
                                            Text(show.episodesToKeep == 0 ? "Keep: All" : "Keep: \(show.episodesToKeep)")
                                                .font(.system(size: 11.5, weight: .bold))
                                                .foregroundStyle(EchoTheme.textPrimary)
                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 8.5, weight: .bold))
                                                .foregroundStyle(EchoTheme.neoMint.opacity(isHovered ? 0.95 : 0.72))
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6.5)
                                        .background(
                                            ZStack {
                                                EchoTheme.surfaceElevated
                                                EchoTheme.neoMint.opacity(isHovered ? 0.14 : 0.05)
                                            }
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: EchoTheme.radiusControl, style: .continuous)
                                                .strokeBorder(EchoTheme.neoMint.opacity(isHovered ? 0.90 : 0.55), lineWidth: 1)
                                        )
                                    }
                                    .fixedSize()
                                    .help("Per-podcast retention limit: choose how many latest episodes of '\(show.title)' to keep on your player. Syncing newer episodes automatically removes older ones beyond this count.")

                                    if !store.devices.isEmpty {
                                        NeoIconMenuButton(icon: "square.stack.3d.up", accent: EchoTheme.neoMint, size: 30) {
                                            store.devices.map { dev in
                                                let selected = store.isPodcastShowSelected(show, on: dev)
                                                return .action(title: dev.name, icon: dev.isVirtualWireless ? "iphone" : "sdcard.fill", isSelected: selected) {
                                                    store.togglePodcastShowSync(show, onDeviceID: dev.id)
                                                }
                                            }
                                        }
                                        .fixedSize()
                                        .help("Assign or remove '\(show.title)' across multiple sync destinations.")
                                    }

                                    if let dev = store.activeDevice, dev.isConnected {
                                        NeoPrimaryButton(title: "Sync Now", icon: "arrow.triangle.2.circlepath", disabled: store.isSyncing) {
                                            store.startSync(for: dev)
                                        }
                                        .help("Download queued episodes and sync '\(show.title)' to '\(dev.name)' right now.")
                                    } else {
                                        let connected = store.devices.filter(\.isConnected)
                                        if !connected.isEmpty {
                                            NeoPrimaryMenuButton(title: "Sync Now", icon: "arrow.triangle.2.circlepath") {
                                                connected.map { dev in
                                                    .action(title: "Sync to \(dev.name)", icon: dev.isVirtualWireless ? "iphone" : "sdcard.fill") {
                                                        store.selectActiveDevice(dev.id)
                                                        store.startSync(for: dev)
                                                    }
                                                }
                                            }
                                            .fixedSize()
                                            .help("Choose a connected destination and sync '\(show.title)' now.")
                                        }
                                    }

                                    Button {
                                        store.refreshPodcast(show)
                                    } label: {
                                        Group {
                                            if isRefreshing {
                                                ProgressView().controlSize(.mini)
                                            } else {
                                                Image(systemName: "arrow.clockwise")
                                                    .font(.system(size: 12.5, weight: .semibold))
                                            }
                                        }
                                        .frame(width: 30, height: 30)
                                        .background(EchoTheme.surfaceElevated)
                                        .foregroundStyle(EchoTheme.textPrimary)
                                        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                                        .overlay(RoundedRectangle(cornerRadius: EchoTheme.radiusControl).strokeBorder(EchoTheme.border, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(isRefreshing)
                                    .help("Refresh '\(show.title)' RSS feed to fetch newly published episodes.")

                                    Button(role: .destructive) {
                                        store.unsubscribePodcast(show)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 12))
                                            .frame(width: 30, height: 30)
                                            .background(EchoTheme.dangerCoral.opacity(0.16))
                                            .foregroundStyle(EchoTheme.dangerCoral)
                                            .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Unsubscribe from '\(show.title)' and remove it from sync selections.")
                                }
                                .padding(.top, 4)
                            }
                            Spacer()
                        }
                        .padding(26)
                    }

                    // Episodes List
                    VStack(alignment: .leading, spacing: 8) {
                        Text("EPISODES (\(show.episodes.count))")
                            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(EchoTheme.textMuted)
                            .padding(.bottom, 4)

                        let totalEpisodes = show.episodes.count
                        LazyVStack(spacing: 6) {
                            ForEach(Array(show.episodes.enumerated()), id: \.element.id) { idx, ep in
                                PodcastEpisodeRowView(episode: ep, episodeNumber: totalEpisodes - idx)
                            }
                        }
                    }
                    .padding(.horizontal, 26)
                    .padding(.bottom, 28)
                }
            }
        } else {
            ContentUnavailableView("Podcast Not Found", systemImage: "mic.slash")
        }
    }
}

struct PodcastEpisodeRowView: View {
    @Environment(EchoStore.self) private var store
    let episode: PodcastEpisode
    var episodeNumber: Int? = nil
    @State private var isHovered = false

    var body: some View {
        let syncReason = store.episodeSyncReason(episode)
        let isDownloading = store.downloadingEpisodeIDs.contains(episode.id)
        let destBadges = store.destinations(forEpisode: episode)

        HStack(spacing: 12) {
            if let episodeNumber {
                Text(String(format: "%02d", episodeNumber))
                    .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(EchoTheme.textMuted)
                    .frame(width: 34, alignment: .trailing)
                    .lineLimit(1)
            }

            Button {
                store.playEpisode(episode)
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: EchoTheme.radiusSmall)
                        .fill(EchoTheme.neoMint.opacity(isHovered ? 0.25 : 0.14))
                        .frame(width: 32, height: 32)
                    Image(systemName: "play.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(EchoTheme.neoMint)
                }
            }
            .buttonStyle(.plain)
            .help(episode.isDownloaded
                  ? "Play '\(episode.title)' immediately in the audio player."
                  : "Download and play '\(episode.title)' in the audio player.")

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(episode.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(EchoTheme.textPrimary)
                        .lineLimit(1)

                    if episode.isDownloaded {
                        Text("LOCAL")
                            .font(.system(size: 8.5, weight: .black, design: .monospaced))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(EchoTheme.neoCyan.opacity(0.18))
                            .foregroundStyle(EchoTheme.neoCyan)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }

                HStack(spacing: 8) {
                    if let pub = episode.publishedAt {
                        Text(pub.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(EchoTheme.textMuted)
                    }
                    if episode.duration > 0 {
                        Text("· \(Formatters.duration(episode.duration))")
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(EchoTheme.textMuted)
                    }
                    if episode.fileSize > 0 {
                        Text("· \(Formatters.bytes(episode.fileSize))")
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(EchoTheme.textMuted)
                    }
                    if !destBadges.isEmpty {
                        DestinationBadgeStrip(badges: destBadges)
                    }
                }
            }

            Spacer(minLength: 8)

            if isDownloading {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 28)
                    .help("Downloading episode audio...")
            } else if episode.isDownloaded {
                Button {
                    store.deleteDownloadedEpisode(episode)
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(EchoTheme.neoCyan)
                }
                .buttonStyle(.plain)
                .help("Downloaded locally. Click to delete the local cached file (you can re-download anytime).")
            } else {
                Button {
                    store.downloadEpisode(episode)
                } label: {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(EchoTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Download this episode locally now for offline listening or faster syncing.")
            }

            Button {
                store.toggleEpisodeSync(episode)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: syncReason != nil ? "checkmark.square.fill" : "square")
                        .font(.system(size: 14))
                        .foregroundStyle(syncReason != nil ? EchoTheme.neoMint : EchoTheme.textMuted)
                    if let reason = syncReason {
                        Text(reason == "Show" ? "KEEP" : "PIN")
                            .font(.system(size: 8.5, weight: .black, design: .monospaced))
                            .foregroundStyle(EchoTheme.neoMint)
                    }
                }
                .frame(width: 64, alignment: .trailing)
            }
            .buttonStyle(.plain)
            .help(syncReason == "Show"
                  ? "Included automatically via this podcast's 'Keep Latest' window. Click to pin explicitly."
                  : (syncReason == "Episode"
                     ? "Pinned for sync to the selected destination. Click to unpin."
                     : "Pin this specific episode to sync to the selected destination (auto-downloads if needed)."))

            if !store.devices.isEmpty {
                Menu {
                    ForEach(store.devices) { dev in
                        let assigned = store.episodeSyncReason(episode, on: dev) != nil
                        let synced = dev.syncedEpisodeIDs.contains(episode.id)
                        Button {
                            store.toggleEpisodeSync(episode, onDeviceID: dev.id)
                        } label: {
                            HStack {
                                Text("\(dev.name)\(synced ? " (Synced)" : "")")
                                if assigned { Image(systemName: "checkmark") }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12))
                        .foregroundStyle(EchoTheme.textMuted)
                        .frame(width: 24, height: 24)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 24)
                .help("Pin or unpin this episode across any configured destination.")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHovered ? EchoTheme.surfaceElevated.opacity(0.8) : EchoTheme.surface.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: EchoTheme.radiusControl))
        .overlay(
            RoundedRectangle(cornerRadius: EchoTheme.radiusControl)
                .strokeBorder(syncReason != nil ? EchoTheme.neoMint.opacity(0.32) : EchoTheme.border, lineWidth: 1)
        )
        .onHover { isHovered = $0 }
        .draggable(EchoDragPayload.podcastEpisode(episode.id).encode()) {
            DragPreviewPill(
                title: episode.title,
                subtitle: episode.showTitle,
                artworkHash: episode.artworkHash,
                artworkCache: store.artworkCache,
                badge: "EPISODE"
            )
        }
    }
}

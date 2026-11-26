import SwiftUI

struct TVPodcastsView: View {
    @Environment(TVEchoStore.self) private var store
    @State private var selectedShow: TVPodcastFeed?

    private let columns = [
        GridItem(.adaptive(minimum: 270, maximum: 300), spacing: 36)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 34) {
                TVSectionHeader(
                    eyebrow: "Subscribed Podcasts",
                    title: "Shows from My Echo Mac",
                    trailing: "\(store.podcastFeeds.count) Shows"
                )

                if store.podcastFeeds.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("No Subscribed Podcasts Loaded")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(EchoTVTheme.textPrimary)
                        Text("Pair with My Echo on Mac in the Servers tab to browse and stream your subscribed podcast shows directly on Apple TV.")
                            .font(.system(size: 21))
                            .foregroundStyle(EchoTVTheme.textSecondary)
                        Button {
                            store.selectedTab = .servers
                        } label: {
                            Label("Open Servers", systemImage: "server.rack")
                                .font(.system(size: 20, weight: .bold))
                                .padding(.horizontal, 24)
                                .padding(.vertical, 14)
                                .background(EchoTVTheme.neoMint)
                                .foregroundStyle(Color.black)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(EchoTVButtonStyle(cornerRadius: 14))
                    }
                    .padding(36)
                    .background(EchoTVTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                } else {
                    LazyVGrid(columns: columns, spacing: 40) {
                        ForEach(store.podcastFeeds) { feed in
                            let artURL: URL? = store.macArtworkURL(for: feed.artworkHash)
                                ?? feed.artworkURL.flatMap(URL.init(string:))
                            TVAlbumCardTile(
                                title: feed.title,
                                subtitle: feed.author.isEmpty ? "Podcast" : feed.author,
                                year: nil,
                                artworkURL: artURL
                            ) {
                                selectedShow = feed
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 40)
        }
        .background(EchoTVTheme.canvas)
        .navigationDestination(item: $selectedShow) { show in
            TVPodcastShowDetailView(show: show)
        }
    }
}

struct TVPodcastShowDetailView: View {
    @Environment(TVEchoStore.self) private var store
    let show: TVPodcastFeed

    var body: some View {
        let episodes = store.episodesByShowID[show.id] ?? []
        let artURL: URL? = store.macArtworkURL(for: show.artworkHash)
            ?? show.artworkURL.flatMap(URL.init(string:))

        ScrollView {
            VStack(alignment: .leading, spacing: 34) {
                HStack(alignment: .top, spacing: 36) {
                    TVArtworkView(url: artURL, cornerRadius: 18, fallbackIcon: "mic.fill")
                        .frame(width: 320, height: 320)

                    VStack(alignment: .leading, spacing: 14) {
                        Text("PODCAST SHOW")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundStyle(EchoTVTheme.neoCyan)
                        Text(show.title)
                            .font(.system(size: 44, weight: .black, design: .rounded))
                            .foregroundStyle(EchoTVTheme.textPrimary)
                        if !show.author.isEmpty {
                            Text(show.author)
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(EchoTVTheme.textSecondary)
                        }
                        if !show.description.isEmpty {
                            Text(show.description)
                                .font(.system(size: 19))
                                .foregroundStyle(EchoTVTheme.textSecondary)
                                .lineLimit(4)
                        }

                        HStack(spacing: 16) {
                            if let latest = episodes.first {
                                Button {
                                    store.playPodcastEpisode(latest, show: show)
                                } label: {
                                    Label("Play Latest Episode", systemImage: "play.fill")
                                        .font(.system(size: 21, weight: .bold))
                                        .padding(.horizontal, 26)
                                        .padding(.vertical, 14)
                                        .background(EchoTVTheme.neoMint)
                                        .foregroundStyle(Color.black)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(EchoTVButtonStyle(cornerRadius: 14))
                            }

                            if !show.feedURL.isEmpty {
                                Button {
                                    Task { await store.refreshPodcastShow(show) }
                                } label: {
                                    Label(store.isRefreshingPodcasts ? "Refreshing RSS..." : "Refresh RSS Feed", systemImage: "arrow.clockwise")
                                        .font(.system(size: 20, weight: .semibold))
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 14)
                                        .background(EchoTVTheme.surfaceElevated)
                                        .foregroundStyle(EchoTVTheme.textPrimary)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(EchoTVButtonStyle(cornerRadius: 14))
                            }
                        }
                        .padding(.top, 6)
                    }
                    Spacer()
                }

                if episodes.isEmpty {
                    Text("No episodes loaded yet — click Refresh RSS Feed to fetch the latest episodes.")
                        .font(.system(size: 22))
                        .foregroundStyle(EchoTVTheme.textSecondary)
                        .padding(24)
                        .background(EchoTVTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(episodes) { ep in
                            Button {
                                store.playPodcastEpisode(ep, show: show)
                            } label: {
                                HStack(alignment: .center, spacing: 20) {
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 34))
                                        .foregroundStyle(EchoTVTheme.neoMint)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(ep.title)
                                            .font(.system(size: 23, weight: .bold))
                                            .foregroundStyle(EchoTVTheme.textPrimary)
                                            .lineLimit(1)
                                        if !ep.summary.isEmpty {
                                            Text(ep.summary)
                                                .font(.system(size: 17))
                                                .foregroundStyle(EchoTVTheme.textSecondary)
                                                .lineLimit(2)
                                        }
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 4) {
                                        if ep.duration > 0 {
                                            Text(TVFormatters.duration(ep.duration))
                                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                                .foregroundStyle(EchoTVTheme.neoCyan)
                                        }
                                        if let pub = ep.publishedAt {
                                            Text(pub, style: .date)
                                                .font(.system(size: 15, design: .monospaced))
                                                .foregroundStyle(EchoTVTheme.textMuted)
                                        }
                                    }
                                }
                                .padding(20)
                                .background(EchoTVTheme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(EchoTVButtonStyle(cornerRadius: 14))
                        }
                    }
                }
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 40)
        }
        .background(EchoTVTheme.canvas)
        .task {
            if episodes.isEmpty && !show.feedURL.isEmpty {
                await store.refreshPodcastShow(show)
            }
        }
    }
}

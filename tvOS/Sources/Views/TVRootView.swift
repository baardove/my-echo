import SwiftUI

struct TVRootView: View {
    @Environment(TVEchoStore.self) private var store

    var body: some View {
        @Bindable var bindableStore = store

        ZStack(alignment: .bottom) {
            EchoTVTheme.canvas.ignoresSafeArea()

            TabView(selection: $bindableStore.selectedTab) {
                NavigationStack {
                    TVHomeView()
                }
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(TVTab.home)

                NavigationStack {
                    TVLibraryView()
                }
                .tabItem {
                    Label("Library", systemImage: "square.stack.fill")
                }
                .tag(TVTab.library)

                TVNowPlayingView()
                    .tabItem {
                        Label(
                            store.player.isPlaying ? "Playing" : "Now Playing",
                            systemImage: store.player.isPlaying ? "waveform" : "play.circle.fill"
                        )
                    }
                    .tag(TVTab.nowPlaying)

                TVPartyModeView()
                    .tabItem {
                        Label(
                            store.partyStatus.isLive ? "Party LIVE" : "Party TV",
                            systemImage: "sparkles.tv.fill"
                        )
                    }
                    .tag(TVTab.partyTV)

                NavigationStack {
                    TVPodcastsView()
                }
                .tabItem {
                    Label("Podcasts", systemImage: "mic.fill")
                }
                .tag(TVTab.podcasts)

                TVMacRemoteView()
                    .tabItem {
                        Label("Mac Remote", systemImage: "desktopcomputer")
                    }
                    .tag(TVTab.macRemote)

                NavigationStack {
                    TVSearchView()
                }
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(TVTab.search)

                NavigationStack {
                    TVServersView()
                }
                .tabItem {
                    Label("Servers", systemImage: "server.rack")
                }
                .tag(TVTab.servers)
            }
            .tint(EchoTVTheme.neoMint)

            if let toast = store.toastMessage {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(EchoTVTheme.neoMint)
                    Text(toast)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(EchoTVTheme.textPrimary)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(EchoTVTheme.surfaceElevated.opacity(0.96))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(EchoTVTheme.neoMint.opacity(0.6), lineWidth: 1.5))
                .shadow(color: .black.opacity(0.6), radius: 20, y: 10)
                .padding(.bottom, 36)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: store.toastMessage)
    }
}

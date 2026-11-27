import SwiftUI
import AppKit

@main
struct EchoApp: App {
    @State private var store = EchoStore()
    @Environment(\.openWindow) private var openWindow

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup("My Echo", id: "main-studio") {
            MainContentView()
                .environment(store)
                .frame(minWidth: 1120, minHeight: 720)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1340, height: 860)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About My Echo") {
                    store.clearGlobalSearch()
                    store.isLidarrLibraryScope = false
                    store.navigate(to: .about)
                }
            }

            CommandGroup(after: .newItem) {
                Button("Add Music Folder / NAS...") {
                    store.addLibrarySourceViaPanel()
                }
                .keyboardShortcut("o", modifiers: [.command])

                Button("Re-Index All Sources") {
                    store.indexAllSources()
                }
                .keyboardShortcut("r", modifiers: [.command])

                Button("Import Spotify Playlist...") {
                    store.showSpotifyImportSheet = true
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])

                Divider()

                Button("Add Player / SD Card Target...") {
                    store.addCustomDeviceFolderViaPanel()
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])

                Divider()

                Button("Settings & Themes...") {
                    store.navigate(to: .settings)
                }
                .keyboardShortcut(",", modifiers: [.command])
            }

            CommandMenu("Playback") {
                Button(store.player.isPlaying ? "Pause" : "Play") {
                    store.player.togglePlayPause()
                }
                .keyboardShortcut("p", modifiers: [.command])

                Button("Next Track") {
                    store.player.nextTrack()
                }
                .keyboardShortcut(.rightArrow, modifiers: [.command])

                Button("Previous Track") {
                    store.player.previousTrack()
                }
                .keyboardShortcut(.leftArrow, modifiers: [.command])

                Divider()

                Button(store.isPartyModeEnabled ? "Exit Party Mode" : "Start Party Mode (Partymode)") {
                    store.togglePartyMode()
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])

                Button(store.isMiniPlayerOpen ? "Hide Winamp Mini Player" : "Show Winamp Mini Player") {
                    if let miniWin = NSApp.windows.first(where: { $0.title == "My Echo Mini" }) {
                        if miniWin.isVisible && !miniWin.isMiniaturized {
                            miniWin.orderOut(nil)
                            store.isMiniPlayerOpen = false
                        } else {
                            if miniWin.isMiniaturized { miniWin.deminiaturize(nil) }
                            miniWin.makeKeyAndOrderFront(nil)
                            NSApp.activate(ignoringOtherApps: true)
                            store.isMiniPlayerOpen = true
                        }
                    } else {
                        openWindow(id: "mini-player")
                        store.isMiniPlayerOpen = true
                    }
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])
            }
        }

        Window("My Echo Mini", id: "mini-player") {
            WinampMiniPlayerView()
                .environment(store)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 396, height: 400)
    }
}

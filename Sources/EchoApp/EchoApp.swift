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
            CommandGroup(after: .newItem) {
                Button("Add Music Folder / NAS...") {
                    store.addLibrarySourceViaPanel()
                }
                .keyboardShortcut("o", modifiers: [.command])

                Button("Re-Index All Sources") {
                    store.indexAllSources()
                }
                .keyboardShortcut("r", modifiers: [.command])

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

                Button("Open Winamp Mini Player") {
                    openWindow(id: "mini-player")
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

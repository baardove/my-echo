import SwiftUI

@main
struct MyEchoiOSApp: App {
    @State private var store = iOSEchoStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(store)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        store.handleAppBecameActive()
                    }
                }
        }
    }
}

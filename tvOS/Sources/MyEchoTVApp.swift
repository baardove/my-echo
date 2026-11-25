import SwiftUI

@main
struct MyEchoTVApp: App {
    @State private var store = TVEchoStore()

    var body: some Scene {
        WindowGroup {
            TVRootView()
                .environment(store)
                .preferredColorScheme(.dark)
        }
    }
}

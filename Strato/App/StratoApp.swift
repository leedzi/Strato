import SwiftUI

@main
struct StratoApp: App {
    @State private var store = StratoStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(.dark)
        }
    }
}

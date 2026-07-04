import SwiftUI

@main
struct VideoLoaderApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                ContentView()
                    .tabItem {
                        Label("Laden", systemImage: "arrow.down.circle")
                    }
                LibraryView()
                    .tabItem {
                        Label("Meine Videos", systemImage: "film.stack")
                    }
            }
        }
    }
}

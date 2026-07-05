import SwiftUI

@main
struct VideoLoaderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var queue = DownloadQueue.shared

    private var activeCount: Int {
        queue.jobs.filter { $0.status == .waiting || $0.status == .running }.count
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                ContentView()
                    .tabItem {
                        Label("Laden", systemImage: "arrow.down.circle")
                    }
                QueueView()
                    .tabItem {
                        Label("Downloads", systemImage: "square.and.arrow.down")
                    }
                    .badge(activeCount)
                LibraryView()
                    .tabItem {
                        Label("Meine Videos", systemImage: "film.stack")
                    }
            }
        }
    }
}

/// Fängt das Ereignis ab, mit dem iOS die App für fertige Hintergrund-Downloads
/// aufweckt, und reicht es an die Warteschlange weiter.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Warteschlange früh anstoßen, damit sie sich wieder mit laufenden
        // Hintergrund-Downloads verbindet.
        _ = DownloadQueue.shared
        return true
    }

    func application(_ application: UIApplication,
                     handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void) {
        DownloadQueue.shared.backgroundCompletionHandler = completionHandler
    }
}

import SwiftUI

@main
struct VideoLoaderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var queue = DownloadQueue.shared

    @State private var selectedTab = 0
    @State private var pendingLink: String?

    private var activeCount: Int {
        queue.jobs.filter { $0.status == .waiting || $0.status == .running }.count
    }

    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                ContentView(pendingLink: $pendingLink)
                    .tabItem {
                        Label("Laden", systemImage: "arrow.down.circle")
                    }
                    .tag(0)
                QueueView()
                    .tabItem {
                        Label("Downloads", systemImage: "square.and.arrow.down")
                    }
                    .badge(activeCount)
                    .tag(1)
                LibraryView()
                    .tabItem {
                        Label("Meine Videos", systemImage: "film.stack")
                    }
                    .tag(2)
            }
            .onOpenURL { url in
                // Vom Teilen-Menü kommt videoloader://add?url=<Link>
                if let link = Self.parseSharedLink(from: url) {
                    pendingLink = link
                    selectedTab = 0
                }
            }
        }
    }

    /// Liest den geteilten Link aus einer videoloader://add?url=… Adresse.
    static func parseSharedLink(from url: URL) -> String? {
        guard url.scheme == "videoloader" else { return nil }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        return components?.queryItems?.first(where: { $0.name == "url" })?.value
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

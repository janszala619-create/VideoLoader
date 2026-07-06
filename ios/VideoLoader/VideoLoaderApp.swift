import SwiftUI

@main
struct VideoLoaderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var queue = DownloadQueue.shared
    @Environment(\.scenePhase) private var scenePhase

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
                        Label("Laden", systemImage: "arrow.down.circle.fill")
                    }
                    .tag(0)
                QueueView()
                    .tabItem {
                        Label("Downloads", systemImage: "square.and.arrow.down.fill")
                    }
                    .badge(activeCount)
                    .tag(1)
                LibraryView()
                    .tabItem {
                        Label("Meine Videos", systemImage: "film.stack.fill")
                    }
                    .tag(2)
            }
            .tint(Aurora.Colors.accentBlue)
            .toolbarBackground(.visible, for: .tabBar)
            .toolbarBackground(.regularMaterial, for: .tabBar)
            .toolbarColorScheme(.dark, for: .tabBar)
            .onOpenURL { url in
                if let link = Self.parseSharedLink(from: url) {
                    pendingLink = link
                    selectedTab = 0
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    queue.resumeIfNeeded()
                }
            }
        }
    }

    static func parseSharedLink(from url: URL) -> String? {
        guard url.scheme == "videoloader" else { return nil }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        return components?.queryItems?.first(where: { $0.name == "url" })?.value
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        _ = DownloadQueue.shared
        return true
    }

    func application(_ application: UIApplication,
                     handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void) {
        DownloadQueue.shared.backgroundCompletionHandler = completionHandler
    }
}

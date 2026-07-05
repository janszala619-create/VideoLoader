import SwiftUI
import AVKit

// MARK: - Load State (One source of truth)
enum LoadState {
    case idle
    case checking
    case loaded(VideoInfo)
    case error(String)
    case checking_server

    var isLoading: Bool {
        switch self {
        case .checking, .checking_server: return true
        default: return false
        }
    }
}

struct ContentViewPremium: View {
    @Binding var pendingLink: String?
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("serverURL_videoLoader") private var macServerURL = ""
    @AppStorage("serverURL_vidSave") private var cloudServerURL = "http://158.101.168.11:8765"
    @AppStorage("activeServer") private var activeServerRaw = ServerKind.vidSave.rawValue

    // MARK: - Single Source of Truth
    @State private var loadState: LoadState = .idle
    @State private var videoLink = ""
    @State private var selectedQuality: QualityOption?
    @State private var showSettings = false
    @State private var showPreviewPlayer = false
    @State private var serverOnline: Bool? = nil
    @State private var clipboardHasLink = false

    @ObservedObject private var queue = DownloadQueue.shared

    private var activeServer: ServerKind {
        ServerKind(rawValue: activeServerRaw) ?? .vidSave
    }

    private var activeBaseURL: String {
        activeServer == .videoLoader ? macServerURL : cloudServerURL
    }

    private var cleanedLink: String {
        videoLink.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PremiumAuroraBackground()

                ScrollView {
                    VStack(spacing: AppThemePremium.sectionSpacing) {
                        // MARK: - Hero Section
                        heroSection

                        // MARK: - Server Status (kompakt, oben)
                        serverStatusBadge

                        // MARK: - Main Content (dynamisch)
                        mainContent

                        Spacer(minLength: AppThemePremium.xl)
                    }
                    .padding(.horizontal, AppThemePremium.screenPadding)
                    .padding(.vertical, AppThemePremium.lg)
                }
            }
            .navigationTitle("VideoLoader")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(AppColorsPremium.accentBlue)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(
                    macServerURL: $macServerURL,
                    cloudServerURL: $cloudServerURL,
                    activeServerRaw: $activeServerRaw
                )
            }
            .sheet(isPresented: $showPreviewPlayer) {
                previewPlayerSheet
            }
            .onAppear {
                if activeBaseURL.isEmpty { showSettings = true }
                Task { await checkServer() }
                consumePendingLink()
                detectClipboardLink()
            }
            .onChange(of: pendingLink) { _, _ in
                consumePendingLink()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    detectClipboardLink()
                }
            }
        }
    }

    // MARK: - Hero Section
    private var heroSection: some View {
        VStack(alignment: .leading, spacing: AppThemePremium.md) {
            Text("Video hinzufügen")
                .font(.title2.weight(.bold))
                .foregroundStyle(AppColorsPremium.textPrimary)

            PremiumGlassInputField(
                placeholder: "Link einfügen oder scannen",
                text: $videoLink,
                icon: "doc.on.clipboard"
            ) {
                if videoLink.isEmpty {
                    if let pasted = UIPasteboard.general.string {
                        videoLink = pasted
                        Task { await loadInfo() }
                    }
                } else {
                    videoLink = ""
                    loadState = .idle
                }
            }

            Button {
                Task { await loadInfo() }
            } label: {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("Video prüfen")
                }
            }
            .buttonStyle(PremiumPrimaryButtonStyle())
            .disabled(cleanedLink.isEmpty || loadState.isLoading)

            if clipboardHasLink && videoLink.isEmpty {
                Button {
                    if let pasted = UIPasteboard.general.string {
                        videoLink = pasted
                        clipboardHasLink = false
                        Task { await loadInfo() }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "link.badge.plus")
                        Text("Link aus Zwischenablage")
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(PremiumSecondaryButtonStyle())
            }
        }
    }

    // MARK: - Server Status Badge (kompakt)
    private var serverStatusBadge: some View {
        HStack(spacing: AppThemePremium.md) {
            HStack(spacing: 6) {
                Circle()
                    .fill(serverStatusColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: serverStatusColor.opacity(0.5), radius: 4)

                Text(serverStatusText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColorsPremium.textSecondary)
            }

            Spacer()

            if serverOnline == false {
                Button {
                    showSettings = true
                } label: {
                    Text("Einstellungen")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColorsPremium.accentTeal)
                }
            }
        }
        .padding(.horizontal, AppThemePremium.md)
        .padding(.vertical, AppThemePremium.sm)
        .background(AppColorsPremium.glassSurface)
        .overlay(
            RoundedRectangle(cornerRadius: AppThemePremium.radiusSmall)
                .stroke(AppColorsPremium.glassBorder, lineWidth: 0.8)
        )
        .cornerRadius(AppThemePremium.radiusSmall)
    }

    private var serverStatusColor: Color {
        switch serverOnline {
        case .some(true): return AppColorsPremium.success
        case .some(false): return AppColorsPremium.error
        case .none: return AppColorsPremium.textTertiary
        }
    }

    private var serverStatusText: String {
        switch serverOnline {
        case .some(true): return "Server online"
        case .some(false): return "Server offline"
        case .none: return "Status wird geprüft..."
        }
    }

    // MARK: - Main Content (State-driven)
    @ViewBuilder
    private var mainContent: some View {
        switch loadState {
        case .idle:
            EmptyStateView()

        case .checking, .checking_server:
            LoadingStateView()

        case .loaded(let info):
            loadedContent(info)

        case .error(let message):
            ErrorStateView(message: message) {
                Task { await checkServer() }
            }
        }
    }

    // MARK: - Loaded Content
    @ViewBuilder
    private func loadedContent(_ info: VideoInfo) -> some View {
        VStack(spacing: AppThemePremium.lg) {
            // Video Preview
            PremiumGlassCard {
                ZStack {
                    AsyncImage(url: info.thumbnailURL) { image in
                        image.resizable().aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Rectangle()
                            .fill(AppColorsPremium.glassSurfaceStrong)
                            .aspectRatio(16 / 9, contentMode: .fit)
                            .overlay {
                                Image(systemName: "film")
                                    .font(.largeTitle)
                                    .foregroundStyle(AppColorsPremium.textTertiary)
                            }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: AppThemePremium.radiusLarge))

                    if info.previewURL != nil {
                        Button {
                            showPreviewPlayer = true
                        } label: {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(.white)
                                .shadow(color: AppColorsPremium.accentBlueGlow, radius: 12)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: AppThemePremium.sm) {
                    Text(info.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppColorsPremium.textPrimary)
                        .lineLimit(2)

                    HStack(spacing: 12) {
                        if let uploader = info.uploader {
                            Label(uploader, systemImage: "person.circle.fill")
                                .font(.caption)
                                .foregroundStyle(AppColorsPremium.textSecondary)
                        }
                        if let duration = info.durationText {
                            Label(duration, systemImage: "clock.fill")
                                .font(.caption)
                                .foregroundStyle(AppColorsPremium.textSecondary)
                        }
                    }
                }
            }

            // Quality Selection
            if !info.qualities.isEmpty {
                VStack(alignment: .leading, spacing: AppThemePremium.sm) {
                    Text("Qualität")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColorsPremium.textPrimary)

                    PremiumGlassCard {
                        Picker("Qualität", selection: $selectedQuality) {
                            ForEach(info.qualities) { quality in
                                Text(quality.label).tag(Optional(quality))
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(AppColorsPremium.accentTeal)
                    }
                }
            }

            // Download Button
            Button {
                enqueueDownload(info)
            } label: {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                    Text("Zur Warteschlange")
                }
            }
            .buttonStyle(PremiumPrimaryButtonStyle(accent: .blue))
        }
    }

    // MARK: - Actions
    private func checkServer() async {
        loadState = .checking_server
        defer { loadState = .idle }
        guard !activeBaseURL.trimmingCharacters(in: .whitespaces).isEmpty else {
            serverOnline = false
            return
        }
        let api = ServerAPI(kind: activeServer, baseURL: activeBaseURL)
        serverOnline = await api.isReachable()
    }

    private func detectClipboardLink() {
        guard videoLink.isEmpty else { return }
        UIPasteboard.general.detectPatterns(for: [\.probableWebURL]) { result in
            DispatchQueue.main.async {
                if case .success(let patterns) = result, patterns.contains(\.probableWebURL) {
                    clipboardHasLink = true
                }
            }
        }
    }

    private func consumePendingLink() {
        guard let link = pendingLink, !link.isEmpty else { return }
        pendingLink = nil
        videoLink = link
        Task { await loadInfo() }
    }

    private func loadInfo() async {
        loadState = .checking
        do {
            let api = ServerAPI(kind: activeServer, baseURL: activeBaseURL)
            let result = try await api.fetchInfo(for: cleanedLink)
            selectedQuality = result.qualities.first
            loadState = .loaded(result)
        } catch let error as APIError {
            loadState = .error(error.errorDescription ?? "Unbekannter Fehler")
        } catch {
            loadState = .error("Video konnte nicht geprüft werden: \(error.localizedDescription)")
        }
    }

    private func enqueueDownload(_ info: VideoInfo) {
        do {
            let api = ServerAPI(kind: activeServer, baseURL: activeBaseURL)
            let url = try api.downloadURL(for: cleanedLink, quality: selectedQuality)
            let fallback = try? api.downloadURL(for: cleanedLink, quality: nil)
            let title = info.title
            queue.enqueue(
                title: title,
                sourceLink: cleanedLink,
                primaryURL: url,
                fallbackURL: fallback == url ? nil : fallback
            )
            videoLink = ""
            loadState = .idle
        } catch let error as APIError {
            loadState = .error(error.errorDescription ?? "Unbekannter Fehler")
        } catch {
            loadState = .error(error.localizedDescription)
        }
    }

    @ViewBuilder
    private var previewPlayerSheet: some View {
        if case .loaded(let info) = loadState, let url = info.previewURL {
            VideoPlayer(player: AVPlayer(url: url))
                .ignoresSafeArea()
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - State Views (Premium)

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: AppThemePremium.xl) {
            Image(systemName: "film.stack")
                .font(.system(size: 48))
                .foregroundStyle(AppColorsPremium.accentBlue)
                .opacity(0.6)

            VStack(spacing: AppThemePremium.sm) {
                Text("Starten Sie jetzt")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppColorsPremium.textPrimary)

                Text("Geben Sie einen Video-Link ein oder fügen Sie einen aus Ihrer Zwischenablage ein, um zu beginnen.")
                    .font(.subheadline)
                    .foregroundStyle(AppColorsPremium.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppThemePremium.xxl)
    }
}

struct LoadingStateView: View {
    var body: some View {
        VStack(spacing: AppThemePremium.lg) {
            ProgressView()
                .tint(AppColorsPremium.accentBlue)
                .scaleEffect(1.2, anchor: .center)

            VStack(spacing: AppThemePremium.sm) {
                Text("Video wird geprüft")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppColorsPremium.textPrimary)

                Text("Metadaten und verfügbare Qualitäten werden geladen...")
                    .font(.subheadline)
                    .foregroundStyle(AppColorsPremium.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppThemePremium.xxl)
    }
}

struct ErrorStateView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        PremiumGlassCard {
            VStack(alignment: .leading, spacing: AppThemePremium.md) {
                HStack(alignment: .top, spacing: AppThemePremium.md) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(AppColorsPremium.error)

                    VStack(alignment: .leading, spacing: AppThemePremium.xs) {
                        Text("Etwas ist schief gelaufen")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppColorsPremium.textPrimary)

                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(AppColorsPremium.textSecondary)
                            .lineLimit(3)
                    }
                }

                HStack(spacing: AppThemePremium.md) {
                    Button(action: onRetry) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Erneut versuchen")
                        }
                    }
                    .buttonStyle(PremiumSecondaryButtonStyle())
                }
            }
        }
    }
}

#Preview {
    ContentViewPremium(pendingLink: .constant(nil))
}

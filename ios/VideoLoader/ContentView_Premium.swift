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
                    VStack(spacing: Aurora.Spacing.section) {
                        // MARK: - Hero Section
                        heroSection

                        // MARK: - Server Status (kompakt, oben)
                        serverStatusBadge

                        // MARK: - Main Content (dynamisch)
                        mainContent

                        Spacer(minLength: Aurora.Spacing.xl)
                    }
                    .padding(.horizontal, Aurora.Spacing.screen)
                    .padding(.vertical, Aurora.Spacing.lg)
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
                            .foregroundStyle(Aurora.Colors.accentBlue)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsViewPremium(
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
        VStack(alignment: .leading, spacing: Aurora.Spacing.md) {
            Text("Video hinzufügen")
                .font(Aurora.Typography.title2)
                .foregroundStyle(Aurora.Colors.textPrimary)

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
                    .font(Aurora.Typography.subheadline.weight(.semibold))
                }
                .buttonStyle(PremiumSecondaryButtonStyle())
            }
        }
    }

    // MARK: - Server Status Badge (kompakt)
    private var serverStatusBadge: some View {
        HStack(spacing: Aurora.Spacing.md) {
            HStack(spacing: 6) {
                Circle()
                    .fill(serverStatusColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: serverStatusColor.opacity(0.5), radius: 4)

                Text(serverStatusText)
                    .font(Aurora.Typography.caption.weight(.semibold))
                    .foregroundStyle(Aurora.Colors.textSecondary)
            }

            Spacer()

            if serverOnline == false {
                Button {
                    showSettings = true
                } label: {
                    Text("Einstellungen")
                        .font(Aurora.Typography.caption.weight(.semibold))
                        .foregroundStyle(Aurora.Colors.accentTeal)
                }
            }
        }
        .padding(.horizontal, Aurora.Spacing.md)
        .padding(.vertical, Aurora.Spacing.sm)
        .background(Aurora.Colors.glassBg)
        .overlay(
            RoundedRectangle(cornerRadius: Aurora.CornerRadius.small)
                .stroke(Aurora.Colors.glassBorder, lineWidth: 0.8)
        )
        .cornerRadius(Aurora.CornerRadius.small)
    }

    private var serverStatusColor: Color {
        switch serverOnline {
        case .some(true): return Aurora.Colors.success
        case .some(false): return Aurora.Colors.error
        case .none: return Aurora.Colors.textTertiary
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
        VStack(spacing: Aurora.Spacing.lg) {
            // Video Preview
            PremiumGlassCard {
                ZStack {
                    AsyncImage(url: info.thumbnailURL) { image in
                        image.resizable().aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Rectangle()
                            .fill(Aurora.Colors.glassBgStrong)
                            .aspectRatio(16 / 9, contentMode: .fit)
                            .overlay {
                                Image(systemName: "film")
                                    .font(.largeTitle)
                                    .foregroundStyle(Aurora.Colors.textTertiary)
                            }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: Aurora.CornerRadius.large))

                    if info.previewURL != nil {
                        Button {
                            showPreviewPlayer = true
                        } label: {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(.white)
                                .shadow(color: Aurora.Colors.accentBlueGlow, radius: 12)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: Aurora.Spacing.sm) {
                    Text(info.title)
                        .font(Aurora.Typography.headline)
                        .foregroundStyle(Aurora.Colors.textPrimary)
                        .lineLimit(2)

                    HStack(spacing: 12) {
                        if let uploader = info.uploader {
                            Label(uploader, systemImage: "person.circle.fill")
                                .font(Aurora.Typography.caption)
                                .foregroundStyle(Aurora.Colors.textSecondary)
                        }
                        if let duration = info.durationText {
                            Label(duration, systemImage: "clock.fill")
                                .font(Aurora.Typography.caption)
                                .foregroundStyle(Aurora.Colors.textSecondary)
                        }
                    }
                }
            }

            // Quality Selection
            if !info.qualities.isEmpty {
                VStack(alignment: .leading, spacing: Aurora.Spacing.sm) {
                    Text("Qualität")
                        .font(Aurora.Typography.subheadline.weight(.semibold))
                        .foregroundStyle(Aurora.Colors.textPrimary)

                    PremiumGlassCard {
                        Picker("Qualität", selection: $selectedQuality) {
                            ForEach(info.qualities) { quality in
                                Text(quality.label).tag(Optional(quality))
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Aurora.Colors.accentTeal)
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
        UIPasteboard.general.detectPatterns(for: [.probableWebURL]) { result in
            DispatchQueue.main.async {
                if case .success(let patterns) = result, patterns.contains(.probableWebURL) {
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
            loadState = .error(error.errorDescription)
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
            loadState = .error(error.errorDescription)
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
    var title: String = "Starten Sie jetzt"
    var message: String = "Geben Sie einen Video-Link ein oder fügen Sie einen aus Ihrer Zwischenablage ein, um zu beginnen."
    var systemImage: String = "film.stack"

    var body: some View {
        VStack(spacing: Aurora.Spacing.xl) {
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundStyle(Aurora.Colors.accentBlue)
                .opacity(0.6)

            VStack(spacing: Aurora.Spacing.sm) {
                Text(title)
                    .font(Aurora.Typography.headline)
                    .foregroundStyle(Aurora.Colors.textPrimary)

                Text(message)
                    .font(Aurora.Typography.subheadline)
                    .foregroundStyle(Aurora.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Aurora.Spacing.xxl)
    }
}

struct LoadingStateView: View {
    var body: some View {
        VStack(spacing: Aurora.Spacing.lg) {
            ProgressView()
                .tint(Aurora.Colors.accentBlue)
                .scaleEffect(1.2, anchor: .center)

            VStack(spacing: Aurora.Spacing.sm) {
                Text("Video wird geprüft")
                    .font(Aurora.Typography.headline)
                    .foregroundStyle(Aurora.Colors.textPrimary)

                Text("Metadaten und verfügbare Qualitäten werden geladen...")
                    .font(Aurora.Typography.subheadline)
                    .foregroundStyle(Aurora.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Aurora.Spacing.xxl)
    }
}

struct ErrorStateView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        PremiumGlassCard {
            VStack(alignment: .leading, spacing: Aurora.Spacing.md) {
                HStack(alignment: .top, spacing: Aurora.Spacing.md) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Aurora.Colors.error)

                    VStack(alignment: .leading, spacing: Aurora.Spacing.xs) {
                        Text("Etwas ist schief gelaufen")
                            .font(Aurora.Typography.headline)
                            .foregroundStyle(Aurora.Colors.textPrimary)

                        Text(message)
                            .font(Aurora.Typography.subheadline)
                            .foregroundStyle(Aurora.Colors.textSecondary)
                            .lineLimit(3)
                    }
                }

                HStack(spacing: Aurora.Spacing.md) {
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

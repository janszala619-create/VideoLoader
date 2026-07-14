import SwiftUI
import AVKit

struct ContentView: View {
    @Binding var pendingLink: String?
    @Environment(\.scenePhase) private var scenePhase

    private static let defaultLocalServerURL = "http://100.80.105.62:9876"
    private static let invalidVideoInputMessage = "Bitte gib einen YouTube-Link ins Linkfeld ein. Die Server-Adresse gehört in die Einstellungen."

    @AppStorage("serverURL_videoLoader") private var macServerURL = "http://100.80.105.62:9876"
    @AppStorage("serverURL_vidSave") private var cloudServerURL = "http://158.101.168.11:8765"
    @AppStorage("activeServer") private var activeServerRaw = ServerKind.videoLoader.rawValue
    @AppStorage("didMigrateToLocalServer8765") private var didMigrateToLocalServer = false
    @AppStorage("didMigrateToWindowsLocalServer8765") private var didMigrateToWindowsLocalServer = false
    @AppStorage("didMigrateToLocalServer9876") private var didMigrateToLocalServer9876 = false

    @State private var clipboardHasLink = false
    @State private var videoLink = ""
    @State private var info: VideoInfo?
    @State private var isLoadingInfo = false
    @State private var selectedQuality: QualityOption?
    @State private var errorMessage: String?
    @State private var showSettings = false
    @State private var showPreviewPlayer = false
    @State private var justQueuedTitle: String?
    @State private var serverOnline: Bool?
    @State private var serverCheckToken = UUID()

    @ObservedObject private var queue = DownloadQueue.shared

    private var activeServer: ServerKind {
        ServerKind(rawValue: activeServerRaw) ?? .videoLoader
    }

    private var activeBaseURL: String {
        activeServer == .videoLoader ? macServerURL : cloudServerURL
    }

    private var cleanedLink: String {
        videoLink.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isIdle: Bool {
        cleanedLink.isEmpty && errorMessage == nil && !isLoadingInfo && justQueuedTitle == nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    linkInputSection
                    serverRow

                    if let errorMessage {
                        ErrorStateView(
                            title: "Aktion fehlgeschlagen",
                            message: errorMessage,
                            retryTitle: "Einstellungen öffnen",
                            retryAction: { showSettings = true }
                        )
                        .transition(AppMotion.bannerTransition)
                    }

                    if isLoadingInfo {
                        LoadingStateView(
                            title: "Video wird geprüft",
                            message: "Metadaten und verfügbare Qualitäten werden geladen."
                        )
                        .transition(AppMotion.contentAppearTransition)
                    }

                    if let justQueuedTitle {
                        queuedBanner(for: justQueuedTitle)
                            .transition(AppMotion.bannerTransition)
                    }

                    if let info {
                        Group {
                            previewSection(info)
                            qualitySection(info)
                            downloadButton
                        }
                        .transition(AppMotion.contentAppearTransition)
                    } else if isIdle {
                        EmptyStateView(
                            systemImage: "link.badge.plus",
                            title: "Bereit für deinen ersten Download",
                            message: "Füge oben einen Video-Link ein und tippe auf „Prüfen“, um Vorschau und Qualitäten zu laden."
                        )
                        .transition(AppMotion.contentAppearTransition)
                    }
                }
                .animation(AppMotion.appearTransition, value: errorMessage == nil)
                .animation(AppMotion.appearTransition, value: isLoadingInfo)
                .animation(AppMotion.appearTransition, value: info == nil)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
            .background(AppGlassBackground())
            .navigationTitle("VideoLoader")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(AppTheme.primaryText)
                    }
                    .accessibilityLabel("Einstellungen öffnen")
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
                if !didMigrateToLocalServer {
                    if macServerURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        macServerURL = Self.defaultLocalServerURL
                    }
                    activeServerRaw = ServerKind.videoLoader.rawValue
                    didMigrateToLocalServer = true
                }
                if !didMigrateToWindowsLocalServer {
                    let currentLocalURL = macServerURL.trimmingCharacters(in: .whitespacesAndNewlines)
                    if currentLocalURL == "http://192.168.1.23:8000" ||
                        currentLocalURL == "http://100.80.105.62:8765" ||
                        currentLocalURL == cloudServerURL.trimmingCharacters(in: .whitespacesAndNewlines) {
                        macServerURL = Self.defaultLocalServerURL
                    }
                    activeServerRaw = ServerKind.videoLoader.rawValue
                    didMigrateToWindowsLocalServer = true
                }
                if !didMigrateToLocalServer9876 {
                    migrateLocalServerURLTo9876IfNeeded()
                    activeServerRaw = ServerKind.videoLoader.rawValue
                    didMigrateToLocalServer9876 = true
                }
                if activeBaseURL.isEmpty { showSettings = true }
                logActiveServer()
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

    // MARK: - Server Row (kompakt, zurückhaltend – kein eigener Abschnitt)

    private var serverRow: some View {
        HStack(spacing: AppSpacing.sm) {
            Picker("", selection: $activeServerRaw) {
                ForEach(ServerKind.allCases) { kind in
                    Text(kind.label).tag(kind.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.small)
            .onChange(of: activeServerRaw) { _, _ in
                info = nil
                errorMessage = nil
                logActiveServer()
                Task { await checkServer() }
            }

            serverStatusPill
        }
    }

    private var serverStatusPill: some View {
        Button {
            Task { await checkServer() }
        } label: {
            HStack(spacing: AppSpacing.xs) {
                AppStatusDot(
                    color: serverOnline == true ? AppTheme.info :
                        serverOnline == false ? AppTheme.danger :
                        AppTheme.secondaryText.opacity(0.6),
                    diameter: 7
                )

                Text(serverOnline == true ? "Online" :
                     serverOnline == false ? "Offline" : "…")
                    .font(AppTypography.caption.weight(.medium))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.sm)
            .background(
                Capsule()
                    .fill(AppColorsPremium.glassSurfaceStrong)
                    .overlay(Capsule().stroke(AppColorsPremium.glassBorder, lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Serverstatus prüfen")
    }

    // MARK: - Link-Eingabe (Hero-Card – wichtigster Call-to-Action)

    private var linkInputSection: some View {
        AppCard {
            AppSectionHeader(title: "Video-Link")

            HStack(spacing: AppSpacing.sm) {
                AppTextField(
                    placeholder: "Link hier einfügen",
                    text: $videoLink,
                    systemImage: "link",
                    keyboardType: .URL,
                    autocapitalization: .never,
                    disablesAutocorrection: true
                )

                if videoLink.isEmpty {
                    Button {
                        if let pasted = UIPasteboard.general.string {
                            videoLink = pasted
                            errorMessage = nil
                            Task { await loadInfo() }
                        }
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .frame(width: AppSpacing.controlHeight, height: AppSpacing.controlHeight)
                    .accessibilityLabel("Link aus Zwischenablage einfügen")
                } else {
                    Button {
                        videoLink = ""
                        info = nil
                        errorMessage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .frame(width: AppSpacing.controlHeight, height: AppSpacing.controlHeight)
                    .accessibilityLabel("Linkfeld leeren")
                }
            }

            HStack(spacing: AppSpacing.sm) {
                AppButton(
                    title: "Prüfen",
                    kind: .primary,
                    systemImage: "magnifyingglass",
                    isLoading: isLoadingInfo,
                    isDisabled: cleanedLink.isEmpty
                ) {
                    Task { await loadInfo() }
                }

                if clipboardHasLink && videoLink.isEmpty {
                    AppButton(
                        title: "Einfügen",
                        kind: .secondary,
                        systemImage: "doc.on.clipboard"
                    ) {
                        if let pasted = UIPasteboard.general.string {
                            videoLink = pasted
                            clipboardHasLink = false
                            errorMessage = nil
                            Task { await loadInfo() }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Zur Warteschlange hinzugefügt

    private func queuedBanner(for title: String) -> some View {
        Group {
            if let job = queue.jobs.last(where: { $0.title == title }) {
                DownloadProgressCard(
                    title: job.title,
                    description: "Wird im Tab „Downloads“ verarbeitet",
                    progress: job.status == .running ? job.progress : nil,
                    statusText: queuedStatusText(for: job),
                    statusTone: queuedStatusTone(for: job)
                )
            } else {
                AppCard {
                    HStack(alignment: .top, spacing: AppSpacing.md) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(AppTheme.success)

                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text("Zur Warteschlange hinzugefügt")
                                .font(AppTypography.sectionTitle)
                                .foregroundStyle(AppTheme.primaryText)
                            Text("„\(title)“ wird jetzt im Tab „Downloads“ verarbeitet.")
                                .font(AppTypography.footnote)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                    }
                }
            }
        }
    }

    private func queuedStatusText(for job: DownloadJob) -> String {
        switch job.status {
        case .waiting: return "Wartet in der Warteschlange"
        case .running: return "Wird heruntergeladen · \(Int(job.progress * 100))%"
        case .done: return "Abgeschlossen"
        case .failed: return "Fehlgeschlagen"
        }
    }

    private func queuedStatusTone(for job: DownloadJob) -> Color {
        switch job.status {
        case .waiting: return AppTheme.secondaryText
        case .running: return AppTheme.accent
        case .done: return AppTheme.success
        case .failed: return AppTheme.danger
        }
    }

    // MARK: - Vorschau

    private func previewSection(_ info: VideoInfo) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            AppSectionHeader(title: "Vorschau")

            AppCard {
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
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))

                    if info.previewURL != nil {
                        Button {
                            showPreviewPlayer = true
                        } label: {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: AppIconSize.hero))
                                .foregroundStyle(.white)
                                .appShadow(AppShadow(color: AppColorsPremium.accentGlow, radius: 18, x: 0, y: 6))
                        }
                        .accessibilityLabel("Videovorschau abspielen")
                    }
                }

                Text(info.title)
                    .font(AppTypography.subtitle)
                    .foregroundStyle(AppTheme.primaryText)

                HStack(spacing: AppSpacing.md) {
                    if let uploader = info.uploader {
                        Label(uploader, systemImage: "person.circle")
                    }
                    if let duration = info.durationText {
                        Label(duration, systemImage: "clock")
                    }
                }
                .font(AppTypography.footnote)
                .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }

    // MARK: - Qualität

    private func qualitySection(_ info: VideoInfo) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            AppSectionHeader(
                title: "Qualität",
                subtitle: selectedQuality.map { "Ausgewählt: \($0.label)" }
            )

            if info.qualities.isEmpty {
                EmptyStateView(
                    systemImage: "checkmark.seal",
                    title: "Automatische Qualität",
                    message: "Für dieses Video bietet der Server nur eine Version an. Wir laden automatisch die beste verfügbare Qualität herunter."
                )
            } else {
                AppCard {
                    VStack(spacing: AppSpacing.sm) {
                        ForEach(info.qualities) { quality in
                            QualityOptionRow(
                                title: quality.label,
                                isSelected: selectedQuality?.id == quality.id,
                                isRecommended: quality.id == info.qualities.first?.id,
                                onSelect: { selectedQuality = quality }
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Download

    private var downloadButton: some View {
        AppButton(
            title: "Download starten",
            kind: .primary,
            systemImage: "arrow.down.circle.fill"
        ) {
            enqueueDownload()
        }
    }

    // MARK: - Vorschau-Player Sheet

    @ViewBuilder
    private var previewPlayerSheet: some View {
        if let url = info?.previewURL {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                VideoPlayer(player: AVPlayer(url: url))
                    .ignoresSafeArea()
            }
            .presentationDragIndicator(.visible)
            .preferredColorScheme(.dark)
        } else {
            ZStack {
                AppGlassBackground()
                Text("Für dieses Video ist keine Vorschau verfügbar.")
                    .font(AppTypography.body)
                    .foregroundStyle(AppTheme.secondaryText)
                    .padding(AppSpacing.lg)
            }
        }
    }

    // MARK: - Aktionen

    private func consumePendingLink() {
        guard let link = pendingLink, !link.isEmpty else { return }
        pendingLink = nil
        videoLink = link
        justQueuedTitle = nil
        errorMessage = nil
        Task { await loadInfo() }
    }

    private func detectClipboardLink() {
        guard cleanedLink.isEmpty, info == nil else { return }
        UIPasteboard.general.detectPatterns(for: [.probableWebURL]) { result in
            DispatchQueue.main.async {
                if case .success(let patterns) = result, patterns.contains(.probableWebURL) {
                    clipboardHasLink = true
                }
            }
        }
    }

    private func checkServer() async {
        let token = UUID()
        serverCheckToken = token
        serverOnline = nil
        guard !activeBaseURL.trimmingCharacters(in: .whitespaces).isEmpty else {
            if serverCheckToken == token { serverOnline = false }
            return
        }
        let api = ServerAPI(kind: activeServer, baseURL: activeBaseURL)
        let reachable = await api.isReachable()
        // Ein inzwischen gestarteter, neuerer Check hat Vorrang – dieses (ältere)
        // Ergebnis würde sonst den aktuelleren Status wieder überschreiben (Flackern).
        if serverCheckToken == token {
            serverOnline = reachable
        }
    }

    private func loadInfo() async {
        info = nil
        justQueuedTitle = nil
        errorMessage = nil
        guard validateVideoInput() else { return }
        isLoadingInfo = true
        defer { isLoadingInfo = false }
        do {
            let api = ServerAPI(kind: activeServer, baseURL: activeBaseURL)
            let result = try await api.fetchInfo(for: cleanedLink)
            info = result
            selectedQuality = result.qualities.first
        } catch let error as APIError {
            #if DEBUG
            print("[VideoLoader][loadInfo] APIError=\(error) link=\"\(cleanedLink)\" server=\(activeServer.rawValue) baseURL=\"\(activeBaseURL)\"")
            #endif
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Das Video konnte nicht geprüft werden: \(error.localizedDescription)"
        }
    }

    private func enqueueDownload() {
        do {
            guard validateVideoInput() else { return }
            let api = ServerAPI(kind: activeServer, baseURL: activeBaseURL)
            let url = try api.downloadURL(for: cleanedLink, quality: selectedQuality)
            let fallback = try? api.downloadURL(for: cleanedLink, quality: nil)
            let title = info?.title ?? "Video"
            queue.enqueue(
                title: title,
                sourceLink: cleanedLink,
                primaryURL: url,
                fallbackURL: fallback == url ? nil : fallback
            )
            AppHaptics.mediumImpact()
            withAnimation(AppMotion.statusTransition) {
                justQueuedTitle = title
                videoLink = ""
                info = nil
                errorMessage = nil
            }
            Task {
                try? await Task.sleep(for: .seconds(3))
                withAnimation(AppMotion.statusTransition) {
                    justQueuedTitle = nil
                }
            }
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func validateVideoInput() -> Bool {
        let lowercased = cleanedLink.lowercased()
        if lowercased.contains("/api/health") ||
            lowercased.contains("/api/info") ||
            lowercased.contains("/api/download") ||
            lowercased.hasSuffix("/health") {
            errorMessage = Self.invalidVideoInputMessage
            return false
        }
        guard let videoHost = URLComponents(string: cleanedLink)?.host?.lowercased(),
              let baseHost = Self.host(fromServerURL: activeBaseURL) else {
            return true
        }
        if videoHost == baseHost {
            errorMessage = Self.invalidVideoInputMessage
            return false
        }
        return true
    }

    private func migrateLocalServerURLTo9876IfNeeded() {
        let current = macServerURL.trimmingCharacters(in: .whitespacesAndNewlines)
        var lowercased = current.lowercased()
        while lowercased.hasSuffix("/") {
            lowercased.removeLast()
        }
        let knownBadValues: Set<String> = [
            "",
            "http://158.101.168.11:8765",
            "http://100.80.105.62:8765",
            "/api/health",
        ]
        if knownBadValues.contains(current) ||
            lowercased.contains("/api/health") ||
            lowercased.contains("/api/info") ||
            lowercased.contains("/api/download") ||
            lowercased.contains("youtube.com") ||
            lowercased.contains("youtu.be") {
            macServerURL = Self.defaultLocalServerURL
        }
    }

    private static func host(fromServerURL serverURL: String) -> String? {
        var trimmed = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if !trimmed.lowercased().hasPrefix("http") {
            trimmed = "http://\(trimmed)"
        }
        return URLComponents(string: trimmed)?.host?.lowercased()
    }

    private func logActiveServer() {
        #if DEBUG
        let resolved = activeServer
        let baseURL = activeBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = baseURL.hasPrefix("http") ? baseURL : "http://\(baseURL)"
        print("[VideoLoader] activeServerRaw=\(activeServerRaw) resolvedServer=\(resolved.rawValue) activeBaseURL=\(baseURL) normalizedBase=\(normalized)")
        if resolved == .vidSave {
            print("[VideoLoader] warning=VidSave legacy server mode is active")
        }
        #endif
    }
}

#Preview {
    ContentView(pendingLink: .constant(nil))
}

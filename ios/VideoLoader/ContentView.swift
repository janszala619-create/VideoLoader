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
    @AppStorage("preferredQualityID") private var preferredQualityID = "auto"

    @State private var clipboardHasLink = false
    @State private var videoLink = ""
    @State private var info: VideoInfo?
    @State private var isLoadingInfo = false
    @State private var selectedQuality: QualityOption?
    @State private var errorMessage: String?
    @State private var showSettings = false
    @State private var showPreviewPlayer = false
    @State private var showQualityPicker = false
    @State private var justQueuedTitle: String?
    @State private var serverOnline: Bool?
    @State private var linkValidationMessage: String?

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

    private var canCheckVideo: Bool {
        !cleanedLink.isEmpty && Self.looksLikeWebURL(cleanedLink) && !isLoadingInfo
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppGlassTheme.sectionSpacing) {
                    serverRow
                    linkInputSection

                    if let errorMessage {
                        GlassErrorStateView(
                            title: "Aktion fehlgeschlagen",
                            message: errorMessage,
                            actionTitle: "Einstellungen öffnen",
                            action: { showSettings = true }
                        )
                    }

                    if isLoadingInfo {
                        GlassLoadingStateView(
                            title: "Video wird geprüft",
                            message: "Metadaten und verfügbare Qualitäten werden geladen."
                        )
                    }

                    if let justQueuedTitle {
                        GlassStatusBanner(
                            tone: .success,
                            title: "Zur Warteschlange hinzugefügt",
                            message: "„\(justQueuedTitle)“ wird jetzt im Tab „Downloads“ verarbeitet."
                        )
                    }

                    if let info {
                        previewSection(info)
                        qualitySection(info)
                        downloadButton
                    } else if !isLoadingInfo && errorMessage == nil {
                        GlassEmptyStateView(
                            title: "Noch kein Video ausgewählt",
                            message: "Füge einen Video-Link ein, prüfe das Video und wähle anschließend die gewünschte Qualität. YouTube und weitere Quellen sind je nach Server verfügbar.",
                            systemImage: "play.rectangle.on.rectangle"
                        )
                    }
                }
                .padding(.bottom, 110)
            }
            .padding(.horizontal, AppGlassTheme.screenPadding)
            .padding(.top, AppGlassSpacing.md)
            .background(AppGlassBackground())
            .navigationTitle("VideoLoader")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(AppGlassColors.textPrimary)
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
            .sheet(isPresented: $showQualityPicker) {
                if let info {
                    QualityPickerSheet(
                        info: info,
                        selectedQuality: $selectedQuality,
                        preferredQualityID: $preferredQualityID
                    )
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .preferredColorScheme(.dark)
                }
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
            .onChange(of: videoLink) { _, _ in
                if linkValidationMessage != nil {
                    linkValidationMessage = nil
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    detectClipboardLink()
                }
            }
        }
    }

    // MARK: - Server Row (kompakt, kein eigener Abschnitt)

    private var serverRow: some View {
        HStack(spacing: AppGlassSpacing.md) {
            Picker("", selection: $activeServerRaw) {
                ForEach(ServerKind.allCases) { kind in
                    Text(kind.label).tag(kind.rawValue)
                }
            }
            .pickerStyle(.segmented)
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
            HStack(spacing: 5) {
                Circle()
                    .fill(serverOnline == true ? AppGlassColors.success :
                          serverOnline == false ? AppGlassColors.error :
                          AppGlassColors.textTertiary)
                    .frame(width: 7, height: 7)
                    .shadow(
                        color: serverOnline == true ? AppGlassColors.success.opacity(0.7) : .clear,
                        radius: 4
                    )

                Text(serverStatusTitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppGlassColors.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(AppGlassColors.glassSurfaceStrong)
                    .overlay(Capsule().stroke(AppGlassColors.glassBorder, lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(serverStatusAccessibilityLabel)
    }

    private var serverStatusTitle: String {
        switch serverOnline {
        case true:
            return activeServer == .videoLoader ? "Lokal online" : "Cloud online"
        case false:
            return "Server offline"
        case nil:
            return "Prüfen…"
        }
    }

    private var serverStatusAccessibilityLabel: String {
        switch serverOnline {
        case true:
            return activeServer == .videoLoader ? "Lokaler Server online" : "Cloud-Server online"
        case false:
            return "Server offline. Zum erneuten Prüfen doppeltippen."
        case nil:
            return "Serverstatus wird geprüft"
        }
    }

    // MARK: - Link-Eingabe (kein GlassCard-Wrapper)

    private var linkInputSection: some View {
        VStack(alignment: .leading, spacing: AppGlassSpacing.md) {
            GlassInputField(
                label: "Video-Link",
                placeholder: "Link hier einfügen",
                text: $videoLink,
                keyboardType: .URL,
                textContentType: .URL,
                autocapitalization: .never,
                disablesAutocorrection: true
            ) {
                if videoLink.isEmpty {
                    Button {
                        pasteFromClipboard()
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                            .foregroundStyle(AppGlassColors.textSecondary)
                    }
                    .frame(minWidth: AppGlassTheme.controlHeight, minHeight: AppGlassTheme.controlHeight)
                    .accessibilityLabel("Link aus Zwischenablage einfügen")
                } else {
                    Button {
                        videoLink = ""
                        info = nil
                        errorMessage = nil
                        linkValidationMessage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppGlassColors.textSecondary)
                    }
                    .frame(minWidth: AppGlassTheme.controlHeight, minHeight: AppGlassTheme.controlHeight)
                    .accessibilityLabel("Linkfeld leeren")
                }
            }

            if let linkValidationMessage {
                Label(linkValidationMessage, systemImage: "exclamationmark.circle.fill")
                    .font(AppGlassTypography.footnote)
                    .foregroundStyle(AppGlassColors.warning)
            } else if !cleanedLink.isEmpty && !Self.looksLikeWebURL(cleanedLink) {
                Label("Bitte füge einen gültigen Video-Link ein.", systemImage: "exclamationmark.circle.fill")
                    .font(AppGlassTypography.footnote)
                    .foregroundStyle(AppGlassColors.warning)
            }

            HStack(spacing: AppGlassSpacing.sm) {
                Button {
                    Task { await loadInfo() }
                } label: {
                    if isLoadingInfo {
                        HStack(spacing: AppGlassSpacing.sm) {
                            ProgressView()
                                .tint(.white)
                            Text("Video wird geprüft…")
                        }
                    } else {
                        Label("Prüfen", systemImage: "magnifyingglass")
                    }
                }
                .buttonStyle(GlassPrimaryButtonStyle())
                .disabled(!canCheckVideo)

                if clipboardHasLink && videoLink.isEmpty {
                    Button {
                        pasteFromClipboard()
                    } label: {
                        Label("Einfügen", systemImage: "doc.on.clipboard")
                    }
                    .buttonStyle(GlassSecondaryButtonStyle())
                }
            }
        }
    }

    // MARK: - Vorschau

    private func previewSection(_ info: VideoInfo) -> some View {
        VStack(alignment: .leading, spacing: AppGlassSpacing.md) {
            AppGlassSectionHeader(title: "Vorschau")

            GlassCard {
                ZStack {
                    AsyncImage(url: info.thumbnailURL) { image in
                        image.resizable().aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Rectangle()
                            .fill(AppGlassColors.glassSurfaceStrong)
                            .aspectRatio(16 / 9, contentMode: .fit)
                            .overlay {
                                Image(systemName: "film")
                                    .font(.largeTitle)
                                    .foregroundStyle(AppGlassColors.textTertiary)
                            }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: AppGlassTheme.radiusLarge, style: .continuous))

                    if info.previewURL != nil {
                        Button {
                            showPreviewPlayer = true
                        } label: {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(.white)
                                .shadow(color: AppGlassColors.accentGlow, radius: 18, x: 0, y: 6)
                        }
                        .accessibilityLabel("Videovorschau abspielen")
                    }
                }

                Text(info.title)
                    .font(AppGlassTypography.title3)
                    .foregroundStyle(AppGlassColors.textPrimary)

                HStack(spacing: 12) {
                    if let uploader = info.uploader {
                        Label(uploader, systemImage: "person.circle")
                    }
                    if let duration = info.durationText {
                        Label(duration, systemImage: "clock")
                    }
                }
                .font(AppGlassTypography.subheadline)
                .foregroundStyle(AppGlassColors.textSecondary)
            }
        }
    }

    // MARK: - Qualität

    private func qualitySection(_ info: VideoInfo) -> some View {
        VStack(alignment: .leading, spacing: AppGlassSpacing.md) {
            AppGlassSectionHeader(title: "Qualität")

            if info.qualities.isEmpty {
                GlassStatusBanner(
                    tone: .warning,
                    title: "Keine Qualitätsliste verfügbar",
                    message: "Die App verwendet beim Download die beste Qualität, die der aktive Server bereitstellt."
                )
            } else {
                Button {
                    showQualityPicker = true
                } label: {
                    HStack(spacing: AppGlassSpacing.md) {
                        VStack(alignment: .leading, spacing: AppGlassSpacing.xs) {
                            Text("Qualität auswählen")
                                .font(AppGlassTypography.headline)
                                .foregroundStyle(AppGlassColors.textPrimary)
                            Text(selectedQualitySummary)
                                .font(AppGlassTypography.footnote)
                                .foregroundStyle(AppGlassColors.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppGlassColors.textTertiary)
                    }
                    .padding(AppGlassSpacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: AppGlassTheme.radiusLarge, style: .continuous)
                            .fill(AppGlassColors.glassSurfaceStrong)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppGlassTheme.radiusLarge, style: .continuous)
                            .stroke(AppGlassColors.glassBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Qualität auswählen")

                if info.hasLimitedQualities {
                    GlassStatusBanner(
                        tone: .warning,
                        title: "Nur begrenzte Qualität verfügbar",
                        message: "Der aktuelle Server liefert für dieses Video keine höheren Qualitätsoptionen."
                    )
                } else if selectedQuality?.isAutomatic == true {
                    Text("Automatisch lädt die beste verfügbare Qualität des aktiven Servers.")
                        .font(AppGlassTypography.footnote)
                        .foregroundStyle(AppGlassColors.textSecondary)
                }
            }
        }
    }

    private var selectedQualitySummary: String {
        guard let selectedQuality else { return "Beste verfügbare Qualität" }
        if selectedQuality.isAutomatic {
            return "Automatisch · beste verfügbare Qualität"
        }
        let detail = selectedQuality.detailText
        return detail.isEmpty ? selectedQuality.label : "\(selectedQuality.label) · \(detail)"
    }

    // MARK: - Download

    private var downloadButton: some View {
        Button {
            enqueueDownload()
        } label: {
            Label("Download starten", systemImage: "arrow.down.circle.fill")
        }
        .buttonStyle(GlassPrimaryButtonStyle())
    }

    // MARK: - Vorschau-Player Sheet

    @ViewBuilder
    private var previewPlayerSheet: some View {
        if let url = info?.previewURL {
            ZStack {
                AppGlassColors.bgDeep.ignoresSafeArea()
                VideoPlayer(player: AVPlayer(url: url))
                    .ignoresSafeArea()
            }
            .presentationDragIndicator(.visible)
            .preferredColorScheme(.dark)
        } else {
            ZStack {
                AppGlassBackground()
                Text("Für dieses Video ist keine Vorschau verfügbar.")
                    .font(AppGlassTypography.body)
                    .foregroundStyle(AppGlassColors.textSecondary)
                    .padding()
            }
        }
    }

    // MARK: - Aktionen

    private func pasteFromClipboard() {
        guard let pasted = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !pasted.isEmpty else {
            linkValidationMessage = "Die Zwischenablage enthält keinen Link."
            clipboardHasLink = false
            return
        }
        guard Self.looksLikeWebURL(pasted) else {
            linkValidationMessage = "Die Zwischenablage enthält keinen gültigen Video-Link."
            clipboardHasLink = false
            return
        }
        videoLink = pasted
        clipboardHasLink = false
        linkValidationMessage = nil
        errorMessage = nil
        Task { await loadInfo() }
    }

    private func consumePendingLink() {
        guard let link = pendingLink, !link.isEmpty else { return }
        pendingLink = nil
        videoLink = link
        justQueuedTitle = nil
        errorMessage = nil
        linkValidationMessage = nil
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
        serverOnline = nil
        guard !activeBaseURL.trimmingCharacters(in: .whitespaces).isEmpty else {
            serverOnline = false
            return
        }
        let api = ServerAPI(kind: activeServer, baseURL: activeBaseURL)
        serverOnline = await api.isReachable()
    }

    private func loadInfo() async {
        info = nil
        justQueuedTitle = nil
        errorMessage = nil
        linkValidationMessage = nil
        guard validateVideoInput() else { return }
        isLoadingInfo = true
        defer { isLoadingInfo = false }
        do {
            let api = ServerAPI(kind: activeServer, baseURL: activeBaseURL)
            let result = try await api.fetchInfo(for: cleanedLink)
            info = result
            selectedQuality = preferredQuality(in: result.qualities)
        } catch let error as APIError {
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
            justQueuedTitle = title
            videoLink = ""
            info = nil
            errorMessage = nil
            Task {
                try? await Task.sleep(for: .seconds(3))
                justQueuedTitle = nil
            }
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func validateVideoInput() -> Bool {
        guard !cleanedLink.isEmpty, Self.looksLikeWebURL(cleanedLink) else {
            linkValidationMessage = "Bitte füge einen gültigen Video-Link ein."
            return false
        }
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

    private func preferredQuality(in qualities: [QualityOption]) -> QualityOption? {
        if let preferred = qualities.first(where: { $0.id == preferredQualityID }) {
            return preferred
        }
        if let automatic = qualities.first(where: { $0.isAutomatic }) {
            return automatic
        }
        return qualities.first
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

    private static func looksLikeWebURL(_ text: String) -> Bool {
        guard let components = URLComponents(string: text),
              let scheme = components.scheme?.lowercased(),
              let host = components.host,
              ["http", "https"].contains(scheme) else { return false }
        return host.contains(".")
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

// MARK: - Qualitätssheet

private struct QualityPickerSheet: View {
    let info: VideoInfo
    @Binding var selectedQuality: QualityOption?
    @Binding var preferredQualityID: String
    @Environment(\.dismiss) private var dismiss

    private var recommended: QualityOption? {
        info.qualities.first(where: { !$0.isAutomatic && !$0.isAudioOnly }) ??
            info.qualities.first(where: { $0.isAutomatic }) ??
            info.qualities.first
    }

    private var otherVideoOptions: [QualityOption] {
        info.qualities.filter {
            !$0.isAudioOnly && $0.id != recommended?.id && !$0.isAutomatic
        }
    }

    private var audioOptions: [QualityOption] {
        info.qualities.filter(\.isAudioOnly)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppGlassTheme.sectionSpacing) {
                    if let recommended {
                        qualityGroup(title: "Empfohlen", options: [recommended])
                    }

                    if !otherVideoOptions.isEmpty {
                        qualityGroup(title: "Weitere Optionen", options: otherVideoOptions)
                    }

                    if !audioOptions.isEmpty {
                        qualityGroup(title: "Audio", options: audioOptions)
                    }

                    if info.hasLimitedQualities {
                        GlassStatusBanner(
                            tone: .warning,
                            title: "Nur begrenzte Qualität verfügbar",
                            message: "Der aktuelle Server liefert für dieses Video keine höheren Qualitätsoptionen."
                        )
                    }

                    if selectedQuality?.isAutomatic == true {
                        GlassStatusBanner(
                            tone: .neutral,
                            title: "Automatisch",
                            message: "Die App lädt automatisch die beste verfügbare Qualität."
                        )
                    }
                }
                .padding(AppGlassTheme.screenPadding)
                .padding(.bottom, AppGlassSpacing.xl)
            }
            .background(AppGlassBackground())
            .navigationTitle("Qualität auswählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                        .foregroundStyle(AppGlassColors.textPrimary)
                }
            }
        }
    }

    private func qualityGroup(title: String, options: [QualityOption]) -> some View {
        VStack(alignment: .leading, spacing: AppGlassSpacing.md) {
            AppGlassSectionHeader(title: title)
            VStack(spacing: AppGlassSpacing.sm) {
                ForEach(options) { option in
                    qualityRow(option)
                }
            }
        }
    }

    private func qualityRow(_ option: QualityOption) -> some View {
        Button {
            selectedQuality = option
            preferredQualityID = option.id
            dismiss()
        } label: {
            HStack(spacing: AppGlassSpacing.md) {
                VStack(alignment: .leading, spacing: AppGlassSpacing.xs) {
                    Text(option.label)
                        .font(AppGlassTypography.headline)
                        .foregroundStyle(AppGlassColors.textPrimary)
                    Text(option.isAutomatic ? "Beste verfügbare Qualität" : option.detailText)
                        .font(AppGlassTypography.footnote)
                        .foregroundStyle(AppGlassColors.textSecondary)
                }
                Spacer()
                if selectedQuality?.id == option.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppGlassColors.accentPrimary)
                        .font(.title3)
                }
            }
            .frame(minHeight: AppGlassTheme.controlHeight)
            .padding(AppGlassSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: AppGlassTheme.radiusLarge, style: .continuous)
                    .fill(AppGlassColors.glassSurfaceStrong)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppGlassTheme.radiusLarge, style: .continuous)
                    .stroke(
                        selectedQuality?.id == option.id ? AppGlassColors.accentPrimary.opacity(0.45) : AppGlassColors.glassBorder,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(option.label), \(option.isAutomatic ? "automatisch beste Qualität" : option.detailText)")
    }
}

private extension VideoInfo {
    var hasLimitedQualities: Bool {
        let realHeights = qualities.compactMap(\.height)
        if realHeights.isEmpty {
            return qualities.contains(where: { $0.isAutomatic }) || qualities.count <= 1
        }
        return realHeights.allSatisfy { $0 <= 360 }
    }
}

#Preview {
    ContentView(pendingLink: .constant(nil))
}

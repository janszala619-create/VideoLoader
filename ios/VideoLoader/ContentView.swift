import SwiftUI
import AVKit
import UIKit

struct ContentView: View {
    @Binding var pendingLink: String?
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("serverURL_videoLoader") private var macServerURL = ""
    @AppStorage("serverURL_vidSave") private var cloudServerURL = "http://158.101.168.11:8765"
    @AppStorage("activeServer") private var activeServerRaw = ServerKind.vidSave.rawValue

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

    private var queueDoneCount: Int {
        queue.jobs.filter { $0.status == .done }.count
    }

    private var hasAnyStatus: Bool {
        errorMessage != nil || isLoadingInfo || justQueuedTitle != nil || info != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                    headerBlock
                    overviewCard

                    if let errorMessage {
                        ErrorStateView(
                            title: "Aktion fehlgeschlagen",
                            message: errorMessage,
                            actionTitle: "Einstellungen öffnen",
                            action: { showSettings = true }
                        )
                        .accessibilityLabel("Fehler beim Verarbeiten des Links")
                    }

                    if isLoadingInfo {
                        LoadingStateView(
                            title: "Video wird geprüft",
                            message: "Metadaten und verfügbare Qualitäten werden geladen."
                        )
                        .accessibilityLabel("Video wird geprüft")
                    }

                    if let justQueuedTitle {
                        successCard(
                            title: "Zur Warteschlange hinzugefügt",
                            message: "„\(justQueuedTitle)“ wird jetzt im Tab „Downloads“ weiterverarbeitet.",
                            systemImage: "checkmark.circle.fill",
                            tint: AppColors.success
                        )
                    }

                    serverSection
                    linkSection

                    if let info {
                        previewSection(info)
                        qualitySection(info)
                        downloadSection
                    } else if !hasAnyStatus {
                        EmptyStateView(
                            title: "Noch kein Video geprüft",
                            message: "Füge einen Video-Link ein oder übernimm ihn aus der Zwischenablage. Danach zeigen wir Serverstatus, Vorschau und Download-Optionen an.",
                            systemImage: "link"
                        )
                        .accessibilityLabel("Leerer Startzustand der Hauptansicht")
                    }
                }
                .padding(.horizontal, AppTheme.screenPadding)
                .padding(.top, AppSpacing.md)
            }
            .background(mainBackground)
            .navigationTitle("VideoLoader")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(AppTheme.navBarMaterial, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(AppColors.textPrimary)
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

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Video senden, prüfen, laden")
                .font(AppTypography.largeTitle)
                .foregroundStyle(AppColors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Text("Füge einen Link ein, prüfe die Video-Infos und schicke den Download mit einem klaren Hauptschritt in die Warteschlange.")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var overviewCard: some View {
        AppCard {
            SectionHeader(
                title: "Übersicht",
                subtitle: summarySubtitle
            )

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: AppSpacing.md),
                    GridItem(.flexible(), spacing: AppSpacing.md)
                ],
                spacing: AppSpacing.md
            ) {
                StatusMetricCard(
                    title: "Server",
                    value: serverStatusTitle,
                    tint: serverStatusTone.tint,
                    systemImage: serverStatusTone.iconName
                )
                StatusMetricCard(
                    title: "Warteschlange",
                    value: queue.jobs.isEmpty ? "Leer" : "\(queueDoneCount) fertig",
                    tint: AppColors.info,
                    systemImage: "arrow.down.circle.fill"
                )
                StatusMetricCard(
                    title: "Eingabe",
                    value: cleanedLink.isEmpty ? "Kein Link" : "Bereit",
                    tint: AppColors.warning,
                    systemImage: "link"
                )
                StatusMetricCard(
                    title: "Aktion",
                    value: info == nil ? "Prüfen" : "Download",
                    tint: AppColors.accentPrimary,
                    systemImage: "play.circle.fill"
                )
            }
        }
    }

    private var serverSection: some View {
        AppCard {
            SectionHeader(
                title: "Server",
                subtitle: "Wähle den aktiven Server und prüfe kurz, ob er erreichbar ist."
            )

            Picker("Aktiver Server", selection: $activeServerRaw) {
                ForEach(ServerKind.allCases) { kind in
                    Text(kind.label).tag(kind.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: activeServerRaw) { _, _ in
                info = nil
                errorMessage = nil
                Task { await checkServer() }
            }
            .accessibilityLabel("Aktiven Server auswählen")

            StatusRow(
                tone: serverStatusTone,
                title: serverStatusTitle,
                message: serverStatusText
            )

            Button {
                Task { await checkServer() }
            } label: {
                Label("Erneut prüfen", systemImage: "arrow.clockwise")
            }
            .buttonStyle(SecondaryButton())
            .accessibilityLabel("Serverstatus erneut prüfen")
        }
    }

    private var linkSection: some View {
        AppCard {
            SectionHeader(
                title: "Video-Link",
                subtitle: "Die Eingabe bleibt bewusst schlicht, damit der Download-Flow schnell bleibt."
            )

            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(spacing: AppSpacing.sm) {
                    TextField("Link hier einfügen", text: $videoLink)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.textPrimary)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .submitLabel(.go)
                        .accessibilityLabel("Video-Link")
                        .onSubmit {
                            Task { await loadInfo() }
                        }

                    if videoLink.isEmpty {
                        Button {
                            if let pasted = UIPasteboard.general.string {
                                videoLink = pasted
                                errorMessage = nil
                                Task { await loadInfo() }
                            }
                        } label: {
                            Image(systemName: "doc.on.clipboard")
                        }
                        .frame(width: AppTheme.controlHeight, height: AppTheme.controlHeight)
                        .accessibilityLabel("Link aus Zwischenablage einfügen")
                    } else {
                        Button {
                            videoLink = ""
                            info = nil
                            errorMessage = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .frame(width: AppTheme.controlHeight, height: AppTheme.controlHeight)
                        .accessibilityLabel("Linkfeld leeren")
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .frame(minHeight: AppTheme.controlHeight)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                        .fill(AppColors.surfaceElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                        .stroke(AppColors.border, lineWidth: 1)
                )

                Text("Füge einen direkten Video-Link ein oder übernimm einen erkannten Link aus der Zwischenablage.")
                    .font(AppTypography.footnote)
                    .foregroundStyle(AppColors.textSecondary)

                Button {
                    Task { await loadInfo() }
                } label: {
                    Label("Video prüfen", systemImage: "magnifyingglass")
                }
                .buttonStyle(PrimaryButton())
                .disabled(cleanedLink.isEmpty || isLoadingInfo)
                .accessibilityLabel("Video-Link prüfen")

                if clipboardHasLink && videoLink.isEmpty {
                    Button {
                        if let pasted = UIPasteboard.general.string {
                            videoLink = pasted
                            clipboardHasLink = false
                            errorMessage = nil
                            Task { await loadInfo() }
                        }
                    } label: {
                        Label("Link aus Zwischenablage übernehmen", systemImage: "link.badge.plus")
                    }
                    .buttonStyle(SecondaryButton())
                    .accessibilityLabel("Link aus Zwischenablage übernehmen")
                }
            }
        }
    }

    private func previewSection(_ info: VideoInfo) -> some View {
        AppCard {
            SectionHeader(
                title: "Vorschau",
                subtitle: "Wenn verfügbar, zeigen wir Titel, Kanal und Länge aus den Videodaten."
            )

            VStack(alignment: .leading, spacing: AppSpacing.md) {
                ZStack {
                    AsyncImage(url: info.thumbnailURL) { image in
                        image.resizable().aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Rectangle()
                            .fill(AppColors.surfaceStrong)
                            .aspectRatio(16 / 9, contentMode: .fit)
                            .overlay {
                                Image(systemName: "film")
                                    .font(.largeTitle)
                                    .foregroundStyle(AppColors.textTertiary)
                            }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))

                    if info.previewURL != nil {
                        Button {
                            showPreviewPlayer = true
                        } label: {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(AppColors.textPrimary)
                                .shadow(color: AppColors.accentGlow, radius: 18, x: 0, y: 6)
                        }
                        .accessibilityLabel("Videovorschau abspielen")
                    }
                }

                Text(info.title)
                    .font(AppTypography.title3)
                    .foregroundStyle(AppColors.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                HStack(spacing: AppSpacing.sm) {
                    if let uploader = info.uploader {
                        Label(uploader, systemImage: "person.circle")
                    }
                    if let duration = info.durationText {
                        Label(duration, systemImage: "clock")
                    }
                }
                .font(AppTypography.subheadline)
                .foregroundStyle(AppColors.textSecondary)
            }
        }
    }

    private func qualitySection(_ info: VideoInfo) -> some View {
        AppCard {
            SectionHeader(
                title: "Qualität",
                subtitle: "Die Auswahl bleibt serverabhängig und nutzt nur vorhandene Qualitätsstufen."
            )

            VStack(alignment: .leading, spacing: AppSpacing.md) {
                if info.qualities.isEmpty {
                    Text("Beste verfügbare Qualität")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.textSecondary)
                } else {
                    Picker("Auflösung", selection: $selectedQuality) {
                        ForEach(info.qualities) { quality in
                            Text(quality.label).tag(Optional(quality))
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(AppColors.accentSecondary)

                    Text("Wenn eine Auswahl fehlschlägt, versucht die App automatisch eine kompatible Variante.")
                        .font(AppTypography.footnote)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
    }

    private var downloadSection: some View {
        AppCard {
            SectionHeader(
                title: "Download",
                subtitle: "Der letzte Schritt: die Warteschlange bekommt die vorbereitete Download-URL."
            )

            Button {
                enqueueDownload()
            } label: {
                Label("Zur Warteschlange hinzufügen", systemImage: "arrow.down.circle.fill")
            }
            .buttonStyle(PrimaryButton())
            .accessibilityLabel("Zur Warteschlange hinzufügen")

            Text("Der Download läuft im Hintergrund weiter – auch wenn du die App schließt oder das iPhone sperrst.")
                .font(AppTypography.footnote)
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    @ViewBuilder
    private var previewPlayerSheet: some View {
        if let url = info?.previewURL {
            VideoPlayer(player: AVPlayer(url: url))
                .ignoresSafeArea()
                .presentationDragIndicator(.visible)
        } else {
            Text("Für dieses Video ist keine Vorschau verfügbar.")
                .padding()
        }
    }

    private var serverStatusTone: ServerStatusTone {
        switch serverOnline {
        case .some(true): return .success
        case .some(false): return .warning
        case .none: return .neutral
        }
    }

    private var serverStatusTitle: String {
        switch serverOnline {
        case .some(true): return "Server erreichbar"
        case .some(false): return "Server braucht Aufmerksamkeit"
        case .none: return "Serverstatus wird geprüft"
        }
    }

    private var serverStatusText: String {
        switch serverOnline {
        case .some(true): return "Der aktive Server antwortet und ist bereit für die Video-Prüfung."
        case .some(false): return "Adresse oder Erreichbarkeit prüfen. Falls nötig, den Server in den Einstellungen anpassen."
        case .none: return "Die Verbindung zum aktuell ausgewählten Server wird gerade getestet."
        }
    }

    private var summarySubtitle: String {
        if let justQueuedTitle {
            return "„\(justQueuedTitle)“ wurde in die Warteschlange gelegt."
        }
        if isLoadingInfo {
            return "Metadaten und verfügbare Qualitäten werden geladen."
        }
        if let errorMessage {
            return errorMessage
        }
        if let info {
            return info.durationText ?? "Video-Infos sind geladen."
        }
        if cleanedLink.isEmpty {
            return "Füge einen Link ein, um zu starten."
        }
        return "Bereit zum Prüfen."
    }

    private var mainBackground: some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.background, AppColors.backgroundSoft, AppColors.background],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [AppColors.backgroundGlow.opacity(0.30), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 320
            )

            RadialGradient(
                colors: [AppColors.accentGlow.opacity(0.18), .clear],
                center: .bottomLeading,
                startRadius: 40,
                endRadius: 260
            )
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func successCard(title: String, message: String, systemImage: String, tint: Color) -> some View {
        AppCard {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.18))
                    Image(systemName: systemImage)
                        .font(.headline)
                        .foregroundStyle(tint)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(title)
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.textPrimary)
                    Text(message)
                        .font(AppTypography.footnote)
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }

    private func detectClipboardLink() {
        guard cleanedLink.isEmpty, info == nil else { return }
        UIPasteboard.general.detectPatterns(for: [\.probableWebURL]) { result in
            DispatchQueue.main.async {
                if case .success(let patterns) = result, patterns.contains(\.probableWebURL) {
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

    private func consumePendingLink() {
        guard let link = pendingLink, !link.isEmpty else { return }
        pendingLink = nil
        videoLink = link
        justQueuedTitle = nil
        errorMessage = nil
        Task { await loadInfo() }
    }

    private func loadInfo() async {
        info = nil
        justQueuedTitle = nil
        errorMessage = nil
        isLoadingInfo = true
        defer { isLoadingInfo = false }
        do {
            let api = ServerAPI(kind: activeServer, baseURL: activeBaseURL)
            let result = try await api.fetchInfo(for: cleanedLink)
            info = result
            selectedQuality = result.qualities.first
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Das Video konnte nicht geprüft werden: \(error.localizedDescription)"
        }
    }

    private func enqueueDownload() {
        do {
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
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private enum ServerStatusTone {
    case neutral
    case success
    case warning

    var iconName: String {
        switch self {
        case .neutral: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .neutral: return AppColors.accentPrimary
        case .success: return AppColors.success
        case .warning: return AppColors.warning
        }
    }
}

private struct StatusMetricCard: View {
    let title: String
    let value: String
    let tint: Color
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)

                Text(title)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Text(value)
                .font(AppTypography.callout.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .fill(AppColors.surfaceStrong)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
        .appShadow(AppShadow.elevated)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

private struct StatusRow: View {
    let tone: ServerStatusTone
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .fill(tone.tint.opacity(0.18))
                Image(systemName: tone.iconName)
                    .font(.headline)
                    .foregroundStyle(tone.tint)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.textPrimary)

                Text(message)
                    .font(AppTypography.footnote)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
    }
}

#Preview {
    ContentView(pendingLink: .constant(nil))
}

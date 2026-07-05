import SwiftUI
import AVKit

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
    @State private var serverOnline: Bool?      // nil = wird gerade geprüft

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

    private var glassBackground: some View {
        ZStack {
            LinearGradient(
                colors: [AppGlassColors.bgAccentTop, AppGlassColors.bgBase, AppGlassColors.bgDeep],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [AppGlassColors.accentGlow.opacity(0.9), Color.clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 280
            )
            .blur(radius: 30)

            RadialGradient(
                colors: [AppGlassColors.glassHighlight.opacity(0.22), Color.clear],
                center: .topLeading,
                startRadius: 10,
                endRadius: 220
            )
            .blur(radius: 40)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppGlassTheme.sectionSpacing) {
                    serverSection
                    linkSection

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
                            message: "„\(justQueuedTitle)“ wird jetzt im Tab „Downloads“ weiterverarbeitet."
                        )
                    }

                    if let info {
                        previewSection(info)
                        qualitySection(info)
                        downloadSection
                    }
                }
            }
            .padding(.horizontal, AppGlassTheme.screenPadding)
            .padding(.top, AppGlassSpacing.md)
            .background(glassBackground.ignoresSafeArea())
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

    // MARK: - Abschnitte

    private var serverSection: some View {
        VStack(alignment: .leading, spacing: AppGlassSpacing.md) {
            sectionTitle("Server")

            GlassCard {
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
                .tint(AppGlassColors.accentPrimary)

                GlassStatusBanner(
                    tone: serverStatusTone,
                    title: serverStatusTitle,
                    message: serverStatusText,
                    actionTitle: "Erneut prüfen",
                    action: { Task { await checkServer() } }
                )
            }
        }
    }

    private var serverStatusTone: GlassStatusTone {
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

    private func checkServer() async {
        serverOnline = nil
        guard !activeBaseURL.trimmingCharacters(in: .whitespaces).isEmpty else {
            serverOnline = false
            return
        }
        let api = ServerAPI(kind: activeServer, baseURL: activeBaseURL)
        serverOnline = await api.isReachable()
    }

    private var linkSection: some View {
        VStack(alignment: .leading, spacing: AppGlassSpacing.md) {
            sectionTitle("Video-Link")

            GlassCard {
                GlassInputField(
                    label: "Link",
                    placeholder: "Link hier einfügen",
                    text: $videoLink,
                    helperText: "Füge einen direkten Video-Link ein oder übernimm einen erkannten Link aus der Zwischenablage.",
                    keyboardType: .URL,
                    textContentType: .URL,
                    autocapitalization: .never,
                    disablesAutocorrection: true
                ) {
                    if videoLink.isEmpty {
                        Button {
                            if let pasted = UIPasteboard.general.string {
                                videoLink = pasted
                                errorMessage = nil
                                Task { await loadInfo() }
                            }
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
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(AppGlassColors.textSecondary)
                        }
                        .frame(minWidth: AppGlassTheme.controlHeight, minHeight: AppGlassTheme.controlHeight)
                        .accessibilityLabel("Linkfeld leeren")
                    }
                }

                Button {
                    Task { await loadInfo() }
                } label: {
                    Label("Video prüfen", systemImage: "magnifyingglass")
                }
                .buttonStyle(GlassSecondaryButtonStyle())
                .disabled(cleanedLink.isEmpty || isLoadingInfo)

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
                    .buttonStyle(.borderless)
                    .foregroundStyle(AppGlassColors.accentSecondary)
                }
            }
        }
    }

    /// Prüft ohne System-Popup, ob ein Web-Link in der Zwischenablage liegt.
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

    private func previewSection(_ info: VideoInfo) -> some View {
        VStack(alignment: .leading, spacing: AppGlassSpacing.md) {
            sectionTitle("Vorschau")

            GlassCard {
                ZStack {
                    AsyncImage(url: info.thumbnailURL) { image in
                        image.resizable().aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Rectangle()
                            .fill(AppGlassColors.glassSurfaceStrong)
                            .aspectRatio(16 / 9, contentMode: .fit)
                            .overlay { Image(systemName: "film").font(.largeTitle).foregroundStyle(AppGlassColors.textTertiary) }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: AppGlassTheme.radiusLarge))

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

    private func qualitySection(_ info: VideoInfo) -> some View {
        VStack(alignment: .leading, spacing: AppGlassSpacing.md) {
            sectionTitle("Qualität")

            GlassCard {
                if info.qualities.isEmpty {
                    Text("Beste verfügbare Qualität")
                        .font(AppGlassTypography.body)
                        .foregroundStyle(AppGlassColors.textSecondary)
                } else {
                    Picker("Auflösung", selection: $selectedQuality) {
                        ForEach(info.qualities) { quality in
                            Text(quality.label).tag(Optional(quality))
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(AppGlassColors.accentSecondary)

                    Text("Wenn eine Auswahl fehlschlägt, versucht die App automatisch eine kompatible Variante.")
                        .font(AppGlassTypography.footnote)
                        .foregroundStyle(AppGlassColors.textSecondary)
                }
            }
        }
    }

    @ViewBuilder
    private var downloadSection: some View {
        VStack(alignment: .leading, spacing: AppGlassSpacing.md) {
            sectionTitle("Download")

            Button {
                enqueueDownload()
            } label: {
                Label("Zur Warteschlange hinzufügen", systemImage: "arrow.down.circle.fill")
            }
            .buttonStyle(GlassPrimaryButtonStyle())

            Text("Der Download läuft im Hintergrund weiter – auch wenn du die App schließt oder das iPhone sperrst.")
                .font(AppGlassTypography.footnote)
                .foregroundStyle(AppGlassColors.textSecondary)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(AppGlassTypography.subheadline)
            .foregroundStyle(AppGlassColors.textSecondary)
            .tracking(1.2)
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

    // MARK: - Aktionen

    /// Übernimmt einen per Teilen-Menü empfangenen Link und prüft ihn direkt.
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
            // Formular für das nächste Video freimachen
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

#Preview {
    ContentView(pendingLink: .constant(nil))
}

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
                            message: "„\(justQueuedTitle)" wird jetzt im Tab „Downloads" verarbeitet."
                        )
                    }

                    if let info {
                        previewSection(info)
                        qualitySection(info)
                        downloadButton
                    }
                }
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

                Text(serverOnline == true ? "Online" :
                     serverOnline == false ? "Offline" : "…")
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
        .accessibilityLabel("Serverstatus prüfen")
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

            HStack(spacing: AppGlassSpacing.sm) {
                Button {
                    Task { await loadInfo() }
                } label: {
                    Label("Prüfen", systemImage: "magnifyingglass")
                }
                .buttonStyle(GlassPrimaryButtonStyle())
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

    // MARK: - Qualität (Chip-Auswahl)

    private func qualitySection(_ info: VideoInfo) -> some View {
        VStack(alignment: .leading, spacing: AppGlassSpacing.md) {
            AppGlassSectionHeader(title: "Qualität")

            if info.qualities.isEmpty {
                Text("Beste verfügbare Qualität wird verwendet.")
                    .font(AppGlassTypography.footnote)
                    .foregroundStyle(AppGlassColors.textSecondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppGlassSpacing.sm) {
                        ForEach(info.qualities) { quality in
                            QualityChip(
                                label: quality.label,
                                isSelected: selectedQuality?.id == quality.id
                            ) {
                                selectedQuality = quality
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
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
            VideoPlayer(player: AVPlayer(url: url))
                .ignoresSafeArea()
                .presentationDragIndicator(.visible)
        } else {
            Text("Für dieses Video ist keine Vorschau verfügbar.")
                .padding()
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
}

// MARK: - Qualitäts-Chip

private struct QualityChip: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : AppGlassColors.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? AppGlassColors.accentPrimary : AppGlassColors.glassSurfaceStrong)
                        .shadow(color: isSelected ? AppGlassColors.accentGlow : .clear, radius: 8, x: 0, y: 4)
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected ? AppGlassColors.accentPrimary.opacity(0.5) : AppGlassColors.glassBorder,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }
}

#Preview {
    ContentView(pendingLink: .constant(nil))
}

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

    var body: some View {
        NavigationStack {
            Form {
                serverSection
                linkSection

                if isLoadingInfo {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Video wird geprüft …")
                                .foregroundStyle(.secondary)
                                .padding(.leading, 8)
                        }
                    }
                }

                if let justQueuedTitle {
                    Section {
                        Label("„\(justQueuedTitle)“ ist in der Warteschlange. Den Fortschritt siehst du im Tab „Downloads“.", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }

                if let info {
                    previewSection(info)
                    qualitySection(info)
                    downloadSection
                }
            }
            .neonScreenBackground()
            .neonCardRow()
            .navigationTitle("VideoLoader")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
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
            .alert("Fehler", isPresented: errorAlertBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
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
        Section("Server") {
            Picker("Aktiver Server", selection: $activeServerRaw) {
                ForEach(ServerKind.allCases) { kind in
                    Text(kind.label).tag(kind.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: activeServerRaw) { _, _ in
                info = nil
                Task { await checkServer() }
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(serverStatusColor)
                    .frame(width: 10, height: 10)
                Text(serverStatusText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    Task { await checkServer() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.footnote)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private var serverStatusColor: Color {
        switch serverOnline {
        case .some(true): return .green
        case .some(false): return .red
        case .none: return .gray
        }
    }

    private var serverStatusText: String {
        switch serverOnline {
        case .some(true): return "Server erreichbar"
        case .some(false): return "Server nicht erreichbar – Adresse in den Einstellungen prüfen"
        case .none: return "Server wird geprüft …"
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
        Section("Video-Link") {
            HStack {
                TextField("Link hier einfügen", text: $videoLink)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if videoLink.isEmpty {
                    Button {
                        if let pasted = UIPasteboard.general.string {
                            videoLink = pasted
                            Task { await loadInfo() }
                        }
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                    }
                } else {
                    Button {
                        videoLink = ""
                        info = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Button {
                Task { await loadInfo() }
            } label: {
                Label("Video prüfen", systemImage: "magnifyingglass")
            }
            .disabled(cleanedLink.isEmpty || isLoadingInfo)

            if clipboardHasLink && videoLink.isEmpty {
                Button {
                    if let pasted = UIPasteboard.general.string {
                        videoLink = pasted
                        clipboardHasLink = false
                        Task { await loadInfo() }
                    }
                } label: {
                    Label("Link aus Zwischenablage übernehmen", systemImage: "link.badge.plus")
                        .foregroundStyle(Theme.tint)
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
        Section("Vorschau") {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    AsyncImage(url: info.thumbnailURL) { image in
                        image.resizable().aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .aspectRatio(16 / 9, contentMode: .fit)
                            .overlay { Image(systemName: "film").font(.largeTitle).foregroundStyle(.secondary) }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    if info.previewURL != nil {
                        Button {
                            showPreviewPlayer = true
                        } label: {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(.white)
                                .shadow(radius: 6)
                        }
                    }
                }

                Text(info.title)
                    .font(.headline)

                HStack(spacing: 12) {
                    if let uploader = info.uploader {
                        Label(uploader, systemImage: "person.circle")
                    }
                    if let duration = info.durationText {
                        Label(duration, systemImage: "clock")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private func qualitySection(_ info: VideoInfo) -> some View {
        Section("Qualität") {
            if info.qualities.isEmpty {
                Text("Beste verfügbare Qualität")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Auflösung", selection: $selectedQuality) {
                    ForEach(info.qualities) { quality in
                        Text(quality.label).tag(Optional(quality))
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    @ViewBuilder
    private var downloadSection: some View {
        Section("Download") {
            Button {
                enqueueDownload()
            } label: {
                Label("Zur Warteschlange hinzufügen", systemImage: "arrow.down.circle.fill")
            }
            .buttonStyle(GlowButtonStyle())
            .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
            .listRowBackground(Color.clear)

            Text("Der Download läuft im Hintergrund weiter – auch wenn du die App schließt oder das iPhone sperrst.")
                .font(.footnote)
                .foregroundStyle(.secondary)
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

    // MARK: - Aktionen

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    /// Übernimmt einen per Teilen-Menü empfangenen Link und prüft ihn direkt.
    private func consumePendingLink() {
        guard let link = pendingLink, !link.isEmpty else { return }
        pendingLink = nil
        videoLink = link
        justQueuedTitle = nil
        Task { await loadInfo() }
    }

    private func loadInfo() async {
        info = nil
        justQueuedTitle = nil
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

import SwiftUI
import AVKit

struct ContentView: View {
    @AppStorage("serverURL_videoLoader") private var macServerURL = ""
    @AppStorage("serverURL_vidSave") private var cloudServerURL = "http://158.101.168.11:8765"
    @AppStorage("activeServer") private var activeServerRaw = ServerKind.vidSave.rawValue

    @State private var videoLink = ""
    @State private var info: VideoInfo?
    @State private var isLoadingInfo = false
    @State private var selectedQuality: QualityOption?
    @State private var errorMessage: String?
    @State private var showSettings = false
    @State private var showPreviewPlayer = false

    @StateObject private var downloader = DownloadManager()

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

                if let info {
                    previewSection(info)
                    qualitySection(info)
                    downloadSection
                }
            }
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
                downloader.reset()
            }
        }
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
                        downloader.reset()
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
            switch downloader.phase {
            case .idle:
                downloadButton
            case .waitingForServer:
                HStack {
                    ProgressView()
                    Text("Server lädt das Video von der Plattform …")
                        .foregroundStyle(.secondary)
                        .padding(.leading, 8)
                }
                cancelButton
            case .downloading(let progress):
                if let progress {
                    ProgressView(value: progress) {
                        Text("Wird aufs iPhone geladen … \(Int(progress * 100)) %")
                    }
                } else {
                    HStack {
                        ProgressView()
                        Text("Wird aufs iPhone geladen …")
                            .foregroundStyle(.secondary)
                            .padding(.leading, 8)
                    }
                }
                cancelButton
            case .saving:
                HStack {
                    ProgressView()
                    Text("Wird in der Fotos-Galerie gespeichert …")
                        .foregroundStyle(.secondary)
                        .padding(.leading, 8)
                }
            case .done:
                Label("Fertig! Das Video ist jetzt in deiner Fotos-Galerie.", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Button("Neues Video laden") {
                    videoLink = ""
                    info = nil
                    downloader.reset()
                }
            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                downloadButton
            }
        }
    }

    private var downloadButton: some View {
        Button {
            startDownload()
        } label: {
            Label("Herunterladen & in Fotos speichern", systemImage: "arrow.down.circle.fill")
                .fontWeight(.semibold)
        }
    }

    private var cancelButton: some View {
        Button("Abbrechen", role: .destructive) {
            downloader.cancel()
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

    private func loadInfo() async {
        info = nil
        downloader.reset()
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

    private func startDownload() {
        do {
            let api = ServerAPI(kind: activeServer, baseURL: activeBaseURL)
            let url = try api.downloadURL(for: cleanedLink, quality: selectedQuality)
            downloader.start(url: url)
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    ContentView()
}

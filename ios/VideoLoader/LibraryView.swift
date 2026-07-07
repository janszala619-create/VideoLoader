import SwiftUI
import AVKit
import Photos

/// Sortierreihenfolge der Bibliothek.
enum LibrarySort: String, CaseIterable, Identifiable {
    case newest, oldest, name, size
    var id: String { rawValue }
    var label: String {
        switch self {
        case .newest: return "Neueste zuerst"
        case .oldest: return "Älteste zuerst"
        case .name:   return "Name (A–Z)"
        case .size:   return "Größe"
        }
    }
}

/// Bibliothek: zeigt alle in der App gespeicherten Videos.
struct LibraryView: View {
    @Environment(\.openURL) private var openURL
    @State private var videos: [DownloadedVideo] = []
    @State private var selectedVideo: DownloadedVideo?
    @State private var feedback: String?
    @State private var searchText = ""
    @State private var sort: LibrarySort = .newest
    @State private var renameTarget: DownloadedVideo?
    @State private var renameText = ""
    @State private var showDeleteAll = false
    @State private var showPhotosPermissionAlert = false
    @ObservedObject private var queue = DownloadQueue.shared

    /// Zahl der fertigen Downloads – ändert sie sich, wurde ein neues Video abgelegt.
    private var doneCount: Int {
        queue.jobs.filter { $0.status == .done }.count
    }

    private var filteredVideos: [DownloadedVideo] {
        let base = searchText.isEmpty
            ? videos
            : videos.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        switch sort {
        case .newest: return base.sorted { $0.date > $1.date }
        case .oldest: return base.sorted { $0.date < $1.date }
        case .name:   return base.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        case .size:   return base.sorted { $0.size > $1.size }
        }
    }

    private var totalSize: Int64 { videos.reduce(0) { $0 + $1.size } }
    private var totalSizeText: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    var body: some View {
        NavigationStack {
            mainContent
            .background(AppGlassBackground(glowAlignment: .topLeading))
            .navigationTitle("Bibliothek")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if !videos.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Picker("Sortieren", selection: $sort) {
                                ForEach(LibrarySort.allCases) { option in
                                    Text(option.label).tag(option)
                                }
                            }
                            Divider()
                            Button(role: .destructive) {
                                showDeleteAll = true
                            } label: {
                                Label("Alle löschen", systemImage: "trash")
                            }
                        } label: {
                            Label("Sortieren", systemImage: "arrow.up.arrow.down.circle")
                                .foregroundStyle(AppGlassColors.textPrimary)
                        }
                    }
                }
            }
            .onAppear(perform: reload)
            .onChange(of: doneCount) { _, _ in reload() }
            .fullScreenCover(item: $selectedVideo) { video in
                ZStack(alignment: .topTrailing) {
                    AppGlassColors.bgDeep.ignoresSafeArea()

                    PlayerView(url: video.url)
                        .ignoresSafeArea()
                    Button {
                        selectedVideo = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white, .black.opacity(0.5))
                            .padding()
                    }
                    .accessibilityLabel("Player schließen")
                }
                .preferredColorScheme(.dark)
            }
            .alert("Video umbenennen", isPresented: renameBinding) {
                TextField("Name", text: $renameText)
                Button("Abbrechen", role: .cancel) {}
                Button("Speichern") { commitRename() }
            }
            .alert("Alle Videos löschen?", isPresented: $showDeleteAll) {
                Button("Abbrechen", role: .cancel) {}
                Button("Alle löschen", role: .destructive) {
                    DownloadLibrary.deleteAll()
                    reload()
                }
            } message: {
                Text("Dadurch werden alle \(videos.count) Videos aus der App entfernt. In der Fotos-Galerie gesicherte Videos bleiben erhalten.")
            }
            .alert("Hinweis", isPresented: feedbackBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(feedback ?? "")
            }
            .alert("Zugriff auf Fotos fehlt", isPresented: $showPhotosPermissionAlert) {
                Button("Abbrechen", role: .cancel) {}
                Button("Einstellungen öffnen") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
            } message: {
                Text("Erlaube VideoLoader in den iPhone-Einstellungen, Videos zur Fotos-App hinzuzufügen.")
            }
        }
    }

    /// In eine eigene Sub-View ausgelagert, weil die verschachtelte if/else-
    /// Struktur sonst den Compiler unnötig belastet.
    @ViewBuilder
    private var mainContent: some View {
        if videos.isEmpty {
            GlassEmptyStateView(
                title: "Noch keine Videos gespeichert",
                message: "Geladene Videos erscheinen hier und können abgespielt, geteilt oder in Fotos gespeichert werden.",
                systemImage: "film.stack"
            )
        } else if filteredVideos.isEmpty {
            GlassEmptyStateView(
                title: "Keine Videos gefunden",
                message: "Versuche einen anderen Suchbegriff oder ändere die Sortierung.",
                systemImage: "magnifyingglass"
            )
            .searchable(text: $searchText, prompt: "Videos durchsuchen")
        } else {
            libraryContent
                .searchable(text: $searchText, prompt: "Videos durchsuchen")
        }
    }

    private var libraryContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppGlassTheme.sectionSpacing) {
                overviewCard

                VStack(spacing: AppGlassSpacing.md) {
                    ForEach(filteredVideos) { video in
                        row(video)
                    }
                }
            }
            .padding(.horizontal, AppGlassTheme.screenPadding)
            .padding(.top, AppGlassSpacing.md)
            .padding(.bottom, 110)
        }
    }

    private var overviewCard: some View {
        AppGlassHeroCard(
            title: "Mediathek",
            subtitle: "\(videos.count) Video\(videos.count == 1 ? "" : "s") · \(totalSizeText) belegt"
        ) {
                Text(sort.label)
                    .font(AppGlassTypography.subheadline)
                    .foregroundStyle(AppGlassColors.textPrimary)
                    .padding(.horizontal, AppGlassSpacing.md)
                    .padding(.vertical, AppGlassSpacing.sm)
                    .background(
                        Capsule(style: .continuous)
                            .fill(AppGlassColors.glassSurfaceStrong)
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(AppGlassColors.glassBorder, lineWidth: 1)
                    )
        }
    }

    private func row(_ video: DownloadedVideo) -> some View {
        GlassCard {
            HStack(alignment: .top, spacing: AppGlassSpacing.md) {
                VideoThumbnail(url: video.url)

                VStack(alignment: .leading, spacing: AppGlassSpacing.xs) {
                    Text(video.name)
                        .font(AppGlassTypography.headline)
                        .foregroundStyle(AppGlassColors.textPrimary)
                        .lineLimit(2)
                    Text("\(video.sizeText) · \(video.germanDateText)")
                        .font(AppGlassTypography.footnote)
                        .foregroundStyle(AppGlassColors.textSecondary)
                }

                Spacer(minLength: 0)

                Menu {
                    Button {
                        selectedVideo = video
                    } label: {
                        Label("Abspielen", systemImage: "play.fill")
                    }
                    ShareLink(item: video.url) {
                        Label("Teilen", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        saveToPhotos(video)
                    } label: {
                        Label("In Fotos sichern", systemImage: "photo.badge.plus")
                    }
                    Button {
                        startRename(video)
                    } label: {
                        Label("Umbenennen", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        remove(video)
                    } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(AppGlassColors.textSecondary)
                        .frame(width: AppGlassTheme.controlHeight, height: AppGlassTheme.controlHeight)
                }
                .accessibilityLabel("Aktionen für \(video.name)")
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { selectedVideo = video }
        .contextMenu {
            Button {
                selectedVideo = video
            } label: {
                Label("Abspielen", systemImage: "play.fill")
            }
            Button {
                startRename(video)
            } label: {
                Label("Umbenennen", systemImage: "pencil")
            }
            Button {
                saveToPhotos(video)
            } label: {
                Label("In Fotos sichern", systemImage: "photo.badge.plus")
            }
            Button(role: .destructive) {
                remove(video)
            } label: {
                Label("Löschen", systemImage: "trash")
            }
        }
    }

    // MARK: - Aktionen

    private var feedbackBinding: Binding<Bool> {
        Binding(
            get: { feedback != nil },
            set: { if !$0 { feedback = nil } }
        )
    }

    private var renameBinding: Binding<Bool> {
        Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )
    }

    private func reload() {
        videos = DownloadLibrary.list()
    }

    private func remove(_ video: DownloadedVideo) {
        try? FileManager.default.removeItem(at: video.url)
        reload()
    }

    private func startRename(_ video: DownloadedVideo) {
        renameTarget = video
        renameText = video.name
    }

    private func commitRename() {
        guard let video = renameTarget else { return }
        let newName = renameText.trimmingCharacters(in: .whitespaces)
        if !newName.isEmpty, newName != video.name {
            DownloadLibrary.rename(video, to: newName)
            reload()
        }
        renameTarget = nil
    }

    private func saveToPhotos(_ video: DownloadedVideo) {
        DownloadManager.saveToPhotos(fileURL: video.url) { errorMessage in
            if let errorMessage, errorMessage.localizedCaseInsensitiveContains("Kein Zugriff auf Fotos") {
                showPhotosPermissionAlert = true
            } else {
                feedback = errorMessage ?? "„\(video.name)“ wurde in die Fotos-Galerie gesichert."
            }
        }
    }
}

/// Erzeugt ein Vorschaubild aus der Videodatei.
struct VideoThumbnail: View {
    let url: URL
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(AppGlassColors.glassSurfaceStrong)
                    .overlay {
                        Image(systemName: "film")
                            .foregroundStyle(AppGlassColors.textTertiary)
                    }
            }
        }
        .frame(width: 104, height: 60)
        .clipShape(RoundedRectangle(cornerRadius: AppGlassTheme.radiusMedium, style: .continuous))
        .overlay {
            Circle()
                .fill(.black.opacity(0.48))
                .frame(width: 28, height: 28)
                .overlay {
                    Image(systemName: "play.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .offset(x: 1)
                }
        }
        .overlay(
            RoundedRectangle(cornerRadius: AppGlassTheme.radiusMedium, style: .continuous)
                .stroke(AppGlassColors.glassBorder, lineWidth: 1)
        )
        .task {
            if image == nil {
                image = await Self.generate(for: url)
            }
        }
    }

    private static func generate(for url: URL) async -> UIImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 400, height: 400)
        return await withCheckedContinuation { continuation in
            generator.generateCGImageAsynchronously(for: CMTime(seconds: 0.5, preferredTimescale: 600)) { cgImage, _, _ in
                continuation.resume(returning: cgImage.map(UIImage.init))
            }
        }
    }
}

#Preview {
    LibraryView()
}

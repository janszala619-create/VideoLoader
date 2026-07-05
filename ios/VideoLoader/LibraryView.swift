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
    @State private var videos: [DownloadedVideo] = []
    @State private var selectedVideo: DownloadedVideo?
    @State private var feedback: String?
    @State private var searchText = ""
    @State private var sort: LibrarySort = .newest
    @State private var renameTarget: DownloadedVideo?
    @State private var renameText = ""
    @State private var showDeleteAll = false
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

    private var glassBackground: some View {
        LinearGradient(
            colors: [AppGlassColors.bgElevated, AppGlassColors.bgBase, AppGlassColors.bgDeep],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if videos.isEmpty {
                    GlassEmptyStateView(
                        title: "Noch keine Videos",
                        message: "Lade im Tab „Laden“ ein Video herunter. Es erscheint dann hier und kann abgespielt, geteilt oder in Fotos gesichert werden.",
                        systemImage: "film.stack"
                    )
                } else {
                    if filteredVideos.isEmpty {
                        GlassEmptyStateView(
                            title: "Keine Treffer",
                            message: "Für „\(searchText)“ wurde kein gespeichertes Video gefunden.",
                            systemImage: "magnifyingglass"
                        )
                    } else {
                        List {
                            Section {
                                overviewCard
                                ForEach(filteredVideos) { video in
                                    row(video)
                                }
                            }
                        }
                        .scrollContentBackground(.hidden)
                    }
                    .searchable(text: $searchText, prompt: "Videos durchsuchen")
                }
            }
            .background(glassBackground.ignoresSafeArea())
            .navigationTitle("Meine Videos")
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
                            Image(systemName: "ellipsis.circle")
                                .foregroundStyle(AppGlassColors.textPrimary)
                        }
                    }
                }
            }
            .onAppear(perform: reload)
            .onChange(of: doneCount) { _, _ in reload() }
            .fullScreenCover(item: $selectedVideo) { video in
                ZStack(alignment: .topTrailing) {
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
        }
    }

    private var overviewCard: some View {
        GlassCard {
            HStack(alignment: .center, spacing: AppGlassSpacing.md) {
                VStack(alignment: .leading, spacing: AppGlassSpacing.xs) {
                    Text("Mediathek")
                        .font(AppGlassTypography.headline)
                        .foregroundStyle(AppGlassColors.textPrimary)
                    Text("\(videos.count) Video\(videos.count == 1 ? "" : "s") gespeichert")
                        .font(AppGlassTypography.footnote)
                        .foregroundStyle(AppGlassColors.textSecondary)
                }

                Spacer()

                Text(totalSizeText)
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
        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 10, trailing: 0))
        .listRowBackground(Color.clear)
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
                    Text("\(video.sizeText) · \(video.date.formatted(date: .abbreviated, time: .shortened))")
                        .font(AppGlassTypography.footnote)
                        .foregroundStyle(AppGlassColors.textSecondary)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: AppGlassSpacing.md) {
                Button {
                    selectedVideo = video
                } label: {
                    Label("Abspielen", systemImage: "play.fill")
                }
                .buttonStyle(GlassPrimaryButtonStyle())

                ShareLink(item: video.url) {
                    Label("Teilen", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(GlassSecondaryButtonStyle())
            }

            Button {
                saveToPhotos(video)
            } label: {
                Label("In Fotos sichern", systemImage: "photo.badge.plus")
            }
            .buttonStyle(.borderless)
            .font(AppGlassTypography.footnote.weight(.semibold))
            .foregroundStyle(AppGlassColors.accentSecondary)
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
        .listRowBackground(Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { selectedVideo = video }
        .contextMenu {
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
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                remove(video)
            } label: {
                Label("Löschen", systemImage: "trash")
            }
            Button {
                startRename(video)
            } label: {
                Label("Umbenennen", systemImage: "pencil")
            }
            .tint(AppGlassColors.accentPrimary)
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
            feedback = errorMessage ?? "„\(video.name)“ wurde in die Fotos-Galerie gesichert."
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
        let generator = AVAssetImageGenerator(asset: AVAsset(url: url))
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

import SwiftUI
import AVKit

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
    @State private var isLoading = true
    @State private var loadError: String?
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

    private var latestVideoDateText: String? {
        guard let latestDate = videos.map(\.date).max() else { return nil }
        return latestDate.formatted(date: .abbreviated, time: .shortened)
    }

    private var overviewSubtitle: String {
        if videos.isEmpty {
            return "Neue Downloads erscheinen hier automatisch."
        }
        if searchText.isEmpty {
            return "\(videos.count) gespeichert · \(totalSizeText) insgesamt"
        }
        return "\(filteredVideos.count) von \(videos.count) sichtbar"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                    headerBlock

                    if isLoading && videos.isEmpty {
                        LoadingStateView(
                            title: "Bibliothek wird geladen",
                            message: "Deine gespeicherten Videos werden gerade aus dem lokalen Archiv gelesen."
                        )
                        .accessibilityLabel("Bibliothek wird geladen")
                    } else if let loadError, videos.isEmpty {
                        ErrorStateView(
                            title: "Bibliothek konnte nicht geladen werden",
                            message: loadError,
                            actionTitle: "Erneut versuchen",
                            action: { Task { await refreshLibrary(showLoading: true) } }
                        )
                        .accessibilityLabel("Fehler beim Laden der Bibliothek")
                    } else if videos.isEmpty {
                        EmptyStateView(
                            title: "Noch keine Medien",
                            message: "Lade im Tab „Laden“ ein Video herunter. Sobald der Download fertig ist, erscheint es hier und kann geöffnet, geteilt oder gelöscht werden.",
                            systemImage: "film.stack"
                        )
                        .accessibilityLabel("Leere Mediathek")
                    } else {
                        overviewCard
                        mediaSection
                    }
                }
                .padding(.horizontal, AppTheme.screenPadding)
                .padding(.top, AppSpacing.md)
            }
            .background(libraryBackground)
            .navigationTitle("Meine Videos")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(AppTheme.navBarMaterial, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
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
                                .foregroundStyle(AppColors.textPrimary)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Videos durchsuchen")
            .task {
                await refreshLibrary(showLoading: true)
            }
            .onChange(of: doneCount) { _, _ in
                Task { await refreshLibrary() }
            }
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
                    Task { await refreshLibrary() }
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

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Mediathek")
                .font(AppTypography.largeTitle)
                .foregroundStyle(AppColors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Text("Alle gespeicherten Videos an einem Ort. Suche, sortiere und öffne deine Downloads direkt aus der Bibliothek.")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var overviewCard: some View {
        AppCard {
            SectionHeader(
                title: "Übersicht",
                subtitle: overviewSubtitle
            )

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: AppSpacing.md),
                    GridItem(.flexible(), spacing: AppSpacing.md)
                ],
                spacing: AppSpacing.md
            ) {
                LibraryMetricCard(
                    title: "Videos",
                    value: "\(videos.count)",
                    tint: AppColors.accentPrimary,
                    systemImage: "film.stack.fill"
                )
                LibraryMetricCard(
                    title: "Größe",
                    value: totalSizeText,
                    tint: AppColors.info,
                    systemImage: "externaldrive.fill"
                )
                LibraryMetricCard(
                    title: "Neueste",
                    value: latestVideoDateText ?? "—",
                    tint: AppColors.success,
                    systemImage: "clock.fill"
                )
                LibraryMetricCard(
                    title: "Sortierung",
                    value: sort.label,
                    tint: AppColors.warning,
                    systemImage: "arrow.up.arrow.down"
                )
            }
        }
    }

    private var mediaSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeader(
                title: "Medien",
                subtitle: filteredVideos.isEmpty
                ? "Keine Treffer für \(searchText)."
                : "\(filteredVideos.count) gespeicherte Medien"
            )

            if filteredVideos.isEmpty {
                EmptyStateView(
                    title: "Keine Treffer",
                    message: emptySearchMessage,
                    systemImage: "magnifyingglass",
                    actionTitle: "Suche löschen",
                    action: { searchText = "" }
                )
                .accessibilityLabel("Keine gespeicherten Videos für die aktuelle Suche")
            } else {
                LazyVStack(spacing: AppSpacing.md) {
                    ForEach(filteredVideos) { video in
                        mediaCard(for: video)
                    }
                }
            }
        }
    }

    private func mediaCard(for video: DownloadedVideo) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(alignment: .top, spacing: AppSpacing.md) {
                    VideoThumbnail(url: video.url)

                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(video.name)
                            .font(AppTypography.headline)
                            .foregroundStyle(AppColors.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .accessibilityAddTraits(.isHeader)

                        HStack(spacing: AppSpacing.sm) {
                            Label(video.sizeText, systemImage: "externaldrive")
                            Label(video.date.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                        }
                        .font(AppTypography.footnote)
                        .foregroundStyle(AppColors.textSecondary)
                        .labelStyle(.titleAndIcon)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: AppSpacing.sm) {
                    Button {
                        selectedVideo = video
                    } label: {
                        Label("Öffnen", systemImage: "play.fill")
                    }
                    .buttonStyle(PrimaryButton())

                    ShareLink(item: video.url) {
                        Label("Teilen", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(SecondaryButton())
                }

                Text("Weitere Aktionen über das Kontextmenü oder Wischen nach links.")
                    .font(AppTypography.footnote)
                    .foregroundStyle(AppColors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(video.name), \(video.sizeText), \(video.date.formatted(date: .abbreviated, time: .shortened))")
            .onTapGesture {
                selectedVideo = video
            }

        }
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
            .tint(AppColors.accentPrimary)
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

    @MainActor
    private func refreshLibrary(showLoading: Bool = false) async {
        loadError = nil
        if showLoading {
            isLoading = true
            await Task.yield()
        }

        do {
            videos = try loadVideos()
        } catch {
            videos = []
            loadError = error.localizedDescription
        }

        isLoading = false
    }

    private func loadVideos() throws -> [DownloadedVideo] {
        let urls = try FileManager.default.contentsOfDirectory(
            at: DownloadLibrary.directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]
        )
        let videoExtensions: Set<String> = ["mp4", "mov", "m4v", "webm", "mkv", "avi"]
        return urls
            .filter { videoExtensions.contains($0.pathExtension.lowercased()) }
            .map { url in
                let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
                return DownloadedVideo(
                    url: url,
                    name: url.deletingPathExtension().lastPathComponent,
                    size: Int64(values?.fileSize ?? 0),
                    date: values?.contentModificationDate ?? .distantPast
                )
            }
            .sorted { $0.date > $1.date }
    }

    private func remove(_ video: DownloadedVideo) {
        try? FileManager.default.removeItem(at: video.url)
        Task { await refreshLibrary() }
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
            Task { await refreshLibrary() }
        }
        renameTarget = nil
    }

    private func saveToPhotos(_ video: DownloadedVideo) {
        DownloadManager.saveToPhotos(fileURL: video.url) { errorMessage in
            feedback = errorMessage ?? "„\(video.name)“ wurde in die Fotos-Galerie gesichert."
        }
    }

    private var emptySearchMessage: String {
        "Für „\(searchText)“ wurde kein gespeichertes Video gefunden."
    }

    private var libraryBackground: some View {
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
                    .fill(AppColors.surfaceStrong)
                    .overlay {
                        Image(systemName: "film")
                            .foregroundStyle(AppColors.textTertiary)
                    }
            }
        }
        .frame(width: 104, height: 60)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .stroke(AppColors.border, lineWidth: 1)
        )
        .accessibilityHidden(true)
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

private struct LibraryMetricCard: View {
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

#Preview {
    LibraryView()
}

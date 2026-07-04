import SwiftUI
import AVKit
import Photos

/// Bibliothek: zeigt alle in der App gespeicherten Videos.
struct LibraryView: View {
    @State private var videos: [DownloadedVideo] = []
    @State private var selectedVideo: DownloadedVideo?
    @State private var feedback: String?

    var body: some View {
        NavigationStack {
            Group {
                if videos.isEmpty {
                    ContentUnavailableView(
                        "Noch keine Videos",
                        systemImage: "film.stack",
                        description: Text("Lade im Tab „Laden“ ein Video herunter – es erscheint dann hier und kann angesehen, geteilt oder in die Fotos-Galerie gesichert werden.")
                    )
                } else {
                    List {
                        ForEach(videos) { video in
                            row(video)
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("Meine Videos")
            .onAppear(perform: reload)
            .sheet(item: $selectedVideo) { video in
                VideoPlayer(player: AVPlayer(url: video.url))
                    .ignoresSafeArea()
                    .presentationDragIndicator(.visible)
            }
            .alert("Hinweis", isPresented: feedbackBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(feedback ?? "")
            }
        }
    }

    private func row(_ video: DownloadedVideo) -> some View {
        HStack(spacing: 12) {
            VideoThumbnail(url: video.url)

            VStack(alignment: .leading, spacing: 4) {
                Text(video.name)
                    .font(.subheadline)
                    .lineLimit(2)
                Text("\(video.sizeText) · \(video.date.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            ShareLink(item: video.url) {
                Image(systemName: "square.and.arrow.up")
            }
            .buttonStyle(.borderless)

            Button {
                saveToPhotos(video)
            } label: {
                Image(systemName: "photo.badge.plus")
            }
            .buttonStyle(.borderless)
        }
        .contentShape(Rectangle())
        .onTapGesture { selectedVideo = video }
        .swipeActions(edge: .trailing) {
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

    private func reload() {
        videos = DownloadLibrary.list()
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            try? FileManager.default.removeItem(at: videos[index].url)
        }
        reload()
    }

    private func remove(_ video: DownloadedVideo) {
        try? FileManager.default.removeItem(at: video.url)
        reload()
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
                    .fill(Color.secondary.opacity(0.2))
                    .overlay {
                        Image(systemName: "film")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(width: 88, height: 50)
        .clipShape(RoundedRectangle(cornerRadius: 8))
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

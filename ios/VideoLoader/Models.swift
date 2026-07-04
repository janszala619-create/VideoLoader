import Foundation

/// Welcher Server-Typ gerade benutzt wird. Beide haben unterschiedliche Schnittstellen.
enum ServerKind: String, CaseIterable, Identifiable {
    case videoLoader   // der selbst gebaute Server auf dem Mac
    case vidSave       // der VidSave-Cloud-Server

    var id: String { rawValue }

    var label: String {
        switch self {
        case .videoLoader: return "Mac-Server"
        case .vidSave: return "Cloud-Server"
        }
    }

    var settingsHint: String {
        switch self {
        case .videoLoader:
            return "Läuft auf deinem Mac (start.sh). Zuverlässig inkl. YouTube, aber Mac muss an sein."
        case .vidSave:
            return "Läuft in der Cloud, überall erreichbar. YouTube & viele große Seiten sind hier oft blockiert."
        }
    }
}

/// Eine wählbare Qualitätsstufe – server-neutral. Je nach Server wird `height`
/// (Mac-Server) oder `formatId` (Cloud-Server) für den Download verwendet.
struct QualityOption: Identifiable, Hashable {
    let id: String
    let label: String
    let height: Int?
    let formatId: String?
}

/// Ein in der App gespeichertes, heruntergeladenes Video.
struct DownloadedVideo: Identifiable, Hashable {
    let url: URL
    let name: String
    let size: Int64
    let date: Date

    var id: String { url.path }

    var sizeText: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

/// Verwaltet den Ordner, in dem heruntergeladene Videos in der App liegen.
enum DownloadLibrary {
    static var directory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func list() -> [DownloadedVideo] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]
        )) ?? []
        return urls
            .filter { $0.pathExtension.lowercased() == "mp4" }
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

    /// Baut aus dem Videotitel einen sicheren, noch freien Dateinamen.
    static func makeDestination(title: String) -> URL {
        var safe = String(title.map { char in
            char.isLetter || char.isNumber || char == " " || char == "-" || char == "_" ? char : " "
        })
        safe = safe.trimmingCharacters(in: .whitespaces)
        if safe.count > 60 { safe = String(safe.prefix(60)).trimmingCharacters(in: .whitespaces) }
        if safe.isEmpty { safe = "Video" }

        var url = directory.appendingPathComponent(safe).appendingPathExtension("mp4")
        var counter = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = directory.appendingPathComponent("\(safe) \(counter)").appendingPathExtension("mp4")
            counter += 1
        }
        return url
    }
}

/// Normalisierte Videoinfos, egal von welchem Server sie stammen.
struct VideoInfo {
    let title: String
    let uploader: String?
    let duration: Double?
    let thumbnail: String?
    let previewUrl: String?
    let qualities: [QualityOption]

    var durationText: String? {
        guard let duration, duration > 0 else { return nil }
        let total = Int(duration)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    var thumbnailURL: URL? {
        guard let thumbnail, !thumbnail.isEmpty else { return nil }
        return URL(string: thumbnail)
    }

    var previewURL: URL? {
        guard let previewUrl, !previewUrl.isEmpty else { return nil }
        return URL(string: previewUrl)
    }
}

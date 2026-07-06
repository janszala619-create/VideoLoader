import Foundation
import Photos

final class DownloadManager: NSObject, ObservableObject {
    enum Phase: Equatable {
        case idle
        case waitingForServer          // Server lädt das Video gerade von der Plattform
        case downloading(Double?)      // Fortschritt 0...1, nil = unbekannt
        case done
        case failed(String)
    }

    @Published var phase: Phase = .idle

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        // Der Server antwortet erst, wenn yt-dlp fertig ist – das kann dauern
        config.timeoutIntervalForRequest = 1800
        config.timeoutIntervalForResource = 7200
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    private var task: URLSessionDownloadTask?
    private var fallbackURL: URL?
    private var fallbackUsed = false
    private var pendingTitle = "Video"
    private var currentURL: URL?
    private var retriesLeft = 0

    func start(url: URL, fallbackURL: URL? = nil, title: String = "Video") {
        task?.cancel()
        self.fallbackURL = fallbackURL
        fallbackUsed = false
        pendingTitle = title
        currentURL = url
        retriesLeft = 2
        phase = .waitingForServer
        task = session.downloadTask(with: url)
        task?.resume()
    }

    /// Startet den zuletzt versuchten Download nach einer kurzen Pause erneut.
    private func restart(after seconds: Double) {
        update(.waitingForServer)
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            guard let url = self.currentURL else { return }
            self.task = self.session.downloadTask(with: url)
            self.task?.resume()
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        currentURL = nil
        update(.idle)
    }

    func reset() {
        task?.cancel()
        task = nil
        currentURL = nil
        phase = .idle
    }

    private func update(_ newPhase: Phase) {
        DispatchQueue.main.async { self.phase = newPhase }
    }

    /// Meldet einen Fehler – versucht es vorher aber selbstständig erneut:
    /// bei "Format nicht verfügbar" mit der besten Qualität, bei vorübergehenden
    /// Fehlern (z. B. flüchtige Videoadressen mit HTTP 404) bis zu zweimal neu.
    private func fail(_ message: String, transientHint: Bool = false) {
        if message.contains("Requested format is not available"),
           let fallbackURL, !fallbackUsed {
            fallbackUsed = true
            currentURL = fallbackURL
            restart(after: 0)
            return
        }
        if retriesLeft > 0, transientHint || Self.isTransient(message) {
            retriesLeft -= 1
            restart(after: 2)
            return
        }
        update(.failed(message))
    }

    /// Fehler, die erfahrungsgemäß beim nächsten Anlauf verschwinden können.
    private static func isTransient(_ message: String) -> Bool {
        let patterns = ["HTTP Error 404", "HTTP Error 403", "HTTP Error 429",
                        "HTTP Error 5", "timed out", "unable to download"]
        return patterns.contains { message.contains($0) }
    }

    /// Sichert ein bereits in der App gespeichertes Video zusätzlich in die Fotos-Galerie.
    /// Ruft die Rückmeldung mit nil (Erfolg) oder einer Fehlermeldung auf.
    static func saveToPhotos(fileURL: URL, completion: @escaping (String?) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    completion("Kein Zugriff auf Fotos. Bitte in den iPhone-Einstellungen unter Datenschutz & Sicherheit → Fotos → VideoLoader das Hinzufügen erlauben.")
                }
                return
            }
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
            }) { success, error in
                DispatchQueue.main.async {
                    completion(success ? nil : "Speichern in Fotos fehlgeschlagen: \(error?.localizedDescription ?? "Unbekannter Fehler")")
                }
            }
        }
    }
}

extension DownloadManager: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        if totalBytesExpectedToWrite > 0 {
            update(.downloading(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)))
        } else {
            update(.downloading(nil))
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        if let http = downloadTask.response as? HTTPURLResponse,
           !(200...299).contains(http.statusCode) {
            let body = (try? String(contentsOf: location, encoding: .utf8)) ?? ""
            fail(Self.serverMessage(from: body, code: http.statusCode))
            return
        }
        // Video dauerhaft in der App-Bibliothek ablegen ("Meine Videos")
        let target = DownloadLibrary.makeDestination(
            title: pendingTitle,
            fileExtension: Self.fileExtension(for: downloadTask.response)
        )
        do {
            try FileManager.default.moveItem(at: location, to: target)
        } catch {
            update(.failed("Die Videodatei konnte nicht gespeichert werden: \(error.localizedDescription)"))
            return
        }
        update(.done)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        let nsError = error as NSError
        guard nsError.code != NSURLErrorCancelled else { return }
        // Netzwerkfehler (Abbrüche, Zeitüberschreitungen) sind meist vorübergehend
        fail("Download fehlgeschlagen: \(error.localizedDescription)", transientHint: true)
    }

    /// Leitet die passende Dateiendung aus dem vom Server gemeldeten Typ ab.
    private static func fileExtension(for response: URLResponse?) -> String {
        switch response?.mimeType?.lowercased() {
        case "video/quicktime": return "mov"
        case "video/webm": return "webm"
        case "video/x-matroska": return "mkv"
        case "video/x-msvideo", "video/avi": return "avi"
        default: return "mp4"
        }
    }

    private static func serverMessage(from body: String, code: Int) -> String {
        if let data = body.data(using: .utf8),
           let payload = try? JSONDecoder().decode(ServerErrorDTO.self, from: data) {
            return payload.userMessage
        }
        if let data = body.data(using: .utf8),
           let payload = try? JSONDecoder().decode(LegacyErrorDTO.self, from: data) {
            let detail = payload.detail
            if detail.contains("yt-dlp") || detail.contains("HTTP Error") || detail.contains("ERROR:") {
                return "Download fehlgeschlagen. Bitte versuche es erneut."
            }
            return detail
        }
        return "Der Server hat einen Fehler gemeldet (Code \(code))."
    }
}

private struct ServerErrorDTO: Decodable {
    struct ErrorBody: Decodable {
        let code: String
        let message: String
        let phase: String?
        let requestId: String?

        enum CodingKeys: String, CodingKey {
            case code, message, phase
            case requestId = "request_id"
        }
    }

    let error: ErrorBody

    var userMessage: String {
        switch error.code {
        case "MISSING_PREREQUISITE":
            return error.message
        case "DOWNLOAD_FAILED":
            if let requestId = error.requestId {
                return "Download fehlgeschlagen. Bitte versuche es erneut. Fehler-ID: \(requestId)"
            }
            return "Download fehlgeschlagen. Bitte versuche es erneut."
        default:
            return error.message
        }
    }
}

private struct LegacyErrorDTO: Decodable {
    let detail: String
}

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

    func start(url: URL, fallbackURL: URL? = nil, title: String = "Video") {
        task?.cancel()
        self.fallbackURL = fallbackURL
        fallbackUsed = false
        pendingTitle = title
        phase = .waitingForServer
        task = session.downloadTask(with: url)
        task?.resume()
    }

    func cancel() {
        task?.cancel()
        task = nil
        update(.idle)
    }

    func reset() {
        task?.cancel()
        task = nil
        phase = .idle
    }

    private func update(_ newPhase: Phase) {
        DispatchQueue.main.async { self.phase = newPhase }
    }

    /// Meldet einen Fehler – bei "Format nicht verfügbar" wird vorher automatisch
    /// ein zweiter Versuch mit der besten verfügbaren Qualität gestartet.
    private func fail(_ message: String) {
        if message.contains("Requested format is not available"),
           let fallbackURL, !fallbackUsed {
            fallbackUsed = true
            update(.waitingForServer)
            DispatchQueue.main.async {
                self.task = self.session.downloadTask(with: fallbackURL)
                self.task?.resume()
            }
            return
        }
        update(.failed(message))
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
        update(.failed("Download fehlgeschlagen: \(error.localizedDescription)"))
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
           let payload = try? JSONDecoder().decode([String: String].self, from: data),
           let detail = payload["detail"] {
            return detail
        }
        return "Der Server hat einen Fehler gemeldet (Code \(code))."
    }
}

import Foundation
import Photos

/// Sammlung von Hilfsfunktionen rund um Downloads: Sichern in die Fotos-Galerie,
/// Dateiendung bestimmen und Server-Fehlermeldungen lesbar machen.
/// Die eigentliche Download-Steuerung liegt in `DownloadQueue`.
enum DownloadManager {

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

    /// Leitet die passende Dateiendung aus dem vom Server gemeldeten Typ ab.
    static func fileExtension(for response: URLResponse?) -> String {
        switch response?.mimeType?.lowercased() {
        case "video/quicktime": return "mov"
        case "video/webm": return "webm"
        case "video/x-matroska": return "mkv"
        case "video/x-msvideo", "video/avi": return "avi"
        default: return "mp4"
        }
    }

    /// Wandelt die JSON-Fehlerantwort des Servers in eine lesbare Meldung um.
    static func serverMessage(from body: String, code: Int) -> String {
        if let data = body.data(using: .utf8),
           let payload = try? JSONDecoder().decode(ServerErrorDTO.self, from: data) {
            return payload.userMessage
        }
        if let data = body.data(using: .utf8),
           let payload = try? JSONDecoder().decode(LegacyErrorDTO.self, from: data) {
            return payload.detail
        }
        return "Der Server hat einen Fehler gemeldet (Code \(code))."
    }
}

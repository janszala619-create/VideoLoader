import Foundation

enum APIError: LocalizedError {
    case missingServer
    case badURL
    case unreachable
    case server(String)

    var errorDescription: String? {
        switch self {
        case .missingServer:
            return "Bitte zuerst die Server-Adresse in den Einstellungen (Zahnrad oben rechts) eintragen."
        case .badURL:
            return "Die Server-Adresse oder der Video-Link ist ungültig."
        case .unreachable:
            return "Der Server ist nicht erreichbar. Läuft er und stimmt die Adresse in den Einstellungen?"
        case .server(let message):
            return message
        }
    }
}

struct ServerAPI {
    let kind: ServerKind
    let baseURL: String

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        return URLSession(configuration: config)
    }()

    // MARK: - Adresse zusammenbauen

    private func normalizedBase() throws -> URLComponents {
        var trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw APIError.missingServer }
        if !trimmed.lowercased().hasPrefix("http") {
            trimmed = "http://" + trimmed
        }
        guard let components = URLComponents(string: trimmed) else { throw APIError.badURL }
        return components
    }

    private func url(path: String, query: [URLQueryItem] = []) throws -> URL {
        var components = try normalizedBase()
        components.path = path
        components.queryItems = query.isEmpty ? nil : query
        guard let result = components.url else { throw APIError.badURL }
        return result
    }

    // MARK: - Infos holen

    func fetchInfo(for videoURL: String) async throws -> VideoInfo {
        switch kind {
        case .videoLoader: return try await fetchInfoVideoLoader(videoURL)
        case .vidSave: return try await fetchInfoVidSave(videoURL)
        }
    }

    private func fetchInfoVideoLoader(_ videoURL: String) async throws -> VideoInfo {
        let endpoint = try url(path: "/api/info", query: [URLQueryItem(name: "url", value: videoURL)])
        let (data, response) = try await get(endpoint)
        try Self.checkStatus(response: response, data: data)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let dto = try decoder.decode(VideoLoaderInfoDTO.self, from: data)

        var qualities = dto.heights.map {
            QualityOption(id: "h\($0)", label: "\($0)p", height: $0, formatId: nil)
        }
        qualities.append(QualityOption(id: "auto", label: "Automatisch (beste Qualität)", height: nil, formatId: nil))

        return VideoInfo(
            title: dto.title,
            uploader: dto.uploader,
            duration: dto.duration,
            thumbnail: dto.thumbnail,
            previewUrl: dto.previewUrl,
            qualities: qualities
        )
    }

    private func fetchInfoVidSave(_ videoURL: String) async throws -> VideoInfo {
        let endpoint = try url(path: "/api/info")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["url": videoURL])

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await Self.session.data(for: request)
        } catch {
            throw APIError.unreachable
        }
        try Self.checkStatus(response: response, data: data)

        let dto = try JSONDecoder().decode(VidSaveInfoDTO.self, from: data)

        // "best" zuerst als bequeme Standardwahl, dann die konkreten Formate
        var qualities = [QualityOption(id: "best", label: "Automatisch (beste Qualität)", height: nil, formatId: "best")]
        qualities += dto.formats.map { f in
            QualityOption(id: f.formatId, label: Self.vidSaveLabel(f), height: Self.parseHeight(f.quality), formatId: f.formatId)
        }

        return VideoInfo(
            title: dto.title ?? "Video",
            uploader: nil,
            duration: dto.duration,
            thumbnail: dto.thumbnail,
            previewUrl: nil,
            qualities: qualities
        )
    }

    // MARK: - Download-Adresse

    func downloadURL(for videoURL: String, quality: QualityOption?) throws -> URL {
        switch kind {
        case .videoLoader:
            var query = [URLQueryItem(name: "url", value: videoURL)]
            if let height = quality?.height {
                query.append(URLQueryItem(name: "quality", value: String(height)))
            }
            return try url(path: "/api/download", query: query)
        case .vidSave:
            let direct = "[protocol!*=m3u8][protocol!*=dash]"
            let selector: String
            if let height = quality?.height {
                let h = "[height<=\(height)]"
                selector = "bv*\(h)+ba/b\(h)[vcodec^=avc1]\(direct)/b\(h)[ext=mp4]\(direct)/b\(h)/b"
            } else if let formatId = quality?.formatId, formatId != "best" {
                selector = "bv*+ba/b[vcodec^=avc1]\(direct)/b[ext=mp4]\(direct)/b/\(formatId)/best"
            } else {
                selector = "bv*+ba/b[vcodec^=avc1]\(direct)/b[ext=mp4]\(direct)/b"
            }
            return try url(path: "/api/download", query: [
                URLQueryItem(name: "url", value: videoURL),
                URLQueryItem(name: "format_id", value: selector),
            ])
        }
    }

    // MARK: - Erreichbarkeit (für die Server-Ampel)

    /// Prüft mit kurzem Zeitlimit, ob der Server antwortet. Jede HTTP-Antwort
    /// (auch 404) zählt als erreichbar – nur ein Verbindungsfehler ist „offline“.
    func isReachable() async -> Bool {
        var components: URLComponents
        do { components = try normalizedBase() } catch { return false }
        components.path = "/health"
        guard let healthURL = components.url else { return false }

        var request = URLRequest(url: healthURL)
        request.timeoutInterval = 6
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 6
        let session = URLSession(configuration: config)
        do {
            let (_, response) = try await session.data(for: request)
            return response is HTTPURLResponse
        } catch {
            return false
        }
    }

    // MARK: - Hilfen

    private func get(_ endpoint: URL) async throws -> (Data, URLResponse) {
        do {
            return try await Self.session.data(from: endpoint)
        } catch {
            throw APIError.unreachable
        }
    }

    /// Liest die Pixelhöhe aus Angaben wie "480p" oder "1080p60".
    private static func parseHeight(_ quality: String?) -> Int? {
        guard let quality else { return nil }
        let digits = quality.prefix { $0.isNumber }
        return Int(digits)
    }

    private static func vidSaveLabel(_ f: VidSaveInfoDTO.Format) -> String {
        var parts: [String] = []
        if let quality = f.quality, !quality.isEmpty {
            parts.append(quality)
        } else if let ext = f.ext, !ext.isEmpty {
            parts.append(ext.uppercased())
        } else {
            parts.append(f.formatId)
        }
        if let size = f.filesize, size > 0 {
            let mb = Double(size) / 1_048_576
            parts.append(String(format: "≈ %.0f MB", mb))
        }
        return parts.joined(separator: " · ")
    }

    static func checkStatus(response: URLResponse, data: Data?) throws {
        guard let http = response as? HTTPURLResponse,
              !(200...299).contains(http.statusCode) else { return }
        if let data,
           let payload = try? JSONDecoder().decode(ServerErrorDTO.self, from: data) {
            throw APIError.server(payload.userMessage)
        }
        if let data,
           let payload = try? JSONDecoder().decode(LegacyErrorDTO.self, from: data) {
            throw APIError.server(payload.detail)
        }
        if http.statusCode == 422 {
            throw APIError.server("Der Server konnte die Download-Anfrage nicht verarbeiten. Bitte prüfe Server-Typ und Server-Adresse in den Einstellungen.")
        }
        throw APIError.server("Der Server hat einen Fehler gemeldet (Code \(http.statusCode)).")
    }
}

// MARK: - Antwortformate der beiden Server

private struct VideoLoaderInfoDTO: Decodable {
    let title: String
    let uploader: String?
    let duration: Double?
    let thumbnail: String?
    let previewUrl: String?
    let heights: [Int]
}

private struct VidSaveInfoDTO: Decodable {
    struct Format: Decodable {
        let formatId: String
        let quality: String?
        let ext: String?
        let filesize: Int?

        enum CodingKeys: String, CodingKey {
            case formatId = "format_id"
            case quality, ext, filesize
        }
    }
    let title: String?
    let thumbnail: String?
    let duration: Double?
    let formats: [Format]
}

struct ServerErrorDTO: Decodable {
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

struct LegacyErrorDTO: Decodable {
    let detail: String
}

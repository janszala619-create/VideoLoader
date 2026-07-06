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

    private static let videoURLInServerFieldMessage = "Bitte gib einen YouTube-Link ins Linkfeld ein. Die Server-Adresse gehört in die Einstellungen."

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
        if Self.containsServerAPIPath(components.path) || Self.looksLikeVideoURL(trimmed) {
            throw APIError.server(Self.videoURLInServerFieldMessage)
        }
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
        try validateVideoURL(videoURL)
        switch kind {
        case .videoLoader: return try await fetchInfoVideoLoader(videoURL)
        case .vidSave: return try await fetchInfoVidSave(videoURL)
        }
    }

    private func fetchInfoVideoLoader(_ videoURL: String) async throws -> VideoInfo {
        let endpoint = try url(path: "/api/info", query: [URLQueryItem(name: "url", value: videoURL)])
        debugRequest(endpoint: endpoint, endpointName: "/api/info", queryNames: ["url"], quality: nil)
        let (data, response) = try await get(endpoint)
        try Self.checkStatus(response: response, data: data)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
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
        } catch {
            if let dto = try? JSONDecoder().decode(VidSaveInfoDTO.self, from: data) {
                return Self.videoInfo(from: dto)
            }
            throw APIError.server("Die Server-Antwort konnte nicht gelesen werden: \(Self.decodeMessage(error))")
        }
    }

    private func fetchInfoVidSave(_ videoURL: String) async throws -> VideoInfo {
        let endpoint = try url(path: "/api/info")
        debugRequest(endpoint: endpoint, endpointName: "/api/info", queryNames: ["body.url"], quality: nil)
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

        do {
            let dto = try JSONDecoder().decode(VidSaveInfoDTO.self, from: data)
            return Self.videoInfo(from: dto)
        } catch {
            throw APIError.server("Die Server-Antwort konnte nicht gelesen werden: \(Self.decodeMessage(error))")
        }
    }

    // MARK: - Download-Adresse

    func downloadURL(for videoURL: String, quality: QualityOption?) throws -> URL {
        try validateVideoURL(videoURL)
        switch kind {
        case .videoLoader:
            var query = [URLQueryItem(name: "url", value: videoURL)]
            if let height = quality?.height {
                query.append(URLQueryItem(name: "quality", value: String(height)))
            }
            let endpoint = try url(path: "/api/download", query: query)
            debugRequest(
                endpoint: endpoint,
                endpointName: "/api/download",
                queryNames: query.map { $0.name },
                quality: quality
            )
            return endpoint
        case .vidSave:
            let endpoint = try url(path: "/api/download", query: [
                URLQueryItem(name: "url", value: videoURL),
                URLQueryItem(name: "format_id", value: Self.vidSaveDownloadSelector(for: quality)),
            ])
            debugRequest(
                endpoint: endpoint,
                endpointName: "/api/download",
                queryNames: ["url", "format_id"],
                quality: quality
            )
            return endpoint
        }
    }

    // MARK: - Erreichbarkeit (für die Server-Ampel)

    /// Prüft mit kurzem Zeitlimit, ob der Server antwortet. Jede HTTP-Antwort
    /// (auch 404) zählt als erreichbar – nur ein Verbindungsfehler ist „offline“.
    func isReachable() async -> Bool {
        var components: URLComponents
        do { components = try normalizedBase() } catch { return false }
        components.path = kind == .videoLoader ? "/api/health" : "/health"
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

    private func validateVideoURL(_ videoURL: String) throws {
        let trimmed = videoURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw APIError.badURL }
        if Self.containsServerAPIPath(trimmed) {
            throw APIError.server(Self.videoURLInServerFieldMessage)
        }

        guard let videoComponents = URLComponents(string: trimmed),
              let videoHost = videoComponents.host?.lowercased() else {
            throw APIError.badURL
        }
        let baseComponents = try normalizedBase()
        if let baseHost = baseComponents.host?.lowercased(), videoHost == baseHost {
            throw APIError.server(Self.videoURLInServerFieldMessage)
        }
        guard Self.looksLikeVideoURL(trimmed) else { throw APIError.badURL }
    }

    private static func containsServerAPIPath(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        return lowercased.contains("/api/health") ||
            lowercased.contains("/api/info") ||
            lowercased.contains("/api/download") ||
            lowercased == "/health" ||
            lowercased.hasSuffix("/health")
    }

    private static func looksLikeVideoURL(_ text: String) -> Bool {
        guard let host = URLComponents(string: text).host?.lowercased() else { return false }
        return host.contains("youtube.com") ||
            host.contains("youtu.be") ||
            host.contains("music.youtube.com") ||
            host.contains("m.youtube.com")
    }

    private func debugRequest(
        endpoint: URL,
        endpointName: String,
        queryNames: [String],
        quality: QualityOption?
    ) {
        #if DEBUG
        let base = (try? normalizedBase())?.url?.absoluteString ?? baseURL
        print("[VideoLoader] activeServer=\(kind.rawValue) baseURL=\(base)")
        let port = endpoint.port.map { String($0) } ?? "-"
        print("[VideoLoader] \(endpointName) host=\(endpoint.host ?? "-") port=\(port) query=\(queryNames.joined(separator: ","))")
        if let quality {
            print("[VideoLoader] selectedQuality id=\(quality.id) label=\(quality.label) height=\(quality.height.map(String.init) ?? "nil") formatId=\(quality.formatId ?? "nil")")
        }
        if kind == .vidSave {
            print("[VideoLoader] warning=VidSave legacy server mode is active")
        }
        #endif
    }

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
        if let label = f.label, !label.isEmpty {
            parts.append(label)
        } else if let quality = f.quality, !quality.isEmpty {
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

    private static func videoInfo(from dto: VidSaveInfoDTO) -> VideoInfo {
        let heights = dto.formats
            .compactMap { Self.parseHeight($0.quality ?? $0.label) }
        let uniqueHeights = Array(Set(heights)).sorted(by: >)

        var qualities = [
            QualityOption(
                id: "auto",
                label: "Automatisch",
                height: nil,
                formatId: "auto"
            )
        ]
        qualities += uniqueHeights.map { height in
            QualityOption(
                id: "h\(height)",
                label: "\(height)p",
                height: height,
                formatId: "h\(height)"
            )
        }

        if qualities.count == 1, let firstFormat = dto.formats.first {
            qualities.append(
                QualityOption(
                    id: firstFormat.formatId,
                    label: Self.vidSaveLabel(firstFormat),
                    height: Self.parseHeight(firstFormat.quality ?? firstFormat.label),
                    formatId: firstFormat.formatId
                )
            )
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

    private static func vidSaveDownloadSelector(for quality: QualityOption?) -> String {
        let h = quality?.height.map { "[height<=\($0)]" } ?? ""
        return [
            "bestvideo\(h)[vcodec^=avc1][ext=mp4]+bestaudio[acodec^=mp4a][ext=m4a]",
            "bestvideo\(h)[vcodec^=avc1]+bestaudio[acodec^=mp4a]",
            "best\(h)[vcodec^=avc1][ext=mp4]",
            "best\(h)[ext=mp4]",
            "best\(h)",
        ].joined(separator: "/")
    }

    private static func decodeMessage(_ error: Error) -> String {
        if case DecodingError.keyNotFound(let key, _) = error {
            return "Feld „\(key.stringValue)“ fehlt."
        }
        return error.localizedDescription
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
        let label: String?
        let ext: String?
        let filesize: Int?

        enum CodingKeys: String, CodingKey {
            case formatId = "format_id"
            case formatIdCamel = "formatId"
            case id, quality, label, ext, filesize
            case fileSize
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            formatId = try container.decodeIfPresent(String.self, forKey: .formatId)
                ?? container.decodeIfPresent(String.self, forKey: .formatIdCamel)
                ?? container.decodeIfPresent(String.self, forKey: .id)
                ?? "best"
            quality = try container.decodeIfPresent(String.self, forKey: .quality)
            label = try container.decodeIfPresent(String.self, forKey: .label)
            ext = try container.decodeIfPresent(String.self, forKey: .ext)
            filesize = try container.decodeIfPresent(Int.self, forKey: .filesize)
                ?? container.decodeIfPresent(Int.self, forKey: .fileSize)
        }
    }
    let title: String?
    let thumbnail: String?
    let duration: Double?
    let formats: [Format]

    enum CodingKeys: String, CodingKey {
        case title, thumbnail, duration, formats
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        thumbnail = try container.decodeIfPresent(String.self, forKey: .thumbnail)
        duration = try container.decodeIfPresent(Double.self, forKey: .duration)
        formats = try container.decodeIfPresent([Format].self, forKey: .formats) ?? []
    }
}

struct ServerErrorDTO: Decodable {
    struct ErrorBody: Decodable {
        let code: String
        let message: String
        let phase: String?
        let requestId: String?
        let exceptionType: String?
        let detail: String?

        enum CodingKeys: String, CodingKey {
            case code, message, phase, detail
            case requestId = "request_id"
            case exceptionType = "exception_type"
        }
    }

    let error: ErrorBody

    var userMessage: String {
        switch error.code {
        case "MISSING_PREREQUISITE":
            return error.message
        case "DOWNLOAD_FAILED":
            var msg = "Download fehlgeschlagen."
            if let requestId = error.requestId {
                msg += " (Fehler-ID: \(requestId))"
            }
            // Den echten technischen Grund anhängen, wenn der Server ihn
            // mitgeschickt hat – so ist der Fehler ohne Server-Log erkennbar.
            if let exType = error.exceptionType, !exType.isEmpty {
                msg += "\n\(exType)"
                if let d = error.detail, !d.isEmpty {
                    msg += ": \(d)"
                }
            } else if let d = error.detail, !d.isEmpty {
                msg += "\n\(d)"
            }
            return msg
        default:
            return error.message
        }
    }
}

struct LegacyErrorDTO: Decodable {
    let detail: String
}

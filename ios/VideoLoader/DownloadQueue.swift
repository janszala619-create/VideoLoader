import Foundation

/// Ein Auftrag in der Download-Warteschlange.
struct DownloadJob: Identifiable, Codable, Equatable {
    enum Status: String, Codable {
        case waiting      // wartet auf seinen Platz in der Reihe
        case running      // wird gerade geladen (progress zeigt den Fortschritt)
        case done         // fertig, liegt in „Meine Videos“
        case failed       // fehlgeschlagen (message erklärt warum)
    }

    let id: UUID
    let title: String
    let sourceLink: String
    let primaryURL: URL
    let fallbackURL: URL?
    var status: Status
    var progress: Double          // 0…1, 0 solange der Server noch vorbereitet
    var message: String?
    let createdAt: Date

    init(title: String, sourceLink: String, primaryURL: URL, fallbackURL: URL?) {
        self.id = UUID()
        self.title = title
        self.sourceLink = sourceLink
        self.primaryURL = primaryURL
        self.fallbackURL = fallbackURL
        self.status = .waiting
        self.progress = 0
        self.message = nil
        self.createdAt = Date()
    }
}

/// Verwaltet die Download-Warteschlange und lädt die Videos über eine
/// Hintergrund-URLSession – die läuft weiter, wenn die App geschlossen oder
/// das iPhone gesperrt ist, und übersteht sogar einen Neustart der App.
final class DownloadQueue: NSObject, ObservableObject {
    static let shared = DownloadQueue()

    @Published private(set) var jobs: [DownloadJob] = []

    /// Wird vom AppDelegate gesetzt, wenn iOS die App für fertige
    /// Hintergrund-Downloads aufweckt.
    var backgroundCompletionHandler: (() -> Void)?

    private static let sessionIdentifier = "de.jansz.VideoLoader.downloads"
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
        config.sessionSendsLaunchEvents = true      // App bei Fertigstellung aufwecken
        config.isDiscretionary = false              // sofort starten, nicht auf WLAN/Strom warten
        config.timeoutIntervalForRequest = 900      // dem Server Zeit geben, das Video vorzubereiten
        config.timeoutIntervalForResource = 7 * 24 * 3600
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    // Auftrags-Zustände, die nicht dauerhaft gespeichert werden müssen
    private var retriesLeft: [UUID: Int] = [:]
    private var fallbackUsed: Set<UUID> = []

    private override init() {
        super.init()
        loadFromDisk()
        reconnect()
    }

    // MARK: - Öffentliche Aktionen

    func enqueue(title: String, sourceLink: String, primaryURL: URL, fallbackURL: URL?) {
        let job = DownloadJob(title: title, sourceLink: sourceLink,
                              primaryURL: primaryURL, fallbackURL: fallbackURL)
        retriesLeft[job.id] = 2
        DispatchQueue.main.async {
            self.jobs.append(job)
            self.saveToDisk()
            self.startNextIfIdle()
        }
    }

    /// Entfernt einen Auftrag aus der Liste (und bricht ihn ab, falls er läuft).
    func remove(_ job: DownloadJob) {
        cancelTask(for: job.id)
        DispatchQueue.main.async {
            self.jobs.removeAll { $0.id == job.id }
            self.retriesLeft[job.id] = nil
            self.fallbackUsed.remove(job.id)
            self.saveToDisk()
            self.startNextIfIdle()
        }
    }

    /// Setzt einen fehlgeschlagenen Auftrag zurück in die Warteschlange.
    func retry(_ job: DownloadJob) {
        DispatchQueue.main.async {
            guard let index = self.jobs.firstIndex(where: { $0.id == job.id }) else { return }
            self.retriesLeft[job.id] = 2
            self.fallbackUsed.remove(job.id)
            self.jobs[index].status = .waiting
            self.jobs[index].progress = 0
            self.jobs[index].message = nil
            self.saveToDisk()
            self.startNextIfIdle()
        }
    }

    /// Entfernt alle fertigen und fehlgeschlagenen Aufträge aus der Liste.
    func clearFinished() {
        DispatchQueue.main.async {
            self.jobs.removeAll { $0.status == .done || $0.status == .failed }
            self.saveToDisk()
        }
    }

    var hasActiveJobs: Bool {
        jobs.contains { $0.status == .waiting || $0.status == .running }
    }

    // MARK: - Ablaufsteuerung (immer auf dem Main-Thread aufrufen)

    private func startNextIfIdle() {
        guard !jobs.contains(where: { $0.status == .running }) else { return }
        guard let index = jobs.firstIndex(where: { $0.status == .waiting }) else { return }
        launch(jobAt: index, url: jobs[index].primaryURL)
    }

    private func launch(jobAt index: Int, url: URL) {
        jobs[index].status = .running
        jobs[index].progress = 0
        jobs[index].message = nil
        saveToDisk()

        let task = session.downloadTask(with: url)
        task.taskDescription = jobs[index].id.uuidString
        task.resume()
    }

    private func updateJob(_ id: UUID, _ change: (inout DownloadJob) -> Void) {
        DispatchQueue.main.async {
            guard let index = self.jobs.firstIndex(where: { $0.id == id }) else { return }
            change(&self.jobs[index])
            self.saveToDisk()
        }
    }

    private func jobID(for task: URLSessionTask) -> UUID? {
        task.taskDescription.flatMap(UUID.init(uuidString:))
    }

    private func cancelTask(for id: UUID) {
        session.getAllTasks { tasks in
            for task in tasks where task.taskDescription == id.uuidString {
                task.cancel()
            }
        }
    }

    /// Wird nach jedem beendeten Auftrag aufgerufen, um den nächsten zu starten.
    private func handleFinished(id: UUID, success: Bool, message: String?) {
        DispatchQueue.main.async {
            if let index = self.jobs.firstIndex(where: { $0.id == id }) {
                self.jobs[index].status = success ? .done : .failed
                self.jobs[index].message = message
                if success { self.jobs[index].progress = 1 }
            }
            self.retriesLeft[id] = nil
            self.fallbackUsed.remove(id)
            self.saveToDisk()
            self.startNextIfIdle()
        }
    }

    /// Entscheidet nach einem Fehler, ob neu versucht, auf beste Qualität
    /// ausgewichen oder endgültig aufgegeben wird.
    private func handleError(id: UUID, message: String) {
        DispatchQueue.main.async {
            guard let index = self.jobs.firstIndex(where: { $0.id == id }) else { return }
            let job = self.jobs[index]

            // 1) „Format nicht verfügbar“ → einmalig auf beste Qualität ausweichen
            if message.contains("Requested format is not available"),
               let fallback = job.fallbackURL, !self.fallbackUsed.contains(id) {
                self.fallbackUsed.insert(id)
                self.launch(jobAt: index, url: fallback)
                return
            }

            // 2) Vorübergehende Fehler → bis zu zweimal neu versuchen
            if (self.retriesLeft[id] ?? 0) > 0, Self.isTransient(message) {
                self.retriesLeft[id] = (self.retriesLeft[id] ?? 0) - 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    guard let i = self.jobs.firstIndex(where: { $0.id == id }),
                          self.jobs[i].status == .running || self.jobs[i].status == .waiting else { return }
                    self.launch(jobAt: i, url: job.primaryURL)
                }
                return
            }

            // 3) Endgültig fehlgeschlagen
            self.handleFinished(id: id, success: false, message: message)
        }
    }

    private static func isTransient(_ message: String) -> Bool {
        let patterns = ["HTTP Error 404", "HTTP Error 403", "HTTP Error 429",
                        "HTTP Error 5", "timed out", "unable to download",
                        "network connection was lost", "downloaded file is empty"]
        return patterns.contains { message.localizedCaseInsensitiveContains($0) }
    }

    // MARK: - Nach App-Neustart wieder andocken

    private func reconnect() {
        session.getAllTasks { tasks in
            let runningIDs = Set(tasks.compactMap { $0.taskDescription.flatMap(UUID.init(uuidString:)) })
            DispatchQueue.main.async {
                for index in self.jobs.indices {
                    // Aufträge, die „läuft“ waren, aber keine laufende Aufgabe mehr
                    // haben, zurück in die Warteschlange stellen.
                    if self.jobs[index].status == .running,
                       !runningIDs.contains(self.jobs[index].id) {
                        self.jobs[index].status = .waiting
                        self.jobs[index].progress = 0
                    }
                    if self.retriesLeft[self.jobs[index].id] == nil {
                        self.retriesLeft[self.jobs[index].id] = 2
                    }
                }
                self.saveToDisk()
                self.startNextIfIdle()
            }
        }
    }

    // MARK: - Dauerhaftes Speichern der Liste

    private static var storeURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("download-queue.json")
    }

    private func saveToDisk() {
        if let data = try? JSONEncoder().encode(jobs) {
            try? data.write(to: Self.storeURL, options: .atomic)
        }
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: Self.storeURL),
              let saved = try? JSONDecoder().decode([DownloadJob].self, from: data) else { return }
        jobs = saved
    }
}

// MARK: - Download-Ereignisse

extension DownloadQueue: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard let id = jobID(for: downloadTask) else { return }
        let progress = totalBytesExpectedToWrite > 0
            ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            : 0
        updateJob(id) { $0.progress = progress }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        guard let id = jobID(for: downloadTask) else { return }

        // Fehlerantwort des Servers (kommt als kleine JSON-Datei mit Fehlercode)
        if let http = downloadTask.response as? HTTPURLResponse,
           !(200...299).contains(http.statusCode) {
            let body = (try? String(contentsOf: location, encoding: .utf8)) ?? ""
            handleError(id: id, message: DownloadManager.serverMessage(from: body, code: http.statusCode))
            return
        }

        // Erfolg: Datei dauerhaft in „Meine Videos“ ablegen. Das muss noch in
        // diesem Callback geschehen, danach ist die temporäre Datei weg.
        let title = jobs.first(where: { $0.id == id })?.title ?? "Video"
        let target = DownloadLibrary.makeDestination(
            title: title,
            fileExtension: DownloadManager.fileExtension(for: downloadTask.response)
        )
        do {
            try FileManager.default.moveItem(at: location, to: target)
            handleFinished(id: id, success: true, message: nil)
        } catch {
            handleError(id: id, message: "Die Videodatei konnte nicht gespeichert werden: \(error.localizedDescription)")
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let id = jobID(for: task), let error else { return }
        let nsError = error as NSError
        // Abbruch durch den Nutzer ist kein Fehler
        guard nsError.code != NSURLErrorCancelled else { return }
        handleError(id: id, message: "Download fehlgeschlagen: \(error.localizedDescription)")
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            self.backgroundCompletionHandler?()
            self.backgroundCompletionHandler = nil
        }
    }
}

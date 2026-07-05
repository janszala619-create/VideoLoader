import SwiftUI

/// Zeigt die Download-Warteschlange mit Status (wartet / lädt / fertig / Fehler).
struct QueueView: View {
    @ObservedObject private var queue = DownloadQueue.shared

    var body: some View {
        NavigationStack {
            Group {
                if queue.jobs.isEmpty {
                    ContentUnavailableView(
                        "Keine Downloads",
                        systemImage: "arrow.down.circle",
                        description: Text("Füge im Tab „Laden“ ein Video hinzu. Mehrere Videos werden nacheinander abgearbeitet – auch wenn die App geschlossen ist.")
                    )
                } else {
                    List {
                        ForEach(queue.jobs.reversed()) { job in
                            row(job)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listRowBackground(Theme.card)
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Downloads")
            .toolbar {
                if queue.jobs.contains(where: { $0.status == .done || $0.status == .failed }) {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Aufräumen") { queue.clearFinished() }
                    }
                }
            }
        }
    }

    private func row(_ job: DownloadJob) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                statusIcon(job)
                Text(job.title)
                    .font(.subheadline)
                    .lineLimit(2)
                Spacer()
            }

            switch job.status {
            case .waiting:
                Text("Wartet …")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .running:
                if job.progress > 0 {
                    ProgressView(value: job.progress)
                    Text("\(Int(job.progress * 100)) %")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Server bereitet das Video vor …")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            case .done:
                Text("Fertig – liegt in „Meine Videos“")
                    .font(.caption)
                    .foregroundStyle(.green)
            case .failed:
                Text(job.message ?? "Fehlgeschlagen")
                    .font(.caption)
                    .foregroundStyle(.red)
                Button {
                    queue.retry(job)
                } label: {
                    Label("Erneut versuchen", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                queue.remove(job)
            } label: {
                Label(job.status == .running ? "Abbrechen" : "Entfernen",
                      systemImage: job.status == .running ? "xmark" : "trash")
            }
        }
    }

    @ViewBuilder
    private func statusIcon(_ job: DownloadJob) -> some View {
        switch job.status {
        case .waiting:
            Image(systemName: "clock").foregroundStyle(.secondary)
        case .running:
            Image(systemName: "arrow.down.circle").foregroundStyle(.blue)
        case .done:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
        }
    }
}

#Preview {
    QueueView()
}

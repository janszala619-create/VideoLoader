import SwiftUI

/// Zeigt die Download-Warteschlange mit Status (wartet / lädt / fertig / Fehler).
struct QueueView: View {
    @ObservedObject private var queue = DownloadQueue.shared

    private var activeCount: Int {
        queue.jobs.filter { $0.status == .running || $0.status == .waiting }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    heroCard

                    if queue.jobs.isEmpty {
                        EmptyStateView(
                            systemImage: "arrow.down.circle",
                            title: "Keine Downloads",
                            message: "Füge im Tab „Laden“ ein Video hinzu. Mehrere Videos werden nacheinander abgearbeitet – auch wenn die App geschlossen ist."
                        )
                    } else {
                        VStack(spacing: AppSpacing.md) {
                            ForEach(queue.jobs.reversed()) { job in
                                row(job)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
            .background(AppGlassBackground())
            .navigationTitle("Downloads")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if queue.jobs.contains(where: { $0.status == .done || $0.status == .failed }) {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Aufräumen") { queue.clearFinished() }
                            .foregroundStyle(AppTheme.primaryText)
                    }
                }
            }
        }
    }

    // MARK: - Übersicht

    private var heroCard: some View {
        AppCard {
            AppSectionHeader(title: "Warteschlange", subtitle: "\(queue.jobs.count) Einträge insgesamt")

            HStack(spacing: AppSpacing.xs) {
                AppStatusDot(color: activeCount > 0 ? AppTheme.accent : AppTheme.secondaryText)
                Text("\(activeCount) aktiv")
                    .font(AppTypography.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }

    // MARK: - Einträge

    @ViewBuilder
    private func row(_ job: DownloadJob) -> some View {
        switch job.status {
        case .waiting:
            DownloadProgressCard(
                title: job.title,
                description: "Der Download startet automatisch, sobald vorherige Aufträge abgeschlossen sind.",
                progress: nil,
                statusText: "Wartet auf freien Platz",
                statusTone: AppTheme.secondaryText
            )
            .contextMenu { removeMenuItem(for: job) }
        case .running:
            DownloadProgressCard(
                title: job.title,
                description: job.progress > 0 ? nil : "Der Server bereitet die Datei vor.",
                progress: job.progress > 0 ? job.progress : nil,
                statusText: job.progress > 0 ? "Wird heruntergeladen · \(Int(job.progress * 100))%" : "Wird vorbereitet…",
                statusTone: AppTheme.accent
            )
            .contextMenu { removeMenuItem(for: job) }
        case .done:
            AppCard {
                HStack(alignment: .top, spacing: AppSpacing.md) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(AppTheme.success)

                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(job.title)
                            .font(AppTypography.bodyEmphasized)
                            .foregroundStyle(AppTheme.primaryText)
                            .lineLimit(2)
                        Text("Liegt jetzt in „Meine Videos“ und kann dort abgespielt oder geteilt werden.")
                            .font(AppTypography.footnote)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
            }
            .contextMenu { removeMenuItem(for: job) }
        case .failed:
            ErrorStateView(
                title: "Download fehlgeschlagen",
                message: job.message ?? "Bitte versuche es erneut.",
                retryTitle: "Erneut versuchen",
                retryAction: { queue.retry(job) }
            )
            .contextMenu { removeMenuItem(for: job) }
        }
    }

    @ViewBuilder
    private func removeMenuItem(for job: DownloadJob) -> some View {
        Button(role: .destructive) {
            queue.remove(job)
        } label: {
            Label(job.status == .running ? "Abbrechen" : "Entfernen",
                  systemImage: job.status == .running ? "xmark" : "trash")
        }
    }
}

#Preview {
    QueueView()
}

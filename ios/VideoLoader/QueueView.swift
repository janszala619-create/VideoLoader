import SwiftUI

/// Zeigt die Download-Warteschlange mit Status (wartet / lädt / fertig / Fehler).
struct QueueView: View {
    @ObservedObject private var queue = DownloadQueue.shared

    private var glassBackground: some View {
        LinearGradient(
            colors: [AppGlassColors.bgElevated, AppGlassColors.bgBase, AppGlassColors.bgDeep],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if queue.jobs.isEmpty {
                    GlassEmptyStateView(
                        title: "Keine Downloads",
                        message: "Füge im Tab „Laden“ ein Video hinzu. Mehrere Videos werden nacheinander abgearbeitet – auch wenn die App geschlossen ist.",
                        systemImage: "arrow.down.circle"
                    )
                } else {
                    List {
                        ForEach(queue.jobs.reversed()) { job in
                            row(job)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(glassBackground.ignoresSafeArea())
            .navigationTitle("Downloads")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if queue.jobs.contains(where: { $0.status == .done || $0.status == .failed }) {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Aufräumen") { queue.clearFinished() }
                            .foregroundStyle(AppGlassColors.textPrimary)
                    }
                }
            }
        }
    }

    private func row(_ job: DownloadJob) -> some View {
        GlassCard {
            HStack(alignment: .top, spacing: AppGlassSpacing.md) {
                statusIcon(job)
                    .font(.headline)
                VStack(alignment: .leading, spacing: AppGlassSpacing.xs) {
                    Text(job.title)
                        .font(AppGlassTypography.headline)
                        .foregroundStyle(AppGlassColors.textPrimary)
                        .lineLimit(2)
                    Text(statusHeadline(job))
                        .font(AppGlassTypography.subheadline)
                        .foregroundStyle(AppGlassColors.textSecondary)
                }
                Spacer()
            }

            detailContent(job)
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
        .listRowBackground(Color.clear)
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
    private func detailContent(_ job: DownloadJob) -> some View {
        switch job.status {
        case .waiting:
            Text("Der Download startet automatisch, sobald vorherige Aufträge abgeschlossen sind.")
                .font(AppGlassTypography.footnote)
                .foregroundStyle(AppGlassColors.textSecondary)
        case .running:
            if job.progress > 0 {
                ProgressView(value: job.progress)
                    .tint(AppGlassColors.accentPrimary)
                Text("\(Int(job.progress * 100)) % heruntergeladen")
                    .font(AppGlassTypography.footnote)
                    .foregroundStyle(AppGlassColors.textSecondary)
            } else {
                HStack(spacing: AppGlassSpacing.sm) {
                    ProgressView()
                        .tint(AppGlassColors.accentPrimary)
                    Text("Der Server bereitet die Datei vor.")
                        .font(AppGlassTypography.footnote)
                        .foregroundStyle(AppGlassColors.textSecondary)
                }
            }
        case .done:
            Text("Das Video liegt jetzt in „Meine Videos“ und kann dort abgespielt oder geteilt werden.")
                .font(AppGlassTypography.footnote)
                .foregroundStyle(AppGlassColors.success)
        case .failed:
            GlassStatusBanner(
                tone: .error,
                title: "Download fehlgeschlagen",
                message: job.message ?? "Bitte versuche es erneut.",
                actionTitle: "Erneut versuchen",
                action: { queue.retry(job) }
            )
        }
    }

    @ViewBuilder
    private func statusIcon(_ job: DownloadJob) -> some View {
        switch job.status {
        case .waiting:
            Image(systemName: "clock").foregroundStyle(AppGlassColors.textTertiary)
        case .running:
            Image(systemName: "arrow.down.circle.fill").foregroundStyle(AppGlassColors.accentPrimary)
        case .done:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(AppGlassColors.success)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(AppGlassColors.error)
        }
    }

    private func statusHeadline(_ job: DownloadJob) -> String {
        switch job.status {
        case .waiting: return "Wartet auf freien Platz in der Warteschlange"
        case .running: return "Wird gerade geladen"
        case .done: return "Abgeschlossen"
        case .failed: return "Aktion erforderlich"
        }
    }
}

#Preview {
    QueueView()
}

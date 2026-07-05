import SwiftUI

/// Zeigt die Download-Warteschlange mit Status (wartet / lädt / fertig / Fehler).
struct QueueView: View {
    @ObservedObject private var queue = DownloadQueue.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppGlassTheme.sectionSpacing) {
                    heroCard

                    if queue.jobs.isEmpty {
                        GlassEmptyStateView(
                            title: "Keine Downloads",
                            message: "Füge im Tab „Laden“ ein Video hinzu. Mehrere Videos werden nacheinander abgearbeitet – auch wenn die App geschlossen ist.",
                            systemImage: "arrow.down.circle"
                        )
                    } else {
                        VStack(spacing: AppGlassSpacing.md) {
                            ForEach(queue.jobs.reversed()) { job in
                                row(job)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, AppGlassTheme.screenPadding)
            .padding(.top, AppGlassSpacing.md)
            .background(AppGlassBackground())
            .navigationTitle("Downloads")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
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

    private var heroCard: some View {
        AppGlassHeroCard(
            title: "Warteschlange",
            subtitle: "\(queue.jobs.count) Einträge insgesamt"
        ) {
                Text("\(queue.jobs.filter { $0.status == .running || $0.status == .waiting }.count) aktiv")
                    .font(AppGlassTypography.subheadline)
                    .foregroundStyle(AppGlassColors.textPrimary)
                    .padding(.horizontal, AppGlassSpacing.md)
                    .padding(.vertical, AppGlassSpacing.sm)
                    .background(
                        Capsule(style: .continuous)
                            .fill(AppGlassColors.glassSurfaceStrong)
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(AppGlassColors.glassBorder, lineWidth: 1)
                    )
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

import SwiftUI

/// Zeigt die Download-Warteschlange mit Status (wartet / lädt / fertig / Fehler).
struct QueueView: View {
    @Binding var selectedTab: Int
    @ObservedObject private var queue = DownloadQueue.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppGlassTheme.sectionSpacing) {
                    heroCard

                    if queue.jobs.isEmpty {
                        GlassEmptyStateView(
                            title: "Keine Downloads",
                            message: "Füge ein Video hinzu. Mehrere Downloads werden nacheinander abgearbeitet, auch wenn die App geschlossen ist.",
                            systemImage: "arrow.down.circle",
                            actionTitle: "Video laden",
                            action: { selectedTab = 0 }
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
            .padding(.bottom, 110)
            .background(AppGlassBackground())
            .navigationTitle("Downloads")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if queue.jobs.contains(where: { $0.status == .done || $0.status == .failed }) {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Abgeschlossene entfernen", systemImage: "checkmark.circle") {
                                queue.clearFinished()
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundStyle(AppGlassColors.textPrimary)
                        }
                        .accessibilityLabel("Download-Aktionen")
                    }
                }
            }
        }
    }

    private var heroCard: some View {
        AppGlassHeroCard(
            title: "Warteschlange",
            subtitle: queueSummary
        ) {
                GlassPill(
                    title: "\(queue.jobs.filter { $0.status == .running || $0.status == .waiting }.count) aktiv",
                    systemImage: "arrow.down.circle",
                    tint: AppGlassColors.accentPrimary
                )
        }
    }

    private var queueSummary: String {
        let active = queue.jobs.filter { $0.status == .running || $0.status == .waiting }.count
        let done = queue.jobs.filter { $0.status == .done }.count
        let failed = queue.jobs.filter { $0.status == .failed }.count
        return "\(active) aktiv · \(done) abgeschlossen · \(failed) fehlgeschlagen"
    }

    private func row(_ job: DownloadJob) -> some View {
        GlassCard {
            HStack(alignment: .top, spacing: AppGlassSpacing.md) {
                statusIcon(job)
                    .font(.headline)
                    .frame(width: AppGlassTheme.minimumTouchTarget, height: AppGlassTheme.minimumTouchTarget, alignment: .top)
                    .accessibilityHidden(true)
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
        .contextMenu {
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
                    .accessibilityLabel("Download-Fortschritt")
                    .accessibilityValue("\(Int(job.progress * 100)) Prozent heruntergeladen")
                Text("\(Int(job.progress * 100)) % heruntergeladen")
                    .font(AppGlassTypography.footnote)
                    .foregroundStyle(AppGlassColors.textSecondary)
                cancelButton(job)
            } else {
                HStack(spacing: AppGlassSpacing.sm) {
                    ProgressView()
                        .tint(AppGlassColors.accentPrimary)
                    Text("Der Server bereitet die Datei vor.")
                        .font(AppGlassTypography.footnote)
                        .foregroundStyle(AppGlassColors.textSecondary)
                }
                cancelButton(job)
            }
        case .done:
            VStack(alignment: .leading, spacing: AppGlassSpacing.md) {
                Label("Abgeschlossen · In Bibliothek gespeichert", systemImage: "checkmark.circle.fill")
                    .font(AppGlassTypography.footnote)
                    .foregroundStyle(AppGlassColors.success)
                Button {
                    selectedTab = 2
                } label: {
                    Label("In Bibliothek öffnen", systemImage: "film.stack")
                }
                .buttonStyle(GlassSecondaryButtonStyle())
            }
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

    private func cancelButton(_ job: DownloadJob) -> some View {
        Button {
            queue.remove(job)
        } label: {
            Label("Abbrechen", systemImage: "xmark.circle")
        }
        .buttonStyle(GlassSecondaryButtonStyle())
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
    QueueView(selectedTab: .constant(1))
}

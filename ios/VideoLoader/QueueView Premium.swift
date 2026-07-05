import SwiftUI

struct QueueViewPremium: View {
    @ObservedObject private var queue = DownloadQueue.shared

    var body: some View {
        NavigationStack {
            ZStack {
                PremiumAuroraBackground()

                if queue.jobs.isEmpty {
                    emptyState
                } else {
                    jobsList
                }
            }
            .navigationTitle("Downloads")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if queue.jobs.contains(where: { $0.status == .done || $0.status == .failed }) {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Aufräumen") { queue.clearFinished() }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColorsPremium.accentTeal)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppThemePremium.xl) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 48))
                .foregroundStyle(AppColorsPremium.accentBlue)
                .opacity(0.6)

            VStack(spacing: AppThemePremium.sm) {
                Text("Keine Downloads")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppColorsPremium.textPrimary)

                Text("Starten Sie einen Download im Tab \"Laden\", um ihn hier zu sehen.")
                    .font(.subheadline)
                    .foregroundStyle(AppColorsPremium.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppThemePremium.xxl)
    }

    private var jobsList: some View {
        ScrollView {
            VStack(spacing: AppThemePremium.lg) {
                ForEach(queue.jobs.reversed()) { job in
                    jobCard(job)
                }
            }
            .padding(AppThemePremium.screenPadding)
        }
    }

    private func jobCard(_ job: DownloadJob) -> some View {
        PremiumGlassCard {
            HStack(alignment: .top, spacing: AppThemePremium.md) {
                statusIcon(job)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: AppThemePremium.xs) {
                    Text(job.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppColorsPremium.textPrimary)
                        .lineLimit(2)

                    Text(statusHeadline(job))
                        .font(.caption)
                        .foregroundStyle(AppColorsPremium.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Menu {
                    Button(role: .destructive) {
                        queue.remove(job)
                    } label: {
                        Label(job.status == .running ? "Abbrechen" : "Entfernen", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(AppColorsPremium.textSecondary)
                }
            }

            detailContent(job)
        }
    }

    @ViewBuilder
    private func detailContent(_ job: DownloadJob) -> some View {
        switch job.status {
        case .waiting:
            Text("Der Download startet automatisch, sobald freier Platz verfügbar ist.")
                .font(.caption)
                .foregroundStyle(AppColorsPremium.textSecondary)

        case .running:
            if job.progress > 0 {
                VStack(alignment: .leading, spacing: AppThemePremium.sm) {
                    ProgressView(value: job.progress)
                        .tint(AppColorsPremium.accentBlue)

                    HStack {
                        Text("Lädt...")
                            .font(.caption)
                            .foregroundStyle(AppColorsPremium.textSecondary)
                        Spacer()
                        Text("\(Int(job.progress * 100))%")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColorsPremium.accentBlue)
                            .fontDesign(.monospaced)
                    }
                }
            } else {
                HStack(spacing: AppThemePremium.sm) {
                    ProgressView()
                        .tint(AppColorsPremium.accentBlue)
                        .scaleEffect(0.9, anchor: .center)

                    Text("Der Server bereitet die Datei vor...")
                        .font(.caption)
                        .foregroundStyle(AppColorsPremium.textSecondary)
                }
            }

        case .done:
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppColorsPremium.success)
                    .font(.caption)

                Text("In \"Meine Videos\" verfügbar")
                    .font(.caption)
                    .foregroundStyle(AppColorsPremium.success)

                Spacer()
            }

        case .failed:
            VStack(alignment: .leading, spacing: AppThemePremium.sm) {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppColorsPremium.error)

                    Text(job.message ?? "Download fehlgeschlagen")
                        .font(.caption)
                        .foregroundStyle(AppColorsPremium.error)
                }

                Button {
                    queue.retry(job)
                } label: {
                    Text("Erneut versuchen")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColorsPremium.accentTeal)
                }
            }
        }
    }

    @ViewBuilder
    private func statusIcon(_ job: DownloadJob) -> some View {
        switch job.status {
        case .waiting:
            Image(systemName: "hourglass")
                .foregroundStyle(AppColorsPremium.textTertiary)
        case .running:
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(AppColorsPremium.accentBlue)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppColorsPremium.success)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(AppColorsPremium.error)
        }
    }

    private func statusHeadline(_ job: DownloadJob) -> String {
        switch job.status {
        case .waiting: return "Wartet in Warteschlange"
        case .running: return "Wird gerade geladen"
        case .done: return "Abgeschlossen"
        case .failed: return "Fehler"
        }
    }
}

#Preview {
    QueueViewPremium()
}

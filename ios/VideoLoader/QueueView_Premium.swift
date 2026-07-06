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
                            .font(Aurora.Typography.subheadline.weight(.semibold))
                            .foregroundStyle(Aurora.Colors.accentTeal)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Aurora.Spacing.xl) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 48))
                .foregroundStyle(Aurora.Colors.accentBlue)
                .opacity(0.6)

            VStack(spacing: Aurora.Spacing.sm) {
                Text("Keine Downloads")
                    .font(Aurora.Typography.headline)
                    .foregroundStyle(Aurora.Colors.textPrimary)

                Text("Starten Sie einen Download im Tab „Laden", um ihn hier zu sehen.")
                    .font(Aurora.Typography.subheadline)
                    .foregroundStyle(Aurora.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Aurora.Spacing.xxl)
    }

    private var jobsList: some View {
        ScrollView {
            VStack(spacing: Aurora.Spacing.lg) {
                ForEach(queue.jobs.reversed()) { job in
                    jobCard(job)
                }
            }
            .padding(Aurora.Spacing.screen)
        }
    }

    private func jobCard(_ job: DownloadJob) -> some View {
        PremiumGlassCard {
            HStack(alignment: .top, spacing: Aurora.Spacing.md) {
                statusIcon(job)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: Aurora.Spacing.xs) {
                    Text(job.title)
                        .font(Aurora.Typography.headline)
                        .foregroundStyle(Aurora.Colors.textPrimary)
                        .lineLimit(2)

                    Text(statusHeadline(job))
                        .font(Aurora.Typography.caption)
                        .foregroundStyle(Aurora.Colors.textSecondary)
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
                        .foregroundStyle(Aurora.Colors.textSecondary)
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
                .font(Aurora.Typography.caption)
                .foregroundStyle(Aurora.Colors.textSecondary)

        case .running:
            if job.progress > 0 {
                VStack(alignment: .leading, spacing: Aurora.Spacing.sm) {
                    ProgressView(value: job.progress)
                        .tint(Aurora.Colors.accentBlue)

                    HStack {
                        Text("Lädt...")
                            .font(Aurora.Typography.caption)
                            .foregroundStyle(Aurora.Colors.textSecondary)
                        Spacer()
                        Text("\(Int(job.progress * 100))%")
                            .font(Aurora.Typography.caption.weight(.semibold))
                            .foregroundStyle(Aurora.Colors.accentBlue)
                            .fontDesign(.monospaced)
                    }
                }
            } else {
                HStack(spacing: Aurora.Spacing.sm) {
                    ProgressView()
                        .tint(Aurora.Colors.accentBlue)
                        .scaleEffect(0.9, anchor: .center)

                    Text("Der Server bereitet die Datei vor...")
                        .font(Aurora.Typography.caption)
                        .foregroundStyle(Aurora.Colors.textSecondary)
                }
            }

        case .done:
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Aurora.Colors.success)
                    .font(Aurora.Typography.caption)

                Text("In „Meine Videos" verfügbar")
                    .font(Aurora.Typography.caption)
                    .foregroundStyle(Aurora.Colors.success)

                Spacer()
            }

        case .failed:
            VStack(alignment: .leading, spacing: Aurora.Spacing.sm) {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Aurora.Colors.error)

                    Text(job.message ?? "Download fehlgeschlagen")
                        .font(Aurora.Typography.caption)
                        .foregroundStyle(Aurora.Colors.error)
                }

                Button {
                    queue.retry(job)
                } label: {
                    Text("Erneut versuchen")
                        .font(Aurora.Typography.caption.weight(.semibold))
                        .foregroundStyle(Aurora.Colors.accentTeal)
                }
            }
        }
    }

    @ViewBuilder
    private func statusIcon(_ job: DownloadJob) -> some View {
        switch job.status {
        case .waiting:
            Image(systemName: "hourglass")
                .foregroundStyle(Aurora.Colors.textTertiary)
        case .running:
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(Aurora.Colors.accentBlue)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Aurora.Colors.success)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(Aurora.Colors.error)
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

import SwiftUI

/// Zeigt die Download-Warteschlange mit Status (wartet / lädt / fertig / Fehler).
struct QueueView: View {
    @ObservedObject private var queue = DownloadQueue.shared

    private var orderedJobs: [DownloadJob] {
        queue.jobs.sorted { $0.createdAt > $1.createdAt }
    }

    private var activeJobs: [DownloadJob] {
        orderedJobs.filter { $0.status == .waiting || $0.status == .running }
    }

    private var finishedJobs: [DownloadJob] {
        orderedJobs.filter { $0.status == .done || $0.status == .failed }
    }

    private var waitingCount: Int { queue.jobs.filter { $0.status == .waiting }.count }
    private var runningCount: Int { queue.jobs.filter { $0.status == .running }.count }
    private var doneCount: Int { queue.jobs.filter { $0.status == .done }.count }
    private var failedCount: Int { queue.jobs.filter { $0.status == .failed }.count }

    private var summarySubtitle: String {
        if queue.jobs.isEmpty {
            return "Füge im Tab „Laden“ einen Link hinzu oder nutze die Share Extension."
        }
        return "\(activeJobs.count) aktiv, \(finishedJobs.count) abgeschlossen"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                    summaryCard

                    if queue.jobs.isEmpty {
                        EmptyStateView(
                            title: "Noch keine Downloads",
                            message: "Füge im Tab „Laden“ einen Link hinzu oder teile ein Video direkt an die App.",
                            systemImage: "arrow.down.circle"
                        )
                        .accessibilityLabel("Leere Download-Warteschlange")
                    } else {
                        if !activeJobs.isEmpty {
                            section(
                                title: "Aktive Downloads",
                                subtitle: "\(waitingCount) wartend, \(runningCount) läuft"
                            ) {
                                VStack(spacing: AppSpacing.md) {
                                    ForEach(activeJobs) { job in
                                        queueCard(for: job)
                                    }
                                }
                            }
                        }

                        if !finishedJobs.isEmpty {
                            section(
                                title: "Abgeschlossene Einträge",
                                subtitle: "\(doneCount) fertig, \(failedCount) fehlgeschlagen"
                            ) {
                                VStack(spacing: AppSpacing.md) {
                                    ForEach(finishedJobs) { job in
                                        queueCard(for: job)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, AppTheme.screenPadding)
            .padding(.top, AppSpacing.md)
            .background(queueBackground)
            .navigationTitle("Downloads")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                if queue.jobs.contains(where: { $0.status == .done || $0.status == .failed }) {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Aufräumen") { queue.clearFinished() }
                            .foregroundStyle(AppColors.textPrimary)
                            .accessibilityLabel("Abgeschlossene Downloads aufräumen")
                    }
                }
            }
        }
    }

    private var queueBackground: some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.background, AppColors.backgroundSoft, AppColors.background],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [AppColors.backgroundGlow.opacity(0.30), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 320
            )

            RadialGradient(
                colors: [AppColors.accentGlow.opacity(0.18), .clear],
                center: .bottomLeading,
                startRadius: 40,
                endRadius: 260
            )
        }
        .ignoresSafeArea()
    }

    private var summaryCard: some View {
        AppCard {
            SectionHeader(
                title: "Warteschlange",
                subtitle: summarySubtitle
            )

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: AppSpacing.md),
                    GridItem(.flexible(), spacing: AppSpacing.md)
                ],
                spacing: AppSpacing.md
            ) {
                QueueMetricChip(
                    title: "Aktiv",
                    value: "\(activeJobs.count)",
                    tint: AppColors.accentPrimary,
                    systemImage: "arrow.down.circle.fill"
                )
                QueueMetricChip(
                    title: "Wartend",
                    value: "\(waitingCount)",
                    tint: AppColors.info,
                    systemImage: "clock.fill"
                )
                QueueMetricChip(
                    title: "Fertig",
                    value: "\(doneCount)",
                    tint: AppColors.success,
                    systemImage: "checkmark.circle.fill"
                )
                QueueMetricChip(
                    title: "Fehler",
                    value: "\(failedCount)",
                    tint: AppColors.error,
                    systemImage: "exclamationmark.triangle.fill"
                )
            }
        }
    }

    private func section<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeader(title: title, subtitle: subtitle)
            content()
        }
    }

    @ViewBuilder
    private func queueCard(for job: DownloadJob) -> some View {
        switch job.status {
        case .failed:
            ErrorStateView(
                title: job.title,
                message: job.message ?? "Bitte versuche den Download erneut.",
                actionTitle: "Erneut versuchen",
                action: { queue.retry(job) }
            )
            .accessibilityLabel("Fehlgeschlagener Download \(job.title)")
            .swipeActions(edge: .trailing) {
                removeAction(for: job)
            }
        default:
            AppCard {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    HStack(alignment: .top, spacing: AppSpacing.md) {
                        QueueStatusBadge(job: job)

                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text(job.title)
                                .font(AppTypography.headline)
                                .foregroundStyle(AppColors.textPrimary)
                                .lineLimit(2)
                                .accessibilityAddTraits(.isHeader)

                            Text(sourceLabel(for: job.sourceLink))
                                .font(AppTypography.footnote)
                                .foregroundStyle(AppColors.textSecondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)
                    }

                    Text(job.sourceLink)
                        .font(AppTypography.mono)
                        .foregroundStyle(AppColors.textTertiary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                        .accessibilityLabel("Quell-Link \(job.sourceLink)")

                    queueDetail(for: job)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel(for: job))
            .swipeActions(edge: .trailing) {
                removeAction(for: job)
            }
        }
    }

    @ViewBuilder
    private func queueDetail(for job: DownloadJob) -> some View {
        switch job.status {
        case .waiting:
            HStack(spacing: AppSpacing.sm) {
                ProgressView()
                    .tint(AppColors.accentPrimary)
                Text("Der Download startet automatisch, sobald vorherige Aufträge abgeschlossen sind.")
                    .font(AppTypography.footnote)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .running:
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                ProgressView(value: job.progress)
                    .tint(AppColors.accentPrimary)
                    .accessibilityLabel("Downloadfortschritt")

                Text(job.progress > 0
                     ? "\(Int(job.progress * 100)) Prozent heruntergeladen"
                     : "Der Server bereitet die Datei vor.")
                    .font(AppTypography.footnote)
                    .foregroundStyle(AppColors.textSecondary)
            }
        case .done:
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppColors.success)
                Text("Das Video liegt jetzt in „Meine Videos“ und kann dort abgespielt oder geteilt werden.")
                    .font(AppTypography.footnote)
                    .foregroundStyle(AppColors.success)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .failed:
            EmptyView()
        }
    }

    @ViewBuilder
    private func removeAction(for job: DownloadJob) -> some View {
        Button(role: .destructive) {
            queue.remove(job)
        } label: {
            Label(job.status == .running ? "Abbrechen" : "Entfernen",
                  systemImage: job.status == .running ? "xmark" : "trash")
        }
        .accessibilityLabel(job.status == .running ? "Download abbrechen" : "Download entfernen")
    }

    private func accessibilityLabel(for job: DownloadJob) -> String {
        switch job.status {
        case .waiting:
            return "\(job.title), wartet auf den Start"
        case .running:
            return "\(job.title), wird heruntergeladen"
        case .done:
            return "\(job.title), abgeschlossen"
        case .failed:
            return "\(job.title), fehlgeschlagen"
        }
    }

    private func sourceLabel(for source: String) -> String {
        guard let url = URL(string: source), let host = url.host else {
            return source
        }
        return host
    }
}

private struct QueueStatusBadge: View {
    let job: DownloadJob

    private var tone: (color: Color, title: String, systemImage: String) {
        switch job.status {
        case .waiting:
            return (AppColors.info, "Wartet", "clock.fill")
        case .running:
            return (AppColors.accentPrimary, "Lädt", "arrow.down.circle.fill")
        case .done:
            return (AppColors.success, "Fertig", "checkmark.circle.fill")
        case .failed:
            return (AppColors.error, "Fehler", "xmark.octagon.fill")
        }
    }

    var body: some View {
        Label {
            Text(tone.title)
                .font(AppTypography.caption.weight(.semibold))
        } icon: {
            Image(systemName: tone.systemImage)
        }
        .labelStyle(.titleAndIcon)
        .font(AppTypography.caption.weight(.semibold))
        .foregroundStyle(tone.color)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(
            Capsule(style: .continuous)
                .fill(tone.color.opacity(0.14))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(tone.color.opacity(0.22), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Status \(tone.title) für \(job.title)")
    }
}

private struct QueueMetricChip: View {
    let title: String
    let value: String
    let tint: Color
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)

                Text(title)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Text(value)
                .font(AppTypography.title2)
                .foregroundStyle(AppColors.textPrimary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .fill(AppColors.surfaceStrong)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
        .appShadow(AppShadow.elevated)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

#Preview {
    QueueView()
}

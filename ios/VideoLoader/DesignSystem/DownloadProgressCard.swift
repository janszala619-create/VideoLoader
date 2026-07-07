import SwiftUI

/// Kartenansicht für einen laufenden oder abgeschlossenen Download-Job.
/// Rein präsentationell — bindet sich bewusst nicht an ein konkretes Queue-Modell,
/// damit bestehende ViewModels/Datenmodelle unverändert bleiben.
struct DownloadProgressCard: View {
    let title: String
    var description: String?
    /// `nil` zeigt einen unbestimmten Fortschrittsbalken (z. B. während des Wartens).
    var progress: Double?
    let statusText: String
    var statusTone: Color = AppTheme.accent

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(title)
                    .font(AppTypography.bodyEmphasized)
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(2)

                if let description {
                    Text(description)
                        .font(AppTypography.footnote)
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(1)
                }

                if let progress {
                    ProgressView(value: progress)
                        .tint(statusTone)
                        .animation(AppMotion.quick, value: progress)
                } else {
                    ProgressView()
                        .tint(statusTone)
                }

                HStack(spacing: AppSpacing.xs) {
                    AppStatusDot(color: statusTone)
                    Text(statusText)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: AppSpacing.md) {
        DownloadProgressCard(
            title: "Mein Urlaubsvideo",
            description: "1080p · MP4",
            progress: 0.64,
            statusText: "Wird heruntergeladen · 64%",
            statusTone: AppTheme.accent
        )
        DownloadProgressCard(
            title: "Wartet in der Warteschlange",
            progress: nil,
            statusText: "Wartet",
            statusTone: AppTheme.secondaryText
        )
    }
    .padding()
    .background(AppTheme.background)
}

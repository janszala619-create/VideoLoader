import SwiftUI

/// Ladezustand mit ProgressView und Statustext.
struct LoadingStateView: View {
    let title: String
    var message: String?

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            ProgressView()
                .tint(AppTheme.accent)
                .frame(width: 88, height: 88)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.accent.opacity(0.16), AppTheme.accent.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    Circle()
                        .stroke(AppColorsPremium.glassBorder, lineWidth: 1)
                )

            VStack(spacing: AppSpacing.sm) {
                Text(title)
                    .font(AppTypography.sectionTitle)
                    .foregroundStyle(AppTheme.primaryText)

                if let message {
                    Text(message)
                        .font(AppTypography.footnote)
                        .foregroundStyle(AppTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xxl)
    }
}

#Preview {
    LoadingStateView(title: "Video wird geprüft", message: "Metadaten werden geladen.")
        .background(AppTheme.background)
}

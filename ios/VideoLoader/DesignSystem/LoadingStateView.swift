import SwiftUI

/// Ladezustand mit ProgressView und Statustext.
struct LoadingStateView: View {
    let title: String
    var message: String?

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            ProgressView()
                .tint(AppTheme.accent)

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

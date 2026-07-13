import SwiftUI

/// Fehlerzustand mit Icon, Titel, Beschreibung und optionalem Retry-Button.
struct ErrorStateView: View {
    var systemImage: String = "exclamationmark.triangle.fill"
    let title: String
    let message: String
    var retryTitle: String?
    var retryAction: (() -> Void)?

    var body: some View {
        AppCard {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(AppTheme.danger)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle().fill(AppTheme.danger.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(title)
                        .font(AppTypography.sectionTitle)
                        .foregroundStyle(AppTheme.danger)
                    Text(message)
                        .font(AppTypography.footnote)
                        .foregroundStyle(AppTheme.secondaryText)

                    if let retryTitle, let retryAction {
                        Button(retryTitle, action: retryAction)
                            .buttonStyle(.borderless)
                            .font(AppTypography.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                            .padding(.top, AppSpacing.xs)
                    }
                }
            }
        }
    }
}

#Preview {
    ErrorStateView(
        title: "Aktion fehlgeschlagen",
        message: "Der Server konnte nicht erreicht werden.",
        retryTitle: "Erneut versuchen",
        retryAction: {}
    )
    .padding()
    .background(AppTheme.background)
}

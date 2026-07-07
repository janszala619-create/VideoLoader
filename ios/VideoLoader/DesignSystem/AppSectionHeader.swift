import SwiftUI

/// Einheitliche Abschnittsüberschrift für Listen und Formularbereiche.
struct AppSectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title.uppercased())
                .font(AppTypography.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)
                .tracking(1.2)

            if let subtitle {
                Text(subtitle)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppTheme.secondaryText.opacity(0.8))
            }
        }
    }
}

#Preview {
    AppSectionHeader(title: "Qualität", subtitle: "Verfügbare Auflösungen")
        .padding()
        .background(AppTheme.background)
}

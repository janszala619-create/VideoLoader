import SwiftUI

/// Einheitlicher Karten-Container mit systemnahem Glass-Hintergrund,
/// konsistentem Padding/Radius und optionalem Schatten.
struct AppCard<Content: View>: View {
    var showsShadow: Bool = true
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            content
        }
        .padding(AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .fill(AppTheme.surface)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .stroke(AppColorsPremium.glassBorder, lineWidth: 1)
        )
        .appShadow(showsShadow ? .card : .none)
    }
}

#Preview {
    AppCard {
        Text("Titel").font(AppTypography.sectionTitle).foregroundStyle(AppTheme.primaryText)
        Text("Beschreibung im Kartenkörper.").font(AppTypography.footnote).foregroundStyle(AppTheme.secondaryText)
    }
    .padding()
    .background(AppTheme.background)
}

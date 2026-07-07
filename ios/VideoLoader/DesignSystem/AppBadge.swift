import SwiftUI

/// Kleines, farbiges Pill-Label für kurze Kennzeichnungen (z. B. „Empfohlen“, „Neu“).
struct AppBadge: View {
    let text: String
    var tint: Color = AppTheme.accent

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(tint.opacity(0.16))
            )
    }
}

#Preview {
    HStack(spacing: AppSpacing.sm) {
        AppBadge(text: "Empfohlen", tint: AppTheme.accent)
        AppBadge(text: "Neu", tint: AppTheme.success)
        AppBadge(text: "Fehler", tint: AppTheme.danger)
    }
    .padding()
    .background(AppTheme.background)
}

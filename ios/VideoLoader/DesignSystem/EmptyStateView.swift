import SwiftUI

/// Leerer Zustand mit Icon, Titel, Beschreibung und optionaler Aktion.
struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.accent.opacity(0.6))

            VStack(spacing: AppSpacing.sm) {
                Text(title)
                    .font(AppTypography.sectionTitle)
                    .foregroundStyle(AppTheme.primaryText)
                Text(message)
                    .font(AppTypography.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle, let action {
                AppButton(title: actionTitle, kind: .secondary, action: action)
                    .frame(maxWidth: 220)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xxl)
        .padding(.horizontal, AppSpacing.lg)
    }
}

#Preview {
    EmptyStateView(
        systemImage: "tray",
        title: "Keine Downloads",
        message: "Füge einen Video-Link hinzu, um deine erste Datei herunterzuladen.",
        actionTitle: "Link einfügen",
        action: {}
    )
    .background(AppTheme.background)
}

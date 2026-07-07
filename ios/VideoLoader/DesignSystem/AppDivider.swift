import SwiftUI

/// Dezenter horizontaler Trenner im Glass-Farbton, z. B. zwischen Listenabschnitten.
struct AppDivider: View {
    var body: some View {
        Rectangle()
            .fill(AppColorsPremium.divider)
            .frame(height: 1)
    }
}

#Preview {
    VStack(spacing: AppSpacing.md) {
        Text("Oben").foregroundStyle(AppTheme.primaryText)
        AppDivider()
        Text("Unten").foregroundStyle(AppTheme.primaryText)
    }
    .padding()
    .background(AppTheme.background)
}

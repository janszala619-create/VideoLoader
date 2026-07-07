import SwiftUI

/// Kleiner Farbpunkt zur Statuskennzeichnung, z. B. neben Statustexten in Karten und Listen.
struct AppStatusDot: View {
    var color: Color = AppTheme.accent
    var diameter: CGFloat = 6

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: diameter, height: diameter)
    }
}

#Preview {
    HStack(spacing: AppSpacing.md) {
        AppStatusDot(color: AppTheme.accent)
        AppStatusDot(color: AppTheme.success)
        AppStatusDot(color: AppTheme.warning)
        AppStatusDot(color: AppTheme.danger)
    }
    .padding()
    .background(AppTheme.background)
}

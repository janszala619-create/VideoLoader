import SwiftUI

struct PrimaryButton: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.button)
            .foregroundStyle(AppColors.textPrimary)
            .frame(maxWidth: .infinity, minHeight: AppTheme.controlHeight)
            .padding(.horizontal, AppSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [AppColors.accentPrimary, AppColors.accentSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .stroke(AppColors.highlight.opacity(0.7), lineWidth: 1)
            )
            .shadow(color: AppColors.accentGlow, radius: 20, x: 0, y: 8)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: AppTheme.animationFast), value: configuration.isPressed)
    }
}

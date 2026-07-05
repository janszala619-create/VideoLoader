import SwiftUI

struct GlassPrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppGlassTypography.button)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: AppGlassTheme.controlHeight)
            .padding(.horizontal, AppGlassSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: AppGlassTheme.radiusMedium, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [AppGlassColors.accentPrimary, AppGlassColors.accentSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppGlassTheme.radiusMedium, style: .continuous)
                    .stroke(AppGlassColors.glassHighlight.opacity(0.7), lineWidth: 1)
            )
            .shadow(color: AppGlassColors.accentGlow, radius: 20, x: 0, y: 8)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct GlassSecondaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppGlassTypography.button)
            .foregroundStyle(AppGlassColors.textPrimary)
            .frame(maxWidth: .infinity, minHeight: AppGlassTheme.controlHeight)
            .padding(.horizontal, AppGlassSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: AppGlassTheme.radiusMedium, style: .continuous)
                    .fill(AppGlassColors.glassSurfaceElevated)
            )
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: AppGlassTheme.radiusMedium, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppGlassTheme.radiusMedium, style: .continuous)
                    .stroke(AppGlassColors.glassBorder, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.92 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

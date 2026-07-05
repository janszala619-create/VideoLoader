import SwiftUI

struct GlassPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppGlassTypography.button)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: AppGlassTheme.controlHeight)
            .padding(.horizontal, AppGlassSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: AppGlassTheme.radiusMedium, style: .continuous)
                    .fill(AppGlassColors.accentPrimary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppGlassTheme.radiusMedium, style: .continuous)
                    .stroke(AppGlassColors.glassHighlight.opacity(0.65), lineWidth: 1)
            )
            .shadow(color: AppGlassColors.accentGlow, radius: 20, x: 0, y: 8)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct GlassSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppGlassTypography.button)
            .foregroundStyle(AppGlassColors.textPrimary)
            .frame(maxWidth: .infinity, minHeight: AppGlassTheme.controlHeight)
            .padding(.horizontal, AppGlassSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: AppGlassTheme.radiusMedium, style: .continuous)
                    .fill(AppGlassColors.glassSurfaceStrong)
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
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

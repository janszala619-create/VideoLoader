import SwiftUI

struct GlassCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppGlassSpacing.md) {
            content
        }
        .padding(AppGlassSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppGlassTheme.radiusLarge, style: .continuous)
                .fill(AppGlassColors.glassSurface)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppGlassTheme.radiusLarge, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppGlassTheme.radiusLarge, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            AppGlassColors.glassHighlight.opacity(0.14),
                            Color.clear,
                            AppGlassColors.accentGlow.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppGlassTheme.radiusLarge, style: .continuous)
                .stroke(AppGlassColors.glassBorder, lineWidth: 1)
        )
        .shadow(
            color: AppGlassShadows.card.color,
            radius: AppGlassShadows.card.radius,
            x: AppGlassShadows.card.x,
            y: AppGlassShadows.card.y
        )
    }
}

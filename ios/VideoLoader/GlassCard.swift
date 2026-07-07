import SwiftUI

struct GlassCard<Content: View>: View {
    @ViewBuilder let content: Content
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        VStack(alignment: .leading, spacing: AppGlassSpacing.md) {
            content
        }
        .padding(AppGlassSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppGlassTheme.radiusLarge, style: .continuous)
                .fill(reduceTransparency ? AppGlassColors.bgElevated : AppGlassColors.glassSurface)
        )
        .background {
            if !reduceTransparency {
                RoundedRectangle(cornerRadius: AppGlassTheme.radiusLarge, style: .continuous)
                    .fill(.regularMaterial)
            }
        }
        .overlay(
            Group {
                if !reduceTransparency {
                    RoundedRectangle(cornerRadius: AppGlassTheme.radiusLarge, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppGlassColors.glassHighlight.opacity(0.10),
                                    Color.clear,
                                    AppGlassColors.accentGlow.opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .allowsHitTesting(false)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppGlassTheme.radiusLarge, style: .continuous)
                .stroke(AppGlassColors.glassBorder, lineWidth: 1)
                .allowsHitTesting(false)
        )
        .shadow(
            color: AppGlassShadows.card.color,
            radius: AppGlassShadows.card.radius,
            x: AppGlassShadows.card.x,
            y: AppGlassShadows.card.y
        )
    }
}

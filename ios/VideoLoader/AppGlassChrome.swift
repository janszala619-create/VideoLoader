import SwiftUI

struct AppGlassBackground: View {
    var glowAlignment: Alignment = .topTrailing

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppGlassColors.bgAccentTop, AppGlassColors.bgBase, AppGlassColors.bgDeep],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [AppGlassColors.accentGlow.opacity(0.7), Color.clear],
                center: glowAlignment == .topLeading ? .topLeading : .topTrailing,
                startRadius: 20,
                endRadius: 280
            )
            .blur(radius: 34)

            RadialGradient(
                colors: [AppGlassColors.glassHighlight.opacity(0.16), Color.clear],
                center: .topLeading,
                startRadius: 10,
                endRadius: 220
            )
            .blur(radius: 42)
        }
        .ignoresSafeArea()
    }
}

struct AppGlassSectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(AppGlassTypography.subheadline)
            .foregroundStyle(AppGlassColors.textSecondary)
            .tracking(1.2)
    }
}

struct AppGlassHeroCard<Trailing: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let trailing: Trailing

    var body: some View {
        GlassCard {
            HStack(alignment: .center, spacing: AppGlassSpacing.md) {
                VStack(alignment: .leading, spacing: AppGlassSpacing.xs) {
                    Text(title)
                        .font(AppGlassTypography.headline)
                        .foregroundStyle(AppGlassColors.textPrimary)
                    Text(subtitle)
                        .font(AppGlassTypography.footnote)
                        .foregroundStyle(AppGlassColors.textSecondary)
                }

                Spacer()
                trailing
            }
        }
    }
}

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

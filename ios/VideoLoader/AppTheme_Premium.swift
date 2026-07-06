import SwiftUI

enum AppThemePremium {
    // MARK: - Spacing
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32

    // MARK: - Border Radius
    static let radiusSmall: CGFloat = 10
    static let radiusMedium: CGFloat = 14
    static let radiusLarge: CGFloat = 20
    static let radiusSheet: CGFloat = 28
    static let radiusFull: CGFloat = 999

    // MARK: - Control Sizes
    static let controlHeight: CGFloat = 48
    static let screenPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 24

    // MARK: - Shadows (Deep, nicht zu subtil)
    static let shadowSmall = ShadowProps(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
    static let shadowMedium = ShadowProps(color: .black.opacity(0.25), radius: 16, x: 0, y: 8)
    static let shadowLarge = ShadowProps(color: .black.opacity(0.35), radius: 24, x: 0, y: 12)

    // MARK: - Animation Durations
    static let durationFast: CGFloat = 0.12
    static let durationNormal: CGFloat = 0.2
    static let durationSlow: CGFloat = 0.3
}

struct ShadowProps {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

/// Aurora Background mit Blau/Teal/Lila Lichtern — Premium Version
struct PremiumAuroraBackground: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            ZStack {
                // Base Gradient
                LinearGradient(
                    colors: [
                        Aurora.Colors.bgElevated,
                        Aurora.Colors.bgBase,
                        Aurora.Colors.bgDeep
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Blau-Aurora (oben links)
                Circle()
                    .fill(Aurora.Colors.blue.opacity(0.28))
                    .frame(width: w * 0.85)
                    .blur(radius: 100)
                    .offset(x: -w * 0.35, y: -h * 0.25)
                    .animation(
                        Animation.easeInOut(duration: 8).repeatForever(autoreverses: true),
                        value: UUID()
                    )

                // Teal-Aurora (oben rechts)
                Circle()
                    .fill(Aurora.Colors.teal.opacity(0.20))
                    .frame(width: w * 0.7)
                    .blur(radius: 110)
                    .offset(x: w * 0.45, y: -h * 0.1)
                    .animation(
                        Animation.easeInOut(duration: 10).repeatForever(autoreverses: true)
                            .delay(1),
                        value: UUID()
                    )

                // Violet-Aurora (unten)
                Circle()
                    .fill(Aurora.Colors.violet.opacity(0.18))
                    .frame(width: w * 0.95)
                    .blur(radius: 120)
                    .offset(x: w * 0.05, y: h * 0.45)
                    .animation(
                        Animation.easeInOut(duration: 12).repeatForever(autoreverses: true)
                            .delay(2),
                        value: UUID()
                    )
            }
        }
        .ignoresSafeArea()
    }
}

/// Für schnelle Schatten-Anwendung
extension View {
    func premiumShadow(_ shadow: ShadowProps) -> some View {
        self.shadow(
            color: shadow.color,
            radius: shadow.radius,
            x: shadow.x,
            y: shadow.y
        )
    }
}

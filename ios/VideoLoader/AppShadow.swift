import SwiftUI

struct AppShadowToken {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

enum AppShadow {
    static let card = AppShadowToken(
        color: .black.opacity(0.16),
        radius: 16,
        x: 0,
        y: 10
    )

    static let elevated = AppShadowToken(
        color: .black.opacity(0.22),
        radius: 22,
        x: 0,
        y: 12
    )

    static let modal = AppShadowToken(
        color: .black.opacity(0.26),
        radius: 24,
        x: 0,
        y: 12
    )

    static let glow = AppShadowToken(
        color: AppColors.accentGlow,
        radius: 20,
        x: 0,
        y: 8
    )
}

extension View {
    func appShadow(_ token: AppShadowToken) -> some View {
        shadow(color: token.color, radius: token.radius, x: token.x, y: token.y)
    }
}

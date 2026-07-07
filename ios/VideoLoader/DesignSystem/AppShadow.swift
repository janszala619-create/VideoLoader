import SwiftUI

/// Beschreibt einen Schatten-Stil, damit Views ihn per `.appShadow(...)` anwenden können.
struct AppShadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    static let none = AppShadow(color: .clear, radius: 0, x: 0, y: 0)

    static let card = AppShadow(
        color: .black.opacity(0.18),
        radius: 18,
        x: 0,
        y: 8
    )

    static let elevated = AppShadow(
        color: .black.opacity(0.28),
        radius: 28,
        x: 0,
        y: 14
    )
}

extension View {
    func appShadow(_ style: AppShadow) -> some View {
        shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }
}

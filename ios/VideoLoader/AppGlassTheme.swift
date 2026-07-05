import SwiftUI

enum AppGlassTheme {
    static let radiusSmall: CGFloat = 10
    static let radiusMedium: CGFloat = 14
    static let radiusLarge: CGFloat = 18
    static let radiusSheet: CGFloat = 24
    static let radiusFull: CGFloat = 999

    static let controlHeight: CGFloat = 44
    static let screenPadding: CGFloat = AppGlassSpacing.lg
    static let sectionSpacing: CGFloat = AppGlassSpacing.xl
    static let heroSpacing: CGFloat = AppGlassSpacing.xxl
}

struct AppGlassShadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

enum AppGlassShadows {
    static let card = AppGlassShadow(
        color: .black.opacity(0.18),
        radius: 18,
        x: 0,
        y: 8
    )

    static let modal = AppGlassShadow(
        color: .black.opacity(0.28),
        radius: 28,
        x: 0,
        y: 14
    )
}

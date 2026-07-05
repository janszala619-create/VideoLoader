import SwiftUI

enum AppGlassTheme {
    static let radiusSmall: CGFloat = 10
    static let radiusMedium: CGFloat = 16
    static let radiusLarge: CGFloat = 20
    static let radiusSheet: CGFloat = 24
    static let radiusFull: CGFloat = 999

    static let controlHeight: CGFloat = 46
    static let screenPadding: CGFloat = AppGlassSpacing.xl
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
        color: .black.opacity(0.16),
        radius: 16,
        x: 0,
        y: 10
    )

    static let modal = AppGlassShadow(
        color: .black.opacity(0.26),
        radius: 24,
        x: 0,
        y: 12
    )
}

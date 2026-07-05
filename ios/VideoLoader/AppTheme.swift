import SwiftUI

enum AppTheme {
    static let minTouchTarget: CGFloat = 44
    static let controlHeight: CGFloat = 46
    static let screenPadding: CGFloat = AppSpacing.xl
    static let sectionSpacing: CGFloat = AppSpacing.xl
    static let heroSpacing: CGFloat = AppSpacing.xxl

    static let animationFast: Double = 0.16
    static let animationStandard: Double = 0.24
    static let animationSlow: Double = 0.32

    static let spring = Animation.interpolatingSpring(stiffness: 180, damping: 22)
    static let gentleSpring = Animation.spring(response: 0.28, dampingFraction: 0.82, blendDuration: 0.04)

    static let cardMaterial: Material = .ultraThinMaterial
    static let navBarMaterial: Material = .ultraThinMaterial
    static let tabBarMaterial: Material = .ultraThinMaterial
}

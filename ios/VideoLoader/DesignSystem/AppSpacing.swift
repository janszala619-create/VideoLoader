import SwiftUI

/// Einheitliche Abstands-Skala für Paddings, Stacks und Layout-Lücken.
enum AppSpacing {
    /// Feinabstimmung für sehr kompakte Elemente (z. B. Badge-Innenabstand).
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32

    /// Mindesthöhe für Buttons, Eingabefelder und Icon-Touch-Targets.
    static let controlHeight: CGFloat = 44
}

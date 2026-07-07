import SwiftUI

/// Einheitliche Textstile. Basiert auf semantischen System-Textstilen,
/// damit Dynamic Type und Accessibility-Schriftgrößen automatisch funktionieren.
enum AppTypography {
    static let title = Font.largeTitle.weight(.bold)
    static let subtitle = Font.title3.weight(.semibold)
    static let sectionTitle = Font.headline.weight(.semibold)
    static let body = Font.body
    static let bodyEmphasized = Font.body.weight(.semibold)
    static let caption = Font.caption
    static let footnote = Font.footnote
}

import SwiftUI

/// Einheitliche Icon-Größen, damit Zustands- und Hero-Icons app-weit konsistent bleiben.
enum AppIconSize {
    /// Durchmesser für große, zentrierte Zustands-Badges (Empty/Loading State).
    static let stateBadge: CGFloat = 88
    /// Glyph-Größe für Icons innerhalb großer Zustands-Badges.
    static let stateGlyph: CGFloat = 36
    /// Durchmesser für kompakte Inline-Badges (z. B. Fehlerzustand).
    static let inlineBadge: CGFloat = 36
    /// Hero-Icon-Größe (z. B. Play-Button auf der Video-Vorschau).
    static let hero: CGFloat = 56
}

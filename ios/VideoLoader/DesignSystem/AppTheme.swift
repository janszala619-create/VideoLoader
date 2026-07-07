import SwiftUI

/// Zentrale Farbrollen des Design-Systems.
/// Baut auf der bestehenden Premium-Glass-Palette (`AppColorsPremium`) auf,
/// damit Farbwerte an einer Stelle gepflegt werden und Dark Mode konsistent bleibt.
enum AppTheme {
    // MARK: - Surfaces
    static let background = AppColorsPremium.bgBase
    static let surface = AppColorsPremium.glassSurface
    static let elevatedSurface = AppColorsPremium.bgElevated

    // MARK: - Text
    static let primaryText = AppColorsPremium.textPrimary
    static let secondaryText = AppColorsPremium.textSecondary

    // MARK: - Accent & Status
    static let accent = AppColorsPremium.accentBlue
    static let success = AppColorsPremium.success
    static let warning = AppColorsPremium.warning
    static let danger = AppColorsPremium.error
}

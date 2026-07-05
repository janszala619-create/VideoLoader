import SwiftUI

enum AppGlassColors {
    static let bgDeep = Color(hex: 0x05070D)
    static let bgBase = Color(hex: 0x0A1020)
    static let bgElevated = Color(hex: 0x10182E)
    static let bgAccentTop = Color(hex: 0x20284D)
    static let bgAccentBottom = Color(hex: 0x141A31)

    static let glassSurface = Color(red: 20 / 255, green: 25 / 255, blue: 39 / 255).opacity(0.42)
    static let glassSurfaceStrong = Color(red: 34 / 255, green: 41 / 255, blue: 59 / 255).opacity(0.68)
    static let glassHighlight = Color.white.opacity(0.22)
    static let glassBorder = Color.white.opacity(0.16)

    static let textPrimary = Color(hex: 0xEDEDEF)
    static let textSecondary = Color(hex: 0xB3B8C2)
    static let textTertiary = Color(hex: 0x8A8F98)

    static let accentPrimary = Color(hex: 0x6F7CFF)
    static let accentSecondary = Color(hex: 0x96A0FF)
    static let accentGlow = Color(red: 111 / 255, green: 124 / 255, blue: 255 / 255).opacity(0.30)

    static let success = Color(hex: 0x22C55E)
    static let warning = Color(hex: 0xF59E0B)
    static let error = Color(hex: 0xF43F5E)
}

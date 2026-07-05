import SwiftUI

enum AppGlassColors {
    static let bgDeep = Color(hex: 0x04060B)
    static let bgBase = Color(hex: 0x08101E)
    static let bgElevated = Color(hex: 0x0D1628)
    static let bgAccentTop = Color(hex: 0x20284D)
    static let bgAccentBottom = Color(hex: 0x10182E)

    static let glassSurface = Color(red: 18 / 255, green: 23 / 255, blue: 38 / 255).opacity(0.44)
    static let glassSurfaceStrong = Color(red: 30 / 255, green: 39 / 255, blue: 60 / 255).opacity(0.72)
    static let glassSurfaceElevated = Color(red: 39 / 255, green: 48 / 255, blue: 72 / 255).opacity(0.84)
    static let glassHighlight = Color.white.opacity(0.24)
    static let glassBorder = Color.white.opacity(0.14)

    static let textPrimary = Color(hex: 0xEDEDEF)
    static let textSecondary = Color(hex: 0xB5BBC6)
    static let textTertiary = Color(hex: 0x89909C)

    static let accentPrimary = Color(hex: 0x6F7CFF)
    static let accentSecondary = Color(hex: 0x96A0FF)
    static let accentGlow = Color(red: 111 / 255, green: 124 / 255, blue: 255 / 255).opacity(0.26)

    static let success = Color(hex: 0x22C55E)
    static let warning = Color(hex: 0xF59E0B)
    static let error = Color(hex: 0xF43F5E)
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

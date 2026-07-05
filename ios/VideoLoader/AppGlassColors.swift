import SwiftUI

enum AppGlassColors {
    static let bgDeep = Color(hex: 0x020203)
    static let bgBase = Color(hex: 0x050506)
    static let bgElevated = Color(hex: 0x0A0A0C)

    static let glassSurface = Color.white.opacity(0.06)
    static let glassSurfaceStrong = Color.white.opacity(0.10)
    static let glassHighlight = Color.white.opacity(0.16)
    static let glassBorder = Color.white.opacity(0.12)

    static let textPrimary = Color(hex: 0xEDEDEF)
    static let textSecondary = Color(hex: 0xB3B8C2)
    static let textTertiary = Color(hex: 0x8A8F98)

    static let accentPrimary = Color(hex: 0x5E6AD2)
    static let accentSecondary = Color(hex: 0x7C8CFF)
    static let accentGlow = Color(red: 94 / 255, green: 106 / 255, blue: 210 / 255).opacity(0.22)

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

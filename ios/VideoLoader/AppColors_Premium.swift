import SwiftUI

/// Premium Color Palette: Blau/Teal/Lila mit cooler, fokussierter Energie
/// Für eine produktive App, die ernst genommen werden möchte
enum AppColorsPremium {
    // MARK: - Backgrounds (Dunkelblau Basis)
    static let bgDeep = Color(hex: 0x0A0D1A)      // Ultra-dunkel, fast schwarz mit Blau-Ton
    static let bgBase = Color(hex: 0x0F1428)      // Standard-Dunkelblau
    static let bgElevated = Color(hex: 0x151D35)  // Etwas heller für Karten/Modals

    // MARK: - Aurora Lights (Cool, fokussiert)
    static let auroraBlue = Color(hex: 0x3B5BFF)     // Satt-Blau, leuchtet
    static let auroraTeal = Color(hex: 0x00D4FF)     // Cyan-Teal, energisch
    static let auroraViolet = Color(hex: 0x8B5CF6)   // Violett, tiefgreifend

    // MARK: - Glass Surfaces
    static let glassSurface = Color.white.opacity(0.04)
    static let glassSurfaceStrong = Color.white.opacity(0.07)
    static let glassHighlight = Color.white.opacity(0.16)
    static let glassBorder = Color.white.opacity(0.10)
    static let glassEdgeTop = Color.white.opacity(0.25)
    static let glassEdgeBottom = Color.white.opacity(0.05)

    // MARK: - Text (Cool-getönt, nicht warm)
    static let textPrimary = Color(hex: 0xF0F4FF)    // Weiß mit leichtem Blau-Ton
    static let textSecondary = Color(hex: 0xA8B5E0)  // Blau-getönt (nicht grau)
    static let textTertiary = Color(hex: 0x6B7FA8)   // Dunkler, aber noch blau

    // MARK: - Primary Accent (Blau dominiert)
    static let accentBlue = Color(hex: 0x3B5BFF)          // Hauptakzent: Satt-Blau
    static let accentBlueLighter = Color(hex: 0x5B7FFF)   // Hover-State
    static let accentBlueDark = Color(hex: 0x2A3FCC)      // Pressed-State
    static let accentBlueGlow = Color(hex: 0x3B5BFF).opacity(0.32)

    // MARK: - Secondary Accent (Teal für Gegenpol)
    static let accentTeal = Color(hex: 0x00D4FF)          // Helles Cyan-Teal
    static let accentTealLight = Color(hex: 0x33E5FF)     // Hover
    static let accentTealDark = Color(hex: 0x00A8CC)      // Pressed

    // MARK: - Tertiary (Violet, zurückhaltend)
    static let accentViolet = Color(hex: 0x8B5CF6)        // Für spezielle Actions

    // MARK: - Status Colors (Satt, gut sichtbar)
    static let success = Color(hex: 0x10B981)     // Grün, aber kälter
    static let warning = Color(hex: 0xF59E0B)     // Amber/Orange
    static let error = Color(hex: 0xEF4444)       // Rot, heller (auf dunkel besser sichtbar)
    static let info = Color(hex: 0x00D4FF)        // = Teal (nicht neu erfinden)

    // MARK: - Neutrals (Für Disabledstates, Dividers)
    static let surfaceDisabled = Color.white.opacity(0.02)
    static let textDisabled = Color.white.opacity(0.35)
    static let divider = Color.white.opacity(0.08)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

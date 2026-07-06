import SwiftUI

// MARK: - Aurora Design System
// Einzige Quelle aller visuellen Tokens. Keine Views, keine Logik.

enum Aurora {

    // MARK: - Colors
    enum Colors {
        // Hintergründe (Dunkelblau-Basis)
        static let bgDeep      = Color(hex: 0x0A0D1A)
        static let bgBase      = Color(hex: 0x0F1428)
        static let bgElevated  = Color(hex: 0x151D35)

        // Aurora-Lichter
        static let blue   = Color(hex: 0x3B5BFF)
        static let teal   = Color(hex: 0x00D4FF)
        static let violet = Color(hex: 0x8B5CF6)

        // Glasoberflächen
        static let glassBg          = Color.white.opacity(0.04)
        static let glassBgStrong    = Color.white.opacity(0.07)
        static let glassHighlight   = Color.white.opacity(0.16)
        static let glassBorder      = Color.white.opacity(0.10)
        static let glassEdgeTop     = Color.white.opacity(0.25)
        static let glassEdgeBottom  = Color.white.opacity(0.05)

        // Text – kühl getönt, nicht neutralgrau
        static let textPrimary   = Color(hex: 0xF0F4FF)
        static let textSecondary = Color(hex: 0xA8B5E0)
        static let textTertiary  = Color(hex: 0x6B7FA8)
        static let textDisabled  = Color.white.opacity(0.35)

        // Blau-Akzent
        static let accentBlue     = Color(hex: 0x3B5BFF)
        static let accentBlueDark = Color(hex: 0x2A3FCC)
        static let accentBlueGlow = Color(hex: 0x3B5BFF).opacity(0.32)

        // Teal-Akzent
        static let accentTeal     = Color(hex: 0x00D4FF)
        static let accentTealDark = Color(hex: 0x00A8CC)

        // Violett-Akzent
        static let accentViolet = Color(hex: 0x8B5CF6)

        // Status
        static let success = Color(hex: 0x10B981)
        static let warning = Color(hex: 0xF59E0B)
        static let error   = Color(hex: 0xEF4444)

        // Strukturell
        static let divider = Color.white.opacity(0.08)
    }

    // MARK: - Spacing
    enum Spacing {
        static let xs:      CGFloat = 4
        static let sm:      CGFloat = 8
        static let md:      CGFloat = 12
        static let lg:      CGFloat = 16
        static let xl:      CGFloat = 24
        static let xxl:     CGFloat = 32
        static let screen:  CGFloat = 16
        static let section: CGFloat = 24
        static let control: CGFloat = 48
    }

    // MARK: - Typography
    enum Typography {
        static let largeTitle  = Font.largeTitle.weight(.bold)
        static let title2      = Font.title2.weight(.bold)
        static let headline    = Font.headline.weight(.semibold)
        static let subheadline = Font.subheadline
        static let body        = Font.body
        static let caption     = Font.caption
        static let caption2    = Font.caption2
    }

    // MARK: - CornerRadius
    enum CornerRadius {
        static let small:  CGFloat = 10
        static let medium: CGFloat = 14
        static let large:  CGFloat = 20
        static let sheet:  CGFloat = 28
        static let full:   CGFloat = 999
    }

    // MARK: - Shadow (gibt ShadowProps zurück – kompatibel mit premiumShadow())
    enum Shadow {
        static let small  = ShadowProps(color: .black.opacity(0.15), radius: 8,  x: 0, y: 2)
        static let medium = ShadowProps(color: .black.opacity(0.25), radius: 16, x: 0, y: 8)
        static let large  = ShadowProps(color: .black.opacity(0.35), radius: 24, x: 0, y: 12)
    }
}

import SwiftUI
import UIKit

/// Steuerbares Motion-Preset für die gesamte App.
/// Entspricht den in Phase 2A definierten Presets — aktuell ist `.smooth` aktiv.
enum AppMotionStyle {
    case none
    case minimal
    case smooth
    case premium
    case fast
}

/// Zentrale Animationswerte. Alle Screens/Komponenten sollen ausschließlich
/// über diese semantischen Namen animieren, statt eigene Dauern/Kurven zu erfinden.
/// Ein Preset-Wechsel (`current`) wirkt sich dadurch konsistent auf die ganze App aus.
enum AppMotion {
    /// Aktives Preset. Phase 2A-Entscheidung: "smooth".
    static let current: AppMotionStyle = .smooth

    private static var reduceMotionEnabled: Bool {
        UIAccessibility.isReduceMotionEnabled
    }

    /// Liefert `nil` (= keine Animation), wenn Reduce Motion aktiv ist oder Preset `.none` gewählt wurde.
    private static func resolved(_ animation: Animation) -> Animation? {
        guard !reduceMotionEnabled, current != .none else { return nil }
        return animation
    }

    // MARK: - Basiskurven

    static var quick: Animation? {
        switch current {
        case .fast: return resolved(.easeOut(duration: 0.08))
        case .minimal: return resolved(.easeOut(duration: 0.1))
        case .premium: return resolved(.easeOut(duration: 0.15))
        default: return resolved(.easeOut(duration: 0.12))
        }
    }

    static var standard: Animation? {
        switch current {
        case .fast: return resolved(.easeInOut(duration: 0.12))
        case .premium: return resolved(.easeInOut(duration: 0.25))
        default: return resolved(.easeInOut(duration: 0.2))
        }
    }

    static var smooth: Animation? {
        switch current {
        case .fast: return resolved(.easeInOut(duration: 0.15))
        case .premium: return resolved(.spring(response: 0.4, dampingFraction: 0.8))
        default: return resolved(.easeInOut(duration: 0.28))
        }
    }

    static var emphasized: Animation? {
        switch current {
        case .fast: return resolved(.easeInOut(duration: 0.15))
        case .premium: return resolved(.spring(response: 0.45, dampingFraction: 0.75))
        default: return resolved(.spring(response: 0.35, dampingFraction: 0.85))
        }
    }

    // MARK: - Semantische Einsatzstellen

    /// Press-Feedback auf Buttons/Rows (kurz, direkt).
    static var buttonPress: Animation? { quick }
    /// Auswahl-Wechsel, z. B. QualityOptionRow selected-Background/Checkmark.
    static var selectionChange: Animation? { standard }
    /// Statuswechsel, z. B. Job waiting → running → done/failed.
    static var statusTransition: Animation? { smooth }
    /// Erscheinen/Verschwinden ganzer Sections (Banner, Preview/Qualität nach loadInfo()).
    static var appearTransition: Animation? { smooth }

    // MARK: - Transitions (Ein-/Ausblenden von Views)

    /// Für Banner, die von oben "hereinfahren" (Fehler-Banner, Queue-Added-Banner).
    static var bannerTransition: AnyTransition {
        guard current != .none else { return .identity }
        return .opacity.combined(with: .move(edge: .top))
    }

    /// Für Content-Sections, die einfach ein-/ausgeblendet werden (Preview/Qualität).
    static var contentAppearTransition: AnyTransition {
        guard current != .none else { return .identity }
        return .opacity
    }
}

import UIKit

/// Zentrale Haptics-Schicht. Feuert ausschließlich bei echten Nutzeraktionen
/// oder eindeutigen Ergebnissen (Erfolg/Fehler) — nicht bei jedem kleinen State-Update.
enum AppHaptics {
    /// Respektiert das aktive Motion-Preset: bei `.none` bleibt die App komplett still.
    private static var enabled: Bool {
        AppMotion.current != .none
    }

    /// Dezentes Feedback für sekundäre Buttons/Taps.
    static func lightImpact() {
        guard enabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    /// Für gewichtigere Aktionen, z. B. "Download starten".
    static func mediumImpact() {
        guard enabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }

    /// Für Auswahländerungen, z. B. Qualitätsauswahl.
    static func selectionChanged() {
        guard enabled else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    /// Für ein klares positives Ergebnis, z. B. Download fertig.
    static func success() {
        guard enabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    /// Für ein klares negatives Ergebnis, z. B. Download fehlgeschlagen.
    static func error() {
        guard enabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }
}

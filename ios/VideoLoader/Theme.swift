import SwiftUI

/// Zentrales Design-System der App: „Neon Glow" – dunkler Hintergrund mit
/// leuchtendem Blau→Violett→Pink-Verlauf (passend zum App-Icon).
enum Theme {
    // Hintergrund (dunkles Nachtblau, oben etwas heller als unten)
    static let bgTop = Color(red: 0.06, green: 0.10, blue: 0.22)
    static let bgBottom = Color(red: 0.02, green: 0.04, blue: 0.12)
    static var background: LinearGradient {
        LinearGradient(colors: [bgTop, bgBottom], startPoint: .top, endPoint: .bottom)
    }

    // Karten / Listenzeilen (leicht durchscheinend über dem Hintergrund)
    static let card = Color(red: 0.11, green: 0.15, blue: 0.30).opacity(0.55)
    static let cardStroke = Color.white.opacity(0.08)

    // Akzent-Verlauf Blau → Violett → Pink
    static let accentStart = Color(red: 0.23, green: 0.51, blue: 0.96)  // #3B82F6
    static let accentMid   = Color(red: 0.66, green: 0.33, blue: 0.97)  // #A855F7
    static let accentEnd   = Color(red: 0.93, green: 0.28, blue: 0.60)  // #EC4899
    static var accent: LinearGradient {
        LinearGradient(colors: [accentStart, accentMid, accentEnd],
                       startPoint: .leading, endPoint: .trailing)
    }
    /// Einzelfarbe für Tint (Tab-Leiste, Schalter, Auswahl).
    static let tint = accentMid

    // Text
    static let textSecondary = Color(red: 0.78, green: 0.82, blue: 0.95).opacity(0.75)
}

/// Leuchtender Verlaufs-Button für die wichtigste Aktion.
struct GlowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Theme.accentMid.opacity(0.55), radius: 14, y: 4)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension View {
    /// Dunkler Verlaufs-Hintergrund + versteckter Standard-Listenhintergrund.
    func neonScreenBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
    }

    /// Durchscheinende Karten-Optik für eine Listenzeile.
    func neonCardRow() -> some View {
        self.listRowBackground(Theme.card)
    }
}

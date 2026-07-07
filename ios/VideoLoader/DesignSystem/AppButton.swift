import SwiftUI

/// Button-Stil mit dezentem Press-Scale-Feedback (Preset "smooth").
private struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(AppMotion.buttonPress, value: configuration.isPressed)
    }
}

/// Visuelle Ausprägung eines `AppButton`.
enum AppButtonKind {
    case primary
    case secondary
    case destructive

    var foreground: Color {
        switch self {
        case .primary: return .white
        case .secondary: return AppTheme.primaryText
        case .destructive: return .white
        }
    }

    var background: Color {
        switch self {
        case .primary: return AppTheme.accent
        case .secondary: return AppColorsPremium.glassSurfaceStrong
        case .destructive: return AppTheme.danger
        }
    }

    var borderColor: Color? {
        switch self {
        case .primary: return nil
        case .secondary: return AppColorsPremium.glassBorder
        case .destructive: return nil
        }
    }
}

/// Einheitlicher Button mit Primary-, Secondary- und Destructive-Stil
/// sowie eingebautem Loading- und Disabled-State.
struct AppButton: View {
    let title: String
    var kind: AppButtonKind = .primary
    var systemImage: String?
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: {
            AppHaptics.lightImpact()
            action()
        }) {
            HStack(spacing: AppSpacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(kind.foreground)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .font(AppTypography.bodyEmphasized)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(kind.foreground)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .fill(kind.background)
            )
            .overlay {
                if let borderColor = kind.borderColor {
                    RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                }
            }
            .opacity(isDisabled ? 0.5 : 1)
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(isDisabled || isLoading)
        .animation(AppMotion.standard, value: isLoading)
    }
}

#Preview {
    VStack(spacing: AppSpacing.md) {
        AppButton(title: "Herunterladen", kind: .primary, systemImage: "arrow.down.circle.fill") {}
        AppButton(title: "Abbrechen", kind: .secondary) {}
        AppButton(title: "Löschen", kind: .destructive, systemImage: "trash") {}
        AppButton(title: "Wird geladen", kind: .primary, isLoading: true) {}
        AppButton(title: "Deaktiviert", kind: .primary, isDisabled: true) {}
    }
    .padding()
    .background(AppTheme.background)
}

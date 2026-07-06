import SwiftUI
import UIKit

// MARK: - Premium Glass Input Field
struct PremiumGlassInputField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String
    let onIconTap: () -> Void

    var body: some View {
        HStack(spacing: Aurora.Spacing.md) {
            TextField(placeholder, text: $text)
                .font(Aurora.Typography.body)
                .foregroundStyle(Aurora.Colors.textPrimary)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)

            Button(action: onIconTap) {
                Image(systemName: icon)
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(Aurora.Colors.accentBlue)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, Aurora.Spacing.md)
        .frame(height: Aurora.Spacing.control)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: Aurora.CornerRadius.medium)
                    .fill(Aurora.Colors.glassBgStrong)

                RoundedRectangle(cornerRadius: Aurora.CornerRadius.medium)
                    .fill(.ultraThinMaterial)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: Aurora.CornerRadius.medium)
                .stroke(
                    LinearGradient(
                        colors: [
                            Aurora.Colors.glassEdgeTop,
                            Aurora.Colors.glassEdgeBottom
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .premiumShadow(Aurora.Shadow.small)
    }
}

// MARK: - Premium Glass Card
struct PremiumGlassCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Aurora.Spacing.md) {
            content
        }
        .padding(Aurora.Spacing.lg)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: Aurora.CornerRadius.large)
                    .fill(Aurora.Colors.glassBg)

                RoundedRectangle(cornerRadius: Aurora.CornerRadius.large)
                    .fill(.ultraThinMaterial)

                // Obere-linke Lichtkante
                RoundedRectangle(cornerRadius: Aurora.CornerRadius.large)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Aurora.Colors.glassEdgeTop,
                                Aurora.Colors.glassEdgeBottom
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: Aurora.CornerRadius.large)
                .stroke(Aurora.Colors.glassBorder, lineWidth: 0.8)
        )
        .premiumShadow(Aurora.Shadow.medium)
    }
}

// MARK: - Premium Button Styles
struct PremiumPrimaryButtonStyle: ButtonStyle {
    var accent: AccentColor = .blue

    enum AccentColor {
        case blue
        case teal
        case violet
    }

    private var accentColor: Color {
        switch accent {
        case .blue:   return Aurora.Colors.accentBlue
        case .teal:   return Aurora.Colors.accentTeal
        case .violet: return Aurora.Colors.accentViolet
        }
    }

    private var glowColor: Color {
        switch accent {
        case .blue:   return Aurora.Colors.accentBlueGlow
        case .teal:   return Aurora.Colors.accentTeal.opacity(0.28)
        case .violet: return Aurora.Colors.accentViolet.opacity(0.28)
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Aurora.Typography.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: Aurora.Spacing.control)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: Aurora.CornerRadius.medium)
                        .fill(accentColor)

                    RoundedRectangle(cornerRadius: Aurora.CornerRadius.medium)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.15),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: Aurora.CornerRadius.medium)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: glowColor, radius: 12, x: 0, y: 6)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: AppThemePremium.durationFast), value: configuration.isPressed)
    }
}

struct PremiumSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Aurora.Typography.headline)
            .foregroundStyle(Aurora.Colors.textPrimary)
            .frame(maxWidth: .infinity, minHeight: Aurora.Spacing.control)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: Aurora.CornerRadius.medium)
                        .fill(Aurora.Colors.glassBgStrong)

                    RoundedRectangle(cornerRadius: Aurora.CornerRadius.medium)
                        .fill(.ultraThinMaterial)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: Aurora.CornerRadius.medium)
                    .stroke(Aurora.Colors.glassBorder, lineWidth: 0.8)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: AppThemePremium.durationFast), value: configuration.isPressed)
    }
}

#Preview {
    VStack(spacing: 16) {
        PremiumGlassInputField(
            placeholder: "Link einfügen",
            text: .constant(""),
            icon: "doc.on.clipboard",
            onIconTap: {}
        )

        Button("Primary") {}
            .buttonStyle(PremiumPrimaryButtonStyle())

        Button("Secondary") {}
            .buttonStyle(PremiumSecondaryButtonStyle())

        PremiumGlassCard {
            Text("Premium Card")
                .font(Aurora.Typography.headline)
                .foregroundStyle(Aurora.Colors.textPrimary)
        }
    }
    .padding()
    .background(PremiumAuroraBackground())
}

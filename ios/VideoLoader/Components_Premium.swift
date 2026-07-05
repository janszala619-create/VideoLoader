import SwiftUI
import UIKit

// MARK: - Premium Glass Input Field
struct PremiumGlassInputField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String
    let onIconTap: () -> Void

    var body: some View {
        HStack(spacing: AppThemePremium.md) {
            TextField(placeholder, text: $text)
                .font(.system(.body, design: .default))
                .foregroundStyle(AppColorsPremium.textPrimary)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)

            Button(action: onIconTap) {
                Image(systemName: icon)
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(AppColorsPremium.accentBlue)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, AppThemePremium.md)
        .frame(height: AppThemePremium.controlHeight)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: AppThemePremium.radiusMedium)
                    .fill(AppColorsPremium.glassSurfaceStrong)

                RoundedRectangle(cornerRadius: AppThemePremium.radiusMedium)
                    .fill(.ultraThinMaterial)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppThemePremium.radiusMedium)
                .stroke(
                    LinearGradient(
                        colors: [
                            AppColorsPremium.glassEdgeTop,
                            AppColorsPremium.glassEdgeBottom
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .premiumShadow(AppThemePremium.shadowSmall)
    }
}

// MARK: - Premium Glass Card
struct PremiumGlassCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppThemePremium.md) {
            content
        }
        .padding(AppThemePremium.lg)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: AppThemePremium.radiusLarge)
                    .fill(AppColorsPremium.glassSurface)

                RoundedRectangle(cornerRadius: AppThemePremium.radiusLarge)
                    .fill(.ultraThinMaterial)

                // Top-left light edge
                RoundedRectangle(cornerRadius: AppThemePremium.radiusLarge)
                    .stroke(
                        LinearGradient(
                            colors: [
                                AppColorsPremium.glassEdgeTop,
                                AppColorsPremium.glassEdgeBottom
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppThemePremium.radiusLarge)
                .stroke(AppColorsPremium.glassBorder, lineWidth: 0.8)
        )
        .premiumShadow(AppThemePremium.shadowMedium)
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
        case .blue: return AppColorsPremium.accentBlue
        case .teal: return AppColorsPremium.accentTeal
        case .violet: return AppColorsPremium.accentViolet
        }
    }

    private var glowColor: Color {
        switch accent {
        case .blue: return AppColorsPremium.accentBlueGlow
        case .teal: return AppColorsPremium.accentTeal.opacity(0.28)
        case .violet: return AppColorsPremium.accentViolet.opacity(0.28)
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: AppThemePremium.controlHeight)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: AppThemePremium.radiusMedium)
                        .fill(accentColor)

                    RoundedRectangle(cornerRadius: AppThemePremium.radiusMedium)
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
                RoundedRectangle(cornerRadius: AppThemePremium.radiusMedium)
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
            .font(.body.weight(.semibold))
            .foregroundStyle(AppColorsPremium.textPrimary)
            .frame(maxWidth: .infinity, minHeight: AppThemePremium.controlHeight)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: AppThemePremium.radiusMedium)
                        .fill(AppColorsPremium.glassSurfaceStrong)

                    RoundedRectangle(cornerRadius: AppThemePremium.radiusMedium)
                        .fill(.ultraThinMaterial)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppThemePremium.radiusMedium)
                    .stroke(AppColorsPremium.glassBorder, lineWidth: 0.8)
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
                .font(.headline)
                .foregroundStyle(AppColorsPremium.textPrimary)
        }
    }
    .padding()
    .background(PremiumAuroraBackground())
}

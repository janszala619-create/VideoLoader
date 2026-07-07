import SwiftUI

enum AppGlassTheme {
    static let radiusSmall: CGFloat = 10
    static let radiusMedium: CGFloat = 14
    static let radiusLarge: CGFloat = 18
    static let radiusSheet: CGFloat = 24
    static let radiusFull: CGFloat = 999

    static let controlHeight: CGFloat = 44
    static let screenPadding: CGFloat = AppGlassSpacing.lg
    static let sectionSpacing: CGFloat = AppGlassSpacing.xl
    static let heroSpacing: CGFloat = AppGlassSpacing.xxl
}

// MARK: - Spacing (fehlende Definition)
enum AppGlassSpacing {
    static let xs:  CGFloat = 4
    static let sm:  CGFloat = 8
    static let md:  CGFloat = 12
    static let lg:  CGFloat = 16
    static let xl:  CGFloat = 24
    static let xxl: CGFloat = 32
}

// MARK: - Typography (fehlende Definition)
enum AppGlassTypography {
    static let largeTitle  = Font.largeTitle.weight(.bold)
    static let title3      = Font.title3.weight(.semibold)
    static let headline    = Font.headline.weight(.semibold)
    static let subheadline = Font.subheadline
    static let body        = Font.body
    static let footnote    = Font.footnote
    static let caption     = Font.caption
}

struct AppGlassShadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

enum AppGlassShadows {
    static let card = AppGlassShadow(
        color: .black.opacity(0.18),
        radius: 18,
        x: 0,
        y: 8
    )

    static let modal = AppGlassShadow(
        color: .black.opacity(0.28),
        radius: 28,
        x: 0,
        y: 14
    )
}

// MARK: - Stub Button Styles (für ContentView.swift Kompatibilität)
struct GlassPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: AppGlassTheme.controlHeight)
            .background(
                RoundedRectangle(cornerRadius: AppGlassTheme.radiusMedium)
                    .fill(AppGlassColors.accentPrimary)
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.88 : 1) : 0.45)
    }
}

struct GlassSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(AppGlassColors.textPrimary)
            .frame(minHeight: AppGlassTheme.controlHeight)
            .padding(.horizontal, AppGlassSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppGlassTheme.radiusMedium)
                    .fill(AppGlassColors.glassSurfaceStrong)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppGlassTheme.radiusMedium)
                    .stroke(AppGlassColors.glassBorder, lineWidth: 1)
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.45)
    }
}

// MARK: - Stub State Views (für ContentView.swift Kompatibilität)
struct GlassEmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String
    var body: some View {
        VStack(spacing: AppGlassSpacing.xl) {
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundStyle(AppGlassColors.accentPrimary.opacity(0.6))
            VStack(spacing: AppGlassSpacing.sm) {
                Text(title).font(AppGlassTypography.headline).foregroundStyle(AppGlassColors.textPrimary)
                Text(message).font(AppGlassTypography.footnote).foregroundStyle(AppGlassColors.textSecondary).multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppGlassSpacing.xxl)
    }
}

struct GlassLoadingStateView: View {
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: AppGlassSpacing.lg) {
            ProgressView().tint(AppGlassColors.accentPrimary)
            VStack(spacing: AppGlassSpacing.sm) {
                Text(title).font(AppGlassTypography.headline).foregroundStyle(AppGlassColors.textPrimary)
                Text(message).font(AppGlassTypography.footnote).foregroundStyle(AppGlassColors.textSecondary).multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppGlassSpacing.xxl)
    }
}

struct GlassErrorStateView: View {
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppGlassSpacing.md) {
                Text(title).font(AppGlassTypography.headline).foregroundStyle(AppGlassColors.error)
                Text(message).font(AppGlassTypography.footnote).foregroundStyle(AppGlassColors.textSecondary)
                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .buttonStyle(.borderless)
                        .font(AppGlassTypography.footnote.weight(.semibold))
                        .foregroundStyle(AppGlassColors.accentPrimary)
                }
            }
        }
    }
}

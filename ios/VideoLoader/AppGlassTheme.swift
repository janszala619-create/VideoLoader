import SwiftUI

enum AppGlassTheme {
    static let radiusSmall: CGFloat = 10
    static let radiusMedium: CGFloat = 14
    static let radiusLarge: CGFloat = 18
    static let radiusSheet: CGFloat = 24
    static let radiusFull: CGFloat = 999

    static let controlHeight: CGFloat = 48
    static let minimumTouchTarget: CGFloat = 44
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

struct GlassPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: AppGlassTheme.controlHeight)
            .background(
                RoundedRectangle(cornerRadius: AppGlassTheme.radiusMedium)
                    .fill(isEnabled ? AppGlassColors.accentPrimary : AppGlassColors.surfaceDisabled)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppGlassTheme.radiusMedium)
                    .stroke(.white.opacity(isEnabled ? 0.10 : 0.04), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: AppGlassTheme.radiusMedium))
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
                    .fill(isEnabled ? AppGlassColors.glassSurfaceStrong : AppGlassColors.surfaceDisabled)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppGlassTheme.radiusMedium)
                    .stroke(AppGlassColors.glassBorder, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: AppGlassTheme.radiusMedium))
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.45)
    }
}

struct GlassEmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: AppGlassSpacing.xl) {
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundStyle(AppGlassColors.accentPrimary.opacity(0.6))
            VStack(spacing: AppGlassSpacing.sm) {
                Text(title).font(AppGlassTypography.headline).foregroundStyle(AppGlassColors.textPrimary)
                Text(message).font(AppGlassTypography.footnote).foregroundStyle(AppGlassColors.textSecondary).multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(GlassSecondaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppGlassSpacing.xxl)
        .accessibilityElement(children: actionTitle == nil ? .combine : .contain)
    }
}

struct GlassLoadingStateView: View {
    let title: String
    let message: String
    var isCompact = false

    var body: some View {
        VStack(spacing: isCompact ? AppGlassSpacing.md : AppGlassSpacing.lg) {
            ProgressView().tint(AppGlassColors.accentPrimary)
            VStack(spacing: AppGlassSpacing.sm) {
                Text(title).font(AppGlassTypography.headline).foregroundStyle(AppGlassColors.textPrimary)
                Text(message).font(AppGlassTypography.footnote).foregroundStyle(AppGlassColors.textSecondary).multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(isCompact ? AppGlassSpacing.lg : AppGlassSpacing.xxl)
        .accessibilityElement(children: .combine)
    }
}

struct GlassErrorStateView: View {
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        GlassCard {
            HStack(alignment: .top, spacing: AppGlassSpacing.md) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(AppGlassColors.error)
                    .frame(width: AppGlassTheme.minimumTouchTarget, height: AppGlassTheme.minimumTouchTarget)

                VStack(alignment: .leading, spacing: AppGlassSpacing.sm) {
                    Text(title)
                        .font(AppGlassTypography.headline)
                        .foregroundStyle(AppGlassColors.textPrimary)
                    Text(message)
                        .font(AppGlassTypography.footnote)
                        .foregroundStyle(AppGlassColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(GlassSecondaryButtonStyle())
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: AppGlassTheme.radiusLarge, style: .continuous)
                .stroke(AppGlassColors.error.opacity(0.28), lineWidth: 1)
                .allowsHitTesting(false)
        )
    }
}

struct GlassPill: View {
    let title: String
    var systemImage: String?
    var tint: Color = AppGlassColors.textPrimary

    var body: some View {
        HStack(spacing: AppGlassSpacing.xs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
            }
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, AppGlassSpacing.md)
        .padding(.vertical, AppGlassSpacing.sm)
        .background(
            Capsule(style: .continuous)
                .fill(tint.opacity(0.14))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        )
    }
}

struct GlassSurfaceButton<Content: View>: View {
    var isSelected = false
    var action: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        Button(action: action) {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppGlassSpacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: AppGlassTheme.radiusLarge, style: .continuous)
                        .fill(AppGlassColors.glassSurfaceStrong)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppGlassTheme.radiusLarge, style: .continuous)
                        .stroke(isSelected ? AppGlassColors.accentPrimary.opacity(0.48) : AppGlassColors.glassBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "Ausgewählt" : "")
    }
}

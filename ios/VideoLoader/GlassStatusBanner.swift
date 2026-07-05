import SwiftUI

enum GlassStatusTone {
    case neutral
    case success
    case warning
    case error

    var iconName: String {
        switch self {
        case .neutral: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }

    var tint: Color {
        switch self {
        case .neutral: return AppGlassColors.accentPrimary
        case .success: return AppGlassColors.success
        case .warning: return AppGlassColors.warning
        case .error: return AppGlassColors.error
        }
    }
}

struct GlassStatusBanner: View {
    let tone: GlassStatusTone
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: AppGlassSpacing.md) {
            HStack(alignment: .top, spacing: AppGlassSpacing.md) {
                ZStack {
                    Circle()
                        .fill(tone.tint.opacity(0.18))
                    Image(systemName: tone.iconName)
                        .font(.headline)
                        .foregroundStyle(tone.tint)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: AppGlassSpacing.xs) {
                    Text(title)
                        .font(AppGlassTypography.headline)
                        .foregroundStyle(AppGlassColors.textPrimary)

                    Text(message)
                        .font(AppGlassTypography.footnote)
                        .foregroundStyle(AppGlassColors.textSecondary)
                }
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderless)
                    .font(AppGlassTypography.footnote.weight(.semibold))
                    .foregroundStyle(tone.tint)
            }
        }
        .padding(AppGlassSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppGlassTheme.radiusLarge, style: .continuous)
                .fill(AppGlassColors.glassSurfaceStrong)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppGlassTheme.radiusLarge, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppGlassTheme.radiusLarge, style: .continuous)
                .stroke(tone.tint.opacity(0.24), lineWidth: 1)
        )
    }
}

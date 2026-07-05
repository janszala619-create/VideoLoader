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
        case .neutral: return AppColors.accentPrimary
        case .success: return AppColors.success
        case .warning: return AppColors.warning
        case .error: return AppColors.error
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
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                ZStack {
                    Circle()
                        .fill(tone.tint.opacity(0.18))
                    Image(systemName: tone.iconName)
                        .font(.headline)
                        .foregroundStyle(tone.tint)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(title)
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.textPrimary)

                    Text(message)
                        .font(AppTypography.footnote)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderless)
                    .font(AppTypography.footnote.weight(.semibold))
                    .foregroundStyle(tone.tint)
            }
        }
        .padding(AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .fill(AppColors.surfaceStrong)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .stroke(tone.tint.opacity(0.24), lineWidth: 1)
        )
    }
}

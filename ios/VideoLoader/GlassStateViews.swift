import SwiftUI

struct GlassEmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        GlassCard {
            VStack(spacing: AppGlassSpacing.lg) {
                ZStack {
                    Circle()
                        .fill(AppGlassColors.glassSurfaceElevated)
                    Image(systemName: systemImage)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(AppGlassColors.textSecondary)
                }
                .frame(width: 72, height: 72)

                VStack(spacing: AppGlassSpacing.sm) {
                    Text(title)
                        .font(AppGlassTypography.title3)
                        .foregroundStyle(AppGlassColors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(message)
                        .font(AppGlassTypography.body)
                        .foregroundStyle(AppGlassColors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .buttonStyle(GlassPrimaryButtonStyle())
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct GlassLoadingStateView: View {
    let title: String
    let message: String

    var body: some View {
        GlassCard {
            HStack(alignment: .top, spacing: AppGlassSpacing.md) {
                ProgressView()
                    .tint(AppGlassColors.accentPrimary)

                VStack(alignment: .leading, spacing: AppGlassSpacing.xs) {
                    Text(title)
                        .font(AppGlassTypography.headline)
                        .foregroundStyle(AppGlassColors.textPrimary)

                    Text(message)
                        .font(AppGlassTypography.footnote)
                        .foregroundStyle(AppGlassColors.textSecondary)
                }
            }
        }
    }
}

struct GlassErrorStateView: View {
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        GlassStatusBanner(
            tone: .error,
            title: title,
            message: message,
            actionTitle: actionTitle,
            action: action
        )
    }
}

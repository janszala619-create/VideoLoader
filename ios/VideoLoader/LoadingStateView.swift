import SwiftUI

struct LoadingStateView: View {
    let title: String
    let message: String

    var body: some View {
        AppCard {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                ProgressView()
                    .tint(AppColors.accentPrimary)

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(title)
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.textPrimary)

                    Text(message)
                        .font(AppTypography.footnote)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer(minLength: 0)
            }
        }
    }
}

import SwiftUI

struct ErrorStateView: View {
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(alignment: .top, spacing: AppSpacing.md) {
                    ZStack {
                        Circle()
                            .fill(AppColors.error.opacity(0.18))
                        Image(systemName: "xmark.octagon.fill")
                            .font(.headline)
                            .foregroundStyle(AppColors.error)
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

                    Spacer(minLength: 0)
                }

                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .buttonStyle(SecondaryButton())
                        .tint(AppColors.error)
                }
            }
        }
    }
}

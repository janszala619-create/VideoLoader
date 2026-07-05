import SwiftUI

struct SectionHeader: View {
    let title: String
    var subtitle: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title.uppercased())
                    .font(AppTypography.label)
                    .foregroundStyle(AppColors.textSecondary)
                    .tracking(1.2)

                if let subtitle {
                    Text(subtitle)
                        .font(AppTypography.footnote)
                        .foregroundStyle(AppColors.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.plain)
                    .font(AppTypography.footnote.weight(.semibold))
                    .foregroundStyle(AppColors.accentSecondary)
            }
        }
    }
}

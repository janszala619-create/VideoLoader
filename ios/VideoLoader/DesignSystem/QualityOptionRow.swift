import SwiftUI

/// Zeile für eine auswählbare Qualitätsoption (z. B. Auflösung/Format).
struct QualityOptionRow: View {
    let title: String
    var subtitle: String?
    let isSelected: Bool
    var isRecommended: Bool = false
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    HStack(spacing: AppSpacing.sm) {
                        Text(title)
                            .font(AppTypography.bodyEmphasized)
                            .foregroundStyle(AppTheme.primaryText)

                        if isRecommended {
                            AppBadge(text: "Empfohlen", tint: AppTheme.special)
                        }
                    }

                    if let subtitle {
                        Text(subtitle)
                            .font(AppTypography.footnote)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.secondaryText.opacity(0.5))
            }
            .padding(.horizontal, AppSpacing.md)
            .frame(minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .fill(isSelected ? AppTheme.accent.opacity(0.12) : AppColorsPremium.glassSurfaceStrong)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .stroke(isSelected ? AppTheme.accent.opacity(0.5) : AppColorsPremium.glassBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: isSelected)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    VStack(spacing: AppSpacing.sm) {
        QualityOptionRow(title: "1080p", subtitle: "MP4 · ~120 MB", isSelected: true, isRecommended: true, onSelect: {})
        QualityOptionRow(title: "720p", subtitle: "MP4 · ~70 MB", isSelected: false, onSelect: {})
        QualityOptionRow(title: "Nur Audio", subtitle: "M4A · ~8 MB", isSelected: false, onSelect: {})
    }
    .padding()
    .background(AppTheme.background)
}

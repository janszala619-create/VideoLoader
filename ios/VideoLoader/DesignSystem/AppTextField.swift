import SwiftUI
import UIKit

/// Einheitliches Eingabefeld, z. B. für URL- oder Server-Adresseingaben.
struct AppTextField: View {
    var label: String?
    let placeholder: String
    @Binding var text: String
    var systemImage: String?
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .never
    var disablesAutocorrection: Bool = true

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            if let label {
                Text(label)
                    .font(AppTypography.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
            }

            HStack(spacing: AppSpacing.sm) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .foregroundStyle(isFocused ? AppTheme.accent : AppTheme.secondaryText)
                }
                TextField(placeholder, text: $text)
                    .font(AppTypography.body)
                    .foregroundStyle(AppTheme.primaryText)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(autocapitalization)
                    .autocorrectionDisabled(disablesAutocorrection)
                    .focused($isFocused)
            }
            .padding(.horizontal, AppSpacing.md)
            .frame(minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .fill(AppColorsPremium.glassSurfaceStrong)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .stroke(isFocused ? AppTheme.accent : AppColorsPremium.glassBorder, lineWidth: isFocused ? 1.5 : 1)
            )
        }
    }
}

#Preview {
    AppTextField(
        label: "Video-Link",
        placeholder: "https://youtube.com/...",
        text: .constant(""),
        systemImage: "link",
        keyboardType: .URL
    )
    .padding()
    .background(AppTheme.background)
}

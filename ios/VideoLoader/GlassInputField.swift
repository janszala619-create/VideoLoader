import SwiftUI
import UIKit

struct GlassInputField<Accessory: View>: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var helperText: String?
    var keyboardType: UIKeyboardType
    var textContentType: UITextContentType?
    var autocapitalization: TextInputAutocapitalization
    var disablesAutocorrection: Bool
    @ViewBuilder var accessory: Accessory

    init(
        label: String,
        placeholder: String,
        text: Binding<String>,
        helperText: String? = nil,
        keyboardType: UIKeyboardType = .default,
        textContentType: UITextContentType? = nil,
        autocapitalization: TextInputAutocapitalization = .sentences,
        disablesAutocorrection: Bool = false,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.label = label
        self.placeholder = placeholder
        self._text = text
        self.helperText = helperText
        self.keyboardType = keyboardType
        self.textContentType = textContentType
        self.autocapitalization = autocapitalization
        self.disablesAutocorrection = disablesAutocorrection
        self.accessory = accessory()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppGlassSpacing.sm) {
            Text(label)
                .font(AppGlassTypography.subheadline.weight(.semibold))
                .foregroundStyle(AppGlassColors.textPrimary)

            HStack(spacing: AppGlassSpacing.sm) {
                TextField(placeholder, text: $text)
                    .font(AppGlassTypography.body)
                    .foregroundStyle(AppGlassColors.textPrimary)
                    .keyboardType(keyboardType)
                    .textContentType(textContentType)
                    .textInputAutocapitalization(autocapitalization)
                    .autocorrectionDisabled(disablesAutocorrection)

                accessory
            }
            .padding(.horizontal, AppGlassSpacing.md)
            .frame(minHeight: AppGlassTheme.controlHeight)
            .background(
                RoundedRectangle(cornerRadius: AppGlassTheme.radiusMedium, style: .continuous)
                    .fill(AppGlassColors.glassSurfaceStrong)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppGlassTheme.radiusMedium, style: .continuous)
                    .stroke(AppGlassColors.glassBorder, lineWidth: 1)
            )

            if let helperText {
                Text(helperText)
                    .font(AppGlassTypography.footnote)
                    .foregroundStyle(AppGlassColors.textSecondary)
            }
        }
    }
}

extension GlassInputField where Accessory == EmptyView {
    /// Bequemer Initialisierer, wenn neben dem Textfeld kein Zusatzelement gebraucht wird.
    init(
        label: String,
        placeholder: String,
        text: Binding<String>,
        helperText: String? = nil,
        keyboardType: UIKeyboardType = .default,
        textContentType: UITextContentType? = nil,
        autocapitalization: TextInputAutocapitalization = .sentences,
        disablesAutocorrection: Bool = false
    ) {
        self.init(
            label: label,
            placeholder: placeholder,
            text: text,
            helperText: helperText,
            keyboardType: keyboardType,
            textContentType: textContentType,
            autocapitalization: autocapitalization,
            disablesAutocorrection: disablesAutocorrection,
            accessory: { EmptyView() }
        )
    }
}

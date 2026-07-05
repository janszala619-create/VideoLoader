import SwiftUI

struct SettingsView: View {
    @Binding var macServerURL: String
    @Binding var cloudServerURL: String
    @Binding var activeServerRaw: String
    @Environment(\.dismiss) private var dismiss

    private var activeServer: ServerKind? {
        ServerKind(rawValue: activeServerRaw)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                    headerBlock
                    activeServerCard
                    cloudServerCard
                    macServerCard
                    footerCard
                }
                .padding(.horizontal, AppTheme.screenPadding)
                .padding(.top, AppSpacing.md)
            }
            .background(settingsBackground)
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(AppTheme.navBarMaterial, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Fertig")
                            .font(AppTypography.button)
                    }
                    .buttonStyle(SecondaryButton())
                    .accessibilityLabel("Einstellungen schließen")
                }
            }
        }
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Verbindung")
                .font(AppTypography.largeTitle)
                .foregroundStyle(AppColors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Text("Wähle den Server, der am zuverlässigsten zu deinem Setup passt, und pflege nur die Adressen, die du wirklich nutzt.")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var activeServerCard: some View {
        AppCard {
            SectionHeader(
                title: "Aktiver Server",
                subtitle: "Der aktive Server bestimmt, wo Video-Infos geprüft und Downloads vorbereitet werden."
            )

            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Picker("Server", selection: $activeServerRaw) {
                    ForEach(ServerKind.allCases) { kind in
                        Text(kind.label).tag(kind.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .tint(AppColors.accentPrimary)
                .accessibilityLabel("Aktiven Server auswählen")

                if let activeServer {
                    StatusRow(
                        tone: .info,
                        title: activeServer.label,
                        message: activeServer.settingsHint
                    )
                }
            }
        }
    }

    private var cloudServerCard: some View {
        serverCard(
            title: "Cloud-Server (VidSave)",
            subtitle: "Überall erreichbar, kein Mac nötig.",
            text: $cloudServerURL,
            placeholder: "http://158.101.168.11:8765",
            helperText: "Gut für unterwegs. Bei manchen Plattformen kann die Erkennung jedoch unzuverlässig sein."
        )
    }

    private var macServerCard: some View {
        serverCard(
            title: "Mac-Server (VideoLoader)",
            subtitle: "Dein lokaler Server im Heimnetzwerk.",
            text: $macServerURL,
            placeholder: "http://192.168.1.23:8000",
            helperText: "Starte auf dem Mac `start.sh` und trage die dort sichtbare Adresse hier ein."
        )
    }

    private var footerCard: some View {
        AppCard {
            SectionHeader(
                title: "Hinweis",
                subtitle: "Diese Einstellungen ändern nur die Verbindung. Download- und Serverlogik bleiben unverändert."
            )

            if macServerURL.isEmpty && cloudServerURL.isEmpty {
                EmptyStateView(
                    title: "Noch keine Serveradressen",
                    message: "Trage zuerst mindestens einen Server ein. Der Mac-Server ist im gleichen WLAN meist am stabilsten.",
                    systemImage: "server.rack"
                )
            } else {
                Text("Wenn du unsicher bist, nimm zuerst den Mac-Server im gleichen WLAN. Das ist meist die stabilste Wahl.")
                    .font(AppTypography.footnote)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                dismiss()
            } label: {
                Label("Fertig", systemImage: "checkmark")
            }
            .buttonStyle(PrimaryButton())
            .accessibilityLabel("Einstellungen übernehmen und schließen")
        }
    }

    private func serverCard(
        title: String,
        subtitle: String,
        text: Binding<String>,
        placeholder: String,
        helperText: String
    ) -> some View {
        AppCard {
            SectionHeader(
                title: title,
                subtitle: subtitle
            )

            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SettingsInputField(
                    label: "Server-Adresse",
                    placeholder: placeholder,
                    text: text,
                    helperText: helperText
                )

                Button {
                    text.wrappedValue = ""
                } label: {
                    Label("Adresse leeren", systemImage: "xmark")
                }
                .buttonStyle(SecondaryButton())
                .accessibilityLabel("\(title) Adresse leeren")
            }
        }
    }

    private var settingsBackground: some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.background, AppColors.backgroundSoft, AppColors.background],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [AppColors.backgroundGlow.opacity(0.28), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 300
            )

            RadialGradient(
                colors: [AppColors.accentGlow.opacity(0.16), .clear],
                center: .bottomLeading,
                startRadius: 40,
                endRadius: 240
            )
        }
        .ignoresSafeArea()
    }
}

private enum SettingsStatusTone {
    case info

    var iconName: String { "info.circle.fill" }

    var tint: Color { AppColors.accentPrimary }
}

private struct StatusRow: View {
    let tone: SettingsStatusTone
    let title: String
    let message: String

    var body: some View {
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
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
    }
}

private struct SettingsInputField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var helperText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(label)
                .font(AppTypography.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)

            TextField(placeholder, text: $text)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textPrimary)
                .keyboardType(.URL)
                .textContentType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .padding(.horizontal, AppSpacing.md)
                .frame(minHeight: AppTheme.controlHeight)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                        .fill(AppColors.surfaceElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                        .stroke(AppColors.border, lineWidth: 1)
                )
                .accessibilityLabel(label)

            if let helperText {
                Text(helperText)
                    .font(AppTypography.footnote)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    SettingsView(
        macServerURL: .constant(""),
        cloudServerURL: .constant("http://158.101.168.11:8765"),
        activeServerRaw: .constant(ServerKind.vidSave.rawValue)
    )
}

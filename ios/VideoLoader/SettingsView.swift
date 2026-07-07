import SwiftUI

struct SettingsView: View {
    @Binding var macServerURL: String
    @Binding var cloudServerURL: String
    @Binding var activeServerRaw: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    activeServerCard

                    serverCard(
                        title: "Cloud-Server (VidSave, Legacy)",
                        text: $cloudServerURL,
                        placeholder: "http://158.101.168.11:8765",
                        helperText: "Überall erreichbar, kein Mac nötig. Für YouTube und viele große Plattformen aber oft unzuverlässig."
                    )

                    serverCard(
                        title: "Lokaler Server (VideoLoader)",
                        text: $macServerURL,
                        placeholder: "http://100.80.105.62:9876",
                        helperText: "Dein lokaler Mac- oder Windows-Server im selben WLAN. Für YouTube diesen Server-Modus verwenden, nicht den Cloud-Server."
                    )
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.md)
            }
            .background(AppGlassBackground())
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                        .foregroundStyle(AppTheme.primaryText)
                }
            }
        }
    }

    private var activeServerCard: some View {
        AppCard {
            AppSectionHeader(
                title: "Verbindung",
                subtitle: "Wähle den Server, der am zuverlässigsten zu deinem Setup passt."
            )

            Picker("Server", selection: $activeServerRaw) {
                ForEach(ServerKind.allCases) { kind in
                    Text(kind.label).tag(kind.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .tint(AppTheme.accent)

            if let activeServer = ServerKind(rawValue: activeServerRaw) {
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    AppStatusDot(color: AppTheme.accent)
                        .padding(.top, 5)
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(activeServer.label)
                            .font(AppTypography.bodyEmphasized)
                            .foregroundStyle(AppTheme.primaryText)
                        Text(activeServer.settingsHint)
                            .font(AppTypography.footnote)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
            }
        }
    }

    private func serverCard(
        title: String,
        text: Binding<String>,
        placeholder: String,
        helperText: String
    ) -> some View {
        AppCard {
            AppSectionHeader(title: title)

            AppTextField(
                label: "Server-Adresse",
                placeholder: placeholder,
                text: text,
                systemImage: "link",
                keyboardType: .URL,
                autocapitalization: .never,
                disablesAutocorrection: true
            )

            Text(helperText)
                .font(AppTypography.footnote)
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

}

#Preview {
    SettingsView(
        macServerURL: .constant("http://100.80.105.62:9876"),
        cloudServerURL: .constant("http://158.101.168.11:8765"),
        activeServerRaw: .constant(ServerKind.videoLoader.rawValue)
    )
}

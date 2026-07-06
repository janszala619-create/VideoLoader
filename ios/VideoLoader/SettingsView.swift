import SwiftUI

struct SettingsView: View {
    @Binding var macServerURL: String
    @Binding var cloudServerURL: String
    @Binding var activeServerRaw: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppGlassTheme.sectionSpacing) {
                    VStack(alignment: .leading, spacing: AppGlassSpacing.sm) {
                        Text("Verbindung")
                            .font(AppGlassTypography.largeTitle)
                            .foregroundStyle(AppGlassColors.textPrimary)

                        Text("Wähle den Server, der am zuverlässigsten zu deinem Setup passt.")
                            .font(AppGlassTypography.body)
                            .foregroundStyle(AppGlassColors.textSecondary)
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: AppGlassSpacing.md) {
                            AppGlassSectionHeader(title: "Aktiver Server")

                            Text("Server-Modus")
                                .font(AppGlassTypography.headline)
                                .foregroundStyle(AppGlassColors.textPrimary)

                            Picker("Server", selection: $activeServerRaw) {
                                ForEach(ServerKind.allCases) { kind in
                                    Text(kind.label).tag(kind.rawValue)
                                }
                            }
                            .pickerStyle(.segmented)
                            .tint(AppGlassColors.accentPrimary)

                            if let activeServer = ServerKind(rawValue: activeServerRaw) {
                                GlassStatusBanner(
                                    tone: .neutral,
                                    title: activeServer.label,
                                    message: activeServer.settingsHint
                                )
                            }
                        }
                    }

                    serverCard(
                        title: "Cloud-Server (VidSave)",
                        text: $cloudServerURL,
                        placeholder: "http://158.101.168.11:8765",
                        helperText: "Überall erreichbar, kein Mac nötig. Für YouTube und viele große Plattformen aber oft unzuverlässig."
                    )

                    serverCard(
                        title: "Lokaler Server (VideoLoader)",
                        text: $macServerURL,
                        placeholder: "http://100.80.105.62:8765",
                        helperText: "Dein lokaler Windows-Server. Für YouTube diesen Server-Modus verwenden, nicht den Cloud-Server."
                    )
                }
            }
            .padding(AppGlassTheme.screenPadding)
            .background(AppGlassBackground())
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                        .foregroundStyle(AppGlassColors.textPrimary)
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
        GlassCard {
            VStack(alignment: .leading, spacing: AppGlassSpacing.md) {
                AppGlassSectionHeader(title: title)

                Text("Server-Adresse")
                    .font(AppGlassTypography.headline)
                    .foregroundStyle(AppGlassColors.textPrimary)

                GlassInputField(
                    label: "URL",
                    placeholder: placeholder,
                    text: text,
                    helperText: helperText,
                    keyboardType: .URL,
                    textContentType: .URL,
                    autocapitalization: .never,
                    disablesAutocorrection: true
                )
            }
        }
    }

}

#Preview {
    SettingsView(
        macServerURL: .constant("http://100.80.105.62:8765"),
        cloudServerURL: .constant("http://158.101.168.11:8765"),
        activeServerRaw: .constant(ServerKind.videoLoader.rawValue)
    )
}

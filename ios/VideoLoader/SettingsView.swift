import SwiftUI

struct SettingsView: View {
    @Binding var macServerURL: String
    @Binding var cloudServerURL: String
    @Binding var activeServerRaw: String
    @Environment(\.dismiss) private var dismiss

    private var glassBackground: some View {
        LinearGradient(
            colors: [AppGlassColors.bgElevated, AppGlassColors.bgBase, AppGlassColors.bgDeep],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppGlassTheme.sectionSpacing) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: AppGlassSpacing.md) {
                            Text("Aktiver Server")
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
                        title: "Mac-Server (VideoLoader)",
                        text: $macServerURL,
                        placeholder: "http://192.168.1.23:8000",
                        helperText: "Starte auf dem Mac `start.sh`. Die angezeigte Adresse hier eintragen. Im gleichen WLAN ist dieser Server die zuverlässigste Wahl."
                    )
                }
            }
            .padding(AppGlassTheme.screenPadding)
            .background(glassBackground.ignoresSafeArea())
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
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
                Text(title)
                    .font(AppGlassTypography.headline)
                    .foregroundStyle(AppGlassColors.textPrimary)

                GlassInputField(
                    label: "Server-Adresse",
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
        macServerURL: .constant(""),
        cloudServerURL: .constant("http://158.101.168.11:8765"),
        activeServerRaw: .constant(ServerKind.vidSave.rawValue)
    )
}

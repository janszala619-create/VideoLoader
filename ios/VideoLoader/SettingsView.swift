import SwiftUI

struct SettingsView: View {
    @Binding var macServerURL: String
    @Binding var cloudServerURL: String
    @Binding var activeServerRaw: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppThemePremium.sectionSpacing) {
                    PremiumGlassCard {
                        VStack(alignment: .leading, spacing: AppThemePremium.md) {
                            Text("Aktiver Server")
                                .font(.headline)
                                .foregroundStyle(AppColorsPremium.textPrimary)

                            Picker("Server", selection: $activeServerRaw) {
                                ForEach(ServerKind.allCases) { kind in
                                    Text(kind.label).tag(kind.rawValue)
                                }
                            }
                            .pickerStyle(.segmented)
                            .tint(AppColorsPremium.accentBlue)

                            if let activeServer = ServerKind(rawValue: activeServerRaw) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(activeServer.label)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppColorsPremium.accentBlue)
                                    Text(activeServer.settingsHint)
                                        .font(.caption)
                                        .foregroundStyle(AppColorsPremium.textSecondary)
                                }
                                .padding(AppThemePremium.md)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(AppColorsPremium.glassSurface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppThemePremium.radiusSmall)
                                        .stroke(AppColorsPremium.glassBorder, lineWidth: 0.8)
                                )
                                .cornerRadius(AppThemePremium.radiusSmall)
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
            .padding(AppThemePremium.screenPadding)
            .background(PremiumAuroraBackground())
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                        .foregroundStyle(AppColorsPremium.accentBlue)
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
        PremiumGlassCard {
            VStack(alignment: .leading, spacing: AppThemePremium.md) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppColorsPremium.textPrimary)

                PremiumGlassInputField(
                    placeholder: placeholder,
                    text: text,
                    icon: "server.rack",
                    onIconTap: {}
                )
                Text(helperText)
                    .font(.caption)
                    .foregroundStyle(AppColorsPremium.textSecondary)

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

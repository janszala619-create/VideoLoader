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
            ZStack {
                PremiumAuroraBackground()

                ScrollView {
                    VStack(spacing: AppThemePremium.xl) {

                        // MARK: - Header
                        VStack(alignment: .leading, spacing: AppThemePremium.sm) {
                            Text("Server-Konfiguration")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(AppColorsPremium.textPrimary)

                            Text("Wähle deinen aktiven Server und trage die Adressen ein.")
                                .font(.subheadline)
                                .foregroundStyle(AppColorsPremium.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // MARK: - Server Auswahl
                        VStack(alignment: .leading, spacing: AppThemePremium.md) {
                            sectionLabel("Aktiver Server")

                            PremiumGlassCard {
                                VStack(alignment: .leading, spacing: AppThemePremium.md) {
                                    Picker("Server", selection: $activeServerRaw) {
                                        ForEach(ServerKind.allCases) { kind in
                                            Text(kind.label).tag(kind.rawValue)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                    .tint(AppColorsPremium.accentBlue)

                                    if let server = activeServer {
                                        HStack(spacing: AppThemePremium.md) {
                                            Image(systemName: "info.circle.fill")
                                                .foregroundStyle(AppColorsPremium.accentTeal)
                                                .font(.subheadline)

                                            Text(server.settingsHint)
                                                .font(.caption)
                                                .foregroundStyle(AppColorsPremium.textSecondary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        .padding(AppThemePremium.md)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(AppColorsPremium.auroraTeal.opacity(0.06))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: AppThemePremium.radiusSmall)
                                                .stroke(AppColorsPremium.accentTeal.opacity(0.25), lineWidth: 1)
                                        )
                                        .cornerRadius(AppThemePremium.radiusSmall)
                                    }
                                }
                            }
                        }

                        // MARK: - Cloud Server
                        VStack(alignment: .leading, spacing: AppThemePremium.md) {
                            sectionLabel("Cloud-Server")

                            PremiumGlassCard {
                                VStack(alignment: .leading, spacing: AppThemePremium.md) {
                                    HStack(spacing: AppThemePremium.sm) {
                                        Image(systemName: "cloud.fill")
                                            .foregroundStyle(AppColorsPremium.accentBlue)
                                        Text("VidSave")
                                            .font(.headline.weight(.semibold))
                                            .foregroundStyle(AppColorsPremium.textPrimary)

                                        Spacer()

                                        if activeServerRaw == ServerKind.vidSave.rawValue {
                                            activeBadge
                                        }
                                    }

                                    PremiumGlassInputField(
                                        placeholder: "http://158.101.168.11:8765",
                                        text: $cloudServerURL,
                                        icon: cloudServerURL.isEmpty ? "exclamationmark.circle" : "checkmark.circle.fill",
                                        onIconTap: {}
                                    )

                                    Text("Überall erreichbar, kein Mac nötig. Für YouTube und viele Plattformen oft unzuverlässig.")
                                        .font(.caption)
                                        .foregroundStyle(AppColorsPremium.textSecondary)
                                }
                            }
                        }

                        // MARK: - Mac Server
                        VStack(alignment: .leading, spacing: AppThemePremium.md) {
                            sectionLabel("Mac-Server")

                            PremiumGlassCard {
                                VStack(alignment: .leading, spacing: AppThemePremium.md) {
                                    HStack(spacing: AppThemePremium.sm) {
                                        Image(systemName: "desktopcomputer")
                                            .foregroundStyle(AppColorsPremium.accentViolet)
                                        Text("VideoLoader (lokal)")
                                            .font(.headline.weight(.semibold))
                                            .foregroundStyle(AppColorsPremium.textPrimary)

                                        Spacer()

                                        if activeServerRaw == ServerKind.videoLoader.rawValue {
                                            activeBadge
                                        }
                                    }

                                    PremiumGlassInputField(
                                        placeholder: "http://192.168.1.23:8000",
                                        text: $macServerURL,
                                        icon: macServerURL.isEmpty ? "exclamationmark.circle" : "checkmark.circle.fill",
                                        onIconTap: {}
                                    )

                                    Text("Starte `start.sh` auf dem Mac, trage die IP-Adresse ein. Im gleichen WLAN die zuverlässigste Option.")
                                        .font(.caption)
                                        .foregroundStyle(AppColorsPremium.textSecondary)
                                }
                            }
                        }

                        Spacer(minHeight: AppThemePremium.xxl)
                    }
                    .padding(AppThemePremium.screenPadding)
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppColorsPremium.accentBlue)
                }
            }
        }
    }

    // MARK: - Helper Views

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(1.2)
            .foregroundStyle(AppColorsPremium.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 4)
    }

    private var activeBadge: some View {
        Text("AKTIV")
            .font(.caption2.weight(.bold))
            .tracking(0.8)
            .foregroundStyle(AppColorsPremium.accentBlue)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(AppColorsPremium.accentBlue.opacity(0.15))
            .overlay(
                Capsule()
                    .stroke(AppColorsPremium.accentBlue.opacity(0.4), lineWidth: 1)
            )
            .clipShape(Capsule())
    }
}

#Preview {
    SettingsView(
        macServerURL: .constant(""),
        cloudServerURL: .constant("http://158.101.168.11:8765"),
        activeServerRaw: .constant(ServerKind.vidSave.rawValue)
    )
}

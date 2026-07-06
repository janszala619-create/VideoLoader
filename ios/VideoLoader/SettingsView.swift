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
                    VStack(spacing: Aurora.Spacing.xl) {
                        headerSection
                        activeServerSection
                        cloudServerSection
                        macServerSection
                        Spacer(minLength: Aurora.Spacing.xxl)
                    }
                    .padding(Aurora.Spacing.screen)
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                        .font(Aurora.Typography.body.weight(.semibold))
                        .foregroundStyle(Aurora.Colors.accentBlue)
                }
            }
        }
    }

    // MARK: - Helper Views

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Aurora.Spacing.sm) {
            Text("Server-Konfiguration")
                .font(Aurora.Typography.title2)
                .foregroundStyle(Aurora.Colors.textPrimary)

            Text("Wähle deinen aktiven Server und trage die Adressen ein.")
                .font(Aurora.Typography.subheadline)
                .foregroundStyle(Aurora.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var activeServerSection: some View {
        VStack(alignment: .leading, spacing: Aurora.Spacing.md) {
            sectionLabel("Aktiver Server")

            PremiumGlassCard {
                VStack(alignment: .leading, spacing: Aurora.Spacing.md) {
                    Picker("Server", selection: $activeServerRaw) {
                        ForEach(ServerKind.allCases) { kind in
                            Text(kind.label).tag(kind.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(Aurora.Colors.accentBlue)

                    if let server = activeServer {
                        serverHint(server.settingsHint, icon: "info.circle.fill", tint: Aurora.Colors.accentTeal)
                    }
                }
            }
        }
    }

    private var cloudServerSection: some View {
        serverSection(
            title: "Cloud-Server",
            icon: "cloud.fill",
            iconColor: Aurora.Colors.accentBlue,
            name: "VidSave",
            isActive: activeServerRaw == ServerKind.vidSave.rawValue,
            placeholder: "http://158.101.168.11:8765",
            text: $cloudServerURL,
            iconName: cloudServerURL.isEmpty ? "exclamationmark.circle" : "checkmark.circle.fill",
            helper: "Überall erreichbar, kein Mac nötig. Für YouTube und viele Plattformen oft unzuverlässig."
        )
    }

    private var macServerSection: some View {
        serverSection(
            title: "Mac-Server",
            icon: "desktopcomputer",
            iconColor: Aurora.Colors.accentViolet,
            name: "VideoLoader (lokal)",
            isActive: activeServerRaw == ServerKind.videoLoader.rawValue,
            placeholder: "http://192.168.1.23:8000",
            text: $macServerURL,
            iconName: macServerURL.isEmpty ? "exclamationmark.circle" : "checkmark.circle.fill",
            helper: "Starte `start.sh` auf dem Mac, trage die IP-Adresse ein. Im gleichen WLAN die zuverlässigste Option."
        )
    }

    private func serverSection(
        title: String,
        icon: String,
        iconColor: Color,
        name: String,
        isActive: Bool,
        placeholder: String,
        text: Binding<String>,
        iconName: String,
        helper: String
    ) -> some View {
        VStack(alignment: .leading, spacing: Aurora.Spacing.md) {
            sectionLabel(title)

            PremiumGlassCard {
                VStack(alignment: .leading, spacing: Aurora.Spacing.md) {
                    HStack(spacing: Aurora.Spacing.sm) {
                        Image(systemName: icon)
                            .foregroundStyle(iconColor)
                        Text(name)
                            .font(Aurora.Typography.headline)
                            .foregroundStyle(Aurora.Colors.textPrimary)

                        Spacer()

                        if isActive {
                            activeBadge
                        }
                    }

                    PremiumGlassInputField(
                        placeholder: placeholder,
                        text: text,
                        icon: iconName,
                        onIconTap: {}
                    )

                    Text(helper)
                        .font(Aurora.Typography.caption)
                        .foregroundStyle(Aurora.Colors.textSecondary)
                }
            }
        }
    }

    private func serverHint(_ text: String, icon: String, tint: Color) -> some View {
        HStack(spacing: Aurora.Spacing.md) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .font(Aurora.Typography.subheadline)

            Text(text)
                .font(Aurora.Typography.caption)
                .foregroundStyle(Aurora.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Aurora.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Aurora.Colors.teal.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: Aurora.CornerRadius.small)
                .stroke(Aurora.Colors.accentTeal.opacity(0.25), lineWidth: 1)
        )
        .cornerRadius(Aurora.CornerRadius.small)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(Aurora.Typography.caption.weight(.semibold))
            .tracking(1.2)
            .foregroundStyle(Aurora.Colors.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 4)
    }

    private var activeBadge: some View {
        Text("AKTIV")
            .font(Aurora.Typography.caption2.weight(.bold))
            .tracking(0.8)
            .foregroundStyle(Aurora.Colors.accentBlue)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Aurora.Colors.accentBlue.opacity(0.15))
            .overlay(
                Capsule()
                    .stroke(Aurora.Colors.accentBlue.opacity(0.4), lineWidth: 1)
            )
            .clipShape(Capsule())
    }
}

typealias SettingsViewPremium = SettingsView

#Preview {
    SettingsView(
        macServerURL: .constant(""),
        cloudServerURL: .constant("http://158.101.168.11:8765"),
        activeServerRaw: .constant(ServerKind.vidSave.rawValue)
    )
}

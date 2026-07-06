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
                settingsContent
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

    private var settingsContent: some View {
        ScrollView {
            VStack(spacing: Aurora.Spacing.xl) {
                headerSection
                activeServerSection
                cloudServerSection
                macServerSection
                Spacer(minHeight: Aurora.Spacing.xxl)
            }
            .padding(Aurora.Spacing.screen)
        }
    }

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
                        serverHint(server)
                    }
                }
            }
        }
    }

    private func serverHint(_ server: ServerKind) -> some View {
        HStack(spacing: Aurora.Spacing.md) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(Aurora.Colors.accentTeal)
                .font(Aurora.Typography.subheadline)

            Text(server.settingsHint)
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

    private var cloudServerSection: some View {
        serverAddressSection(
            title: "VidSave",
            label: "Cloud-Server",
            icon: "cloud.fill",
            iconColor: Aurora.Colors.accentBlue,
            placeholder: "http://158.101.168.11:8765",
            text: $cloudServerURL,
            isActive: activeServerRaw == ServerKind.vidSave.rawValue,
            footer: "Überall erreichbar, kein Mac nötig. Für YouTube und viele Plattformen oft unzuverlässig."
        )
    }

    private var macServerSection: some View {
        serverAddressSection(
            title: "VideoLoader (lokal)",
            label: "Mac-Server",
            icon: "desktopcomputer",
            iconColor: Aurora.Colors.accentViolet,
            placeholder: "http://192.168.1.23:8000",
            text: $macServerURL,
            isActive: activeServerRaw == ServerKind.videoLoader.rawValue,
            footer: "Starte `start.sh` auf dem Mac, trage die IP-Adresse ein. Im gleichen WLAN die zuverlässigste Option."
        )
    }

    private func serverAddressSection(
        title: String,
        label: String,
        icon: String,
        iconColor: Color,
        placeholder: String,
        text: Binding<String>,
        isActive: Bool,
        footer: String
    ) -> some View {
        VStack(alignment: .leading, spacing: Aurora.Spacing.md) {
            sectionLabel(label)

            PremiumGlassCard {
                VStack(alignment: .leading, spacing: Aurora.Spacing.md) {
                    HStack(spacing: Aurora.Spacing.sm) {
                        Image(systemName: icon)
                            .foregroundStyle(iconColor)
                        Text(title)
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
                        icon: text.wrappedValue.isEmpty ? "exclamationmark.circle" : "checkmark.circle.fill",
                        onIconTap: {}
                    )

                    Text(footer)
                        .font(Aurora.Typography.caption)
                        .foregroundStyle(Aurora.Colors.textSecondary)
                }
            }
        }
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

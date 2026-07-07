import SwiftUI

struct SettingsView: View {
    @Binding var macServerURL: String
    @Binding var cloudServerURL: String
    @Binding var activeServerRaw: String
    @Environment(\.dismiss) private var dismiss

    @State private var localStatus: ConnectionStatus = .unknown
    @State private var cloudStatus: ConnectionStatus = .unknown
    @State private var advancedExpanded = false

    private static let defaultLocalServerURL = "http://100.80.105.62:9876"
    private static let defaultCloudServerURL = "http://158.101.168.11:8765"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppGlassTheme.sectionSpacing) {
                    header
                    activeServerCard
                    connectionCard(
                        title: "Lokaler Server",
                        subtitle: "Empfohlen für YouTube im selben WLAN.",
                        url: macServerURL,
                        status: localStatus,
                        kind: .videoLoader
                    )
                    connectionCard(
                        title: "Cloud-Server",
                        subtitle: "Überall erreichbar, aber je nach Quelle weniger zuverlässig.",
                        url: cloudServerURL,
                        status: cloudStatus,
                        kind: .vidSave
                    )
                    advancedCard
                }
                .padding(AppGlassTheme.screenPadding)
                .padding(.bottom, 110)
            }
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

    private var header: some View {
        VStack(alignment: .leading, spacing: AppGlassSpacing.sm) {
            Text("Verbindung")
                .font(AppGlassTypography.largeTitle)
                .foregroundStyle(AppGlassColors.textPrimary)
            Text("Wähle den Server, der am zuverlässigsten zu deinem Setup passt.")
                .font(AppGlassTypography.body)
                .foregroundStyle(AppGlassColors.textSecondary)
        }
    }

    private var activeServerCard: some View {
        GlassCard {
            AppGlassSectionHeader(title: "Aktiver Server")
            Picker("Aktiver Server", selection: $activeServerRaw) {
                ForEach(ServerKind.allCases) { kind in
                    Text(kind.label).tag(kind.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .tint(AppGlassColors.accentPrimary)
        }
    }

    private func connectionCard(
        title: String,
        subtitle: String,
        url: String,
        status: ConnectionStatus,
        kind: ServerKind
    ) -> some View {
        GlassCard {
            HStack(alignment: .top, spacing: AppGlassSpacing.md) {
                VStack(alignment: .leading, spacing: AppGlassSpacing.sm) {
                    Text(title)
                        .font(AppGlassTypography.headline)
                        .foregroundStyle(AppGlassColors.textPrimary)
                    Text(subtitle)
                        .font(AppGlassTypography.footnote)
                        .foregroundStyle(AppGlassColors.textSecondary)
                    Text(url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Keine URL hinterlegt" : url)
                        .font(AppGlassTypography.caption)
                        .foregroundStyle(AppGlassColors.textTertiary)
                        .lineLimit(2)
                }
                Spacer(minLength: AppGlassSpacing.sm)
                statusPill(status, kind: kind)
            }

            Button {
                Task { await testConnection(kind) }
            } label: {
                Label(status == .testing ? "Verbindung wird getestet…" : "Verbindung testen",
                      systemImage: status == .testing ? "hourglass" : "network")
            }
            .buttonStyle(GlassSecondaryButtonStyle())
            .disabled(status == .testing)
        }
    }

    private var advancedCard: some View {
        GlassCard {
            DisclosureGroup(isExpanded: $advancedExpanded) {
                VStack(alignment: .leading, spacing: AppGlassSpacing.lg) {
                    editableServerField(
                        title: "Lokaler Server",
                        text: $macServerURL,
                        placeholder: Self.defaultLocalServerURL,
                        helperText: "Standard-Port für den lokalen VideoLoader-Server: 9876."
                    )
                    editableServerField(
                        title: "Cloud-Server",
                        text: $cloudServerURL,
                        placeholder: Self.defaultCloudServerURL,
                        helperText: "Legacy/VidSave bleibt separat und nutzt Port 8765."
                    )
                    Button(role: .destructive) {
                        macServerURL = Self.defaultLocalServerURL
                        cloudServerURL = Self.defaultCloudServerURL
                        localStatus = .unknown
                        cloudStatus = .unknown
                    } label: {
                        Label("Standardwerte zurücksetzen", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(AppGlassColors.error)
                }
                .padding(.top, AppGlassSpacing.md)
            } label: {
                Text("Erweitert")
                    .font(AppGlassTypography.headline)
                    .foregroundStyle(AppGlassColors.textPrimary)
            }
            .tint(AppGlassColors.textPrimary)
        }
    }

    private func editableServerField(
        title: String,
        text: Binding<String>,
        placeholder: String,
        helperText: String
    ) -> some View {
        VStack(alignment: .leading, spacing: AppGlassSpacing.sm) {
            Text(title)
                .font(AppGlassTypography.subheadline.weight(.semibold))
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

    private func statusPill(_ status: ConnectionStatus, kind: ServerKind) -> some View {
        HStack(spacing: AppGlassSpacing.xs) {
            Image(systemName: status.iconName)
                .font(.caption.weight(.semibold))
            Text(status.title(for: kind))
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(status.tint)
        .padding(.horizontal, AppGlassSpacing.md)
        .padding(.vertical, AppGlassSpacing.sm)
        .background(
            Capsule()
                .fill(status.tint.opacity(0.14))
        )
        .accessibilityLabel(status.accessibilityLabel(for: kind))
    }

    @MainActor
    private func testConnection(_ kind: ServerKind) async {
        setStatus(.testing, for: kind)
        let baseURL = kind == .videoLoader ? macServerURL : cloudServerURL
        let isReachable = await ServerAPI(kind: kind, baseURL: baseURL).isReachable()
        setStatus(isReachable ? .online : .offline, for: kind)
    }

    @MainActor
    private func setStatus(_ status: ConnectionStatus, for kind: ServerKind) {
        switch kind {
        case .videoLoader:
            localStatus = status
        case .vidSave:
            cloudStatus = status
        }
    }
}

private enum ConnectionStatus: Equatable {
    case unknown
    case testing
    case online
    case offline

    var iconName: String {
        switch self {
        case .unknown: return "questionmark.circle.fill"
        case .testing: return "clock.fill"
        case .online: return "checkmark.circle.fill"
        case .offline: return "exclamationmark.triangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .unknown: return AppGlassColors.textTertiary
        case .testing: return AppGlassColors.warning
        case .online: return AppGlassColors.success
        case .offline: return AppGlassColors.error
        }
    }

    func title(for kind: ServerKind) -> String {
        switch self {
        case .unknown:
            return "Unbekannt"
        case .testing:
            return "Prüfen…"
        case .online:
            return kind == .videoLoader ? "Lokal online" : "Cloud online"
        case .offline:
            return "Offline"
        }
    }

    func accessibilityLabel(for kind: ServerKind) -> String {
        switch self {
        case .unknown:
            return "Serverstatus unbekannt"
        case .testing:
            return "Serverstatus wird geprüft"
        case .online:
            return kind == .videoLoader ? "Lokaler Server online" : "Cloud-Server online"
        case .offline:
            return "Server offline"
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

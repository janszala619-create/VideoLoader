import SwiftUI

struct SettingsView: View {
    @Binding var macServerURL: String
    @Binding var cloudServerURL: String
    @Binding var activeServerRaw: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Aktiver Server") {
                    Picker("Server", selection: $activeServerRaw) {
                        ForEach(ServerKind.allCases) { kind in
                            Text(kind.label).tag(kind.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(ServerKind(rawValue: activeServerRaw)?.settingsHint ?? "")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Cloud-Server (VidSave)") {
                    TextField("http://158.101.168.11:8765", text: $cloudServerURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("Überall erreichbar, kein Mac nötig. YouTube & viele große Seiten sind hier aber oft blockiert.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Mac-Server (VideoLoader)") {
                    TextField("http://192.168.1.23:8000", text: $macServerURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("Starte auf dem Mac start.sh im Ordner „server“ – dort wird dir die Adresse angezeigt. iPhone und Mac müssen im selben WLAN sein. Zuverlässig auch für YouTube.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .neonScreenBackground()
            .neonCardRow()
            .preferredColorScheme(.dark)
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
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

import SwiftUI

struct PreferencesView: View {
    @State private var apiKey: String = (try? KeychainHelper.shared.apiKey()) ?? ""
    @State private var databasePath: String = DataStore.defaultPath
    @State private var launchAtLogin: Bool = false
    var onSave: () -> Void = {}

    var body: some View {
        Form {
            Section(header: Text("Google AI Studio")) {
                SecureField("API Key", text: $apiKey)
                Button("Save Key") {
                    try? KeychainHelper.shared.save(apiKey: apiKey)
                }
            }
            Section(header: Text("Database")) {
                TextField("Path", text: $databasePath)
                Button("Reset to default") { databasePath = DataStore.defaultPath }
            }
            Section(header: Text("General")) {
                Toggle("Automatically open app when logging in", isOn: $launchAtLogin)
                    .disabled(true)
            }
        }
        .padding()
        .frame(width: 420)
    }
}

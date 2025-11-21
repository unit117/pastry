import SwiftUI

@main
struct PastryArchitectApp: App {
    @StateObject private var viewModel = AppViewModel()
    @State private var showingPreferences = false

    var body: some Scene {
        WindowGroup {
            MainView(viewModel: viewModel)
                .frame(minWidth: 900, minHeight: 600)
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Preferences…") { showingPreferences = true }
                    .keyboardShortcut(",")
            }
        }
        .sheet(isPresented: $showingPreferences) {
            PreferencesView()
        }

        Settings {
            PreferencesView()
        }
    }
}

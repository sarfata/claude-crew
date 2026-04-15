import SwiftUI

@main
struct ClaudeCrewApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1100, height: 700)

        #if os(macOS)
        Settings {
            SettingsView()
                .environment(appState)
        }
        #endif
    }
}

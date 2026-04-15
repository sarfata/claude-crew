import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        if !appState.hasAPIKey {
            WelcomeView()
        } else {
            NavigationSplitView {
                SidebarView()
            } detail: {
                detailView
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 300)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    SessionStatusBar()
                }
                ToolbarItem(placement: .automatic) {
                    Button {
                        Task { await appState.refreshAll() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Refresh all data")
                }
            }
            .task {
                await appState.refreshAll()
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch appState.selectedSection {
        case .sessions:
            SessionsListView()
        case .agents:
            AgentsListView()
        case .environments:
            EnvironmentsListView()
        case .vaults:
            VaultsListView()
        case .settings:
            SettingsView()
        case nil:
            Text("Select a section from the sidebar")
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Welcome View (no API key)

struct WelcomeView: View {
    @Environment(AppState.self) private var appState
    @State private var apiKey = ""
    @State private var error: String?

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.2.badge.gearshape")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            Text("Welcome to Claude Crew")
                .font(.largeTitle.bold())

            Text("Manage Claude's Managed Agents with a native interface.\nCreate agents, configure environments, and monitor sessions.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Anthropic API Key")
                    .font(.headline)

                SecureField("sk-ant-...", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 400)
                    .onSubmit { saveKey() }

                Text("Your API key is stored securely in the macOS Keychain.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let error {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Button("Get Started") {
                saveKey()
            }
            .buttonStyle(.borderedProminent)
            .disabled(apiKey.isEmpty)
            .keyboardShortcut(.defaultAction)
        }
        .padding(40)
        .frame(minWidth: 600, minHeight: 500)
    }

    private func saveKey() {
        do {
            try appState.setAPIKey(apiKey)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Session Status Bar

struct SessionStatusBar: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 12) {
            if appState.activeSessionCount > 0 {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                    Text("\(appState.activeSessionCount) running")
                        .font(.caption)
                }
            }

            if appState.idleSessionCount > 0 {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.secondary)
                        .frame(width: 8, height: 8)
                    Text("\(appState.idleSessionCount) idle")
                        .font(.caption)
                }
            }

            if appState.isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }
}

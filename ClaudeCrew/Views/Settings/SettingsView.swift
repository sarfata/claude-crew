import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var apiKey = ""
    @State private var showKey = false
    @State private var saved = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Settings")
                    .font(.title.bold())

                // API Key
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Anthropic API Key", systemImage: "key")
                            .font(.headline)

                        Text("Your API key is required to communicate with the Claude Managed Agents API. It is stored securely in the macOS Keychain.")
                            .font(.callout)
                            .foregroundStyle(.secondary)

                        HStack {
                            if showKey {
                                TextField("sk-ant-...", text: $apiKey)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.body.monospaced())
                            } else {
                                SecureField("sk-ant-...", text: $apiKey)
                                    .textFieldStyle(.roundedBorder)
                            }

                            Button {
                                showKey.toggle()
                            } label: {
                                Image(systemName: showKey ? "eye.slash" : "eye")
                            }
                        }

                        HStack {
                            Button("Save") {
                                do {
                                    try appState.setAPIKey(apiKey)
                                    saved = true
                                    Task {
                                        try? await Task.sleep(for: .seconds(2))
                                        saved = false
                                    }
                                } catch {
                                    // Handle error
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(apiKey.isEmpty)

                            if appState.hasAPIKey {
                                Button("Remove Key", role: .destructive) {
                                    appState.clearAPIKey()
                                    apiKey = ""
                                }
                            }

                            if saved {
                                Label("Saved", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                            }
                        }
                    }
                    .padding(4)
                }

                // About
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("About Claude Crew", systemImage: "info.circle")
                            .font(.headline)

                        Text("Claude Crew is an open-source macOS app for managing Claude Managed Agents.")
                            .font(.callout)
                            .foregroundStyle(.secondary)

                        Text("API Reference")
                            .font(.subheadline.bold())
                            .padding(.top, 4)

                        VStack(alignment: .leading, spacing: 4) {
                            BulletPoint("All API requests use the `managed-agents-2026-04-01` beta header")
                            BulletPoint("Agents define model, system prompt, tools, and MCP servers")
                            BulletPoint("Environments define container configuration (packages, networking)")
                            BulletPoint("Sessions are running agent instances within environments")
                            BulletPoint("Vaults store per-user authentication credentials for MCP servers")
                        }
                    }
                    .padding(4)
                }
            }
            .padding(20)
            .frame(maxWidth: 600)
        }
        .frame(minWidth: 500, minHeight: 400)
        .onAppear {
            apiKey = KeychainHelper.load() ?? ""
        }
    }
}

struct BulletPoint: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text("\u{2022}")
                .foregroundStyle(.secondary)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

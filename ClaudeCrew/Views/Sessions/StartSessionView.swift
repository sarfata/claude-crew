import SwiftUI

struct StartSessionView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var agentId: String?

    @State private var selectedAgentId: String?
    @State private var selectedEnvironmentId: String?
    @State private var selectedVaultIds: Set<String> = []
    @State private var title = ""
    @State private var initialMessage = ""
    @State private var isCreating = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Start Session")
                    .font(.title2.bold())
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Agent
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Agent")
                            .font(.headline)
                        if appState.agents.isEmpty {
                            Text("No agents available. Create one first.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Picker("Agent", selection: $selectedAgentId) {
                                Text("Select an agent...").tag(nil as String?)
                                ForEach(appState.agents) { agent in
                                    Text("\(agent.name) (v\(agent.version))")
                                        .tag(agent.id as String?)
                                }
                            }
                            .labelsHidden()
                        }
                    }

                    // Environment
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Environment")
                            .font(.headline)
                        if appState.environments.isEmpty {
                            Text("No environments available. Create one first.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Picker("Environment", selection: $selectedEnvironmentId) {
                                Text("Select an environment...").tag(nil as String?)
                                ForEach(appState.environments) { env in
                                    Text(env.name)
                                        .tag(env.id as String?)
                                }
                            }
                            .labelsHidden()
                        }
                    }

                    // Title
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Title")
                            .font(.headline)
                        TextField("Optional session title", text: $title)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Vaults
                    if !appState.vaults.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Vaults (optional)")
                                .font(.headline)
                            Text("Select vaults to provide MCP authentication credentials.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ForEach(appState.vaults) { vault in
                                Toggle(isOn: Binding(
                                    get: { selectedVaultIds.contains(vault.id) },
                                    set: { selected in
                                        if selected {
                                            selectedVaultIds.insert(vault.id)
                                        } else {
                                            selectedVaultIds.remove(vault.id)
                                        }
                                    }
                                )) {
                                    Text(vault.displayName)
                                }
                            }
                        }
                    }

                    // Initial message
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Initial Message")
                            .font(.headline)
                        Text("Send a message to start the agent working right away.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $initialMessage)
                            .font(.body)
                            .frame(minHeight: 80)
                            .padding(4)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                    }

                    if let error {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
                .padding()
            }

            Divider()

            HStack {
                Spacer()
                Button {
                    Task { await startSession() }
                } label: {
                    if isCreating {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Starting...")
                        }
                    } else {
                        Text("Start Session")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedAgentId == nil || selectedEnvironmentId == nil || isCreating)
            }
            .padding()
        }
        .frame(width: 550, height: 650)
        .onAppear {
            if let agentId {
                selectedAgentId = agentId
            }
        }
    }

    private func startSession() async {
        guard let client = appState.client,
              let agentId = selectedAgentId,
              let envId = selectedEnvironmentId else { return }

        isCreating = true
        error = nil

        let params = SessionCreateParams(
            agent: agentId,
            environmentId: envId,
            vaultIds: selectedVaultIds.isEmpty ? nil : Array(selectedVaultIds),
            title: title.isEmpty ? nil : title
        )

        do {
            let session = try await client.createSession(params: params)

            // Send initial message if provided
            let msg = initialMessage.trimmingCharacters(in: .whitespacesAndNewlines)
            if !msg.isEmpty {
                try await client.sendMessage(sessionId: session.id, text: msg)
            }

            await appState.refreshSessions()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }

        isCreating = false
    }
}

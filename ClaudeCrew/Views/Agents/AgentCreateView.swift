import SwiftUI

struct AgentCreateView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedModel = AvailableModel.claudeSonnet
    @State private var systemPrompt = ""
    @State private var description = ""
    @State private var useToolset = true
    @State private var disabledTools: Set<String> = []
    @State private var mcpServers: [MCPServerDraft] = []
    @State private var isSaving = false
    @State private var error: String?

    struct MCPServerDraft: Identifiable {
        let id = UUID()
        var name: String = ""
        var url: String = ""
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Create Agent")
                    .font(.title2.bold())
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            // Form
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Name
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Name")
                            .font(.headline)
                        TextField("My Coding Assistant", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Model
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Model")
                            .font(.headline)
                        Picker("Model", selection: $selectedModel) {
                            ForEach(AvailableModel.allCases, id: \.self) { model in
                                Text(model.displayName).tag(model)
                            }
                        }
                        .labelsHidden()
                    }

                    // System Prompt
                    VStack(alignment: .leading, spacing: 4) {
                        Text("System Prompt")
                            .font(.headline)
                        Text("Define the agent's behavior and persona.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $systemPrompt)
                            .font(.body.monospaced())
                            .frame(minHeight: 120)
                            .padding(4)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                    }

                    // Description
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description")
                            .font(.headline)
                        TextField("What does this agent do?", text: $description)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Tools
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tools")
                            .font(.headline)
                        Toggle("Enable Agent Toolset", isOn: $useToolset)

                        if useToolset {
                            Text("Configure which tools are available:")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ForEach(AvailableAgentTool.allCases, id: \.self) { tool in
                                HStack {
                                    Toggle(isOn: Binding(
                                        get: { !disabledTools.contains(tool.rawValue) },
                                        set: { enabled in
                                            if enabled {
                                                disabledTools.remove(tool.rawValue)
                                            } else {
                                                disabledTools.insert(tool.rawValue)
                                            }
                                        }
                                    )) {
                                        VStack(alignment: .leading) {
                                            Text(tool.displayName)
                                                .font(.body)
                                            Text(tool.description)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // MCP Servers
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("MCP Servers")
                                .font(.headline)
                            Spacer()
                            Button {
                                mcpServers.append(MCPServerDraft())
                            } label: {
                                Image(systemName: "plus.circle")
                            }
                        }

                        if mcpServers.isEmpty {
                            Text("No MCP servers configured. Add one to connect external tools.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        ForEach($mcpServers) { $server in
                            HStack {
                                VStack {
                                    TextField("Name (e.g. github)", text: $server.name)
                                        .textFieldStyle(.roundedBorder)
                                    TextField("URL (e.g. https://api.githubcopilot.com/mcp/)", text: $server.url)
                                        .textFieldStyle(.roundedBorder)
                                }
                                Button {
                                    mcpServers.removeAll { $0.id == server.id }
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.red)
                                }
                            }
                            .padding(8)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                        }
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

            // Footer
            HStack {
                Spacer()
                Button {
                    Task { await createAgent() }
                } label: {
                    if isSaving {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Creating...")
                        }
                    } else {
                        Text("Create Agent")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || isSaving)
            }
            .padding()
        }
        .frame(width: 600, height: 700)
    }

    private func createAgent() async {
        guard let client = appState.client else { return }
        isSaving = true
        error = nil

        var tools: [AgentTool] = []
        if useToolset {
            var configs: [ToolConfig] = []
            for toolName in disabledTools {
                configs.append(ToolConfig(name: toolName, enabled: false))
            }
            let toolset = AgentTool.AgentToolset(
                type: "agent_toolset_20251212",
                configs: configs.isEmpty ? nil : configs
            )
            tools.append(.toolset(toolset))
        }

        let mcpServerConfigs = mcpServers
            .filter { !$0.name.isEmpty && !$0.url.isEmpty }
            .map { MCPServer(type: "url", name: $0.name, url: $0.url) }

        for server in mcpServerConfigs {
            tools.append(.mcpToolset(AgentTool.MCPToolset(
                type: "mcp_toolset",
                mcpServerName: server.name
            )))
        }

        let params = AgentCreateParams(
            name: name,
            model: selectedModel.rawValue,
            system: systemPrompt.isEmpty ? nil : systemPrompt,
            description: description.isEmpty ? nil : description,
            tools: tools,
            mcpServers: mcpServerConfigs.isEmpty ? nil : mcpServerConfigs
        )

        do {
            _ = try await client.createAgent(params: params)
            await appState.refreshAgents()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }

        isSaving = false
    }
}

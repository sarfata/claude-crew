import SwiftUI

struct AgentDetailView: View {
    let agent: Agent
    @Environment(AppState.self) private var appState
    @State private var showStartSession = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(agent.name)
                            .font(.title2.bold())
                        Text("Version \(agent.version)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Start Session") {
                        showStartSession = true
                    }
                    .buttonStyle(.borderedProminent)
                }

                Divider()

                // Model
                DetailSection(title: "Model", icon: "cpu") {
                    HStack {
                        Text(agent.model.id)
                            .font(.body.monospaced())
                        if let speed = agent.model.speed {
                            Text(speed)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.blue.opacity(0.1), in: Capsule())
                        }
                    }
                }

                // System Prompt
                if let system = agent.system, !system.isEmpty {
                    DetailSection(title: "System Prompt", icon: "text.quote") {
                        Text(system)
                            .font(.body)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                    }
                }

                // Tools
                DetailSection(title: "Tools", icon: "wrench") {
                    ForEach(Array(agent.tools.enumerated()), id: \.offset) { _, tool in
                        ToolBadge(tool: tool)
                    }
                }

                // MCP Servers
                if !agent.mcpServers.isEmpty {
                    DetailSection(title: "MCP Servers", icon: "network") {
                        ForEach(agent.mcpServers) { server in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(server.name)
                                    .font(.headline)
                                Text(server.url)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }

                // Description
                if let desc = agent.description, !desc.isEmpty {
                    DetailSection(title: "Description", icon: "doc.text") {
                        Text(desc)
                            .foregroundStyle(.secondary)
                    }
                }

                // Metadata
                if !agent.metadata.isEmpty {
                    DetailSection(title: "Metadata", icon: "tag") {
                        ForEach(agent.metadata.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                            HStack {
                                Text(key)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(value)
                                    .font(.caption.monospaced())
                            }
                        }
                    }
                }

                // Timestamps
                DetailSection(title: "Info", icon: "info.circle") {
                    LabeledContent("Created", value: agent.createdAt.formatted())
                    LabeledContent("Updated", value: agent.updatedAt.formatted())
                    if let archived = agent.archivedAt {
                        LabeledContent("Archived", value: archived.formatted())
                    }
                    LabeledContent("ID", value: agent.id)
                        .textSelection(.enabled)
                }
            }
            .padding(20)
        }
        .sheet(isPresented: $showStartSession) {
            StartSessionView(agentId: agent.id)
        }
    }
}

// MARK: - Detail Section

struct DetailSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(.primary)

            content
        }
    }
}

// MARK: - Tool Badge

struct ToolBadge: View {
    let tool: AgentTool

    var body: some View {
        switch tool {
        case .toolset(let ts):
            VStack(alignment: .leading, spacing: 4) {
                Text("Agent Toolset")
                    .font(.caption.bold())
                if let configs = ts.configs, !configs.isEmpty {
                    FlowLayout(spacing: 4) {
                        ForEach(configs, id: \.name) { config in
                            Text(config.name)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(config.enabled ? .green.opacity(0.1) : .red.opacity(0.1), in: Capsule())
                                .foregroundStyle(config.enabled ? .green : .red)
                        }
                    }
                } else {
                    Text("All tools enabled")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))

        case .mcpToolset(let mcp):
            HStack {
                Image(systemName: "network")
                Text("MCP: \(mcp.mcpServerName)")
                    .font(.caption)
            }
            .padding(8)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))

        case .custom(let custom):
            VStack(alignment: .leading, spacing: 2) {
                Text(custom.name)
                    .font(.caption.bold())
                Text(custom.description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
        }
    }
}

// MARK: - Simple FlowLayout

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}

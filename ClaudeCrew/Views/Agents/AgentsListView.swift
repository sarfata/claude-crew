import SwiftUI

struct AgentsListView: View {
    @Environment(AppState.self) private var appState
    @State private var showCreateSheet = false
    @State private var selectedAgent: Agent?

    var body: some View {
        HSplitView {
            // List
            VStack(spacing: 0) {
                List(appState.agents, selection: Binding(
                    get: { selectedAgent?.id },
                    set: { id in selectedAgent = appState.agents.first { $0.id == id } }
                )) { agent in
                    AgentRow(agent: agent)
                        .tag(agent.id)
                }
                .listStyle(.inset)
            }
            .frame(minWidth: 280)

            // Detail
            if let agent = selectedAgent {
                AgentDetailView(agent: agent)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "person.2")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("Select an agent to view details")
                        .foregroundStyle(.secondary)
                    Text("Or create a new one to get started")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar {
            ToolbarItem {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Create new agent")
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            AgentCreateView()
        }
        .navigationTitle("Agents")
    }
}

// MARK: - Agent Row

struct AgentRow: View {
    let agent: Agent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(agent.name)
                    .font(.headline)
                Spacer()
                Text("v\(agent.version)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }

            Text(agent.model.id)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let system = agent.system, !system.isEmpty {
                Text(system)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

import SwiftUI

struct VaultsListView: View {
    @Environment(AppState.self) private var appState
    @State private var showCreateSheet = false
    @State private var selectedVault: Vault?
    @State private var credentials: [String: [Credential]] = [:]

    var body: some View {
        HSplitView {
            // List
            VStack(spacing: 0) {
                if appState.vaults.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 48))
                            .foregroundStyle(.tertiary)
                        Text("No vaults yet")
                            .foregroundStyle(.secondary)

                        GroupBox {
                            VStack(alignment: .leading, spacing: 4) {
                                Label("What is a Vault?", systemImage: "lightbulb")
                                    .font(.subheadline.bold())
                                Text("""
                                A **Vault** stores authentication credentials for external services (like GitHub, Slack, Linear). \
                                Each vault represents a user and their credentials.

                                When you start a session, you attach vaults so the agent can authenticate with MCP servers on behalf of that user.
                                """)
                                .font(.caption)
                            }
                            .padding(4)
                        }
                        .frame(maxWidth: 400)

                        Button("Create Vault") {
                            showCreateSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(appState.vaults, selection: Binding(
                        get: { selectedVault?.id },
                        set: { id in selectedVault = appState.vaults.first { $0.id == id } }
                    )) { vault in
                        VaultRow(vault: vault)
                            .tag(vault.id)
                    }
                    .listStyle(.inset)
                }
            }
            .frame(minWidth: 280)

            // Detail
            if let vault = selectedVault {
                VaultDetailView(
                    vault: vault,
                    credentials: credentials[vault.id] ?? []
                )
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("Select a vault to manage credentials")
                        .foregroundStyle(.secondary)
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
                .help("Create new vault")
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            VaultCreateView()
        }
        .onChange(of: selectedVault?.id) {
            Task { await loadCredentials() }
        }
        .navigationTitle("Vaults")
    }

    private func loadCredentials() async {
        guard let vault = selectedVault, let client = appState.client else { return }
        do {
            let creds = try await client.listCredentials(vaultId: vault.id)
            credentials[vault.id] = creds
        } catch {
            // Credentials may not be available yet
        }
    }
}

// MARK: - Vault Row

struct VaultRow: View {
    let vault: Vault

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(vault.displayName)
                .font(.headline)
            if let meta = vault.metadata, let userId = meta["external_user_id"] {
                Text(userId)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

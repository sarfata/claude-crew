import SwiftUI

struct VaultDetailView: View {
    let vault: Vault
    let credentials: [Credential]
    @Environment(AppState.self) private var appState
    @State private var showAddCredential = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(vault.displayName)
                            .font(.title2.bold())
                        if let meta = vault.metadata, !meta.isEmpty {
                            HStack(spacing: 8) {
                                ForEach(meta.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                                    Text("\(key): \(value)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    Spacer()
                    Button {
                        showAddCredential = true
                    } label: {
                        Label("Add Credential", systemImage: "plus")
                    }
                }

                Divider()

                // Credentials
                DetailSection(title: "Credentials", icon: "key") {
                    if credentials.isEmpty {
                        Text("No credentials yet. Add one to authenticate with MCP servers.")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    } else {
                        ForEach(credentials) { cred in
                            CredentialRow(credential: cred)
                        }
                    }
                }

                // Info
                DetailSection(title: "Info", icon: "info.circle") {
                    LabeledContent("Created", value: vault.createdAt.formatted())
                    LabeledContent("Updated", value: vault.updatedAt.formatted())
                    if let archived = vault.archivedAt {
                        LabeledContent("Archived", value: archived.formatted())
                    }
                    LabeledContent("ID", value: vault.id)
                        .textSelection(.enabled)
                }

                // Usage info
                GroupBox {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("How Vaults Work", systemImage: "lightbulb")
                            .font(.subheadline.bold())
                        Text("""
                        When you start a session, attach this vault via `vault_ids` to provide credentials. \
                        The agent will automatically authenticate with MCP servers that match the credential's URL.

                        Credentials are matched by `mcp_server_url`. One active credential per URL per vault.

                        Secret fields (tokens, secrets) are write-only and never returned in API responses.
                        """)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(4)
                }
            }
            .padding(20)
        }
        .sheet(isPresented: $showAddCredential) {
            AddCredentialView(vaultId: vault.id)
        }
    }
}

// MARK: - Credential Row

struct CredentialRow: View {
    let credential: Credential

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(credential.displayName)
                    .font(.headline)
                Spacer()
                Text(credential.auth.typeName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.blue.opacity(0.1), in: Capsule())
                    .foregroundStyle(.blue)
            }
            Text(credential.auth.mcpServerUrl)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}

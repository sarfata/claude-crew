import SwiftUI

struct EnvironmentsListView: View {
    @Environment(AppState.self) private var appState
    @State private var showCreateSheet = false
    @State private var selectedEnv: AgentEnvironment?

    var body: some View {
        HSplitView {
            // List
            List(appState.environments, selection: Binding(
                get: { selectedEnv?.id },
                set: { id in selectedEnv = appState.environments.first { $0.id == id } }
            )) { env in
                EnvironmentRow(environment: env)
                    .tag(env.id)
            }
            .listStyle(.inset)
            .frame(minWidth: 280)

            // Detail
            if let env = selectedEnv {
                EnvironmentDetailView(environment: env)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("Select an environment")
                        .foregroundStyle(.secondary)

                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("What is an Environment?", systemImage: "lightbulb")
                                .font(.headline)

                            Text("""
                            An **Environment** defines the cloud container where your agent runs. \
                            Think of it as a virtual machine template.

                            Each environment specifies:
                            """)
                            .font(.callout)

                            VStack(alignment: .leading, spacing: 4) {
                                Label("**Packages** - Pre-installed software (Python, Node.js, etc.)", systemImage: "shippingbox")
                                Label("**Networking** - What the agent can access online", systemImage: "network")
                            }
                            .font(.callout)

                            Text("""
                            You create an environment once, then reuse it across multiple sessions. \
                            Each session gets its own isolated container, so agents can't interfere with each other.
                            """)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        }
                        .padding(4)
                    }
                    .frame(maxWidth: 500)
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
                .help("Create new environment")
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            EnvironmentCreateView()
        }
        .navigationTitle("Environments")
    }
}

// MARK: - Environment Row

struct EnvironmentRow: View {
    let environment: AgentEnvironment

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(environment.name)
                .font(.headline)

            HStack(spacing: 8) {
                networkingBadge
                if let pkgs = environment.config.packages, !pkgs.isEmpty {
                    Image(systemName: "shippingbox")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var networkingBadge: some View {
        switch environment.config.networking {
        case .unrestricted:
            Text("unrestricted")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(.green.opacity(0.1), in: Capsule())
                .foregroundStyle(.green)
        case .limited:
            Text("limited")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(.orange.opacity(0.1), in: Capsule())
                .foregroundStyle(.orange)
        }
    }
}

// MARK: - Environment Detail

struct EnvironmentDetailView: View {
    let environment: AgentEnvironment
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Text(environment.name)
                        .font(.title2.bold())
                    Spacer()
                    if environment.archivedAt != nil {
                        Text("Archived")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.red.opacity(0.1), in: Capsule())
                            .foregroundStyle(.red)
                    }
                }

                Divider()

                // Networking
                DetailSection(title: "Networking", icon: "network") {
                    switch environment.config.networking {
                    case .unrestricted:
                        Text("Full outbound network access (except safety blocklist)")
                            .foregroundStyle(.secondary)
                    case .limited(let config):
                        VStack(alignment: .leading, spacing: 8) {
                            if !config.allowedHosts.isEmpty {
                                Text("Allowed hosts:")
                                    .font(.caption.bold())
                                ForEach(config.allowedHosts, id: \.self) { host in
                                    Text(host)
                                        .font(.caption.monospaced())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(.quaternary, in: Capsule())
                                }
                            }
                            LabeledContent("Allow MCP servers", value: config.allowMcpServers ? "Yes" : "No")
                            LabeledContent("Allow package managers", value: config.allowPackageManagers ? "Yes" : "No")
                        }
                    }
                }

                // Packages
                if let packages = environment.config.packages, !packages.isEmpty {
                    DetailSection(title: "Packages", icon: "shippingbox") {
                        PackagesList(packages: packages)
                    }
                }

                // Info
                DetailSection(title: "Info", icon: "info.circle") {
                    LabeledContent("Created", value: environment.createdAt.formatted())
                    LabeledContent("Updated", value: environment.updatedAt.formatted())
                    LabeledContent("ID", value: environment.id)
                        .textSelection(.enabled)
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Packages List

struct PackagesList: View {
    let packages: Packages

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            packageSection("apt", packages: packages.apt)
            packageSection("cargo", packages: packages.cargo)
            packageSection("gem", packages: packages.gem)
            packageSection("go", packages: packages.go)
            packageSection("npm", packages: packages.npm)
            packageSection("pip", packages: packages.pip)
        }
    }

    @ViewBuilder
    private func packageSection(_ manager: String, packages: [String]?) -> some View {
        if let pkgs = packages, !pkgs.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text(manager)
                    .font(.caption.bold())
                FlowLayout(spacing: 4) {
                    ForEach(pkgs, id: \.self) { pkg in
                        Text(pkg)
                            .font(.caption.monospaced())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }
                }
            }
        }
    }
}

import SwiftUI

struct EnvironmentCreateView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var networkingType = "unrestricted"
    @State private var allowedHosts: [String] = []
    @State private var newHost = ""
    @State private var allowMcpServers = false
    @State private var allowPackageManagers = false

    // Packages
    @State private var pipPackages = ""
    @State private var npmPackages = ""
    @State private var aptPackages = ""
    @State private var cargoPackages = ""
    @State private var gemPackages = ""
    @State private var goPackages = ""

    @State private var isSaving = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Create Environment")
                    .font(.title2.bold())
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Info box
                    GroupBox {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("About Environments", systemImage: "lightbulb")
                                .font(.subheadline.bold())
                            Text("An environment is a container template. It defines what software is installed and what network access your agent has. You create it once and reuse it across sessions.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(4)
                    }

                    // Name
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Name")
                            .font(.headline)
                        Text("Must be unique within your organization.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("e.g. python-dev, web-scraper", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Networking
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Networking")
                            .font(.headline)

                        Picker("Network access", selection: $networkingType) {
                            Text("Unrestricted").tag("unrestricted")
                            Text("Limited").tag("limited")
                        }
                        .pickerStyle(.segmented)

                        if networkingType == "unrestricted" {
                            Text("Full outbound network access, except for a general safety blocklist. Good for development and exploration.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Restricts network access to specific hosts. Recommended for production.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Allowed Hosts")
                                    .font(.subheadline.bold())
                                HStack {
                                    TextField("api.example.com", text: $newHost)
                                        .textFieldStyle(.roundedBorder)
                                    Button("Add") {
                                        if !newHost.isEmpty {
                                            allowedHosts.append(newHost)
                                            newHost = ""
                                        }
                                    }
                                }
                                ForEach(allowedHosts, id: \.self) { host in
                                    HStack {
                                        Text(host)
                                            .font(.caption.monospaced())
                                        Spacer()
                                        Button {
                                            allowedHosts.removeAll { $0 == host }
                                        } label: {
                                            Image(systemName: "xmark.circle")
                                                .foregroundStyle(.red)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                                }

                                Toggle("Allow MCP server connections", isOn: $allowMcpServers)
                                Toggle("Allow package manager registries", isOn: $allowPackageManagers)
                            }
                        }
                    }

                    // Packages
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Packages")
                            .font(.headline)
                        Text("Pre-install packages into the container. Separate multiple packages with commas or newlines.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ForEach(PackageManager.allCases, id: \.self) { pm in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pm.displayName)
                                    .font(.subheadline)
                                TextField("e.g. \(pm.example)", text: bindingForPackageManager(pm))
                                    .textFieldStyle(.roundedBorder)
                                    .font(.body.monospaced())
                            }
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

            HStack {
                Spacer()
                Button {
                    Task { await createEnvironment() }
                } label: {
                    if isSaving {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Creating...")
                        }
                    } else {
                        Text("Create Environment")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || isSaving)
            }
            .padding()
        }
        .frame(width: 600, height: 700)
    }

    private func bindingForPackageManager(_ pm: PackageManager) -> Binding<String> {
        switch pm {
        case .pip: return $pipPackages
        case .npm: return $npmPackages
        case .apt: return $aptPackages
        case .cargo: return $cargoPackages
        case .gem: return $gemPackages
        case .go: return $goPackages
        }
    }

    private func parsePackages(_ text: String) -> [String]? {
        let pkgs = text.split(whereSeparator: { $0 == "," || $0.isNewline })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return pkgs.isEmpty ? nil : pkgs
    }

    private func createEnvironment() async {
        guard let client = appState.client else { return }
        isSaving = true
        error = nil

        let networking: Networking
        if networkingType == "limited" {
            networking = .limited(.init(
                allowedHosts: allowedHosts,
                allowMcpServers: allowMcpServers,
                allowPackageManagers: allowPackageManagers
            ))
        } else {
            networking = .unrestricted
        }

        let packages = Packages(
            apt: parsePackages(aptPackages),
            cargo: parsePackages(cargoPackages),
            gem: parsePackages(gemPackages),
            go: parsePackages(goPackages),
            npm: parsePackages(npmPackages),
            pip: parsePackages(pipPackages)
        )

        let config = CloudConfig(
            packages: packages.isEmpty ? nil : packages,
            networking: networking
        )

        let params = EnvironmentCreateParams(name: name, config: config)

        do {
            _ = try await client.createEnvironment(params: params)
            await appState.refreshEnvironments()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }

        isSaving = false
    }
}

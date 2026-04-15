import SwiftUI

struct AddCredentialView: View {
    let vaultId: String
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var credentialType = "static_bearer"
    @State private var mcpServerUrl = ""
    @State private var token = ""

    // OAuth fields
    @State private var accessToken = ""
    @State private var expiresAt = ""
    @State private var tokenEndpoint = ""
    @State private var clientId = ""
    @State private var scope = ""
    @State private var refreshToken = ""
    @State private var authType = "none"
    @State private var clientSecret = ""

    @State private var isSaving = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Credential")
                    .font(.title2.bold())
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Display Name")
                            .font(.headline)
                        TextField("e.g. Alice's Slack", text: $displayName)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Type")
                            .font(.headline)
                        Picker("Type", selection: $credentialType) {
                            Text("Static Bearer Token").tag("static_bearer")
                            Text("MCP OAuth").tag("mcp_oauth")
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("MCP Server URL")
                            .font(.headline)
                        TextField("https://mcp.example.com/mcp", text: $mcpServerUrl)
                            .textFieldStyle(.roundedBorder)
                        Text("Must match the MCP server URL configured on the agent.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if credentialType == "static_bearer" {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Token")
                                .font(.headline)
                            SecureField("API key or token", text: $token)
                                .textFieldStyle(.roundedBorder)
                        }
                    } else {
                        // OAuth fields
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Access Token")
                                .font(.headline)
                            SecureField("OAuth access token", text: $accessToken)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Expires At")
                                .font(.headline)
                            TextField("2026-04-15T00:00:00Z", text: $expiresAt)
                                .textFieldStyle(.roundedBorder)
                        }

                        GroupBox("Refresh Configuration (Optional)") {
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("Token endpoint URL", text: $tokenEndpoint)
                                    .textFieldStyle(.roundedBorder)
                                TextField("Client ID", text: $clientId)
                                    .textFieldStyle(.roundedBorder)
                                TextField("Scope", text: $scope)
                                    .textFieldStyle(.roundedBorder)
                                SecureField("Refresh token", text: $refreshToken)
                                    .textFieldStyle(.roundedBorder)

                                Picker("Auth method", selection: $authType) {
                                    Text("None (public client)").tag("none")
                                    Text("Client Secret (Basic)").tag("client_secret_basic")
                                    Text("Client Secret (POST)").tag("client_secret_post")
                                }

                                if authType != "none" {
                                    SecureField("Client secret", text: $clientSecret)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }
                            .padding(4)
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
                    Task { await addCredential() }
                } label: {
                    if isSaving {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Adding...")
                        }
                    } else {
                        Text("Add Credential")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(displayName.isEmpty || mcpServerUrl.isEmpty || isSaving)
            }
            .padding()
        }
        .frame(width: 550, height: 650)
    }

    private func addCredential() async {
        guard let client = appState.client else { return }
        isSaving = true
        error = nil

        let auth: CredentialAuth
        if credentialType == "static_bearer" {
            auth = .staticBearer(.init(
                type: "static_bearer",
                mcpServerUrl: mcpServerUrl,
                token: token
            ))
        } else {
            var refresh: CredentialAuth.OAuthRefresh?
            if !tokenEndpoint.isEmpty {
                refresh = .init(
                    tokenEndpoint: tokenEndpoint,
                    clientId: clientId,
                    scope: scope.isEmpty ? nil : scope,
                    refreshToken: refreshToken.isEmpty ? nil : refreshToken,
                    tokenEndpointAuth: .init(
                        type: authType,
                        clientSecret: authType != "none" ? clientSecret : nil
                    )
                )
            }
            auth = .mcpOAuth(.init(
                type: "mcp_oauth",
                mcpServerUrl: mcpServerUrl,
                accessToken: accessToken,
                expiresAt: expiresAt.isEmpty ? nil : expiresAt,
                refresh: refresh
            ))
        }

        let params = CredentialCreateParams(displayName: displayName, auth: auth)

        do {
            _ = try await client.createCredential(vaultId: vaultId, params: params)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }

        isSaving = false
    }
}

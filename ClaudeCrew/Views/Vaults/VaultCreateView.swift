import SwiftUI

struct VaultCreateView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var externalUserId = ""
    @State private var isSaving = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Create Vault")
                    .font(.title2.bold())
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("About Vaults", systemImage: "lightbulb")
                            .font(.subheadline.bold())
                        Text("A vault groups credentials for one user. Give it a display name (like the user's name) and optionally an external user ID for mapping back to your systems.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(4)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Display Name")
                        .font(.headline)
                    TextField("e.g. Alice", text: $displayName)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("External User ID (optional)")
                        .font(.headline)
                    TextField("e.g. usr_abc123", text: $externalUserId)
                        .textFieldStyle(.roundedBorder)
                    Text("Stored as metadata for mapping to your own user records.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let error {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            .padding()

            Spacer()

            Divider()

            HStack {
                Spacer()
                Button {
                    Task { await createVault() }
                } label: {
                    if isSaving {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Creating...")
                        }
                    } else {
                        Text("Create Vault")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(displayName.isEmpty || isSaving)
            }
            .padding()
        }
        .frame(width: 450, height: 400)
    }

    private func createVault() async {
        guard let client = appState.client else { return }
        isSaving = true
        error = nil

        var metadata: [String: String]?
        if !externalUserId.isEmpty {
            metadata = ["external_user_id": externalUserId]
        }

        let params = VaultCreateParams(displayName: displayName, metadata: metadata)

        do {
            _ = try await client.createVault(params: params)
            await appState.refreshVaults()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }

        isSaving = false
    }
}

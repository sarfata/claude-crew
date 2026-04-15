import Foundation
import SwiftUI

@MainActor
@Observable
final class AppState {
    var client: AnthropicClient?
    var hasAPIKey: Bool = false
    var isLoading: Bool = false
    var error: String?

    // Navigation
    var selectedSection: SidebarSection? = .sessions
    var selectedAgentId: String?
    var selectedEnvironmentId: String?
    var selectedSessionId: String?
    var selectedVaultId: String?

    // Data
    var agents: [Agent] = []
    var environments: [AgentEnvironment] = []
    var sessions: [Session] = []
    var vaults: [Vault] = []

    init() {
        loadAPIKey()
    }

    func loadAPIKey() {
        // Environment variable takes priority — avoids Keychain password prompts during development/testing
        if let envKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !envKey.isEmpty {
            client = AnthropicClient(apiKey: envKey)
            hasAPIKey = true
        } else if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            // Running as test host — skip Keychain to avoid password prompts
            hasAPIKey = false
        } else if let key = KeychainHelper.load() {
            client = AnthropicClient(apiKey: key)
            hasAPIKey = true
        } else {
            hasAPIKey = false
        }
    }

    func setAPIKey(_ key: String) throws {
        try KeychainHelper.save(apiKey: key)
        client = AnthropicClient(apiKey: key)
        hasAPIKey = true
    }

    func clearAPIKey() {
        KeychainHelper.delete()
        client = nil
        hasAPIKey = false
    }

    func refreshAll() async {
        guard let client else { return }
        isLoading = true
        error = nil

        async let agentsResult = client.listAgents()
        async let environmentsResult = client.listEnvironments()
        async let sessionsResult = client.listSessions()
        async let vaultsResult = client.listVaults()

        do {
            agents = try await agentsResult
            environments = try await environmentsResult
            sessions = try await sessionsResult
            vaults = try await vaultsResult
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func refreshAgents() async {
        guard let client else { return }
        do {
            agents = try await client.listAgents()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func refreshEnvironments() async {
        guard let client else { return }
        do {
            environments = try await client.listEnvironments()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func refreshSessions() async {
        guard let client else { return }
        do {
            sessions = try await client.listSessions()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func refreshVaults() async {
        guard let client else { return }
        do {
            vaults = try await client.listVaults()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // Active session count
    var activeSessionCount: Int {
        sessions.filter { $0.status == .running }.count
    }

    var idleSessionCount: Int {
        sessions.filter { $0.status == .idle }.count
    }
}

// MARK: - Sidebar Sections

enum SidebarSection: String, CaseIterable, Identifiable, Hashable, Sendable {
    case sessions = "Sessions"
    case agents = "Agents"
    case environments = "Environments"
    case vaults = "Vaults"
    case settings = "Settings"

    var id: Self { self }

    var icon: String {
        switch self {
        case .sessions: return "bubble.left.and.bubble.right"
        case .agents: return "person.2"
        case .environments: return "server.rack"
        case .vaults: return "lock.shield"
        case .settings: return "gear"
        }
    }
}

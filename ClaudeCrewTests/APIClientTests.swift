import XCTest
@testable import Claude_Crew

/// Smoke tests that hit the real Anthropic API.
/// Requires ANTHROPIC_API_KEY environment variable or a key in Keychain.
final class APIClientTests: XCTestCase {

    private var client: AnthropicClient!
    private var hasAPIKey = false

    override func setUp() async throws {
        // Read API key: env var first, then fallback to ~/.claude-crew-test-key file
        // Never touch Keychain from tests (triggers password prompts on every build)
        let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]
            ?? (try? String(contentsOfFile: NSHomeDirectory() + "/.claude-crew-test-key", encoding: .utf8))?
                .trimmingCharacters(in: .whitespacesAndNewlines)

        if let key, !key.isEmpty {
            client = AnthropicClient(apiKey: key)
            hasAPIKey = true
        }
    }

    private func skipIfNoKey() throws {
        try XCTSkipUnless(hasAPIKey, "No ANTHROPIC_API_KEY — skipping live API test")
    }

    // MARK: - Agents

    func testListAgents() async throws {
        try skipIfNoKey()
        let agents = try await client.listAgents()
        // Should not throw; may be empty
        XCTAssertNotNil(agents)
        print("  [smoke] Listed \(agents.count) agents")
    }

    // MARK: - Environments

    func testListEnvironments() async throws {
        try skipIfNoKey()
        let envs = try await client.listEnvironments()
        XCTAssertNotNil(envs)
        print("  [smoke] Listed \(envs.count) environments")
    }

    // MARK: - Sessions

    func testListSessions() async throws {
        try skipIfNoKey()
        let sessions = try await client.listSessions()
        XCTAssertNotNil(sessions)
        print("  [smoke] Listed \(sessions.count) sessions")

        // If there's at least one session, verify we can retrieve it
        if let first = sessions.first {
            let retrieved = try await client.getSession(id: first.id)
            XCTAssertEqual(retrieved.id, first.id)
            XCTAssertNotNil(retrieved.status)
            print("  [smoke] Retrieved session \(first.id) — status: \(retrieved.status.rawValue)")
        }
    }

    // MARK: - Vaults

    func testListVaults() async throws {
        try skipIfNoKey()
        let vaults = try await client.listVaults()
        XCTAssertNotNil(vaults)
        print("  [smoke] Listed \(vaults.count) vaults")
    }

    // MARK: - Full flow: create agent + environment + session

    func testCreateAndCleanup() async throws {
        try skipIfNoKey()

        // 1. Create agent
        let agentParams = AgentCreateParams(
            name: "smoke-test-\(Int.random(in: 1000...9999))",
            model: "claude-sonnet-4-6",
            system: "You are a test agent. Respond briefly.",
            tools: [.toolset(.init(type: "agent_toolset_20260401"))]
        )
        let agent = try await client.createAgent(params: agentParams)
        XCTAssertFalse(agent.id.isEmpty)
        XCTAssertEqual(agent.version, 1)
        print("  [smoke] Created agent: \(agent.id)")

        // 2. Create environment
        let envParams = EnvironmentCreateParams(
            name: "smoke-test-\(Int.random(in: 1000...9999))",
            config: CloudConfig(networking: .unrestricted)
        )
        let env = try await client.createEnvironment(params: envParams)
        XCTAssertFalse(env.id.isEmpty)
        print("  [smoke] Created environment: \(env.id)")

        // 3. Create session
        let sessionParams = SessionCreateParams(
            agent: agent.id,
            environmentId: env.id,
            title: "Smoke test session"
        )
        let session = try await client.createSession(params: sessionParams)
        XCTAssertFalse(session.id.isEmpty)
        XCTAssertEqual(session.status, .idle)
        print("  [smoke] Created session: \(session.id) — status: \(session.status.rawValue)")

        // 4. Send a message
        try await client.sendMessage(sessionId: session.id, text: "Say hello in one word.")
        print("  [smoke] Sent message to session")

        // 5. Brief pause to let agent start
        try await Task.sleep(for: .seconds(2))

        // 6. Verify session is running or idle
        let updated = try await client.getSession(id: session.id)
        XCTAssertTrue([.running, .idle].contains(updated.status),
                       "Expected running or idle, got \(updated.status.rawValue)")
        print("  [smoke] Session status after message: \(updated.status.rawValue)")

        // 7. Cleanup — interrupt if running, wait for idle, then archive
        if updated.status == .running {
            try await client.sendInterrupt(sessionId: session.id)
            print("  [smoke] Sent interrupt")

            // Poll until idle (max 30s)
            for _ in 0..<15 {
                try await Task.sleep(for: .seconds(2))
                let polled = try await client.getSession(id: session.id)
                if polled.status == .idle {
                    break
                }
                print("  [smoke] Waiting for idle... currently \(polled.status.rawValue)")
            }
        }

        try await client.archiveSession(id: session.id)
        print("  [smoke] Archived session")

        _ = try await client.archiveAgent(id: agent.id)
        print("  [smoke] Archived agent")

        try await client.archiveEnvironment(id: env.id)
        print("  [smoke] Archived environment")

        print("  [smoke] Full flow test PASSED")
    }

    // MARK: - Error handling

    func testInvalidAgentReturnsError() async throws {
        try skipIfNoKey()

        do {
            _ = try await client.getAgent(id: "agent_nonexistent")
            XCTFail("Should have thrown")
        } catch let error as APIError {
            if case .httpError(let code, _) = error {
                XCTAssertTrue([400, 404].contains(code), "Expected 400 or 404, got \(code)")
                print("  [smoke] Correctly got \(code) for nonexistent agent")
            } else {
                XCTFail("Expected httpError, got \(error)")
            }
        }
    }

    func testInvalidSessionReturnsError() async throws {
        try skipIfNoKey()

        do {
            _ = try await client.getSession(id: "sesn_nonexistent")
            XCTFail("Should have thrown")
        } catch let error as APIError {
            if case .httpError(let code, _) = error {
                XCTAssertTrue([404, 400].contains(code), "Expected 404 or 400, got \(code)")
                print("  [smoke] Correctly got \(code) for nonexistent session")
            } else {
                XCTFail("Expected httpError, got \(error)")
            }
        }
    }
}

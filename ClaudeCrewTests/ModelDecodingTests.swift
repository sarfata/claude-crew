import XCTest
@testable import Claude_Crew

final class ModelDecodingTests: XCTestCase {

    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: string) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(string)")
        }
        return d
    }

    private var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }

    // MARK: - Agent

    func testDecodeAgent() throws {
        let json = """
        {
          "id": "agent_01HqR2k7vXbZ9mNpL3wYcT8f",
          "type": "agent",
          "name": "Coding Assistant",
          "model": {"id": "claude-sonnet-4-6", "speed": "standard"},
          "system": "You are a helpful coding agent.",
          "description": null,
          "tools": [
            {
              "type": "agent_toolset_20260401",
              "default_config": {"permission_policy": {"type": "always_allow"}}
            }
          ],
          "skills": [],
          "mcp_servers": [],
          "metadata": {},
          "version": 1,
          "created_at": "2026-04-03T18:24:10.412Z",
          "updated_at": "2026-04-03T18:24:10.412Z",
          "archived_at": null
        }
        """.data(using: .utf8)!

        let agent = try decoder.decode(Agent.self, from: json)
        XCTAssertEqual(agent.id, "agent_01HqR2k7vXbZ9mNpL3wYcT8f")
        XCTAssertEqual(agent.name, "Coding Assistant")
        XCTAssertEqual(agent.model.id, "claude-sonnet-4-6")
        XCTAssertEqual(agent.model.speed, "standard")
        XCTAssertEqual(agent.system, "You are a helpful coding agent.")
        XCTAssertEqual(agent.version, 1)
        XCTAssertEqual(agent.tools.count, 1)
        XCTAssertTrue(agent.mcpServers.isEmpty)
        XCTAssertNil(agent.archivedAt)
    }

    func testDecodeAgentWithStringModel() throws {
        let json = """
        {
          "id": "agent_01test",
          "type": "agent",
          "name": "Test",
          "model": "claude-sonnet-4-6",
          "tools": [],
          "skills": [],
          "mcp_servers": [],
          "metadata": {},
          "version": 1,
          "created_at": "2026-04-03T18:00:00Z",
          "updated_at": "2026-04-03T18:00:00Z",
          "archived_at": null
        }
        """.data(using: .utf8)!

        let agent = try decoder.decode(Agent.self, from: json)
        XCTAssertEqual(agent.model.id, "claude-sonnet-4-6")
        XCTAssertNil(agent.model.speed)
    }

    func testDecodeAgentWithCustomTool() throws {
        let json = """
        {
          "id": "agent_02",
          "type": "agent",
          "name": "Weather Agent",
          "model": {"id": "claude-sonnet-4-6"},
          "tools": [
            {"type": "agent_toolset_20260401"},
            {
              "type": "custom",
              "name": "get_weather",
              "description": "Get weather for a location",
              "input_schema": {
                "type": "object",
                "properties": {"location": {"type": "string", "description": "City"}},
                "required": ["location"]
              }
            }
          ],
          "skills": [],
          "mcp_servers": [],
          "metadata": {},
          "version": 1,
          "created_at": "2026-04-03T18:00:00Z",
          "updated_at": "2026-04-03T18:00:00Z",
          "archived_at": null
        }
        """.data(using: .utf8)!

        let agent = try decoder.decode(Agent.self, from: json)
        XCTAssertEqual(agent.tools.count, 2)
        if case .custom(let tool) = agent.tools[1] {
            XCTAssertEqual(tool.name, "get_weather")
            XCTAssertEqual(tool.description, "Get weather for a location")
        } else {
            XCTFail("Expected custom tool")
        }
    }

    // MARK: - Environment

    func testDecodeEnvironment() throws {
        let json = """
        {
          "id": "env_01abc",
          "type": "environment",
          "name": "python-dev",
          "config": {
            "type": "cloud",
            "packages": {"pip": ["pandas", "numpy"], "npm": ["express"]},
            "networking": {"type": "unrestricted"}
          },
          "created_at": "2026-04-03T18:00:00Z",
          "updated_at": "2026-04-03T18:00:00Z",
          "archived_at": null
        }
        """.data(using: .utf8)!

        let env = try decoder.decode(AgentEnvironment.self, from: json)
        XCTAssertEqual(env.id, "env_01abc")
        XCTAssertEqual(env.name, "python-dev")
        XCTAssertEqual(env.config.type, "cloud")
        XCTAssertEqual(env.config.packages?.pip, ["pandas", "numpy"])
        XCTAssertEqual(env.config.packages?.npm, ["express"])
        if case .unrestricted = env.config.networking {} else {
            XCTFail("Expected unrestricted networking")
        }
    }

    func testDecodeEnvironmentWithLimitedNetworking() throws {
        let json = """
        {
          "id": "env_02",
          "type": "environment",
          "name": "prod",
          "config": {
            "type": "cloud",
            "networking": {
              "type": "limited",
              "allowed_hosts": ["api.example.com"],
              "allow_mcp_servers": true,
              "allow_package_managers": false
            }
          },
          "created_at": "2026-04-03T18:00:00Z",
          "updated_at": "2026-04-03T18:00:00Z",
          "archived_at": null
        }
        """.data(using: .utf8)!

        let env = try decoder.decode(AgentEnvironment.self, from: json)
        if case .limited(let config) = env.config.networking {
            XCTAssertEqual(config.allowedHosts, ["api.example.com"])
            XCTAssertTrue(config.allowMcpServers)
            XCTAssertFalse(config.allowPackageManagers)
        } else {
            XCTFail("Expected limited networking")
        }
    }

    // MARK: - Session

    func testDecodeSession() throws {
        let json = """
        {
          "id": "sesn_01abc",
          "type": "session",
          "title": "My session",
          "agent_id": "agent_01",
          "environment_id": "env_01",
          "status": "running",
          "created_at": "2026-04-03T18:00:00Z",
          "updated_at": "2026-04-03T18:00:00.500Z",
          "archived_at": null
        }
        """.data(using: .utf8)!

        let session = try decoder.decode(Session.self, from: json)
        XCTAssertEqual(session.id, "sesn_01abc")
        XCTAssertEqual(session.title, "My session")
        XCTAssertEqual(session.status, .running)
        XCTAssertEqual(session.agentId, "agent_01")
    }

    func testAllSessionStatuses() throws {
        for status in ["idle", "running", "rescheduling", "terminated"] {
            let json = """
            {
              "id": "sesn_\(status)",
              "type": "session",
              "status": "\(status)",
              "created_at": "2026-04-03T18:00:00Z",
              "updated_at": "2026-04-03T18:00:00Z",
              "archived_at": null
            }
            """.data(using: .utf8)!
            let session = try decoder.decode(Session.self, from: json)
            XCTAssertEqual(session.status.rawValue, status)
        }
    }

    // MARK: - Vault

    func testDecodeVault() throws {
        let json = """
        {
          "type": "vault",
          "id": "vlt_01ABC",
          "display_name": "Alice",
          "metadata": {"external_user_id": "usr_abc123"},
          "created_at": "2026-03-18T10:00:00Z",
          "updated_at": "2026-03-18T10:00:00Z",
          "archived_at": null
        }
        """.data(using: .utf8)!

        let vault = try decoder.decode(Vault.self, from: json)
        XCTAssertEqual(vault.id, "vlt_01ABC")
        XCTAssertEqual(vault.displayName, "Alice")
        XCTAssertEqual(vault.metadata?["external_user_id"], "usr_abc123")
    }

    // MARK: - Credential

    func testDecodeStaticBearerCredential() throws {
        let json = """
        {
          "id": "cred_01",
          "type": "credential",
          "display_name": "Linear API key",
          "auth": {
            "type": "static_bearer",
            "mcp_server_url": "https://mcp.linear.app/mcp"
          },
          "created_at": "2026-04-03T18:00:00Z",
          "updated_at": "2026-04-03T18:00:00Z",
          "archived_at": null
        }
        """.data(using: .utf8)!

        let cred = try decoder.decode(Credential.self, from: json)
        XCTAssertEqual(cred.displayName, "Linear API key")
        XCTAssertEqual(cred.auth.typeName, "Static Bearer")
        XCTAssertEqual(cred.auth.mcpServerUrl, "https://mcp.linear.app/mcp")
    }

    func testDecodeOAuthCredential() throws {
        let json = """
        {
          "id": "cred_02",
          "type": "credential",
          "display_name": "Slack",
          "auth": {
            "type": "mcp_oauth",
            "mcp_server_url": "https://mcp.slack.com/mcp"
          },
          "created_at": "2026-04-03T18:00:00Z",
          "updated_at": "2026-04-03T18:00:00Z",
          "archived_at": null
        }
        """.data(using: .utf8)!

        let cred = try decoder.decode(Credential.self, from: json)
        XCTAssertEqual(cred.auth.typeName, "OAuth")
        XCTAssertEqual(cred.auth.mcpServerUrl, "https://mcp.slack.com/mcp")
    }

    // MARK: - Events

    func testDecodeAgentMessageEvent() throws {
        let json = """
        {
          "type": "agent.message",
          "sequence_number": 3,
          "content": [{"type": "text", "text": "Hello, I'll help you."}]
        }
        """.data(using: .utf8)!

        let event = try decoder.decode(SessionEvent.self, from: json)
        XCTAssertEqual(event.type, "agent.message")
        XCTAssertEqual(event.sequenceNumber, 3)
        XCTAssertEqual(event.content?.first?.text, "Hello, I'll help you.")
        XCTAssertEqual(event.displayType, .message)
    }

    func testDecodeToolUseEvent() throws {
        let json = """
        {
          "type": "agent.tool_use",
          "name": "bash",
          "tool_use_id": "tu_01abc"
        }
        """.data(using: .utf8)!

        let event = try decoder.decode(SessionEvent.self, from: json)
        XCTAssertEqual(event.type, "agent.tool_use")
        XCTAssertEqual(event.name, "bash")
        XCTAssertEqual(event.toolUseId, "tu_01abc")
        XCTAssertEqual(event.displayType, .toolUse)
    }

    func testDecodeStatusEvents() throws {
        let idleJson = """
        {"type": "session.status_idle"}
        """.data(using: .utf8)!
        let idle = try decoder.decode(SessionEvent.self, from: idleJson)
        XCTAssertEqual(idle.displayType, .statusIdle)

        let runningJson = """
        {"type": "session.status_running"}
        """.data(using: .utf8)!
        let running = try decoder.decode(SessionEvent.self, from: runningJson)
        XCTAssertEqual(running.displayType, .statusRunning)
    }

    func testDecodeErrorEvent() throws {
        let json = """
        {
          "type": "session.error",
          "error": {"type": "auth_error", "message": "Invalid token"}
        }
        """.data(using: .utf8)!

        let event = try decoder.decode(SessionEvent.self, from: json)
        XCTAssertEqual(event.displayType, .error)
        XCTAssertEqual(event.error?.type, "auth_error")
        XCTAssertEqual(event.error?.message, "Invalid token")
    }

    // MARK: - Encoding

    func testEncodeAgentCreateParams() throws {
        let params = AgentCreateParams(
            name: "Test Agent",
            model: "claude-sonnet-4-6",
            system: "Be helpful",
            tools: [
                .toolset(.init(
                    type: "agent_toolset_20260401",
                    configs: [ToolConfig(name: "web_fetch", enabled: false)]
                ))
            ]
        )

        let data = try encoder.encode(params)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["name"] as? String, "Test Agent")
        XCTAssertEqual(json["model"] as? String, "claude-sonnet-4-6")

        let tools = json["tools"] as? [[String: Any]]
        XCTAssertEqual(tools?.count, 1)
        XCTAssertEqual(tools?.first?["type"] as? String, "agent_toolset_20260401")
    }

    func testEncodeSessionCreateParams() throws {
        let params = SessionCreateParams(
            agent: "agent_01",
            environmentId: "env_01",
            vaultIds: ["vlt_01"],
            title: "Test session"
        )

        let data = try encoder.encode(params)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["agent"] as? String, "agent_01")
        XCTAssertEqual(json["environment_id"] as? String, "env_01")
        XCTAssertEqual(json["vault_ids"] as? [String], ["vlt_01"])
        XCTAssertEqual(json["title"] as? String, "Test session")
    }

    func testEncodeEnvironmentCreateParams() throws {
        let params = EnvironmentCreateParams(
            name: "test-env",
            config: CloudConfig(
                packages: Packages(pip: ["pandas"]),
                networking: .limited(.init(
                    allowedHosts: ["api.example.com"],
                    allowMcpServers: true,
                    allowPackageManagers: false
                ))
            )
        )

        let data = try encoder.encode(params)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["name"] as? String, "test-env")
        let config = json["config"] as? [String: Any]
        XCTAssertEqual(config?["type"] as? String, "cloud")
    }

    // MARK: - Paginated Response

    func testDecodePaginatedResponse() throws {
        let json = """
        {
          "data": [
            {
              "id": "sesn_01",
              "type": "session",
              "status": "idle",
              "created_at": "2026-04-03T18:00:00Z",
              "updated_at": "2026-04-03T18:00:00Z",
              "archived_at": null
            }
          ],
          "has_more": false,
          "first_id": "sesn_01",
          "last_id": "sesn_01"
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(PaginatedResponse<Session>.self, from: json)
        XCTAssertEqual(response.data.count, 1)
        XCTAssertEqual(response.data[0].id, "sesn_01")
        XCTAssertEqual(response.hasMore, false)
    }
}

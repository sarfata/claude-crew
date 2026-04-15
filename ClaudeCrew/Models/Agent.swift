import Foundation

// MARK: - Agent

struct Agent: Codable, Identifiable, Sendable {
    let id: String
    let type: String?
    var name: String
    var model: ModelConfig
    var system: String?
    var description: String?
    var tools: [AgentTool]
    var mcpServers: [MCPServer]
    var skills: [Skill]
    var metadata: [String: String]
    let version: Int
    let createdAt: Date
    let updatedAt: Date
    let archivedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, type, name, model, system, description, tools
        case mcpServers = "mcp_servers"
        case skills, metadata, version
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case archivedAt = "archived_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        name = try container.decode(String.self, forKey: .name)
        model = try container.decode(ModelConfig.self, forKey: .model)
        system = try container.decodeIfPresent(String.self, forKey: .system)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        tools = (try? container.decode([AgentTool].self, forKey: .tools)) ?? []
        mcpServers = (try? container.decode([MCPServer].self, forKey: .mcpServers)) ?? []
        skills = (try? container.decode([Skill].self, forKey: .skills)) ?? []
        metadata = (try? container.decode([String: String].self, forKey: .metadata)) ?? [:]
        // version can be int or string
        if let intVersion = try? container.decode(Int.self, forKey: .version) {
            version = intVersion
        } else if let strVersion = try? container.decode(String.self, forKey: .version),
                  let parsed = Int(strVersion) {
            version = parsed
        } else {
            version = 0
        }
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        archivedAt = try container.decodeIfPresent(Date.self, forKey: .archivedAt)
    }
}

// MARK: - Model Config

struct ModelConfig: Codable, Sendable {
    var id: String
    var speed: String?

    init(id: String, speed: String? = nil) {
        self.id = id
        self.speed = speed
    }

    init(from decoder: Decoder) throws {
        // Handle both string and object forms
        if let container = try? decoder.singleValueContainer(),
           let stringValue = try? container.decode(String.self) {
            self.id = stringValue
            self.speed = nil
        } else {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.id = try container.decode(String.self, forKey: .id)
            self.speed = try container.decodeIfPresent(String.self, forKey: .speed)
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, speed
    }
}

// MARK: - Tools

enum AgentTool: Codable, Sendable {
    case toolset(AgentToolset)
    case mcpToolset(MCPToolset)
    case custom(CustomTool)

    struct AgentToolset: Codable, Sendable {
        let type: String // "agent_toolset_20260401"
        var defaultConfig: ToolDefaultConfig?
        var configs: [ToolConfig]?

        enum CodingKeys: String, CodingKey {
            case type
            case defaultConfig = "default_config"
            case configs
        }
    }

    struct MCPToolset: Codable, Sendable {
        let type: String // "mcp_toolset"
        var mcpServerName: String

        enum CodingKeys: String, CodingKey {
            case type
            case mcpServerName = "mcp_server_name"
        }
    }

    struct CustomTool: Codable, Sendable {
        let type: String // "custom"
        var name: String
        var description: String
        var inputSchema: InputSchema

        enum CodingKeys: String, CodingKey {
            case type, name, description
            case inputSchema = "input_schema"
        }
    }

    struct InputSchema: Codable, Sendable {
        var type: String
        var properties: [String: SchemaProperty]?
        var required: [String]?
    }

    struct SchemaProperty: Codable, Sendable {
        var type: String
        var description: String?
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TypeKey.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case let t where t.hasPrefix("agent_toolset"):
            self = .toolset(try AgentToolset(from: decoder))
        case "mcp_toolset":
            self = .mcpToolset(try MCPToolset(from: decoder))
        case "custom":
            self = .custom(try CustomTool(from: decoder))
        default:
            self = .toolset(try AgentToolset(from: decoder))
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .toolset(let t): try t.encode(to: encoder)
        case .mcpToolset(let t): try t.encode(to: encoder)
        case .custom(let t): try t.encode(to: encoder)
        }
    }

    private enum TypeKey: String, CodingKey {
        case type
    }
}

struct ToolDefaultConfig: Codable, Sendable {
    var enabled: Bool?
    var permissionPolicy: PermissionPolicy?

    enum CodingKeys: String, CodingKey {
        case enabled
        case permissionPolicy = "permission_policy"
    }
}

struct PermissionPolicy: Codable, Sendable {
    var type: String // "always_allow", "always_ask"
}

struct ToolConfig: Codable, Sendable {
    var name: String
    var enabled: Bool
}

// MARK: - MCP Server

struct MCPServer: Codable, Sendable, Identifiable {
    var id: String { name }
    let type: String // "url"
    var name: String
    var url: String
}

// MARK: - Skill

struct Skill: Codable, Sendable {
    // Skills are a managed agents feature - placeholder for now
    var type: String?
}

// MARK: - Available Models

enum AvailableModel: String, CaseIterable, Sendable {
    case claudeOpus = "claude-opus-4-6"
    case claudeSonnet = "claude-sonnet-4-6"
    case claudeHaiku = "claude-haiku-4-5-20251001"

    var displayName: String {
        switch self {
        case .claudeOpus: return "Claude Opus 4.6"
        case .claudeSonnet: return "Claude Sonnet 4.6"
        case .claudeHaiku: return "Claude Haiku 4.5"
        }
    }
}

// MARK: - Available Agent Tools

enum AvailableAgentTool: String, CaseIterable, Sendable {
    case bash, read, write, edit, glob, grep
    case webFetch = "web_fetch"
    case webSearch = "web_search"

    var displayName: String {
        switch self {
        case .bash: return "Bash"
        case .read: return "Read"
        case .write: return "Write"
        case .edit: return "Edit"
        case .glob: return "Glob"
        case .grep: return "Grep"
        case .webFetch: return "Web Fetch"
        case .webSearch: return "Web Search"
        }
    }

    var description: String {
        switch self {
        case .bash: return "Execute bash commands in a shell session"
        case .read: return "Read a file from the local filesystem"
        case .write: return "Write a file to the local filesystem"
        case .edit: return "Perform string replacement in a file"
        case .glob: return "Fast file pattern matching using glob patterns"
        case .grep: return "Text search using regex patterns"
        case .webFetch: return "Fetch content from a URL"
        case .webSearch: return "Search the web for information"
        }
    }
}

// MARK: - Create/Update Params

struct AgentCreateParams: Codable, Sendable {
    var name: String
    var model: String
    var system: String?
    var description: String?
    var tools: [AgentTool]
    var mcpServers: [MCPServer]?
    var metadata: [String: String]?

    enum CodingKeys: String, CodingKey {
        case name, model, system, description, tools
        case mcpServers = "mcp_servers"
        case metadata
    }
}

struct AgentUpdateParams: Codable, Sendable {
    var version: Int
    var name: String?
    var model: String?
    var system: String?
    var description: String?
    var tools: [AgentTool]?
    var mcpServers: [MCPServer]?
    var metadata: [String: String]?

    enum CodingKeys: String, CodingKey {
        case version, name, model, system, description, tools
        case mcpServers = "mcp_servers"
        case metadata
    }
}

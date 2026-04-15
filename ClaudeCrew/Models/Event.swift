import Foundation

// MARK: - Session Event (received from stream)

struct SessionEvent: Codable, Sendable, Identifiable {
    var id: String { eventId ?? "\(type)-\(sequenceNumber ?? 0)-\(UUID().uuidString.prefix(6))" }
    let type: String
    let sequenceNumber: Int?
    let eventId: String?

    // agent.message / agent content fields
    let content: [ContentBlock]?

    // agent.tool_use fields (managed-agents uses "name", agent-api uses "tool_name")
    let name: String?
    let toolName: String?
    let toolUseId: String?
    let input: AnyCodable?

    // agent.tool_result fields
    let output: String?

    // session.error fields
    let error: SessionError?

    // agent-api specific
    let isError: Bool?

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceNumber = "sequence_number"
        case eventId = "id"
        case content, name, input, output, error
        case toolName = "tool_name"
        case toolUseId = "tool_use_id"
        case isError = "is_error"
    }

    /// Resolved tool name from either API version
    var resolvedToolName: String? {
        toolName ?? name
    }
}

// MARK: - Content Block

struct ContentBlock: Codable, Sendable {
    let type: String
    var text: String?
}

// MARK: - Session Error

struct SessionError: Codable, Sendable {
    let type: String?
    let message: String?
}

// MARK: - User Event (sent to session)

struct UserMessageEvent: Codable, Sendable {
    let type: String
    let content: [ContentBlock]

    static func message(_ text: String) -> UserMessageEvent {
        UserMessageEvent(
            type: "user.message",
            content: [ContentBlock(type: "text", text: text)]
        )
    }
}

struct UserInterruptEvent: Codable, Sendable {
    let type: String

    static var interrupt: UserInterruptEvent {
        UserInterruptEvent(type: "user.interrupt")
    }
}

struct SendEventsParams: Codable, Sendable {
    let events: [AnyCodable]
}

// MARK: - AnyCodable helper

struct AnyCodable: Codable, @unchecked Sendable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map(\.value)
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues(\.value)
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - Paginated Response

struct PaginatedResponse<T: Codable & Sendable>: Codable, Sendable {
    let data: [T]
    let hasMore: Bool?
    let firstId: String?
    let lastId: String?

    enum CodingKeys: String, CodingKey {
        case data
        case hasMore = "has_more"
        case firstId = "first_id"
        case lastId = "last_id"
    }
}

// MARK: - Display helpers

extension SessionEvent {
    var displayType: EventDisplayType {
        switch type {
        // managed-agents-2026-04-01 event names
        case "agent.message": return .message
        case "agent.thinking": return .thinking
        case "agent.tool_use": return .toolUse
        case "agent.tool_result": return .toolResult
        case "agent.mcp_tool_use": return .mcpToolUse
        case "agent.mcp_tool_result": return .mcpToolResult
        case "agent.custom_tool_use": return .customToolUse
        case "session.status_idle": return .statusIdle
        case "session.status_running": return .statusRunning
        case "session.error": return .error
        // agent-api-2026-03-01 event names (used by stream endpoint)
        case "agent": return .message
        case "agent_tool_use": return .toolUse
        case "agent_tool_result": return .toolResult
        case "status_idle": return .statusIdle
        case "status_running": return .statusRunning
        case "model_request_start", "model_request_end": return .unknown
        case "user": return .unknown
        default: return .unknown
        }
    }
}

enum EventDisplayType: Sendable {
    case message
    case thinking
    case toolUse
    case toolResult
    case mcpToolUse
    case mcpToolResult
    case customToolUse
    case statusIdle
    case statusRunning
    case error
    case unknown
}

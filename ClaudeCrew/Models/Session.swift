import Foundation

// MARK: - Session

struct Session: Codable, Identifiable, Sendable {
    let id: String
    let type: String?
    var title: String?
    let agentId: String?
    let environmentId: String?
    var status: SessionStatus
    let createdAt: Date
    let updatedAt: Date
    let archivedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, type, title, status
        case agentId = "agent_id"
        case environmentId = "environment_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case archivedAt = "archived_at"
    }
}

// MARK: - Session Status

enum SessionStatus: String, Codable, Sendable {
    case idle
    case running
    case rescheduling
    case terminated

    var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .running: return "Running"
        case .rescheduling: return "Rescheduling"
        case .terminated: return "Terminated"
        }
    }

    var iconName: String {
        switch self {
        case .idle: return "circle"
        case .running: return "circle.fill"
        case .rescheduling: return "arrow.clockwise.circle"
        case .terminated: return "xmark.circle"
        }
    }

    var color: String {
        switch self {
        case .idle: return "secondary"
        case .running: return "green"
        case .rescheduling: return "orange"
        case .terminated: return "red"
        }
    }
}

// MARK: - Session Create Params

struct SessionCreateParams: Codable, Sendable {
    var agent: String
    var environmentId: String
    var vaultIds: [String]?
    var title: String?

    enum CodingKeys: String, CodingKey {
        case agent
        case environmentId = "environment_id"
        case vaultIds = "vault_ids"
        case title
    }
}

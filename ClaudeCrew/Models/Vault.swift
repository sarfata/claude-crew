import Foundation

// MARK: - Vault

struct Vault: Codable, Identifiable, Sendable {
    let id: String
    let type: String?
    var displayName: String
    var metadata: [String: String]?
    let createdAt: Date
    let updatedAt: Date
    let archivedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, type, metadata
        case displayName = "display_name"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case archivedAt = "archived_at"
    }
}

// MARK: - Credential

struct Credential: Codable, Identifiable, Sendable {
    let id: String
    let type: String?
    var displayName: String
    var auth: CredentialAuth
    let createdAt: Date
    let updatedAt: Date
    let archivedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, type, auth
        case displayName = "display_name"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case archivedAt = "archived_at"
    }
}

// MARK: - Credential Auth

enum CredentialAuth: Codable, Sendable {
    case mcpOAuth(MCPOAuthAuth)
    case staticBearer(StaticBearerAuth)

    struct MCPOAuthAuth: Codable, Sendable {
        let type: String // "mcp_oauth"
        var mcpServerUrl: String
        var accessToken: String?
        var expiresAt: String?
        var refresh: OAuthRefresh?

        enum CodingKeys: String, CodingKey {
            case type
            case mcpServerUrl = "mcp_server_url"
            case accessToken = "access_token"
            case expiresAt = "expires_at"
            case refresh
        }
    }

    struct OAuthRefresh: Codable, Sendable {
        var tokenEndpoint: String
        var clientId: String
        var scope: String?
        var refreshToken: String?
        var tokenEndpointAuth: TokenEndpointAuth?

        enum CodingKeys: String, CodingKey {
            case tokenEndpoint = "token_endpoint"
            case clientId = "client_id"
            case scope
            case refreshToken = "refresh_token"
            case tokenEndpointAuth = "token_endpoint_auth"
        }
    }

    struct TokenEndpointAuth: Codable, Sendable {
        var type: String // "none", "client_secret_basic", "client_secret_post"
        var clientSecret: String?

        enum CodingKeys: String, CodingKey {
            case type
            case clientSecret = "client_secret"
        }
    }

    struct StaticBearerAuth: Codable, Sendable {
        let type: String // "static_bearer"
        var mcpServerUrl: String
        var token: String?

        enum CodingKeys: String, CodingKey {
            case type
            case mcpServerUrl = "mcp_server_url"
            case token
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TypeKey.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "static_bearer":
            self = .staticBearer(try StaticBearerAuth(from: decoder))
        default:
            self = .mcpOAuth(try MCPOAuthAuth(from: decoder))
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .mcpOAuth(let auth): try auth.encode(to: encoder)
        case .staticBearer(let auth): try auth.encode(to: encoder)
        }
    }

    private enum TypeKey: String, CodingKey {
        case type
    }

    var mcpServerUrl: String {
        switch self {
        case .mcpOAuth(let a): return a.mcpServerUrl
        case .staticBearer(let a): return a.mcpServerUrl
        }
    }

    var typeName: String {
        switch self {
        case .mcpOAuth: return "OAuth"
        case .staticBearer: return "Static Bearer"
        }
    }
}

// MARK: - Create Params

struct VaultCreateParams: Codable, Sendable {
    var displayName: String
    var metadata: [String: String]?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case metadata
    }
}

struct CredentialCreateParams: Codable, Sendable {
    var displayName: String
    var auth: CredentialAuth

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case auth
    }
}

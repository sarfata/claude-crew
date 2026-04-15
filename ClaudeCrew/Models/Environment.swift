import Foundation

// MARK: - Environment

struct AgentEnvironment: Codable, Identifiable, Sendable {
    let id: String
    let type: String?
    var name: String
    var config: CloudConfig
    let createdAt: Date
    let updatedAt: Date
    let archivedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, type, name, config
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case archivedAt = "archived_at"
    }
}

// MARK: - Cloud Config

struct CloudConfig: Codable, Sendable {
    var type: String // "cloud"
    var packages: Packages?
    var networking: Networking

    init(type: String = "cloud", packages: Packages? = nil, networking: Networking = .unrestricted) {
        self.type = type
        self.packages = packages
        self.networking = networking
    }
}

// MARK: - Packages

struct Packages: Codable, Sendable {
    var apt: [String]?
    var cargo: [String]?
    var gem: [String]?
    var go: [String]?
    var npm: [String]?
    var pip: [String]?

    var isEmpty: Bool {
        (apt ?? []).isEmpty && (cargo ?? []).isEmpty && (gem ?? []).isEmpty &&
        (go ?? []).isEmpty && (npm ?? []).isEmpty && (pip ?? []).isEmpty
    }
}

// MARK: - Networking

enum Networking: Codable, Sendable {
    case unrestricted
    case limited(LimitedNetworking)

    struct LimitedNetworking: Codable, Sendable {
        var allowedHosts: [String]
        var allowMcpServers: Bool
        var allowPackageManagers: Bool

        enum CodingKeys: String, CodingKey {
            case allowedHosts = "allowed_hosts"
            case allowMcpServers = "allow_mcp_servers"
            case allowPackageManagers = "allow_package_managers"
        }

        init(allowedHosts: [String] = [], allowMcpServers: Bool = false, allowPackageManagers: Bool = false) {
            self.allowedHosts = allowedHosts
            self.allowMcpServers = allowMcpServers
            self.allowPackageManagers = allowPackageManagers
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TypeKey.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "limited":
            self = .limited(try LimitedNetworking(from: decoder))
        default:
            self = .unrestricted
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .unrestricted:
            var container = encoder.container(keyedBy: TypeKey.self)
            try container.encode("unrestricted", forKey: .type)
        case .limited(let config):
            var container = encoder.container(keyedBy: TypeKey.self)
            try container.encode("limited", forKey: .type)
            try config.encode(to: encoder)
        }
    }

    private enum TypeKey: String, CodingKey {
        case type
    }

    static var `default`: Networking { .unrestricted }
}

// MARK: - Supported Package Managers

enum PackageManager: String, CaseIterable, Sendable {
    case apt, cargo, gem, go, npm, pip

    var displayName: String {
        switch self {
        case .apt: return "apt (System packages)"
        case .cargo: return "cargo (Rust)"
        case .gem: return "gem (Ruby)"
        case .go: return "go (Go modules)"
        case .npm: return "npm (Node.js)"
        case .pip: return "pip (Python)"
        }
    }

    var example: String {
        switch self {
        case .apt: return "ffmpeg"
        case .cargo: return "ripgrep@14.0.0"
        case .gem: return "rails:7.1.0"
        case .go: return "golang.org/x/tools/cmd/goimports@latest"
        case .npm: return "express@4.18.0"
        case .pip: return "pandas==2.2.0"
        }
    }
}

// MARK: - Create Params

struct EnvironmentCreateParams: Codable, Sendable {
    var name: String
    var config: CloudConfig
}

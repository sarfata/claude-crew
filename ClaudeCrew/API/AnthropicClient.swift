import Foundation

actor AnthropicClient {
    private let baseURL = URL(string: "https://api.anthropic.com/v1")!
    private let apiVersion = "2023-06-01"
    private let betaHeader = "managed-agents-2026-04-01"
    private let streamBetaHeader = "agent-api-2026-03-01"
    private let session: URLSession

    var apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }

    // MARK: - Helpers

    private func makeRequest(path: String, method: String = "GET", body: Data? = nil) -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue(betaHeader, forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = body
        return request
    }

    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)

            // Try ISO 8601 with fractional seconds
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: string) { return date }

            // Try without fractional seconds
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

    private func perform<T: Decodable & Sendable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error body"
            throw APIError.httpError(statusCode: httpResponse.statusCode, body: errorBody)
        }

        return try decoder.decode(T.self, from: data)
    }

    private func performVoid(_ request: URLRequest) async throws {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error body"
            throw APIError.httpError(statusCode: httpResponse.statusCode, body: errorBody)
        }
    }

    // MARK: - Agents

    func listAgents() async throws -> [Agent] {
        let request = makeRequest(path: "agents")
        let response: PaginatedResponse<Agent> = try await perform(request)
        return response.data
    }

    func getAgent(id: String) async throws -> Agent {
        let request = makeRequest(path: "agents/\(id)")
        return try await perform(request)
    }

    func createAgent(params: AgentCreateParams) async throws -> Agent {
        let body = try encoder.encode(params)
        let request = makeRequest(path: "agents", method: "POST", body: body)
        return try await perform(request)
    }

    func updateAgent(id: String, params: AgentUpdateParams) async throws -> Agent {
        let body = try encoder.encode(params)
        let request = makeRequest(path: "agents/\(id)", method: "POST", body: body)
        return try await perform(request)
    }

    func archiveAgent(id: String) async throws -> Agent {
        let request = makeRequest(path: "agents/\(id)/archive", method: "POST")
        return try await perform(request)
    }

    // MARK: - Environments

    func listEnvironments() async throws -> [AgentEnvironment] {
        let request = makeRequest(path: "environments")
        let response: PaginatedResponse<AgentEnvironment> = try await perform(request)
        return response.data
    }

    func getEnvironment(id: String) async throws -> AgentEnvironment {
        let request = makeRequest(path: "environments/\(id)")
        return try await perform(request)
    }

    func createEnvironment(params: EnvironmentCreateParams) async throws -> AgentEnvironment {
        let body = try encoder.encode(params)
        let request = makeRequest(path: "environments", method: "POST", body: body)
        return try await perform(request)
    }

    func archiveEnvironment(id: String) async throws {
        let request = makeRequest(path: "environments/\(id)/archive", method: "POST")
        try await performVoid(request)
    }

    func deleteEnvironment(id: String) async throws {
        let request = makeRequest(path: "environments/\(id)", method: "DELETE")
        try await performVoid(request)
    }

    // MARK: - Sessions

    func listSessions() async throws -> [Session] {
        let request = makeRequest(path: "sessions")
        let response: PaginatedResponse<Session> = try await perform(request)
        return response.data
    }

    func getSession(id: String) async throws -> Session {
        let request = makeRequest(path: "sessions/\(id)")
        return try await perform(request)
    }

    func createSession(params: SessionCreateParams) async throws -> Session {
        let body = try encoder.encode(params)
        let request = makeRequest(path: "sessions", method: "POST", body: body)
        return try await perform(request)
    }

    func archiveSession(id: String) async throws {
        let request = makeRequest(path: "sessions/\(id)/archive", method: "POST")
        try await performVoid(request)
    }

    func deleteSession(id: String) async throws {
        let request = makeRequest(path: "sessions/\(id)", method: "DELETE")
        try await performVoid(request)
    }

    // MARK: - Session Events

    func sendEvents(sessionId: String, events: [any Encodable & Sendable]) async throws {
        struct EventsWrapper: Encodable {
            let events: [AnyEncodable]
        }
        let wrapped = EventsWrapper(events: events.map { AnyEncodable($0) })
        let body = try encoder.encode(wrapped)
        let request = makeRequest(path: "sessions/\(sessionId)/events", method: "POST", body: body)
        try await performVoid(request)
    }

    func sendMessage(sessionId: String, text: String) async throws {
        let event = UserMessageEvent.message(text)
        try await sendEvents(sessionId: sessionId, events: [event])
    }

    func sendInterrupt(sessionId: String) async throws {
        let event = UserInterruptEvent.interrupt
        try await sendEvents(sessionId: sessionId, events: [event])
    }

    nonisolated func streamEvents(sessionId: String) -> AsyncThrowingStream<SessionEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task { [self] in
                do {
                    var request = await makeRequest(path: "sessions/\(sessionId)/stream")
                    // Stream endpoint requires the older beta header
                    request.setValue(await streamBetaHeader, forHTTPHeaderField: "anthropic-beta")
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    request.timeoutInterval = 600

                    let (bytes, response) = try await session.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw APIError.invalidResponse
                    }

                    guard (200...299).contains(httpResponse.statusCode) else {
                        // Read the error body from the stream
                        var errorBody = ""
                        for try await byte in bytes {
                            errorBody.append(Character(UnicodeScalar(byte)))
                            if errorBody.count > 2000 { break }
                        }
                        throw APIError.httpError(
                            statusCode: httpResponse.statusCode,
                            body: errorBody.isEmpty ? "No response body" : errorBody
                        )
                    }

                    var buffer = ""
                    let jsonDecoder = await self.decoder

                    for try await byte in bytes {
                        let char = Character(UnicodeScalar(byte))
                        buffer.append(char)

                        if buffer.hasSuffix("\n\n") || buffer.hasSuffix("\r\n\r\n") {
                            let lines = buffer.components(separatedBy: .newlines)
                            for line in lines {
                                if line.hasPrefix("data: ") {
                                    let jsonStr = String(line.dropFirst(6))
                                    if let data = jsonStr.data(using: .utf8) {
                                        if let event = try? jsonDecoder.decode(SessionEvent.self, from: data) {
                                            continuation.yield(event)
                                        } else {
                                            // Log unparseable events as raw unknown events
                                            let raw = SessionEvent(
                                                type: "raw.unparsed",
                                                sequenceNumber: nil,
                                                eventId: nil,
                                                content: [ContentBlock(type: "text", text: jsonStr)],
                                                name: nil,
                                                toolName: nil,
                                                toolUseId: nil,
                                                input: nil,
                                                output: nil,
                                                error: nil,
                                                isError: nil
                                            )
                                            continuation.yield(raw)
                                        }
                                    }
                                }
                            }
                            buffer = ""
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Vaults

    func listVaults() async throws -> [Vault] {
        let request = makeRequest(path: "vaults")
        let response: PaginatedResponse<Vault> = try await perform(request)
        return response.data
    }

    func createVault(params: VaultCreateParams) async throws -> Vault {
        let body = try encoder.encode(params)
        let request = makeRequest(path: "vaults", method: "POST", body: body)
        return try await perform(request)
    }

    func archiveVault(id: String) async throws {
        let request = makeRequest(path: "vaults/\(id)/archive", method: "POST")
        try await performVoid(request)
    }

    func deleteVault(id: String) async throws {
        let request = makeRequest(path: "vaults/\(id)", method: "DELETE")
        try await performVoid(request)
    }

    // MARK: - Credentials

    func listCredentials(vaultId: String) async throws -> [Credential] {
        let request = makeRequest(path: "vaults/\(vaultId)/credentials")
        let response: PaginatedResponse<Credential> = try await perform(request)
        return response.data
    }

    func createCredential(vaultId: String, params: CredentialCreateParams) async throws -> Credential {
        let body = try encoder.encode(params)
        let request = makeRequest(path: "vaults/\(vaultId)/credentials", method: "POST", body: body)
        return try await perform(request)
    }

    func archiveCredential(vaultId: String, credentialId: String) async throws {
        let request = makeRequest(path: "vaults/\(vaultId)/credentials/\(credentialId)/archive", method: "POST")
        try await performVoid(request)
    }
}

// MARK: - Errors

enum APIError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int, body: String)
    case noAPIKey

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code, let body):
            return "HTTP \(code): \(body)"
        case .noAPIKey:
            return "No API key configured. Go to Settings to add your Anthropic API key."
        }
    }
}

// MARK: - AnyEncodable

struct AnyEncodable: Encodable, Sendable {
    private let _encode: @Sendable (Encoder) throws -> Void

    init<T: Encodable & Sendable>(_ wrapped: T) {
        _encode = { encoder in try wrapped.encode(to: encoder) }
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}

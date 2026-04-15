import Foundation

@MainActor
@Observable
final class SessionViewModel {
    let sessionId: String
    private let client: AnthropicClient

    var events: [SessionEvent] = []
    var isStreaming = false
    var messageText = ""
    var error: String?
    var session: Session?

    private var streamTask: Task<Void, Never>?

    init(sessionId: String, client: AnthropicClient) {
        self.sessionId = sessionId
        self.client = client
    }

    func loadSession() async {
        do {
            session = try await client.getSession(id: sessionId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func startStreaming() {
        guard !isStreaming else { return }
        isStreaming = true

        streamTask = Task {
            do {
                for try await event in client.streamEvents(sessionId: sessionId) {
                    self.events.append(event)

                    // Update session status from status events (both API versions)
                    switch event.type {
                    case "session.status_idle", "status_idle":
                        self.session?.status = .idle
                    case "session.status_running", "status_running":
                        self.session?.status = .running
                    case "session.status_rescheduling":
                        self.session?.status = .rescheduling
                    case "session.status_terminated":
                        self.session?.status = .terminated
                    default:
                        break
                    }
                }
            } catch {
                if !Task.isCancelled {
                    self.error = error.localizedDescription
                }
            }
            self.isStreaming = false
        }
    }

    func stopStreaming() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
    }

    func sendMessage() async {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        messageText = ""

        do {
            try await client.sendMessage(sessionId: sessionId, text: text)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func sendInterrupt() async {
        do {
            try await client.sendInterrupt(sessionId: sessionId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    nonisolated deinit {
        // streamTask will be cancelled when the reference is released
    }

    // Filtered events for display
    var displayEvents: [SessionEvent] {
        events.filter { event in
            switch event.displayType {
            case .message, .thinking, .toolUse, .toolResult,
                 .mcpToolUse, .mcpToolResult, .error:
                return true
            default:
                return false
            }
        }
    }
}

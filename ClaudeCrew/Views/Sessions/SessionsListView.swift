import SwiftUI

struct SessionsListView: View {
    @Environment(AppState.self) private var appState
    @State private var showStartSession = false
    @State private var selectedSessionId: String?

    var body: some View {
        HSplitView {
            // List
            VStack(spacing: 0) {
                if appState.sessions.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 48))
                            .foregroundStyle(.tertiary)
                        Text("No sessions yet")
                            .foregroundStyle(.secondary)
                        Button("Start a Session") {
                            showStartSession = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(appState.sessions, selection: $selectedSessionId) { session in
                        SessionRow(session: session)
                            .tag(session.id)
                    }
                    .listStyle(.inset)
                }
            }
            .frame(minWidth: 300)

            // Detail
            if let sessionId = selectedSessionId,
               let client = appState.client {
                SessionDetailView(sessionId: sessionId, client: client)
                    .id(sessionId)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("Select a session to view its events")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar {
            ToolbarItem {
                Button {
                    showStartSession = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Start new session")
            }
        }
        .sheet(isPresented: $showStartSession) {
            StartSessionView()
        }
        .navigationTitle("Sessions")
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: Session

    var body: some View {
        HStack {
            statusIndicator

            VStack(alignment: .leading, spacing: 2) {
                Text(session.title ?? session.id)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(session.status.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(session.createdAt.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch session.status {
        case .running:
            Circle()
                .fill(.green)
                .frame(width: 10, height: 10)
        case .idle:
            Circle()
                .fill(.secondary.opacity(0.5))
                .frame(width: 10, height: 10)
        case .rescheduling:
            Image(systemName: "arrow.clockwise.circle.fill")
                .foregroundStyle(.orange)
                .font(.caption)
        case .terminated:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.caption)
        }
    }
}

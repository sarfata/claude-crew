import SwiftUI

struct SessionDetailView: View {
    let sessionId: String
    let client: AnthropicClient
    @State private var viewModel: SessionViewModel?
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            if let vm = viewModel {
                // Header
                sessionHeader(vm: vm)

                Divider()

                // Events log
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            if vm.events.isEmpty && !vm.isStreaming {
                                VStack(spacing: 8) {
                                    ProgressView()
                                    Text("Connecting to event stream...")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                            } else if vm.events.isEmpty && vm.isStreaming {
                                VStack(spacing: 8) {
                                    HStack(spacing: 6) {
                                        ProgressView()
                                            .controlSize(.small)
                                        Text("Stream connected. Waiting for events...")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                            }

                            ForEach(Array(vm.events.enumerated()), id: \.offset) { index, event in
                                EventLogRow(event: event, index: index)
                                    .id(index)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: vm.events.count) {
                        if vm.events.count > 0 {
                            withAnimation {
                                proxy.scrollTo(vm.events.count - 1, anchor: .bottom)
                            }
                        }
                    }
                }

                if let error = vm.error {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .lineLimit(2)
                        Spacer()
                        Button("Dismiss") { vm.error = nil }
                            .font(.caption)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(.red.opacity(0.05))
                }

                Divider()

                // Input
                messageInput(vm: vm)
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Loading session...")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            let vm = SessionViewModel(sessionId: sessionId, client: client)
            viewModel = vm
            await vm.loadSession()
            vm.startStreaming()
        }
    }

    private func sessionHeader(vm: SessionViewModel) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(vm.session?.title ?? "Session")
                    .font(.headline)
                HStack(spacing: 8) {
                    statusBadge(status: vm.session?.status ?? .idle)

                    Text(sessionId)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .textSelection(.enabled)

                    if vm.isStreaming {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.green)
                                .frame(width: 6, height: 6)
                            Text("Stream connected")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.red)
                                .frame(width: 6, height: 6)
                            Text("Disconnected")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                HStack(spacing: 8) {
                    Text("\(vm.events.count) events")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                if vm.session?.status == .running {
                    Button {
                        Task { await vm.sendInterrupt() }
                    } label: {
                        Label("Interrupt", systemImage: "stop.circle")
                            .font(.caption)
                    }
                    .help("Interrupt agent")
                }

                Button {
                    if vm.isStreaming {
                        vm.stopStreaming()
                    } else {
                        vm.startStreaming()
                    }
                } label: {
                    Label(
                        vm.isStreaming ? "Pause" : "Resume",
                        systemImage: vm.isStreaming ? "pause.circle" : "play.circle"
                    )
                    .font(.caption)
                }
                .help(vm.isStreaming ? "Pause streaming" : "Resume streaming")
            }
        }
        .padding()
    }

    private func statusBadge(status: SessionStatus) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor(status))
                .frame(width: 8, height: 8)
            Text(status.displayName)
                .font(.caption.bold())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(statusColor(status).opacity(0.1), in: Capsule())
    }

    private func statusColor(_ status: SessionStatus) -> Color {
        switch status {
        case .idle: return .secondary
        case .running: return .green
        case .rescheduling: return .orange
        case .terminated: return .red
        }
    }

    private func messageInput(vm: SessionViewModel) -> some View {
        HStack(spacing: 8) {
            TextField("Send a message...", text: Binding(
                get: { vm.messageText },
                set: { vm.messageText = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .onSubmit {
                Task { await vm.sendMessage() }
            }

            Button {
                Task { await vm.sendMessage() }
            } label: {
                Image(systemName: "paperplane.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.messageText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding()
    }
}

// MARK: - Event Log Row — shows ALL events with full detail

struct EventLogRow: View {
    let event: SessionEvent
    let index: Int

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Event number
            Text("#\(index)")
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
                .frame(width: 30, alignment: .trailing)

            // Type icon
            eventIcon
                .frame(width: 16)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                // Event type label
                HStack(spacing: 6) {
                    Text(event.type)
                        .font(.caption.monospaced().bold())
                        .foregroundStyle(typeColor)

                    if let seq = event.sequenceNumber {
                        Text("seq:\(seq)")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.tertiary)
                    }
                }

                // Event-specific content
                eventContent
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private var eventIcon: some View {
        switch event.displayType {
        case .message:
            Image(systemName: "sparkles")
                .font(.caption)
                .foregroundStyle(.purple)
        case .thinking:
            Image(systemName: "brain")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .toolUse, .mcpToolUse:
            Image(systemName: "wrench")
                .font(.caption)
                .foregroundStyle(.blue)
        case .toolResult, .mcpToolResult:
            Image(systemName: "arrow.turn.down.right")
                .font(.caption)
                .foregroundStyle(.cyan)
        case .customToolUse:
            Image(systemName: "gearshape")
                .font(.caption)
                .foregroundStyle(.orange)
        case .statusIdle:
            Image(systemName: "circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .statusRunning:
            Image(systemName: "circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.red)
        case .unknown:
            Image(systemName: "questionmark.circle")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private var eventContent: some View {
        switch event.displayType {
        case .message:
            if let blocks = event.content {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    if let text = block.text, !text.isEmpty {
                        Text(text)
                            .font(.callout)
                            .textSelection(.enabled)
                    }
                }
            }

        case .thinking:
            if let blocks = event.content {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    if let text = block.text, !text.isEmpty {
                        Text(text)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .lineLimit(10)
                    }
                }
            }

        case .toolUse, .mcpToolUse:
            HStack(spacing: 6) {
                if let name = event.resolvedToolName {
                    Text(name)
                        .font(.caption.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.1), in: Capsule())
                        .foregroundStyle(.blue)
                }
                if let toolId = event.toolUseId {
                    Text(toolId)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                }
            }

        case .toolResult, .mcpToolResult:
            if let output = event.output, !output.isEmpty {
                Text(output)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(20)
            } else {
                Text("(empty result)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

        case .statusIdle:
            Text("Agent is idle — waiting for input")
                .font(.caption)
                .foregroundStyle(.secondary)

        case .statusRunning:
            Text("Agent is running")
                .font(.caption)
                .foregroundStyle(.green)

        case .error:
            VStack(alignment: .leading, spacing: 2) {
                if let errType = event.error?.type {
                    Text(errType)
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                }
                if let msg = event.error?.message {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }

        case .customToolUse:
            if let name = event.resolvedToolName {
                Text("Custom tool: \(name)")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

        case .unknown:
            Text("(unrecognized event)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var typeColor: Color {
        switch event.displayType {
        case .message: return .purple
        case .thinking: return .secondary
        case .toolUse, .mcpToolUse: return .blue
        case .toolResult, .mcpToolResult: return .cyan
        case .customToolUse: return .orange
        case .statusIdle: return .secondary
        case .statusRunning: return .green
        case .error: return .red
        case .unknown: return .gray
        }
    }

    private var rowBackground: Color {
        switch event.displayType {
        case .message: return .purple.opacity(0.03)
        case .error: return .red.opacity(0.05)
        case .statusIdle, .statusRunning: return .secondary.opacity(0.03)
        default: return .clear
        }
    }
}

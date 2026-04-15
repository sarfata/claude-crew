# Claude Crew

A native macOS app for managing [Claude Managed Agents](https://platform.claude.com/docs/en/managed-agents/quickstart).

Create agents, configure environments, manage sessions, and handle vault credentials — all from a native SwiftUI interface.

## Features

- **Agents** — Create and configure agents with model selection, system prompts, tool configuration, and MCP server connections
- **Environments** — Define cloud container templates with package management and networking controls
- **Sessions** — Start agent sessions, stream events in real-time, send messages, and monitor status
- **Vaults** — Manage per-user authentication credentials for MCP servers (OAuth and static bearer tokens)
- **Status Bar** — See at a glance how many agents are running or idle

## Requirements

- macOS 14.0+
- Xcode 16.0+
- An [Anthropic API key](https://console.anthropic.com/settings/keys)

## Building

The Xcode project is generated using [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
brew install xcodegen
xcodegen generate
open ClaudeCrew.xcodeproj
```

Then build and run with Cmd+R.

## API Coverage

Claude Crew wraps the Managed Agents API (`managed-agents-2026-04-01` beta):

| Resource | Create | List | Get | Update | Archive | Delete |
|----------|--------|------|-----|--------|---------|--------|
| Agents | Yes | Yes | Yes | Yes | Yes | — |
| Environments | Yes | Yes | Yes | — | Yes | Yes |
| Sessions | Yes | Yes | Yes | — | Yes | Yes |
| Vaults | Yes | Yes | — | — | Yes | Yes |
| Credentials | Yes | Yes | — | — | Yes | — |

Session event streaming (SSE) is fully supported for real-time agent monitoring.

## Architecture

```
ClaudeCrew/
├── App/                  # App entry point
├── API/                  # Anthropic API client, Keychain helper
├── Models/               # Codable models (Agent, Environment, Session, Vault, Event)
├── ViewModels/           # Observable state (AppState, SessionViewModel)
└── Views/
    ├── Agents/           # Agent list, detail, create
    ├── Environments/     # Environment list, detail, create
    ├── Sessions/         # Session list, detail, start session, event stream
    ├── Vaults/           # Vault list, detail, create, add credentials
    └── Settings/         # API key management
```

## License

MIT

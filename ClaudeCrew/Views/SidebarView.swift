import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        List(SidebarSection.allCases, selection: $appState.selectedSection) { section in
            Label(section.rawValue, systemImage: section.icon)
                .badge(badgeCount(for: section))
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)

        if let error = appState.error {
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
                .padding(.horizontal)
        }
    }

    private func badgeCount(for section: SidebarSection) -> Int {
        switch section {
        case .sessions: return appState.activeSessionCount
        case .agents: return appState.agents.count
        case .environments: return appState.environments.count
        case .vaults: return appState.vaults.count
        case .settings: return 0
        }
    }
}

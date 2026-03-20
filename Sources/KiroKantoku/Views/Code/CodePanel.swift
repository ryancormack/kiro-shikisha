#if os(macOS)
import SwiftUI

/// Panel showing code changes and terminal output from agent activity
public struct CodePanel: View {
    let agent: Agent
    let workspacePath: URL

    @State private var selectedTab: CodePanelTab = .filesChanged

    public init(agent: Agent, workspacePath: URL) {
        self.agent = agent
        self.workspacePath = workspacePath
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Compact tab picker
            Picker("", selection: $selectedTab) {
                ForEach(CodePanelTab.allCases, id: \.self) { tab in
                    Text(tab.title)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, DesignConstants.spacingMD)
            .padding(.vertical, DesignConstants.spacingSM)

            Divider()

            // Tab content - all views stay alive to preserve scroll state
            ZStack {
                FilesChangedView(workspacePath: workspacePath)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(selectedTab == .filesChanged ? 1 : 0)
                    .allowsHitTesting(selectedTab == .filesChanged)

                TerminalOutputView(agent: agent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(selectedTab == .terminal ? 1 : 0)
                    .allowsHitTesting(selectedTab == .terminal)

                DebugLogView(agent: agent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(selectedTab == .debug ? 1 : 0)
                    .allowsHitTesting(selectedTab == .debug)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

/// Available tabs in the code panel
enum CodePanelTab: String, CaseIterable {
    case filesChanged
    case terminal
    case debug

    var title: String {
        switch self {
        case .filesChanged: return "Files Changed"
        case .terminal: return "Terminal"
        case .debug: return "Debug"
        }
    }
}

#Preview {
    let workspace = Workspace(
        name: "Test Project",
        path: URL(fileURLWithPath: "/Users/test/Projects/test-project")
    )
    let agent = Agent(
        name: "Test Agent",
        workspace: workspace,
        fileChanges: [
            FileChange(
                path: "Sources/main.swift",
                oldContent: "let x = 1",
                newContent: "let x = 2\nlet y = 3",
                changeType: .modified,
                toolCallId: "tool-1"
            ),
            FileChange(
                path: "Sources/helper.swift",
                newContent: "func helper() {}",
                changeType: .created,
                toolCallId: "tool-2"
            )
        ]
    )

    return CodePanel(agent: agent, workspacePath: URL(fileURLWithPath: "/Users/test/Projects/test-project"))
        .frame(width: 1000, height: 650)
}
#endif

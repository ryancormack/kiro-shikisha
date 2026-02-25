#if os(macOS)
import SwiftUI

/// Panel showing code changes and terminal output from agent activity
public struct CodePanel: View {
    let agent: Agent
    
    @State private var selectedTab: CodePanelTab = .filesChanged
    
    public init(agent: Agent) {
        self.agent = agent
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("", selection: $selectedTab) {
                ForEach(CodePanelTab.allCases, id: \.self) { tab in
                    Text(tab.title)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            Divider()
            
            // Tab content
            switch selectedTab {
            case .filesChanged:
                FilesChangedView(agent: agent)
            case .terminal:
                TerminalOutputView(agent: agent)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

/// Available tabs in the code panel
enum CodePanelTab: String, CaseIterable {
    case filesChanged
    case terminal
    
    var title: String {
        switch self {
        case .filesChanged:
            return "Files Changed"
        case .terminal:
            return "Terminal"
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
    
    return CodePanel(agent: agent)
        .frame(width: 300, height: 400)
}
#endif

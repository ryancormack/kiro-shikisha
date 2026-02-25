#if os(macOS)
import SwiftUI

/// View showing list of files changed by the agent
struct FilesChangedView: View {
    let agent: Agent
    
    @State private var selectedFileId: UUID?
    @State private var selectedFileChange: FileChange?
    @State private var showingDiff = false
    
    var body: some View {
        if agent.fileChanges.isEmpty {
            VStack {
                Spacer()
                Image(systemName: "doc.text")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("No files changed yet")
                    .foregroundColor(.secondary)
                    .font(.caption)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(selection: $selectedFileId) {
                // Group by tool call ID if available
                ForEach(groupedFileChanges, id: \.0) { group in
                    Section(header: sectionHeader(for: group.0)) {
                        ForEach(group.1) { fileChange in
                            FileChangeRow(fileChange: fileChange, isSelected: selectedFileId == fileChange.id)
                                .tag(fileChange.id)
                                .onTapGesture {
                                    selectedFileChange = fileChange
                                    showingDiff = true
                                }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .sheet(isPresented: $showingDiff) {
                if let fileChange = selectedFileChange {
                    DiffSheet(fileChange: fileChange, isPresented: $showingDiff)
                }
            }
        }
    }
    
    /// Group file changes by tool call ID (or "Other" for nil)
    private var groupedFileChanges: [(String, [FileChange])] {
        var groups: [String: [FileChange]] = [:]
        
        for change in agent.fileChanges {
            let key = change.toolCallId ?? "Other"
            groups[key, default: []].append(change)
        }
        
        // Sort by timestamp of first item in each group
        return groups.sorted { group1, group2 in
            let time1 = group1.value.first?.timestamp ?? Date.distantPast
            let time2 = group2.value.first?.timestamp ?? Date.distantPast
            return time1 > time2  // Most recent first
        }
    }
    
    @ViewBuilder
    private func sectionHeader(for toolCallId: String) -> some View {
        if toolCallId == "Other" {
            Text("Other Changes")
                .font(.caption)
                .foregroundColor(.secondary)
        } else {
            // Try to find the tool call title
            if let toolCall = agent.activeToolCalls.first(where: { $0.toolCallId == toolCallId }) {
                HStack {
                    Image(systemName: iconForKind(toolCall.kind))
                        .foregroundColor(.secondary)
                    Text(toolCall.title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("Tool: \(toolCallId.prefix(8))...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func iconForKind(_ kind: ToolCallKind) -> String {
        switch kind {
        case .read:
            return "doc.text"
        case .edit:
            return "pencil"
        case .delete:
            return "trash"
        case .move:
            return "arrow.right.arrow.left"
        case .search:
            return "magnifyingglass"
        case .execute:
            return "terminal"
        case .think:
            return "brain"
        case .fetch:
            return "arrow.down.circle"
        case .other:
            return "questionmark.circle"
        }
    }
}

/// Sheet view for displaying file diff
struct DiffSheet: View {
    let fileChange: FileChange
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Title bar with close button
            HStack {
                Text("Changes: \(fileChange.fileName)")
                    .font(.headline)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            // Diff view
            DiffView(fileChange: fileChange)
        }
        .frame(minWidth: 600, idealWidth: 800, minHeight: 400, idealHeight: 600)
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
                toolCallId: "tool-1"
            ),
            FileChange(
                path: "README.md",
                oldContent: "# Old",
                newContent: "# New\n\nUpdated content",
                changeType: .modified,
                toolCallId: "tool-2"
            )
        ]
    )
    
    return FilesChangedView(agent: agent)
        .frame(width: 300, height: 400)
}
#endif

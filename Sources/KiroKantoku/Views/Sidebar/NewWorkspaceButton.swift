#if os(macOS)
// DEPRECATED: This view is being replaced by NewTaskButton as part of the task-centric architecture refactor.
// Kept for backward compatibility with workspace settings views.
import SwiftUI
public struct NewWorkspaceButton: View {
    @Binding var showingSheet: Bool
    
    public init(showingSheet: Binding<Bool>) {
        self._showingSheet = showingSheet
    }
    
    public var body: some View {
        Button(action: { showingSheet = true }) {
            Label("Add Workspace", systemImage: "plus")
        }
        .help("Create a new workspace")
    }
}

#Preview {
    NewWorkspaceButton(showingSheet: .constant(false))
}
#endif

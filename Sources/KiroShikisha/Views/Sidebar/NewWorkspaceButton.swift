#if os(macOS)
import SwiftUI

/// Button component that shows a sheet for creating a new workspace
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

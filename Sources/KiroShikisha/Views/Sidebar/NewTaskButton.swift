#if os(macOS)
import SwiftUI

/// Button component that triggers showing a new task creation sheet
public struct NewTaskButton: View {
    @Binding var showingSheet: Bool

    public init(showingSheet: Binding<Bool>) {
        self._showingSheet = showingSheet
    }

    public var body: some View {
        Button(action: { showingSheet = true }) {
            Label("New Task", systemImage: "plus")
        }
        .help("Create a new task")
    }
}

#Preview {
    NewTaskButton(showingSheet: .constant(false))
}
#endif

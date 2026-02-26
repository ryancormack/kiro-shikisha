#if os(macOS)
import SwiftUI

/// A view for editing session names with optional git branch suggestions
public struct SessionNameEditor: View {
    /// The current session name being edited
    @Binding var sessionName: String
    
    /// Optional git branch for auto-suggestions
    let gitBranch: String?
    
    /// Callback when save is pressed
    let onSave: () -> Void
    
    /// Callback when cancel is pressed
    let onCancel: () -> Void
    
    /// Suggested name based on git branch
    private var suggestedName: String? {
        guard let branch = gitBranch else { return nil }
        return branchNameToDisplayName(branch)
    }
    
    public init(
        sessionName: Binding<String>,
        gitBranch: String? = nil,
        onSave: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self._sessionName = sessionName
        self.gitBranch = gitBranch
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Session Name")
                .font(.headline)
            
            TextField("Enter session name", text: $sessionName)
                .textFieldStyle(.roundedBorder)
            
            // Show suggestion based on git branch if available
            if let suggested = suggestedName, !suggested.isEmpty, sessionName.isEmpty {
                HStack(spacing: 4) {
                    Text("Suggestion:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        sessionName = suggested
                    }) {
                        Text(suggested)
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            HStack {
                Spacer()
                
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.escape, modifiers: [])
                
                Button("Save", action: onSave)
                    .keyboardShortcut(.return, modifiers: [])
                    .buttonStyle(.borderedProminent)
                    .disabled(sessionName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(minWidth: 300)
    }
    
    /// Convert a branch name to a human-readable display name
    private func branchNameToDisplayName(_ branch: String) -> String {
        // Remove common prefixes
        var name = branch
        for prefix in ["feature/", "bugfix/", "hotfix/", "release/"] {
            if name.hasPrefix(prefix) {
                name = String(name.dropFirst(prefix.count))
                break
            }
        }
        // Replace separators with spaces and capitalize
        return name
            .replacingOccurrences(of: "/", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var name = ""
        
        var body: some View {
            SessionNameEditor(
                sessionName: $name,
                gitBranch: "feature/add-user-auth",
                onSave: { print("Save: \(name)") },
                onCancel: { print("Cancel") }
            )
        }
    }
    
    return PreviewWrapper()
}
#endif

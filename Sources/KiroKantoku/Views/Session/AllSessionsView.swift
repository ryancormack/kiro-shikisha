#if os(macOS)
import SwiftUI

/// Browse all kiro-cli sessions across every workspace and load one into a new task
public struct AllSessionsView: View {
    @Environment(\.dismiss) private var dismiss
    
    /// Callback when a session is selected — passes (sessionId, cwd)
    let onSelectSession: (String, URL) -> Void
    
    private let sessionStorage = SessionStorage()
    
    @State private var sessions: [SessionMetadata] = []
    @State private var searchText = ""
    @State private var isLoading = true
    
    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            
            if isLoading {
                Spacer()
                ProgressView("Scanning sessions…")
                Spacer()
            } else if filteredGroups.isEmpty {
                Spacer()
                emptyState
                Spacer()
            } else {
                sessionList
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .onAppear { loadSessions() }
    }
    
    // MARK: - Subviews
    
    private var header: some View {
        HStack {
            Text("All Sessions")
                .font(.headline)
            Spacer()
            TextField("Filter…", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 200)
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding()
    }
    
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("No sessions found")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var sessionList: some View {
        List {
            ForEach(filteredGroups, id: \.workspace) { group in
                Section(header: Text(group.workspace).font(.caption).foregroundColor(.secondary)) {
                    ForEach(group.sessions) { session in
                        sessionRow(session)
                    }
                }
            }
        }
        .listStyle(.inset)
    }
    
    private func sessionRow(_ session: SessionMetadata) -> some View {
        Button {
            onSelectSession(session.sessionId, URL(fileURLWithPath: session.cwd))
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.displayName)
                        .font(.body)
                        .lineLimit(1)
                    if let date = session.lastActivityDate {
                        Text(date, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "arrow.right.circle")
                    .foregroundColor(.accentColor)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Data
    
    private struct WorkspaceGroup: Sendable {
        let workspace: String
        let sessions: [SessionMetadata]
    }
    
    private var filteredGroups: [WorkspaceGroup] {
        let query = searchText.lowercased()
        let filtered = query.isEmpty ? sessions : sessions.filter {
            $0.displayName.lowercased().contains(query) ||
            $0.cwd.lowercased().contains(query)
        }
        
        let grouped = Dictionary(grouping: filtered) { $0.cwd }
        return grouped.map { cwd, items in
            WorkspaceGroup(
                workspace: cwd,
                sessions: items.sorted { ($0.lastActivityDate ?? .distantPast) > ($1.lastActivityDate ?? .distantPast) }
            )
        }
        .sorted { ($0.sessions.first?.lastActivityDate ?? .distantPast) > ($1.sessions.first?.lastActivityDate ?? .distantPast) }
    }
    
    private func loadSessions() {
        isLoading = true
        Task {
            let all = sessionStorage.listAllSessions()
            await MainActor.run {
                sessions = all
                isLoading = false
            }
        }
    }
}
#endif

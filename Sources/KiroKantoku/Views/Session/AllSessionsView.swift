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
    @State private var sessionToDelete: SessionMetadata?
    
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
        .frame(minWidth: 560, minHeight: 440)
        .onAppear { loadSessions() }
        .alert("Delete session?", isPresented: Binding(
            get: { sessionToDelete != nil },
            set: { if !$0 { sessionToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { sessionToDelete = nil }
            Button("Delete", role: .destructive) {
                if let session = sessionToDelete {
                    deleteSession(session)
                }
                sessionToDelete = nil
            }
        } message: {
            if let session = sessionToDelete {
                Text("This will permanently delete the session \"\(session.displayName)\" and its conversation history from disk. This cannot be undone.")
            }
        }
    }
    
    // MARK: - Subviews
    
    private var header: some View {
        HStack {
            Text("All Sessions")
                .font(.headline)
            Spacer()
            TextField("Filter…", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 220)
            Button {
                loadSessions()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Refresh")
            Button("Close") { dismiss() }
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
            if !searchText.isEmpty {
                Button("Clear filter") { searchText = "" }
                    .font(.caption)
            }
        }
    }
    
    private var sessionList: some View {
        List {
            ForEach(filteredGroups, id: \.workspace) { group in
                Section(header: Text(group.workspace).font(.caption).foregroundColor(.secondary)) {
                    ForEach(group.sessions) { session in
                        sessionRow(session)
                            .contextMenu {
                                Button {
                                    selectSession(session)
                                } label: {
                                    Label("Resume", systemImage: "play.fill")
                                }
                                Button(role: .destructive) {
                                    sessionToDelete = session
                                } label: {
                                    Label("Delete…", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    sessionToDelete = session
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.inset)
    }
    
    private func sessionRow(_ session: SessionMetadata) -> some View {
        Button {
            selectSession(session)
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

    private func selectSession(_ session: SessionMetadata) {
        onSelectSession(session.sessionId, URL(fileURLWithPath: session.cwd))
        dismiss()
    }

    private func deleteSession(_ session: SessionMetadata) {
        _ = sessionStorage.deleteSession(sessionId: session.sessionId)
        sessions.removeAll { $0.sessionId == session.sessionId }
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

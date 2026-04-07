#if os(macOS)
import SwiftUI

/// Row displaying a single session with preview and actions
public struct SessionRow: View {
    /// The session metadata
    let session: SessionMetadata
    
    /// Session storage for loading preview
    let sessionStorage: SessionStorage
    
    /// Callback when resume button is tapped
    let onResume: () -> Void
    
    /// Callback when delete action is triggered
    let onDelete: (() -> Void)?
    
    /// Preview text loaded from session history
    @State private var previewText: String?
    
    /// Message count loaded from session history
    @State private var messageCount: Int?
    
    /// Whether preview is loading
    @State private var isLoadingPreview: Bool = true
    
    public init(
        session: SessionMetadata,
        sessionStorage: SessionStorage = SessionStorage(),
        onResume: @escaping () -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.session = session
        self.sessionStorage = sessionStorage
        self.onResume = onResume
        self.onDelete = onDelete
    }
    
    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Session icon
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 4) {
                // Session name header (prioritized)
                HStack {
                    HStack(spacing: 4) {
                        Text(session.displayName)
                            .font(.headline)
                            .lineLimit(1)
                        
                        // Visual indicator for custom name
                        if session.hasCustomName {
                            Image(systemName: "pencil.circle.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if let count = messageCount, count > 0 {
                        Text("\(count) messages")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: DesignConstants.badgeCornerRadius))
                    }
                }
                
                // Date and path as secondary info
                HStack(spacing: 8) {
                    Text(formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !session.hasCustomName {
                        // Only show path if no custom name (since displayName shows workspace name)
                    } else {
                        // Show path as additional context when there's a custom name
                        Text(URL(fileURLWithPath: session.cwd).lastPathComponent)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Preview text
                if isLoadingPreview {
                    Text("Loading preview...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                } else if let preview = previewText {
                    Text(preview)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                } else {
                    Text("No messages")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
                
                // Resume button
                HStack {
                    Spacer()
                    Button(action: onResume) {
                        Label("Resume", systemImage: "play.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onResume()
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if let onDelete = onDelete {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .onAppear {
            loadPreview()
        }
    }
    
    /// Formatted date string showing relative dates
    private var formattedDate: String {
        guard let date = session.lastActivityDate else {
            return "Unknown date"
        }
        
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            return "Today, \(timeFormatter.string(from: date))"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday, \(timeFormatter.string(from: date))"
        } else if let daysAgo = calendar.dateComponents([.day], from: date, to: Date()).day,
                  daysAgo < 7 {
            return "\(dayOfWeekFormatter.string(from: date)), \(timeFormatter.string(from: date))"
        } else {
            return dateFormatter.string(from: date)
        }
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }
    
    private var dayOfWeekFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    private func loadPreview() {
        isLoadingPreview = true
        
        Task {
            do {
                let messages = try sessionStorage.loadSessionHistory(sessionId: session.sessionId)
                
                await MainActor.run {
                    self.messageCount = messages.count
                    
                    // Get last user or assistant message as preview
                    if let lastMessage = messages.last {
                        let truncated = String(lastMessage.content.prefix(150))
                        self.previewText = truncated.count < lastMessage.content.count
                            ? truncated + "..."
                            : truncated
                    } else {
                        self.previewText = nil
                    }
                    
                    self.isLoadingPreview = false
                }
            } catch {
                await MainActor.run {
                    self.previewText = nil
                    self.messageCount = nil
                    self.isLoadingPreview = false
                }
            }
        }
    }
}

#Preview {
    let session = SessionMetadata(
        sessionId: "test-session-123",
        cwd: "/Users/developer/Projects/MyProject",
        sessionName: "Implement User Auth",
        createdAt: Date().addingTimeInterval(-3600),
        lastModified: Date()
    )
    
    let sessionWithoutName = SessionMetadata(
        sessionId: "test-session-456",
        cwd: "/Users/developer/Projects/AnotherProject",
        createdAt: Date().addingTimeInterval(-7200),
        lastModified: Date().addingTimeInterval(-3600)
    )
    
    return List {
        SessionRow(
            session: session,
            onResume: {
                print("Resume tapped")
            },
            onDelete: {
                print("Delete tapped")
            }
        )
        SessionRow(
            session: sessionWithoutName,
            onResume: {
                print("Resume tapped")
            },
            onDelete: {
                print("Delete tapped")
            }
        )
    }
    .frame(width: 350, height: 300)
}
#endif

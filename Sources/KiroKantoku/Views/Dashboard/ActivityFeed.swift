#if os(macOS)
import SwiftUI

/// Chronological feed of recent activity across all agents
public struct ActivityFeed: View {
    let events: [ActivityEvent]
    
    /// Maximum number of events to display
    private let maxEvents = 50
    
    public init(events: [ActivityEvent]) {
        self.events = events
    }
    
    private var sortedEvents: [ActivityEvent] {
        Array(events.sorted { $0.timestamp > $1.timestamp }.prefix(maxEvents))
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Activity Feed")
                    .font(.headline)
                
                Spacer()
                
                Text("\(events.count) events")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
            
            // Content
            if sortedEvents.isEmpty {
                emptyStateView
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(sortedEvents) { event in
                                ActivityEventRow(event: event)
                                    .id(event.id)
                                
                                if event.id != sortedEvents.last?.id {
                                    Divider()
                                        .padding(.leading, 40)
                                }
                            }
                        }
                    }
                    .onChange(of: events.count) { _, _ in
                        // Auto-scroll to latest when new events arrive
                        if let latestEvent = sortedEvents.first {
                            withAnimation {
                                proxy.scrollTo(latestEvent.id, anchor: .top)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignConstants.cardBackground)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            
            Image(systemName: "clock")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            
            Text("No Activity Yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Agent activity will appear here")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A single row in the activity feed
struct ActivityEventRow: View {
    let event: ActivityEvent
    
    private var icon: String {
        switch event.eventType {
        case .message:
            return "bubble.left"
        case .toolCall:
            return "gearshape"
        case .error:
            return "exclamationmark.triangle.fill"
        case .complete:
            return "checkmark.circle.fill"
        }
    }
    
    private var iconColor: Color {
        switch event.eventType {
        case .message:
            return .blue
        case .toolCall:
            return .orange
        case .error:
            return .red
        case .complete:
            return .green
        }
    }
    
    private var formattedTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: event.timestamp, relativeTo: Date())
    }
    
    /// Agent name with branch context if available
    private var agentDisplayName: String {
        if let branch = event.branch {
            return "\(event.agentName) (\(branch))"
        }
        return event.agentName
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Event type icon
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(iconColor)
                .frame(width: 20, height: 20)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    // Agent name with optional worktree indicator
                    HStack(spacing: 4) {
                        Text(event.agentName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        // Show branch badge for worktree agents
                        if let branch = event.branch {
                            HStack(spacing: 2) {
                                Image(systemName: "arrow.triangle.branch")
                                    .font(.system(size: 8))
                                Text(shortenedBranch(branch))
                                    .font(.caption2)
                            }
                            .foregroundColor(.purple)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.purple.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: DesignConstants.badgeCornerRadius))
                        }
                    }
                    
                    Spacer()
                    
                    Text(formattedTime)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text(event.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
    
    /// Shorten long branch names
    private func shortenedBranch(_ branch: String) -> String {
        // Remove common prefixes for display
        var name = branch
        for prefix in ["feature/", "bugfix/", "hotfix/", "release/"] {
            if name.hasPrefix(prefix) {
                name = String(name.dropFirst(prefix.count))
                break
            }
        }
        // Truncate if still too long
        if name.count > 15 {
            return String(name.prefix(12)) + "..."
        }
        return name
    }
}

#Preview {
    let events: [ActivityEvent] = [
        ActivityEvent(
            agentId: UUID(),
            agentName: "Agent 1",
            eventType: .message,
            description: "Started working on the feature implementation",
            timestamp: Date().addingTimeInterval(-60),
            branch: "feature/new-ui",
            isWorktree: true
        ),
        ActivityEvent(
            agentId: UUID(),
            agentName: "Agent 2",
            eventType: .toolCall,
            description: "Reading main.swift",
            timestamp: Date().addingTimeInterval(-120)
        ),
        ActivityEvent(
            agentId: UUID(),
            agentName: "Agent 1",
            eventType: .toolCall,
            description: "Writing new file: Feature.swift",
            timestamp: Date().addingTimeInterval(-180),
            branch: "feature/new-ui",
            isWorktree: true
        ),
        ActivityEvent(
            agentId: UUID(),
            agentName: "Agent 2",
            eventType: .error,
            description: "Build failed: Missing import statement",
            timestamp: Date().addingTimeInterval(-240)
        ),
        ActivityEvent(
            agentId: UUID(),
            agentName: "Agent 3",
            eventType: .complete,
            description: "Task completed successfully",
            timestamp: Date().addingTimeInterval(-300),
            branch: "bugfix/login-issue",
            isWorktree: true
        )
    ]
    
    return ActivityFeed(events: events)
        .frame(width: 350, height: 400)
}
#endif

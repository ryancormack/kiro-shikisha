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
        .background(Color(nsColor: .controlBackgroundColor))
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
                    Text(event.agentName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
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
}

#Preview {
    let events: [ActivityEvent] = [
        ActivityEvent(
            agentId: UUID(),
            agentName: "Agent 1",
            eventType: .message,
            description: "Started working on the feature implementation",
            timestamp: Date().addingTimeInterval(-60)
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
            timestamp: Date().addingTimeInterval(-180)
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
            timestamp: Date().addingTimeInterval(-300)
        )
    ]
    
    return ActivityFeed(events: events)
        .frame(width: 350, height: 400)
}
#endif

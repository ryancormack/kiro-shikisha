#if os(macOS)
import SwiftUI

/// A badge that displays the status of an agent with a colored circle and optional label
public struct StatusBadge: View {
    let status: AgentStatus
    let showLabel: Bool
    
    public init(status: AgentStatus, showLabel: Bool = false) {
        self.status = status
        self.showLabel = showLabel
    }
    
    private var statusColor: Color {
        switch status {
        case .active:
            return .green
        case .idle:
            return .gray
        case .connecting:
            return .yellow
        case .error:
            return .red
        }
    }
    
    private var statusLabel: String {
        switch status {
        case .active:
            return "Active"
        case .idle:
            return "Idle"
        case .connecting:
            return "Connecting"
        case .error:
            return "Error"
        }
    }
    
    public var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            if showLabel {
                Text(statusLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        StatusBadge(status: .active, showLabel: true)
        StatusBadge(status: .idle, showLabel: true)
        StatusBadge(status: .connecting, showLabel: true)
        StatusBadge(status: .error, showLabel: true)
        StatusBadge(status: .active)
    }
    .padding()
}
#endif

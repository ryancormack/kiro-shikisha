#if os(macOS)
import SwiftUI

/// Visual status indicator for agent state
/// Shows colored circle/animation based on agent status
public struct AgentStatusIndicator: View {
    let status: AgentStatus
    let showLabel: Bool
    
    @State private var isAnimating: Bool = false
    
    public init(status: AgentStatus, showLabel: Bool = false) {
        self.status = status
        self.showLabel = showLabel
    }
    
    private var statusColor: Color {
        switch status {
        case .idle:
            return .gray
        case .connecting:
            return .yellow
        case .active:
            return .green
        case .error:
            return .red
        }
    }
    
    private var statusLabel: String {
        switch status {
        case .idle:
            return "Idle"
        case .connecting:
            return "Connecting"
        case .active:
            return "Active"
        case .error:
            return "Error"
        }
    }
    
    public var body: some View {
        HStack(spacing: 6) {
            indicatorView
            
            if showLabel {
                Text(statusLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var indicatorView: some View {
        switch status {
        case .idle:
            // Gray circle for idle
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            
        case .connecting:
            // Yellow spinner for connecting
            ProgressView()
                .controlSize(.mini)
                .tint(statusColor)
            
        case .active:
            // Green pulsing circle for active
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(statusColor.opacity(0.5), lineWidth: 2)
                        .scaleEffect(isAnimating ? 1.5 : 1.0)
                        .opacity(isAnimating ? 0 : 1)
                )
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false)) {
                        isAnimating = true
                    }
                }
            
        case .error:
            // Red exclamation icon for error
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(statusColor)
                .font(.system(size: 12))
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 30) {
            AgentStatusIndicator(status: .idle, showLabel: true)
            AgentStatusIndicator(status: .connecting, showLabel: true)
            AgentStatusIndicator(status: .active, showLabel: true)
            AgentStatusIndicator(status: .error, showLabel: true)
        }
        
        HStack(spacing: 30) {
            AgentStatusIndicator(status: .idle)
            AgentStatusIndicator(status: .connecting)
            AgentStatusIndicator(status: .active)
            AgentStatusIndicator(status: .error)
        }
    }
    .padding()
}
#endif

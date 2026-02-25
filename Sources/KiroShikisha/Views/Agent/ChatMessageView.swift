#if os(macOS)
import SwiftUI

/// Individual chat message bubble with role-based styling
public struct ChatMessageView: View {
    let message: ChatMessage
    
    public init(message: ChatMessage) {
        self.message = message
    }
    
    private var isUser: Bool {
        message.role == .user
    }
    
    private var backgroundColor: Color {
        switch message.role {
        case .user:
            return .blue
        case .assistant:
            return Color(nsColor: .controlBackgroundColor)
        case .system:
            return Color(nsColor: .controlBackgroundColor).opacity(0.5)
        }
    }
    
    private var textColor: Color {
        switch message.role {
        case .user:
            return .white
        case .assistant, .system:
            return Color(nsColor: .textColor)
        }
    }
    
    private var timestampFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
    public var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(LocalizedStringKey(message.content))
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(backgroundColor)
                    .foregroundColor(textColor)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                
                Text(timestampFormatter.string(from: message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !isUser {
                Spacer(minLength: 60)
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        ChatMessageView(message: ChatMessage(
            role: .user,
            content: "Hello! Can you help me with SwiftUI?"
        ))
        
        ChatMessageView(message: ChatMessage(
            role: .assistant,
            content: "Of course! I'd be happy to help with SwiftUI.\n\n**What would you like to know?**\n\n- Views and modifiers\n- State management\n- Navigation\n- Animations"
        ))
        
        ChatMessageView(message: ChatMessage(
            role: .user,
            content: "Tell me about `@State` and `@Binding`"
        ))
        
        ChatMessageView(message: ChatMessage(
            role: .system,
            content: "System message example"
        ))
    }
    .padding()
    .frame(width: 400)
}
#endif

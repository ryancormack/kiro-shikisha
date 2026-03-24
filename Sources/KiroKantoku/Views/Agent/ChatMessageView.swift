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
            return .accentColor
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
        if message.role == .system {
            Text(message.content)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        } else {
            HStack(alignment: .bottom, spacing: 8) {
                if isUser {
                    Spacer(minLength: 60)
                }
                
                VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                    Group {
                        if isUser {
                            Text(message.content)
                                .textSelection(.enabled)
                        } else {
                            MarkdownContentView(content: message.content)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(backgroundColor)
                    .foregroundColor(textColor)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(DesignConstants.separatorColor.opacity(isUser ? 0 : 0.15), lineWidth: 0.5)
                    )
                    
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
}

#Preview {
    VStack(spacing: 16) {
        ChatMessageView(message: ChatMessage(
            role: .user,
            content: "Hello! Can you help me with SwiftUI?"
        ))
        
        ChatMessageView(message: ChatMessage(
            role: .assistant,
            content: "# Analysis Complete\n\nHere's what I found:\n\n## Key Points\n\n- **Memory usage** is high\n- *Performance* is acceptable\n- Check `AppDelegate.swift` for details\n\n```swift\nfunc optimize() {\n    let cache = Cache()\n    cache.clear()\n}\n```\n\n> Note: This requires a restart\n\n1. First, backup your data\n2. Then run the migration\n3. Finally, verify the results\n\n```mermaid\ngraph TD\n    A[Start] --> B[Process]\n    B --> C[End]\n```"
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

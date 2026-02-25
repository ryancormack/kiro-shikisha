#if os(macOS)
import SwiftUI

/// Chat panel with message list and input area
public struct ChatPanel: View {
    let agent: Agent
    @State private var isLoading: Bool = false
    
    public init(agent: Agent) {
        self.agent = agent
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(agent.messages) { message in
                            ChatMessageView(message: message)
                                .id(message.id)
                        }
                        
                        if isLoading {
                            TypingIndicator()
                                .id("typing-indicator")
                        }
                    }
                    .padding()
                }
                .onChange(of: agent.messages.count) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: isLoading) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
                .onAppear {
                    scrollToBottom(proxy: proxy)
                }
            }
            
            Divider()
            
            ChatInputView { message in
                sendMessage(message)
            }
            .padding()
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if isLoading {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo("typing-indicator", anchor: .bottom)
            }
        } else if let lastMessage = agent.messages.last {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
    
    private func sendMessage(_ content: String) {
        // In a real implementation, this would:
        // 1. Add the user message to the agent
        // 2. Send via ACP to the agent
        // 3. Set isLoading = true
        // 4. Handle streaming response
        // For now, just a placeholder
        isLoading = true
        
        // Simulate async response
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isLoading = false
        }
    }
}

/// Typing indicator showing the agent is processing
struct TypingIndicator: View {
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 6, height: 6)
                        .offset(y: animationOffset(for: index))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            Spacer()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                animationOffset = -4
            }
        }
    }
    
    private func animationOffset(for index: Int) -> CGFloat {
        let delay = Double(index) * 0.15
        return animationOffset * cos(delay * .pi)
    }
}

#Preview {
    let workspace = Workspace(
        name: "Test Project",
        path: URL(fileURLWithPath: "/Users/test/Projects/test-project")
    )
    let agent = Agent(
        name: "Test Agent",
        workspace: workspace,
        messages: [
            ChatMessage(role: .user, content: "Can you help me refactor this code?"),
            ChatMessage(role: .assistant, content: "Of course! I'd be happy to help you refactor your code. Could you share the specific file or code snippet you'd like me to work on?\n\nI can help with:\n- **Improving readability**\n- **Extracting methods**\n- **Reducing complexity**"),
            ChatMessage(role: .user, content: "Here's a function that needs cleanup...")
        ]
    )
    
    return ChatPanel(agent: agent)
        .frame(width: 500, height: 400)
}
#endif

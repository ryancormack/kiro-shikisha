#if os(macOS)
import SwiftUI

/// Chat panel with message list and input area
public struct ChatPanel: View {
    let agent: Agent
    @Environment(AgentManager.self) private var agentManager
    @State private var errorMessage: String?
    
    public init(agent: Agent) {
        self.agent = agent
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    LazyVStack(spacing: 12) {
                        ForEach(agent.messages) { message in
                            if message.role == .system, let tcIds = message.toolCallIds {
                                // Inline tool call marker
                                ForEach(tcIds, id: \.self) { tcId in
                                    let tc = agent.toolCallHistory[tcId]
                                    InlineToolCallView(toolCall: tc, toolCallId: tcId)
                                        .id("\(message.id)-\(tcId)")
                                }
                            } else if !message.content.isEmpty {
                                ChatMessageView(message: message)
                                    .id(message.id)
                            }
                        }
                        
                        if agent.messages.isEmpty && agent.status != .active {
                            VStack(spacing: 8) {
                                Spacer()
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                                Text("Agent ready — waiting for first response")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                        }

                        if agent.status == .active {
                            TypingIndicator(label: agent.messages.isEmpty ? "Agent is starting up…" : nil)
                                .id("typing-indicator")
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                }
                .scrollContentBackground(.hidden)
                .onChange(of: agent.messages.count) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: agent.status) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
                .onAppear {
                    scrollToBottom(proxy: proxy)
                }
            }
            .layoutPriority(1)
            
            VStack(spacing: 0) {
                Divider()
                
                if agent.sessionId == nil {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Connecting…")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    ConfigSelectorBar(agent: agent, onError: { error in
                        errorMessage = error
                    })

                    SkillsPanel(skills: agent.availableSkills) { skillName in
                        sendMessage("Please use the \(skillName) skill for the following request.")
                    }

                    ChatInputView { message, images in
                        sendMessage(message, images: images)
                    }
                    .padding()
                }
                
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                        .padding(.bottom, 4)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if agent.status == .active {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo("typing-indicator", anchor: .bottom)
            }
        } else if let lastMessage = agent.messages.last {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
    
    private func sendMessage(_ content: String, images: [Data] = []) {
        errorMessage = nil
        
        // Detect slash commands
        if content.hasPrefix("/") {
            let parts = content.dropFirst().split(separator: " ", maxSplits: 1)
            let command = String(parts.first ?? "")
            let argsString = parts.count > 1 ? String(parts[1]) : nil
            
            if !command.isEmpty {
                Task {
                    do {
                        var args: [String: String] = [:]
                        if let argsString = argsString {
                            args["value"] = argsString
                        }
                        try await agentManager.executeSlashCommand(agentId: agent.id, command: command, args: args)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
                return
            }
        }
        
        Task {
            do {
                try await agentManager.sendPrompt(agentId: agent.id, prompt: content, imageAttachments: images)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

/// Typing indicator showing the agent is processing
struct TypingIndicator: View {
    var label: String? = nil
    @State private var isAnimating = false
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 6, height: 6)
                        .offset(y: isAnimating ? -4 * cos(Double(index) * 0.15 * .pi) : 0)
                        .animation(
                            .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                            value: isAnimating
                        )
                }
                if let label {
                    Text(label)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            Spacer()
        }
        .frame(height: 26)
        .onAppear {
            isAnimating = true
        }
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

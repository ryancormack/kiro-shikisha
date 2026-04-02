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

                        // Show agent plan if available
                        if let plan = agent.currentPlan, !plan.entries.isEmpty {
                            PlanView(plan: plan)
                                .id("plan-view")
                        }

                        // Show agent thinking if active
                        if !agent.thoughtContent.isEmpty, agent.status == .active {
                            ThoughtBubbleView(content: agent.thoughtContent)
                                .id("thought-view")
                        }

                        if agent.status == .active {
                            TypingIndicator(label: agent.messages.isEmpty ? "Agent is starting up\u{2026}" : nil)
                                .id("typing-indicator")
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .textSelection(.enabled)
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
                    if let usage = agent.contextUsagePercentage {
                        ContextUsageBar(percentage: usage)
                            .padding(.top, DesignConstants.spacingSM)
                    }

                    ConfigSelectorBar(agent: agent, onError: { error in
                        errorMessage = error
                    })

                    SkillsPanel(skills: agent.availableSkills) { skillName in
                        sendMessage("Please use the \(skillName) skill for the following request.")
                    }

                    if agent.isCompacting, let message = agent.compactionMessage {
                        StatusBannerView(
                            icon: "arrow.triangle.2.circlepath",
                            message: message,
                            color: .blue
                        )
                    }

                    if agent.isClearingHistory, let message = agent.clearStatusMessage {
                        StatusBannerView(
                            icon: "trash",
                            message: message,
                            color: .orange
                        )
                    }

                    if let oauthURL = agent.pendingOAuthURL {
                        OAuthRequestView(url: oauthURL) {
                            if let url = URL(string: oauthURL) {
                                NSWorkspace.shared.open(url)
                            }
                            agent.pendingOAuthURL = nil
                        }
                    }

                    if let permissionRequest = agent.pendingPermissionRequest {
                        PermissionRequestView(
                            request: permissionRequest,
                            onSelect: { optionId in
                                agentManager.resolvePermission(agentId: agent.id, optionId: optionId)
                            },
                            onCancel: {
                                agentManager.cancelPermission(agentId: agent.id)
                            }
                        )
                    }

                    ChatInputView(agent: agent, onSend: { message, images in
                        sendMessage(message, images: images)
                    }, onSlashCommand: { command, optionValue in
                        handleSlashCommand(command, optionValue: optionValue)
                    })
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
        
        // Detect slash commands (fallback for text typed directly without picker)
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
    
    private func handleSlashCommand(_ command: SlashCommand, optionValue: String?) {
        errorMessage = nil
        
        switch command.inputType {
        case .local:
            // Handle local commands client-side
            if command.name == "quit" || command.name == "exit" {
                Task {
                    await agentManager.stopAgent(id: agent.id)
                }
            } else if command.name == "clear" {
                agent.messages.removeAll()
            }
            
        case .selection:
            // Execute with the selected option value
            Task {
                do {
                    var args: [String: String] = [:]
                    if let value = optionValue {
                        args["value"] = value
                    }
                    try await agentManager.executeSlashCommand(agentId: agent.id, command: command.name, args: args)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
            
        case .panel:
            // Execute the command; response arrives through session updates
            Task {
                do {
                    try await agentManager.executeSlashCommand(agentId: agent.id, command: command.name)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
            
        case .simple:
            // Execute directly; response arrives through session updates
            Task {
                do {
                    var args: [String: String] = [:]
                    if let value = optionValue {
                        args["value"] = value
                    }
                    try await agentManager.executeSlashCommand(agentId: agent.id, command: command.name, args: args)
                } catch {
                    errorMessage = error.localizedDescription
                }
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
            .background(DesignConstants.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignConstants.cornerRadiusMedium))
            
            Spacer()
        }
        .frame(height: 26)
        .onAppear {
            isAnimating = true
        }
    }
}

/// Small horizontal bar showing context usage percentage
private struct ContextUsageBar: View {
    let percentage: Double

    private var color: Color {
        if percentage < 50 { return .green }
        if percentage < 80 { return .yellow }
        return .red
    }

    var body: some View {
        HStack(spacing: 6) {
            Text("Context")
                .font(.system(.caption2))
                .foregroundColor(.secondary)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: DesignConstants.cornerRadiusSmall)
                        .fill(Color.secondary.opacity(0.2))
                    RoundedRectangle(cornerRadius: DesignConstants.cornerRadiusSmall)
                        .fill(color)
                        .frame(width: geometry.size.width * min(percentage / 100.0, 1.0))
                }
            }
            .frame(height: 5)

            Text(String(format: "%.0f%%", percentage))
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(color)
                .frame(width: 32, alignment: .trailing)
        }
        .padding(.horizontal, DesignConstants.spacingMD)
        .padding(.vertical, 2)
    }
}

/// Reusable status banner with spinner, icon, and message text
private struct StatusBannerView: View {
    let icon: String
    let message: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, DesignConstants.spacingMD)
        .padding(.vertical, DesignConstants.spacingSM)
        .background(color.opacity(0.06))
    }
}

/// Inline view prompting the user to open an MCP OAuth URL
private struct OAuthRequestView: View {
    let url: String
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "key.fill")
                .foregroundColor(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text("MCP Server Authentication Required")
                    .font(.caption)
                    .fontWeight(.medium)
                Text(url)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button("Open in Browser") {
                onOpen()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, DesignConstants.spacingMD)
        .padding(.vertical, DesignConstants.spacingSM)
        .background(Color.blue.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: DesignConstants.cornerRadiusMedium))
        .padding(.horizontal)
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

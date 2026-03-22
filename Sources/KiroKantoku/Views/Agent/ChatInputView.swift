#if os(macOS)
import SwiftUI
import UniformTypeIdentifiers

/// Text input area for composing and sending chat messages with slash command autocomplete
public struct ChatInputView: View {
    let agent: Agent
    let onSend: (String, [Data]) -> Void
    let onSlashCommand: (SlashCommand, String?) -> Void
    
    @Environment(AgentManager.self) private var agentManager
    
    @State private var inputText: String = ""
    @State private var imageAttachments: [Data] = []
    @FocusState private var isFocused: Bool
    
    // Slash command autocomplete state
    @State private var showSlashPicker: Bool = false
    @State private var slashFilterText: String = ""
    
    // Command options picker state
    @State private var showOptionsPicker: Bool = false
    @State private var currentOptionsCommand: SlashCommand? = nil
    @State private var commandOptions: [CommandOption] = []
    @State private var optionsFilterText: String = ""
    @State private var isLoadingOptions: Bool = false
    
    public init(
        agent: Agent,
        onSend: @escaping (String, [Data]) -> Void,
        onSlashCommand: @escaping (SlashCommand, String?) -> Void
    ) {
        self.agent = agent
        self.onSend = onSend
        self.onSlashCommand = onSlashCommand
    }
    
    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Merged list of all available slash commands
    private var allCommands: [SlashCommand] {
        mergeSlashCommands(
            acpCommands: agent.availableCommands,
            kiroCommands: agent.kiroAvailableCommands
        )
    }
    
    public var body: some View {
        VStack(spacing: 4) {
            if !imageAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(imageAttachments.indices, id: \.self) { index in
                            ZStack(alignment: .topTrailing) {
                                if let nsImage = NSImage(data: imageAttachments[index]) {
                                    Image(nsImage: nsImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 48, height: 48)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                } else {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.secondary.opacity(0.3))
                                        .frame(width: 48, height: 48)
                                }
                                Button {
                                    imageAttachments.remove(at: index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)
                                        .background(Circle().fill(Color.black.opacity(0.5)))
                                }
                                .buttonStyle(.plain)
                                .offset(x: 4, y: -4)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .frame(height: 56)
            }
            
            ZStack(alignment: .bottom) {
                // Slash command picker overlay (positioned above the input)
                if showSlashPicker {
                    VStack {
                        Spacer()
                        SlashCommandPicker(
                            commands: allCommands,
                            filterText: slashFilterText,
                            onSelect: { command in
                                handleCommandSelection(command)
                            },
                            onDismiss: {
                                dismissSlashPicker()
                            }
                        )
                        .padding(.horizontal, DesignConstants.spacingSM)
                    }
                    .offset(y: -44)
                    .zIndex(1)
                }
                
                // Options picker overlay
                if showOptionsPicker {
                    VStack {
                        Spacer()
                        if isLoadingOptions {
                            HStack {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Loading options...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: DesignConstants.cornerRadiusMedium)
                                    .fill(Color(nsColor: .controlBackgroundColor))
                                    .shadow(color: .black.opacity(0.2), radius: 8, y: -2)
                            )
                        } else {
                            CommandOptionsPicker(
                                options: commandOptions,
                                filterText: optionsFilterText,
                                onSelect: { option in
                                    handleOptionSelection(option)
                                },
                                onDismiss: {
                                    dismissOptionsPicker()
                                }
                            )
                        }
                    }
                    .padding(.horizontal, DesignConstants.spacingSM)
                    .offset(y: -44)
                    .zIndex(1)
                }
                
                HStack(alignment: .bottom, spacing: 8) {
                    Button(action: pickImages) {
                        Image(systemName: "photo")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 28, height: 36)
                    
                    TextEditor(text: $inputText)
                        .font(.body)
                        .focused($isFocused)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: DesignConstants.cornerRadiusLarge))
                        .frame(minHeight: 36, maxHeight: 100)
                    
                    Button(action: send) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(canSend ? .blue : .secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSend)
                    .keyboardShortcut(.return, modifiers: .command)
                    .frame(width: 36, height: 36)
                }
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onChange(of: inputText) { _, newValue in
            updateSlashPickerState(newValue)
        }
    }
    
    // MARK: - Slash Command Logic
    
    private func updateSlashPickerState(_ text: String) {
        if text.hasPrefix("/") && !showOptionsPicker {
            let afterSlash = String(text.dropFirst())
            // Only show picker if no space (user is still typing the command name)
            if !afterSlash.contains(" ") {
                slashFilterText = afterSlash
                showSlashPicker = true
            } else {
                showSlashPicker = false
            }
        } else {
            showSlashPicker = false
            slashFilterText = ""
        }
    }
    
    private func handleCommandSelection(_ command: SlashCommand) {
        showSlashPicker = false
        
        switch command.inputType {
        case .local:
            // Handle local commands client-side
            inputText = ""
            onSlashCommand(command, nil)
            
        case .selection:
            // Show options picker
            inputText = ""
            currentOptionsCommand = command
            showOptionsPicker = true
            isLoadingOptions = true
            Task {
                do {
                    let options = try await agentManager.requestCommandOptions(
                        agentId: agent.id,
                        command: command.name
                    )
                    await MainActor.run {
                        commandOptions = options
                        isLoadingOptions = false
                    }
                } catch {
                    await MainActor.run {
                        commandOptions = []
                        isLoadingOptions = false
                        showOptionsPicker = false
                    }
                }
            }
            
        case .panel, .simple:
            // Execute directly
            inputText = ""
            onSlashCommand(command, nil)
        }
    }
    
    private func handleOptionSelection(_ option: CommandOption) {
        guard let command = currentOptionsCommand else { return }
        dismissOptionsPicker()
        inputText = ""
        onSlashCommand(command, option.value)
    }
    
    private func dismissSlashPicker() {
        showSlashPicker = false
        slashFilterText = ""
    }
    
    private func dismissOptionsPicker() {
        showOptionsPicker = false
        currentOptionsCommand = nil
        commandOptions = []
        optionsFilterText = ""
        isLoadingOptions = false
    }
    
    private func send() {
        guard canSend else { return }
        
        let message = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let images = imageAttachments
        inputText = ""
        imageAttachments = []
        onSend(message, images)
    }
    
    private func pickImages() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            UTType.png,
            UTType.jpeg,
            UTType.gif,
            UTType.webP
        ]
        
        if panel.runModal() == .OK {
            for url in panel.urls {
                if let data = try? Data(contentsOf: url) {
                    imageAttachments.append(data)
                }
            }
        }
    }
}

#Preview {
    let workspace = Workspace(
        name: "Test Project",
        path: URL(fileURLWithPath: "/tmp/test")
    )
    let agent = Agent(
        name: "Test Agent",
        workspace: workspace
    )
    VStack {
        Spacer()
        ChatInputView(agent: agent, onSend: { message, images in
            print("Sent: \(message), images: \(images.count)")
        }, onSlashCommand: { command, value in
            print("Command: /\(command.name), value: \(value ?? "nil")")
        })
        .padding()
    }
    .frame(width: 400, height: 200)
}
#endif

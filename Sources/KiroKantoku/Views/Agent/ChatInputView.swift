#if os(macOS)
import SwiftUI
import UniformTypeIdentifiers

/// Text input area for composing and sending chat messages with slash command autocomplete
public struct ChatInputView: View {
    let agent: Agent?
    let onSend: (String, [Data]) -> Void
    let onSlashCommand: ((SlashCommand, String?) -> Void)?
    
    @Environment(AgentManager.self) private var agentManager
    
    @State private var inputText: String = ""
    @State private var imageAttachments: [Data] = []
    @FocusState private var isFocused: Bool
    @State private var isPhotoHovered: Bool = false
    @State private var isSendHovered: Bool = false
    
    // Slash command autocomplete state
    @State private var showSlashPicker: Bool = false
    @State private var slashFilterText: String = ""
    
    // Command options picker state
    @State private var showOptionsPicker: Bool = false
    @State private var currentOptionsCommand: SlashCommand? = nil
    @State private var commandOptions: [CommandOption] = []
    @State private var optionsFilterText: String = ""
    @State private var isLoadingOptions: Bool = false
    
    // Keyboard navigation state for pickers
    @State private var slashSelectedIndex: Int = 0
    @State private var optionsSelectedIndex: Int = 0
    
    public init(
        agent: Agent? = nil,
        onSend: @escaping (String, [Data]) -> Void,
        onSlashCommand: ((SlashCommand, String?) -> Void)? = nil
    ) {
        self.agent = agent
        self.onSend = onSend
        self.onSlashCommand = onSlashCommand
    }
    
    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !imageAttachments.isEmpty
    }
    
    /// Merged list of all available slash commands
    private var allCommands: [SlashCommand] {
        guard let agent else { return [] }
        return mergeSlashCommands(
            acpCommands: agent.availableCommands,
            kiroCommands: agent.kiroAvailableCommands
        )
    }
    
    /// Filtered slash commands for the current filter text
    private var filteredSlashCommands: [SlashCommand] {
        if slashFilterText.isEmpty {
            return allCommands
        }
        let query = slashFilterText.lowercased()
        return allCommands.filter { $0.name.lowercased().contains(query) }
    }
    
    /// Filtered command options for the current filter text
    private var filteredCommandOptions: [CommandOption] {
        if optionsFilterText.isEmpty {
            return commandOptions
        }
        let query = optionsFilterText.lowercased()
        return commandOptions.filter {
            $0.label.lowercased().contains(query) ||
            ($0.description?.lowercased().contains(query) ?? false)
        }
    }
    
    public var body: some View {
        VStack(spacing: 4) {
            if !imageAttachments.isEmpty {
                imageAttachmentsBar
            }
            ZStack(alignment: .bottom) {
                if showSlashPicker {
                    slashPickerOverlay
                }
                if showOptionsPicker {
                    optionsPickerOverlay
                }
                inputBar
            }
        }
        .padding(.horizontal, DesignConstants.spacingLG)
        .padding(.vertical, DesignConstants.spacingMD)
        .onChange(of: inputText) { _, newValue in
            updateSlashPickerState(newValue)
        }
    }
    
    // MARK: - Extracted Subviews
    
    private var imageAttachmentsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(imageAttachments.indices, id: \.self) { index in
                    ZStack(alignment: .topTrailing) {
                        if let nsImage = NSImage(data: imageAttachments[index]) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 48, height: 48)
                                .clipShape(RoundedRectangle(cornerRadius: DesignConstants.cornerRadiusMedium))
                        } else {
                            RoundedRectangle(cornerRadius: DesignConstants.cornerRadiusMedium)
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
    
    private var slashPickerOverlay: some View {
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
                },
                selectedIndex: $slashSelectedIndex
            )
            .padding(.horizontal, DesignConstants.spacingSM)
        }
        .offset(y: -44)
        .zIndex(1)
    }
    
    private var optionsPickerOverlay: some View {
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
                        .shadow(color: .black.opacity(DesignConstants.popoverShadowOpacity), radius: DesignConstants.popoverShadowRadius, y: -2)
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
                    },
                    selectedIndex: $optionsSelectedIndex
                )
            }
        }
        .padding(.horizontal, DesignConstants.spacingSM)
        .offset(y: -44)
        .zIndex(1)
    }
    
    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Button(action: pickImages) {
                Image(systemName: "photo")
                    .font(.system(size: 16))
                    .foregroundColor(isPhotoHovered ? .primary : .secondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isPhotoHovered = hovering
                }
            }
            .padding(.leading, 6)
            .padding(.bottom, 4)
            
            textEditor
            
            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(canSend ? .accentColor : .secondary.opacity(0.4))
                    .scaleEffect(isSendHovered && canSend ? 1.08 : 1.0)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .keyboardShortcut(.return, modifiers: .command)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isSendHovered = hovering
                }
            }
            .padding(.trailing, 6)
            .padding(.bottom, 4)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    isFocused ? Color.accentColor.opacity(0.5) : Color(nsColor: .separatorColor).opacity(0.3),
                    lineWidth: isFocused ? 1.5 : 0.5
                )
        )
        .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
        .frame(maxWidth: .infinity)
    }
    
    private var textEditor: some View {
        TextEditor(text: $inputText)
            .font(.body)
            .focused($isFocused)
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .frame(minHeight: 56, maxHeight: 300)
            .onKeyPress(.init("v"), modifiers: .command) {
                let pasteboard = NSPasteboard.general
                let hasImage = pasteboard.types?.contains(where: { $0 == .png || $0 == .tiff || $0 == .init("public.jpeg") }) ?? false
                if hasImage {
                    return pasteImagesFromClipboard() ? .handled : .ignored
                }
                return .ignored
            }
            .onKeyPress(.upArrow) {
                if showSlashPicker {
                    if slashSelectedIndex > 0 { slashSelectedIndex -= 1 }
                    return .handled
                }
                if showOptionsPicker {
                    if optionsSelectedIndex > 0 { optionsSelectedIndex -= 1 }
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(.downArrow) {
                if showSlashPicker {
                    let count = filteredSlashCommands.count
                    if slashSelectedIndex < count - 1 { slashSelectedIndex += 1 }
                    return .handled
                }
                if showOptionsPicker {
                    let count = filteredCommandOptions.count
                    if optionsSelectedIndex < count - 1 { optionsSelectedIndex += 1 }
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(.return) {
                if showSlashPicker {
                    let cmds = filteredSlashCommands
                    if slashSelectedIndex >= 0 && slashSelectedIndex < cmds.count {
                        handleCommandSelection(cmds[slashSelectedIndex])
                    }
                    return .handled
                }
                if showOptionsPicker {
                    let opts = filteredCommandOptions
                    if optionsSelectedIndex >= 0 && optionsSelectedIndex < opts.count {
                        handleOptionSelection(opts[optionsSelectedIndex])
                    }
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(.escape) {
                if showSlashPicker {
                    dismissSlashPicker()
                    return .handled
                }
                if showOptionsPicker {
                    dismissOptionsPicker()
                    return .handled
                }
                return .ignored
            }
    }
    
    // MARK: - Slash Command Logic
    
    private func updateSlashPickerState(_ text: String) {
        guard agent != nil else {
            showSlashPicker = false
            slashFilterText = ""
            return
        }
        if text.hasPrefix("/") && !showOptionsPicker {
            let afterSlash = String(text.dropFirst())
            // Only show picker if no space (user is still typing the command name)
            if !afterSlash.contains(" ") {
                let oldFilter = slashFilterText
                slashFilterText = afterSlash
                if oldFilter != afterSlash {
                    slashSelectedIndex = 0
                }
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
            onSlashCommand?(command, nil)
            
        case .selection:
            // Show options picker
            inputText = ""
            currentOptionsCommand = command
            showOptionsPicker = true
            isLoadingOptions = true
            Task {
                guard let agent else { return }
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
            onSlashCommand?(command, nil)
        }
    }
    
    private func handleOptionSelection(_ option: CommandOption) {
        guard let command = currentOptionsCommand else { return }
        dismissOptionsPicker()
        inputText = ""
        onSlashCommand?(command, option.value)
    }
    
    private func dismissSlashPicker() {
        showSlashPicker = false
        slashFilterText = ""
        slashSelectedIndex = 0
    }
    
    private func dismissOptionsPicker() {
        showOptionsPicker = false
        currentOptionsCommand = nil
        commandOptions = []
        optionsFilterText = ""
        isLoadingOptions = false
        optionsSelectedIndex = 0
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
    
    @discardableResult
    private func pasteImagesFromClipboard() -> Bool {
        let pasteboard = NSPasteboard.general
        
        // Try PNG first
        if let pngData = pasteboard.data(forType: .png) {
            imageAttachments.append(pngData)
            return true
        }
        
        // Try JPEG
        if let jpegData = pasteboard.data(forType: .init("public.jpeg")) {
            // Convert JPEG to PNG for consistent handling
            if let bitmapRep = NSBitmapImageRep(data: jpegData),
               let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                imageAttachments.append(pngData)
                return true
            }
        }
        
        // Fall back to TIFF (macOS stores most copied images as TIFF)
        if let tiffData = pasteboard.data(forType: .tiff) {
            // Convert TIFF to PNG
            if let bitmapRep = NSBitmapImageRep(data: tiffData),
               let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                imageAttachments.append(pngData)
                return true
            }
        }
        
        return false
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

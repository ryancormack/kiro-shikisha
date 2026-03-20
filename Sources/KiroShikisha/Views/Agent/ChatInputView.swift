#if os(macOS)
import SwiftUI
import UniformTypeIdentifiers

/// Text input area for composing and sending chat messages
public struct ChatInputView: View {
    let onSend: (String, [Data]) -> Void
    
    @State private var inputText: String = ""
    @State private var imageAttachments: [Data] = []
    @FocusState private var isFocused: Bool
    
    public init(onSend: @escaping (String, [Data]) -> Void) {
        self.onSend = onSend
    }
    
    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
    VStack {
        Spacer()
        ChatInputView { message, images in
            print("Sent: \(message), images: \(images.count)")
        }
        .padding()
    }
    .frame(width: 400, height: 200)
}
#endif

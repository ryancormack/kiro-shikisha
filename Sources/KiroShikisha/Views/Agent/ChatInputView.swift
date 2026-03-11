#if os(macOS)
import SwiftUI

/// Text input area for composing and sending chat messages
public struct ChatInputView: View {
    let onSend: (String) -> Void
    
    @State private var inputText: String = ""
    @FocusState private var isFocused: Bool
    
    public init(onSend: @escaping (String) -> Void) {
        self.onSend = onSend
    }
    
    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    public var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextEditor(text: $inputText)
                .font(.body)
                .focused($isFocused)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .frame(minHeight: 36, idealHeight: 36, maxHeight: 120)
            
            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(canSend ? .blue : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .keyboardShortcut(.return, modifiers: .command)
        }
    }
    
    private func send() {
        guard canSend else { return }
        
        let message = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        inputText = ""
        onSend(message)
    }
}

#Preview {
    VStack {
        Spacer()
        ChatInputView { message in
            print("Sent: \(message)")
        }
        .padding()
    }
    .frame(width: 400, height: 200)
}
#endif

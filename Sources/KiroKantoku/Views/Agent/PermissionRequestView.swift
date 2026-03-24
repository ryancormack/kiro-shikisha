#if os(macOS)
import SwiftUI

/// Inline permission request card shown when the agent needs user approval
struct PermissionRequestView: View {
    let request: PendingPermissionRequest
    let onSelect: (String) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundColor(.orange)
                Text("Permission Required")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            Text("**\(request.toolCallTitle)** wants to execute:")
                .font(.subheadline)
            
            if let rawInput = request.rawInput {
                Text(rawInput)
                    .font(.system(.caption, design: .monospaced))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            HStack(spacing: 8) {
                ForEach(request.options) { option in
                    Button(action: { onSelect(option.optionId) }) {
                        Text(option.label)
                            .font(.subheadline)
                            .padding(.horizontal, DesignConstants.buttonPaddingH)
                            .padding(.vertical, DesignConstants.buttonPaddingV)
                    }
                    .buttonStyle(.bordered)
                    .tint(colorForKind(option.kind))
                }
                
                Spacer()
                
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .font(.subheadline)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: DesignConstants.cardCornerRadius)
                .fill(Color.orange.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignConstants.cardCornerRadius)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }
    
    private func colorForKind(_ kind: String) -> Color {
        switch kind {
        case "allow_once", "allow_always":
            return .green
        case "reject_once", "reject_always":
            return .red
        default:
            return .blue
        }
    }
}
#endif

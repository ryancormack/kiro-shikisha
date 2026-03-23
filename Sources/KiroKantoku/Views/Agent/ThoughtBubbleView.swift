#if os(macOS)
import SwiftUI

/// Collapsible view showing the agent's internal reasoning/thinking
struct ThoughtBubbleView: View {
    let content: String
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() } }) {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 10)
                    Image(systemName: "brain")
                        .foregroundColor(.purple)
                        .frame(width: 14)
                    Text("Thinking\u{2026}")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(content)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
                    .textSelection(.enabled)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
                    .frame(maxHeight: 200)
            }
        }
        .background(Color.purple.opacity(0.05))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.purple.opacity(0.3))
                .frame(width: 2)
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignConstants.cornerRadiusMedium))
    }
}
#endif

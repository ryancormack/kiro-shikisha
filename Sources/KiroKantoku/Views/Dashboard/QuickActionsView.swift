#if os(macOS)
import SwiftUI

/// Floating panel with bulk actions for managing all tasks
public struct QuickActionsView: View {
    @Environment(TaskManager.self) var taskManager

    /// Callback when cancel all is triggered
    let onCancelAll: () async -> Void
    /// Callback when refresh all is triggered
    let onRefreshAll: () async -> Void
    /// Callback when new task is requested
    let onNewTask: (() -> Void)?

    @State private var isCancellingAll: Bool = false
    @State private var isRefreshingAll: Bool = false
    @State private var isNewTaskHovered: Bool = false
    @State private var isCancelHovered: Bool = false
    @State private var isRefreshHovered: Bool = false

    public init(
        onCancelAll: @escaping () async -> Void,
        onRefreshAll: @escaping () async -> Void,
        onNewTask: (() -> Void)? = nil
    ) {
        self.onCancelAll = onCancelAll
        self.onRefreshAll = onRefreshAll
        self.onNewTask = onNewTask
    }

    private var activeTaskCount: Int {
        taskManager.activeTasks.count
    }

    private var attentionCount: Int {
        taskManager.tasksNeedingAttention.count
    }

    private var hasActiveTasks: Bool {
        activeTaskCount > 0
    }

    public var body: some View {
        HStack(spacing: 16) {
            // Task count display
            taskCountDisplay

            Divider()
                .frame(height: 24)

            // New Task button
            if let onNewTask = onNewTask {
                newTaskButton(action: onNewTask)
            }

            // Cancel All Tasks button
            cancelAllButton

            // Refresh All button
            refreshAllButton
        }
        .padding(.horizontal, DesignConstants.spacingLG)
        .padding(.vertical, DesignConstants.spacingSM)
        .background(backgroundView)
    }

    private var taskCountDisplay: some View {
        HStack(spacing: 6) {
            Image(systemName: "checklist")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Text("\(activeTaskCount)")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)

            Text("task\(activeTaskCount == 1 ? "" : "s")")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            if attentionCount > 0 {
                Text("\(attentionCount) needs attention")
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
            }
        }
    }

    private func newTaskButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 12))
                Text("New Task")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(.accentColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: DesignConstants.buttonCornerRadius).fill(Color.primary.opacity(isNewTaskHovered ? DesignConstants.hoverBackgroundOpacity : 0)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isNewTaskHovered = hovering
            }
        }
        .help("Create a new task")
    }

    private var cancelAllButton: some View {
        Button {
            Task {
                isCancellingAll = true
                await onCancelAll()
                isCancellingAll = false
            }
        } label: {
            HStack(spacing: 4) {
                if isCancellingAll {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 12))
                }
                Text("Cancel All Tasks")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(hasActiveTasks ? .red : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: DesignConstants.buttonCornerRadius).fill(Color.primary.opacity(isCancelHovered ? DesignConstants.hoverBackgroundOpacity : 0)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!hasActiveTasks || isCancellingAll)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isCancelHovered = hovering
            }
        }
        .help("Cancel all active tasks")
    }

    private var refreshAllButton: some View {
        Button {
            Task {
                isRefreshingAll = true
                await onRefreshAll()
                isRefreshingAll = false
            }
        } label: {
            HStack(spacing: 4) {
                if isRefreshingAll {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                Text("Refresh All")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(.accentColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: DesignConstants.buttonCornerRadius).fill(Color.primary.opacity(isRefreshHovered ? DesignConstants.hoverBackgroundOpacity : 0)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isRefreshingAll)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isRefreshHovered = hovering
            }
        }
        .help("Reconnect all agents")
    }

    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: DesignConstants.cardCornerRadius)
            .fill(Color(nsColor: .controlBackgroundColor))
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    QuickActionsView(
        onCancelAll: {
            try? await Task.sleep(for: .seconds(1))
        },
        onRefreshAll: {
            try? await Task.sleep(for: .seconds(1))
        },
        onNewTask: {
            print("New task requested")
        }
    )
    .environment(TaskManager())
    .padding()
    .frame(width: 500)
}
#endif

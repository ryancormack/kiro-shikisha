#if os(macOS)
import SwiftUI

/// Pixel art "House of Kiroween" office scene showing agent ghosts at work
public struct KiroweenOfficeView: View {
    @Environment(TaskManager.self) var taskManager

    var onNewTask: (() -> Void)?
    var onSelectTask: ((AgentTask) -> Void)?

    @State private var floatPhase: Bool = false
    @State private var glowPhase: Bool = false
    @State private var showInterior: Bool = false

    private var workingTasks: [AgentTask] {
        taskManager.allTasks.filter { $0.status == .working || $0.status == .starting }
    }

    private var attentionTasks: [AgentTask] {
        taskManager.allTasks.filter { $0.status == .needsAttention }
    }

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.15, green: 0.05, blue: 0.25), Color(red: 0.08, green: 0.02, blue: 0.15)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Text("🏚️ House of Kiroween")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
                    )
                    .shadow(color: .orange.opacity(0.5), radius: 8)
                    .padding(.top, 16)

                // House background — click to enter
                cachedImage("house-of-kiroween")
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 220)
                    .clipped()
                    .contentShape(Rectangle())
                    .onTapGesture { showInterior = true }
                    .overlay(alignment: .bottom) {
                        Text("Click to enter")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.black.opacity(0.4))
                            .clipShape(Capsule())
                            .padding(.bottom, 6)
                    }

                // Agent ghosts
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 24) {
                        ForEach(taskManager.allTasks, id: \.id) { task in
                            ghostAgent(for: task)
                                .onTapGesture { onSelectTask?(task) }
                        }

                        if let onNewTask {
                            addGhostButton(action: onNewTask)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                }

                // Pumpkin footer
                pumpkinPatch
                    .padding(.bottom, 8)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                floatPhase = true
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                glowPhase = true
            }
        }
        .sheet(isPresented: $showInterior) {
            KiroweenInteriorView(
                onSelectTask: { task in
                    showInterior = false
                    onSelectTask?(task)
                },
                onDismiss: { showInterior = false }
            )
            .frame(minWidth: 700, minHeight: 500)
        }
    }

    // MARK: - Ghost Agents

    private func ghostAgent(for task: AgentTask) -> some View {
        let isWorking = task.status == .working || task.status == .starting
        let needsAttention = task.status == .needsAttention

        return VStack(spacing: 6) {
            ZStack {
                Ellipse()
                    .fill(
                        needsAttention ? Color.orange.opacity(0.3) :
                        isWorking ? Color.blue.opacity(0.25) :
                        Color.purple.opacity(0.15)
                    )
                    .frame(width: 100, height: 20)
                    .offset(y: 55)
                    .blur(radius: 8)

                cachedImage(isWorking ? "kiro-ghost-working" : "kiro-ghost")
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .offset(y: floatPhase ? -8 : 0)

                if needsAttention {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 16, height: 16)
                        .overlay(Text("!").font(.system(size: 10, weight: .bold)).foregroundColor(.white))
                        .offset(x: 40, y: -40)
                        .opacity(glowPhase ? 1 : 0.4)
                }
            }

            Text(task.name)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(maxWidth: 120)

            Text(task.status.rawValue.capitalized)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(task.status.displayColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(task.status.displayColor.opacity(0.2))
                .clipShape(Capsule())
        }
        .frame(width: 130)
    }

    private func addGhostButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    cachedImage("kiro-ghost")
                        .resizable()
                        .interpolation(.none)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .opacity(0.3)
                        .offset(y: floatPhase ? -8 : 0)

                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white.opacity(0.7))
                }

                Text("New Task")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }
            .frame(width: 130)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Pumpkin Patch

    private var pumpkinPatch: some View {
        HStack(spacing: 16) {
            cachedImage("pixel-pumpkins")
                .resizable()
                .interpolation(.none)
                .aspectRatio(contentMode: .fit)
                .frame(height: 80)
                .shadow(color: .orange.opacity(glowPhase ? 0.4 : 0.2), radius: 12)

            VStack(alignment: .leading, spacing: 4) {
                let total = taskManager.allTasks.count
                let active = workingTasks.count
                let attention = attentionTasks.count

                Text("\(total) ghost\(total == 1 ? "" : "s") in the office")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))

                if active > 0 {
                    Text("🔮 \(active) working")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.cyan)
                }
                if attention > 0 {
                    Text("⚠️ \(attention) need\(attention == 1 ? "s" : "") attention")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.orange)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Helpers

    private func cachedImage(_ name: String) -> Image {
        guard let nsImage = KiroweenImageCache.shared.image(named: name) else {
            return Image(systemName: "ghost.fill")
        }
        return Image(nsImage: nsImage)
    }
}

#Preview {
    KiroweenOfficeView(
        onNewTask: { print("New task") },
        onSelectTask: { print("Selected: \($0.name)") }
    )
    .environment(TaskManager())
    .frame(width: 800, height: 500)
}
#endif

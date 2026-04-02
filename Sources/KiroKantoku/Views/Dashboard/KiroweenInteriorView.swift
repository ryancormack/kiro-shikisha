#if os(macOS)
import SwiftUI

/// Interior view of the Kiroween office — shown when clicking the house
public struct KiroweenInteriorView: View {
    @Environment(TaskManager.self) var taskManager

    var onSelectTask: ((AgentTask) -> Void)?
    var onDismiss: (() -> Void)?

    @State private var floatPhase: Bool = false

    // Desk positions — on the chair seats in front of monitors
    private let deskPositions: [(x: CGFloat, y: CGFloat)] = [
        (0.185, 0.51), (0.37, 0.51),  // back row chairs
        (0.185, 0.80), (0.55, 0.80),  // front row chairs
    ]

    // Kitchen/break area — stacked vertically in bottom right
    private let kitchenPositions: [(x: CGFloat, y: CGFloat)] = [
        (0.75, 0.65),
        (0.75, 0.77),
        (0.75, 0.89),
        (0.75, 0.97),
    ]

    private var workingTasks: [AgentTask] {
        taskManager.allTasks.filter { $0.status == .working || $0.status == .starting }
    }

    private var idleTasks: [AgentTask] {
        taskManager.allTasks.filter { !($0.status == .working || $0.status == .starting) }
    }

    public var body: some View {
        ZStack {
            Color(red: 0.1, green: 0.03, blue: 0.18)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                // Header
                HStack {
                    Text("🏚️ Inside the Office")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
                        )

                    Spacer()

                    if let onDismiss {
                        Button(action: onDismiss) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                // Office scene with ghost overlays
                GeometryReader { geo in
                    let imageAspect: CGFloat = 1024.0 / 768.0
                    let geoAspect = geo.size.width / geo.size.height
                    let imgW = geoAspect > imageAspect ? geo.size.height * imageAspect : geo.size.width
                    let imgH = geoAspect > imageAspect ? geo.size.height : geo.size.width / imageAspect
                    let offsetX = (geo.size.width - imgW) / 2
                    let offsetY = (geo.size.height - imgH) / 2

                    ZStack(alignment: .topLeading) {
                        cachedImage("kiroween-office-interior")
                            .resizable()
                            .interpolation(.none)
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        // Working ghosts at desks
                        ForEach(Array(workingTasks.prefix(deskPositions.count).enumerated()), id: \.element.id) { index, task in
                            let pos = deskPositions[index]
                            ghostSprite(task: task, imageName: "kiro-ghost-working", size: 64)
                                .position(x: offsetX + imgW * pos.x, y: offsetY + imgH * pos.y)
                        }

                        // Idle/chilling ghosts in kitchen
                        ForEach(Array(idleTasks.prefix(kitchenPositions.count).enumerated()), id: \.element.id) { index, task in
                            let pos = kitchenPositions[index]
                            ghostSprite(task: task, imageName: "kiro-ghost-chilling", size: 56)
                                .position(x: offsetX + imgW * pos.x, y: offsetY + imgH * pos.y)
                        }
                    }
                }
                .padding(.horizontal, 16)

                // Agent roster bar
                agentRoster
                    .padding(.bottom, 8)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                floatPhase = true
            }
        }
    }

    // MARK: - Ghost Sprite

    private func ghostSprite(task: AgentTask, imageName: String, size: CGFloat) -> some View {
        VStack(spacing: 2) {
            cachedImage(imageName)
                .resizable()
                .interpolation(.none)
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .offset(y: floatPhase ? -3 : 0)
                .shadow(color: task.status.displayColor.opacity(0.5), radius: 6)

            Text(task.name)
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(.black.opacity(0.6))
                .clipShape(Capsule())
        }
        .onTapGesture { onSelectTask?(task) }
    }

    // MARK: - Agent Roster

    private var agentRoster: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(taskManager.allTasks, id: \.id) { task in
                    let isWorking = task.status == .working || task.status == .starting
                    Button {
                        onSelectTask?(task)
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(task.status.displayColor)
                                .frame(width: 8, height: 8)

                            Text(task.name)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            Text(isWorking ? "💻" : "☕")
                                .font(.system(size: 10))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.6))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Helpers

    private func cachedImage(_ name: String) -> Image {
        guard let nsImage = KiroweenImageCache.shared.image(named: name) else {
            return Image(systemName: "ghost.fill")
        }
        return Image(nsImage: nsImage)
    }
}

/// Shared cache — also used by KiroweenOfficeView
@MainActor
final class KiroweenImageCache {
    static let shared = KiroweenImageCache()
    private var cache: [String: NSImage] = [:]

    /// Resolve the resource bundle without crashing.
    /// Bundle.module uses fatalError when the SPM resource bundle isn't found,
    /// which happens when the app is distributed as a .app bundle (e.g. Homebrew cask).
    private static let resourceBundle: Bundle? = {
        // 1. SPM resource bundle next to the main bundle
        let mainPath = Bundle.main.bundleURL
            .appendingPathComponent("KiroKantoku_KiroKantoku.bundle").path
        if let b = Bundle(path: mainPath) { return b }

        // 2. Inside Contents/Resources (standard .app layout)
        let appResources = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources/KiroKantoku_KiroKantoku.bundle").path
        if let b = Bundle(path: appResources) { return b }

        // 3. Fallback: main bundle itself (resources copied directly)
        if Bundle.main.url(forResource: "kiro-ghost", withExtension: "png", subdirectory: "Kiroween") != nil {
            return Bundle.main
        }

        return nil
    }()

    func image(named name: String) -> NSImage? {
        if let cached = cache[name] { return cached }
        guard let bundle = Self.resourceBundle,
              let url = bundle.url(forResource: name, withExtension: "png", subdirectory: "Kiroween"),
              let img = NSImage(contentsOf: url) else { return nil }
        cache[name] = img
        return img
    }
}

#Preview {
    KiroweenInteriorView(
        onSelectTask: { print("Selected: \($0.name)") },
        onDismiss: { print("Dismiss") }
    )
    .environment(TaskManager())
    .frame(width: 700, height: 500)
}
#endif

#if os(macOS)
import SwiftUI

/// The main container view for the pixel office visualization
struct PixelOfficeView: View {
    @Environment(TaskManager.self) var taskManager
    @Environment(AgentManager.self) var agentManager
    @State private var viewModel = PixelOfficeViewModel()
    @State private var animationTimer: Timer?

    private let tileSize = PixelOfficeConstants.tileSize
    private let officeWidth = PixelOfficeConstants.officeWidth
    private let officeHeight = PixelOfficeConstants.officeHeight

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            Divider()

            ZStack(alignment: .topLeading) {
                officeFloor
                officeWalls
                furnitureLayer
                characterLayer
            }
            .frame(
                width: CGFloat(officeWidth) * tileSize,
                height: CGFloat(officeHeight) * tileSize
            )
            .clipped()

            Divider()

            statusBar
        }
        .background(Color(red: 0.10, green: 0.05, blue: 0.14))
        .onAppear {
            updateCharacters()
            startAnimationTimer()
        }
        .onDisappear {
            stopAnimationTimer()
        }
        .onChange(of: taskManager.allTasks.map { "\($0.id)-\($0.status.rawValue)" }) { _, _ in
            updateCharacters()
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Text("House of Kiroween")
                .font(.headline)

            Spacer()

            Text("\(taskManager.activeTasks.count) active tasks")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, DesignConstants.spacingLG)
        .padding(.vertical, DesignConstants.spacingSM)
    }

    // MARK: - Office Floor

    private var officeFloor: some View {
        let floorLight = Color(red: 0.15, green: 0.08, blue: 0.20)
        let floorDark = Color(red: 0.12, green: 0.06, blue: 0.16)

        return Canvas { context, size in
            let ts = tileSize
            for row in 0..<officeHeight {
                for col in 0..<officeWidth {
                    let isLight = (row + col) % 2 == 0
                    let rect = CGRect(
                        x: Double(col) * ts,
                        y: Double(row) * ts,
                        width: ts,
                        height: ts
                    )
                    context.fill(
                        Path(rect),
                        with: .color(isLight ? floorLight : floorDark)
                    )
                }
            }
        }
        .frame(
            width: CGFloat(officeWidth) * tileSize,
            height: CGFloat(officeHeight) * tileSize
        )
    }

    // MARK: - Office Walls

    private var officeWalls: some View {
        Rectangle()
            .fill(Color(red: 0.20, green: 0.12, blue: 0.25))
            .frame(
                width: CGFloat(officeWidth) * tileSize,
                height: tileSize * 2
            )
    }

    // MARK: - Furniture

    private var furnitureLayer: some View {
        ZStack(alignment: .topLeading) {
            // Desks and chairs at each desk position
            ForEach(0..<PixelOfficeConstants.deskPositions.count, id: \.self) { i in
                let pos = PixelOfficeConstants.deskPositions[i]
                DeskView()
                    .position(
                        x: Double(pos.x) * tileSize + tileSize / 2,
                        y: Double(pos.y) * tileSize - tileSize * 0.3
                    )
                ChairView()
                    .position(
                        x: Double(pos.x) * tileSize + tileSize / 2,
                        y: Double(pos.y) * tileSize + tileSize * 0.5
                    )
            }

            // Coffee counter
            CoffeeCounterView()
                .position(
                    x: 16.5 * tileSize,
                    y: 5.0 * tileSize
                )

            // Coffee machine
            CoffeeMachineView()
                .position(
                    x: 15.5 * tileSize,
                    y: 3.5 * tileSize
                )

            // Decorative plants
            PlantView()
                .position(x: 1.0 * tileSize, y: 2.5 * tileSize)
            PlantView()
                .position(x: 18.5 * tileSize, y: 2.5 * tileSize)
            PlantView()
                .position(x: 1.0 * tileSize, y: 10.0 * tileSize)

            // Floating candles
            FloatingCandleView()
                .position(x: 2.0 * tileSize, y: 1.5 * tileSize)
            FloatingCandleView()
                .position(x: 14.0 * tileSize, y: 1.5 * tileSize)
            FloatingCandleView()
                .position(x: 10.0 * tileSize, y: 10.0 * tileSize)
        }
        .frame(
            width: CGFloat(officeWidth) * tileSize,
            height: CGFloat(officeHeight) * tileSize
        )
    }

    // MARK: - Characters

    private var characterLayer: some View {
        ZStack(alignment: .topLeading) {
            ForEach(viewModel.characters) { character in
                PixelSpriteView(character: character)
                    .position(
                        x: character.positionX * tileSize + tileSize / 2,
                        y: character.positionY * tileSize + tileSize / 2
                    )
            }
        }
        .frame(
            width: CGFloat(officeWidth) * tileSize,
            height: CGFloat(officeHeight) * tileSize
        )
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack(spacing: DesignConstants.spacingLG) {
            legendItem(color: .green, label: "Working")
            legendItem(color: .orange, label: "On Break")
            legendItem(color: .yellow, label: "Needs Input")
            legendItem(color: .purple, label: "Waiting for Work")

            Spacer()
        }
        .padding(.horizontal, DesignConstants.spacingLG)
        .padding(.vertical, DesignConstants.spacingXS)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Animation

    private func startAnimationTimer() {
        animationTimer = Timer.scheduledTimer(
            withTimeInterval: PixelOfficeConstants.animationTickInterval,
            repeats: true
        ) { _ in
            Task { @MainActor in
                viewModel.moveCharactersTowardTargets()
                viewModel.advanceAnimations()
            }
        }
    }

    private func stopAnimationTimer() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    private func updateCharacters() {
        var agentStatuses: [UUID: AgentStatus] = [:]
        for task in taskManager.allTasks {
            if let agentId = task.agentId,
               let agent = agentManager.getAgent(id: agentId) {
                agentStatuses[task.id] = agent.status
            }
        }
        viewModel.updateCharacters(from: taskManager.allTasks, agentStatuses: agentStatuses)
    }
}
#endif

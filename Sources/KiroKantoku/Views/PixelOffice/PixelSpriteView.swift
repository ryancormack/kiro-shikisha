#if os(macOS)
import SwiftUI

/// Renders a single pixel ghost character using SwiftUI shapes
struct PixelSpriteView: View {
    let character: PixelCharacter

    private var palette: (hair: String, shirt: String) {
        let palettes = PixelOfficeConstants.characterPalettes
        let index = character.characterIndex % palettes.count
        return palettes[index]
    }

    /// Ghost body color (mapped from palette.hair)
    private var bodyColor: Color { Color(hex: palette.hair) }
    /// Accent / glow color (mapped from palette.shirt)
    private var glowColor: Color { Color(hex: palette.shirt) }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                ghostBody
                    .frame(width: 28, height: 36)

                if character.state == .needsInput {
                    speechBubble
                        .offset(y: -20)
                }

                if character.state == .waitingForWork {
                    zzzBubble
                        .offset(y: -18)
                }
            }

            Text(character.taskName)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(.horizontal, 4)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.black.opacity(0.7))
                )
                .frame(width: 50)
        }
    }

    // MARK: - Ghost Body

    @ViewBuilder
    private var ghostBody: some View {
        let verticalBob = ghostBob

        ZStack {
            // Glow effect behind ghost
            Ellipse()
                .fill(glowColor.opacity(0.25))
                .frame(width: 22, height: 24)
                .blur(radius: 3)
                .offset(y: verticalBob)

            VStack(spacing: 0) {
                // Main ghost body (rounded top)
                Capsule()
                    .fill(bodyColor)
                    .frame(width: 18, height: 20)

                // Wavy bottom edge (3 scallops)
                HStack(spacing: 0) {
                    Circle()
                        .fill(bodyColor)
                        .frame(width: 6, height: 6)
                    Circle()
                        .fill(bodyColor)
                        .frame(width: 6, height: 6)
                    Circle()
                        .fill(bodyColor)
                        .frame(width: 6, height: 6)
                }
                .offset(y: -3)
            }
            .offset(y: verticalBob)

            // Eyes
            ghostEyes
                .offset(y: verticalBob - 2)

            // State-specific overlays
            stateOverlay
                .offset(y: verticalBob)
        }
    }

    // MARK: - Ghost Eyes

    @ViewBuilder
    private var ghostEyes: some View {
        switch character.state {
        case .waitingForWork:
            // Half-closed eyes (thin horizontal ovals)
            HStack(spacing: 4) {
                Ellipse()
                    .fill(Color.white)
                    .frame(width: 5, height: 2)
                Ellipse()
                    .fill(Color.white)
                    .frame(width: 5, height: 2)
            }
        default:
            // Normal friendly round eyes
            HStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 5, height: 5)
                    Circle()
                        .fill(Color.black)
                        .frame(width: 2, height: 2)
                        .offset(x: 0.5, y: 0.5)
                }
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 5, height: 5)
                    Circle()
                        .fill(Color.black)
                        .frame(width: 2, height: 2)
                        .offset(x: 0.5, y: 0.5)
                }
            }
        }
    }

    // MARK: - State Overlay

    @ViewBuilder
    private var stateOverlay: some View {
        switch character.state {
        case .working:
            workingOverlay
        case .drinkingCoffee:
            potionOverlay
        case .walking:
            EmptyView()
        case .idle:
            EmptyView()
        case .needsInput:
            EmptyView()
        case .waitingForWork:
            EmptyView()
        }
    }

    // MARK: - Working Overlay (arms + keyboard glow)

    private var workingOverlay: some View {
        let raised = character.animationFrame % 2 == 0
        return ZStack {
            // Left arm bump
            Circle()
                .fill(bodyColor)
                .frame(width: 5, height: 5)
                .offset(x: -12, y: raised ? -2 : 0)

            // Right arm bump
            Circle()
                .fill(bodyColor)
                .frame(width: 5, height: 5)
                .offset(x: 12, y: raised ? 0 : -2)

            // Keyboard glow
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.cyan.opacity(0.6))
                .frame(width: 12, height: 3)
                .offset(y: 10)
        }
    }

    // MARK: - Potion Overlay (drinking coffee -> holding potion)

    private var potionOverlay: some View {
        ZStack {
            // Left arm bump (at side)
            Circle()
                .fill(bodyColor)
                .frame(width: 5, height: 5)
                .offset(x: -12, y: 0)

            // Right arm bump extended with potion bottle
            Circle()
                .fill(bodyColor)
                .frame(width: 5, height: 5)
                .offset(x: 13, y: -2)

            // Potion bottle
            VStack(spacing: 0) {
                // Bottle neck
                Rectangle()
                    .fill(Color(red: 0.3, green: 0.6, blue: 0.3))
                    .frame(width: 2, height: 3)
                // Bottle body
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(red: 0.4, green: 0.2, blue: 0.6))
                    .frame(width: 4, height: 5)
            }
            .offset(x: 16, y: -4)
        }
    }

    // MARK: - Speech Bubble

    private var speechBubble: some View {
        let scale: CGFloat = character.animationFrame % 2 == 0 ? 1.0 : 1.2

        return ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.yellow)
                .frame(width: 16, height: 14)

            Text("!")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.black)
        }
        .scaleEffect(scale)
    }

    // MARK: - Zzz Bubble (waitingForWork)

    private var zzzBubble: some View {
        let drift: CGFloat = character.animationFrame % 2 == 0 ? 0 : -2

        return Text("zzz")
            .font(.system(size: 7, weight: .medium))
            .foregroundColor(glowColor.opacity(0.8))
            .offset(x: 6, y: drift)
    }

    // MARK: - Helpers

    private var ghostBob: CGFloat {
        switch character.state {
        case .idle:
            return character.animationFrame % 2 == 0 ? 0 : -2
        case .walking:
            return character.animationFrame % 2 == 0 ? -2 : 2
        case .waitingForWork:
            return character.animationFrame % 2 == 0 ? -1 : 1
        default:
            return 0
        }
    }
}

// MARK: - Hex Color Extension

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
#endif

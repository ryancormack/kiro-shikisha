#if os(macOS)
import SwiftUI

/// Renders a single pixel character using SwiftUI shapes
struct PixelSpriteView: View {
    let character: PixelCharacter

    private var palette: (hair: String, shirt: String) {
        let palettes = PixelOfficeConstants.characterPalettes
        let index = character.characterIndex % palettes.count
        return palettes[index]
    }

    private var hairColor: Color { Color(hex: palette.hair) }
    private var shirtColor: Color { Color(hex: palette.shirt) }
    private let skinColor = Color(red: 0.93, green: 0.78, blue: 0.65)
    private let legColor = Color(red: 0.22, green: 0.22, blue: 0.28)
    private let shoeColor = Color(red: 0.18, green: 0.18, blue: 0.22)

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                characterBody
                    .frame(width: 24, height: 32)

                if character.state == .needsInput {
                    speechBubble
                        .offset(y: -18)
                }
            }

            Text(character.taskName)
                .font(.system(size: 8))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(width: 40)
        }
    }

    // MARK: - Character Body

    @ViewBuilder
    private var characterBody: some View {
        ZStack {
            // Legs
            legsView

            // Body (torso)
            Rectangle()
                .fill(shirtColor)
                .frame(width: 12, height: 10)
                .offset(y: 2)

            // Arms
            armsView

            // Head
            headView
        }
    }

    // MARK: - Head

    private var headView: some View {
        ZStack {
            // Hair (back)
            Ellipse()
                .fill(hairColor)
                .frame(width: 12, height: 12)

            // Face
            Ellipse()
                .fill(skinColor)
                .frame(width: 10, height: 9)
                .offset(y: 1)
        }
        .offset(y: idleBob - 11)
    }

    // MARK: - Arms

    @ViewBuilder
    private var armsView: some View {
        switch character.state {
        case .working:
            workingArms
        case .drinkingCoffee:
            coffeeArms
        default:
            // Default arms at sides
            HStack(spacing: 10) {
                Rectangle()
                    .fill(skinColor)
                    .frame(width: 4, height: 8)
                Rectangle()
                    .fill(skinColor)
                    .frame(width: 4, height: 8)
            }
            .offset(y: 2)
        }
    }

    private var workingArms: some View {
        let raised = character.animationFrame % 2 == 0
        return HStack(spacing: 6) {
            Rectangle()
                .fill(skinColor)
                .frame(width: 4, height: 6)
                .offset(y: raised ? -4 : -2)
            Rectangle()
                .fill(skinColor)
                .frame(width: 4, height: 6)
                .offset(y: raised ? -2 : -4)
        }
        .overlay(
            // Keyboard glow
            Rectangle()
                .fill(Color.cyan.opacity(0.5))
                .frame(width: 10, height: 2)
                .offset(y: 2)
        )
        .offset(y: 0)
    }

    private var coffeeArms: some View {
        HStack(spacing: 8) {
            // Left arm at side
            Rectangle()
                .fill(skinColor)
                .frame(width: 4, height: 8)
                .offset(y: 2)

            // Right arm extended with cup
            VStack(spacing: 0) {
                Rectangle()
                    .fill(skinColor)
                    .frame(width: 4, height: 6)
                // Coffee cup
                Rectangle()
                    .fill(Color(red: 0.55, green: 0.35, blue: 0.17))
                    .frame(width: 4, height: 4)
                    .cornerRadius(1)
            }
            .offset(y: -2)
        }
    }

    // MARK: - Legs

    @ViewBuilder
    private var legsView: some View {
        let walkOffset: CGFloat = character.state == .walking
            ? (character.animationFrame % 2 == 0 ? 3 : -3)
            : 0

        HStack(spacing: 4) {
            Rectangle()
                .fill(legColor)
                .frame(width: 4, height: 8)
                .offset(x: walkOffset)
            Rectangle()
                .fill(legColor)
                .frame(width: 4, height: 8)
                .offset(x: -walkOffset)
        }
        .offset(y: 13)
    }

    // MARK: - Speech Bubble

    private var speechBubble: some View {
        let scale: CGFloat = character.animationFrame % 2 == 0 ? 1.0 : 1.15

        return ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.yellow)
                .frame(width: 14, height: 12)

            Text("!")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.black)
        }
        .scaleEffect(scale)
    }

    // MARK: - Helpers

    private var idleBob: CGFloat {
        guard character.state == .idle else { return 0 }
        return character.animationFrame % 2 == 0 ? 0 : -1
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

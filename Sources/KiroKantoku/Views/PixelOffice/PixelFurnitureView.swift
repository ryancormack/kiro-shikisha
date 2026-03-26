#if os(macOS)
import SwiftUI

/// A dark gothic desk with a purple glowing monitor and candle
struct DeskView: View {
    var body: some View {
        ZStack(alignment: .top) {
            // Desk surface (very dark brown wood)
            Rectangle()
                .fill(Color(red: 0.15, green: 0.10, blue: 0.08))
                .frame(width: 40, height: 20)

            // Monitor
            ZStack {
                // Dark frame
                Rectangle()
                    .fill(Color(red: 0.12, green: 0.12, blue: 0.14))
                    .frame(width: 16, height: 12)
                // Purple glowing screen
                Rectangle()
                    .fill(Color(red: 0.45, green: 0.20, blue: 0.65))
                    .frame(width: 12, height: 8)
            }
            .offset(y: -10)

            // Candle
            VStack(spacing: 0) {
                // Flame
                Circle()
                    .fill(Color.yellow.opacity(0.9))
                    .frame(width: 3, height: 3)
                // Candle body
                Rectangle()
                    .fill(Color(red: 0.45, green: 0.30, blue: 0.15))
                    .frame(width: 2, height: 5)
            }
            .offset(x: 14, y: -8)
        }
    }
}

/// A dark throne-style chair with purple accents
struct ChairView: View {
    var body: some View {
        ZStack(alignment: .top) {
            // Seat (dark purple-black)
            Rectangle()
                .fill(Color(red: 0.15, green: 0.10, blue: 0.18))
                .frame(width: 16, height: 8)
            // Back rest (slightly darker with purple tint)
            Rectangle()
                .fill(Color(red: 0.12, green: 0.08, blue: 0.16))
                .frame(width: 16, height: 4)
                .offset(y: -4)
        }
    }
}

/// A bubbling potion cauldron replacing the coffee machine
struct CoffeeMachineView: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            // Cauldron body (round dark pot)
            Ellipse()
                .fill(Color(red: 0.10, green: 0.10, blue: 0.12))
                .frame(width: 22, height: 20)
                .offset(y: -4)

            // Bubbling glow on top (green/purple)
            ZStack {
                Circle()
                    .fill(Color(red: 0.3, green: 0.7, blue: 0.3).opacity(0.7))
                    .frame(width: 8, height: 8)
                    .offset(x: -3, y: -20)
                Circle()
                    .fill(Color(red: 0.5, green: 0.2, blue: 0.7).opacity(0.6))
                    .frame(width: 6, height: 6)
                    .offset(x: 3, y: -22)
            }

            // Legs
            HStack(spacing: 10) {
                Rectangle()
                    .fill(Color(red: 0.10, green: 0.10, blue: 0.12))
                    .frame(width: 3, height: 5)
                Rectangle()
                    .fill(Color(red: 0.10, green: 0.10, blue: 0.12))
                    .frame(width: 3, height: 5)
            }
        }
        .frame(width: 22, height: 30)
    }
}

/// A dark stone counter for the potion brewing area
struct CoffeeCounterView: View {
    var body: some View {
        Rectangle()
            .fill(Color(red: 0.18, green: 0.14, blue: 0.22))
            .frame(width: 80, height: 20)
            .cornerRadius(2)
    }
}

/// A jack-o-lantern replacing the potted plant
struct PlantView: View {
    var body: some View {
        ZStack {
            // Yellow glow behind the face
            Circle()
                .fill(Color.yellow.opacity(0.3))
                .frame(width: 18, height: 18)
                .offset(y: 2)

            VStack(spacing: 0) {
                // Green stem
                Rectangle()
                    .fill(Color(red: 0.2, green: 0.5, blue: 0.2))
                    .frame(width: 3, height: 4)

                // Orange pumpkin body
                ZStack {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 14, height: 14)

                    // Carved face - triangle eyes
                    HStack(spacing: 3) {
                        Triangle()
                            .fill(Color(red: 0.15, green: 0.10, blue: 0.05))
                            .frame(width: 3, height: 3)
                        Triangle()
                            .fill(Color(red: 0.15, green: 0.10, blue: 0.05))
                            .frame(width: 3, height: 3)
                    }
                    .offset(y: -1)

                    // Jagged mouth
                    Rectangle()
                        .fill(Color(red: 0.15, green: 0.10, blue: 0.05))
                        .frame(width: 6, height: 2)
                        .cornerRadius(1)
                        .offset(y: 3)
                }
            }
        }
    }
}

/// Simple triangle shape for jack-o-lantern eyes
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
#endif

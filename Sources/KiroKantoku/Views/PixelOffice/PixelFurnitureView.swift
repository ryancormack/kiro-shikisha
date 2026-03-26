#if os(macOS)
import SwiftUI

/// A brown desk with a small monitor on top
struct DeskView: View {
    var body: some View {
        ZStack(alignment: .top) {
            // Desk surface
            Rectangle()
                .fill(Color(red: 0.55, green: 0.35, blue: 0.17))
                .frame(width: 40, height: 20)

            // Monitor
            ZStack {
                Rectangle()
                    .fill(Color(red: 0.3, green: 0.3, blue: 0.32))
                    .frame(width: 16, height: 12)
                // Screen
                Rectangle()
                    .fill(Color(red: 0.2, green: 0.5, blue: 0.85))
                    .frame(width: 12, height: 8)
            }
            .offset(y: -10)
        }
    }
}

/// A small chair seat positioned in front of a desk
struct ChairView: View {
    var body: some View {
        ZStack(alignment: .top) {
            // Seat
            Rectangle()
                .fill(Color(red: 0.25, green: 0.25, blue: 0.3))
                .frame(width: 16, height: 8)
            // Back rest
            Rectangle()
                .fill(Color(red: 0.2, green: 0.2, blue: 0.25))
                .frame(width: 16, height: 4)
                .offset(y: -4)
        }
    }
}

/// A tall coffee machine with an indicator light and nozzle
struct CoffeeMachineView: View {
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Body
            Rectangle()
                .fill(Color(red: 0.22, green: 0.22, blue: 0.24))
                .frame(width: 20, height: 30)
                .cornerRadius(2)

            // Indicator light
            Circle()
                .fill(Color.red)
                .frame(width: 4, height: 4)
                .offset(x: -3, y: 4)

            // Nozzle
            Rectangle()
                .fill(Color(red: 0.45, green: 0.3, blue: 0.15))
                .frame(width: 6, height: 4)
                .offset(x: -7, y: 20)
        }
    }
}

/// A long counter surface for the coffee area
struct CoffeeCounterView: View {
    var body: some View {
        Rectangle()
            .fill(Color(red: 0.5, green: 0.32, blue: 0.15))
            .frame(width: 80, height: 20)
            .cornerRadius(2)
    }
}

/// A small potted plant for decoration
struct PlantView: View {
    var body: some View {
        VStack(spacing: 0) {
            // Leaves
            Circle()
                .fill(Color(red: 0.2, green: 0.65, blue: 0.3))
                .frame(width: 14, height: 14)

            // Pot
            Rectangle()
                .fill(Color(red: 0.55, green: 0.35, blue: 0.17))
                .frame(width: 10, height: 8)
                .cornerRadius(1)
        }
    }
}
#endif

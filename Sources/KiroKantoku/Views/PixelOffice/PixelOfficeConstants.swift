import Foundation

/// Constants for the pixel office visualization
enum PixelOfficeConstants {
    /// Size of each tile in points
    static let tileSize: Double = 32.0

    /// Office grid dimensions (in tiles)
    static let officeWidth: Int = 20
    static let officeHeight: Int = 14

    /// Animation tick interval in seconds
    static let animationTickInterval: Double = 0.15

    /// Character movement speed (tiles per tick)
    static let moveSpeed: Double = 0.3

    /// Desk positions in grid coordinates (x, y) - left side of office
    static let deskPositions: [(x: Int, y: Int)] = [
        (3, 3), (6, 3), (9, 3), (12, 3),
        (3, 7), (6, 7), (9, 7), (12, 7)
    ]

    /// Coffee bar positions in grid coordinates (x, y) - right side
    static let coffeeBarPositions: [(x: Int, y: Int)] = [
        (16, 4), (17, 4), (16, 6), (17, 6)
    ]

    /// Character appearance palettes (hair color, shirt color as hex strings)
    static let characterPalettes: [(hair: String, shirt: String)] = [
        ("4A3728", "4A90D9"),  // brown hair, blue shirt
        ("2C2C2C", "D94A4A"),  // black hair, red shirt
        ("C4A35A", "4AD97A"),  // blonde hair, green shirt
        ("8B4513", "D9A04A"),  // auburn hair, orange shirt
        ("1A1A2E", "9B59B6"),  // dark hair, purple shirt
        ("D4A574", "3498DB"),  // light brown hair, sky blue shirt
        ("2D1B0E", "E74C3C"),  // very dark hair, crimson shirt
        ("F5DEB3", "2ECC71"),  // wheat hair, emerald shirt
    ]
}

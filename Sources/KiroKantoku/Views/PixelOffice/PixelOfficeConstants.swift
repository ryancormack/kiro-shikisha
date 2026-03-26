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

    /// Ghost character appearance palettes (body tint, glow/accent color as hex strings)
    static let characterPalettes: [(hair: String, shirt: String)] = [
        ("6B3FA0", "9B59B6"),  // deep purple body, lavender glow
        ("2C3E50", "1ABC9C"),  // dark teal body, spectral green glow
        ("4A0E4E", "E056A0"),  // dark magenta body, pink glow
        ("1A1A3E", "5DADE2"),  // midnight blue body, spectral blue glow
        ("2D1F3D", "BB8FCE"),  // dark violet body, soft purple glow
        ("1E3A2F", "58D68D"),  // dark forest body, ghostly green glow
        ("3B1C4A", "F39C12"),  // dark plum body, amber glow
        ("0D1B2A", "76D7C4"),  // near-black body, teal glow
    ]

    // MARK: - Haunted Mansion Colors

    /// Dark purple wall color for the haunted mansion
    static let wallColorHex = "331A40"

    /// Dark purple floor tile (lighter of the pair)
    static let floorTileLightHex = "261433"

    /// Near-black floor tile (darker of the pair)
    static let floorTileDarkHex = "1F0F29"

    /// Ghost glow color (soft purple)
    static let ghostGlowHex = "C084FC"

    /// Candle flame color
    static let candleFlameHex = "FBBF24"

    /// Potion cauldron bubble color
    static let cauldronBubbleHex = "4ADE80"
}

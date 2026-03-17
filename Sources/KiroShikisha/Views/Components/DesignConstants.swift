#if os(macOS)
import SwiftUI

/// Centralized UI constants for consistent styling across the application
enum DesignConstants {
    // MARK: - Corner Radii

    static let cornerRadiusSmall: CGFloat = 4
    static let cornerRadiusMedium: CGFloat = 8
    static let cornerRadiusLarge: CGFloat = 12

    // MARK: - Spacing

    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 12
    static let spacingLG: CGFloat = 16
    static let spacingXL: CGFloat = 24

    // MARK: - Font Sizes

    static let codeFontSize: CGFloat = 12
    static let codeLineNumberFontSize: CGFloat = 11

    // MARK: - Diff View

    static let lineNumberGutterWidth: CGFloat = 44
    static let changeIndicatorWidth: CGFloat = 4

    // MARK: - Background Colors (macOS only)

    static var controlBackground: Color {
        Color(nsColor: .controlBackgroundColor)
    }

    static var textBackground: Color {
        Color(nsColor: .textBackgroundColor)
    }

    static var separatorColor: Color {
        Color(nsColor: .separatorColor)
    }
}
#endif

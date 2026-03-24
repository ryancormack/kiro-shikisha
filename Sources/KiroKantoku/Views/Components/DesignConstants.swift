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

    // MARK: - Button

    static let buttonCornerRadius: CGFloat = 6
    static let buttonPaddingH: CGFloat = 12
    static let buttonPaddingV: CGFloat = 6
    static let buttonMinHeight: CGFloat = 28

    // MARK: - Cards

    static let cardCornerRadius: CGFloat = 10
    static let cardPadding: CGFloat = 14
    static let cardShadowRadius: CGFloat = 3
    static let cardShadowY: CGFloat = 1.5
    static let cardBorderOpacity: Double = 0.12

    // MARK: - Inputs

    static let inputCornerRadius: CGFloat = 8
    static let inputMinHeight: CGFloat = 36
    static let inputPaddingH: CGFloat = 10
    static let inputPaddingV: CGFloat = 8

    // MARK: - Popups & Sheets

    static let sheetCornerRadius: CGFloat = 12
    static let popoverShadowRadius: CGFloat = 12
    static let popoverShadowOpacity: Double = 0.15

    // MARK: - Badges

    static let badgeCornerRadius: CGFloat = 5
    static let badgePaddingH: CGFloat = 6
    static let badgePaddingV: CGFloat = 2
    static let badgeFontSize: CGFloat = 10

    // MARK: - Typography

    static let captionSecondaryOpacity: Double = 0.7

    // MARK: - Animation

    static let standardDuration: Double = 0.2
    static let hoverScale: CGFloat = 1.015

    // MARK: - Semantic Colors

    static var subtleBackground: Color {
        Color(nsColor: .windowBackgroundColor)
    }

    static var cardBackground: Color {
        Color(nsColor: .controlBackgroundColor)
    }

    static var accentSubtle: Color {
        Color.accentColor.opacity(0.08)
    }

    static var dangerSubtle: Color {
        Color.red.opacity(0.08)
    }

    static var warningSubtle: Color {
        Color.orange.opacity(0.08)
    }

    static var successSubtle: Color {
        Color.green.opacity(0.08)
    }

    // MARK: - Layout

    static let sidebarMinWidth: CGFloat = 220
    static let detailMinWidth: CGFloat = 400
    static let chatMinWidth: CGFloat = 320

    // MARK: - Chips

    static let chipCornerRadius: CGFloat = 6
}
#endif

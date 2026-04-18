import SwiftUI

enum AppTheme {
    // Dark theme colors
    static let darkBackground = Color(white: 0.04)
    static let darkSecondaryBackground = Color(white: 0.10)
    static let darkTertiaryBackground = Color(white: 0.15)

    // Light theme colors
    static let lightBackground = Color(hex: "EFF4FA")
    static let lightSecondaryBackground = Color(hex: "E5ECF5")
    static let lightTertiaryBackground = Color(hex: "EFF4FA")

    // Adaptive BG colors
    static func adaptiveBackground(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkBackground : lightBackground
    }

    static func adaptiveSecondary(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkSecondaryBackground : lightSecondaryBackground
    }

    static func adaptiveTertiary(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkTertiaryBackground : lightTertiaryBackground
    }

    static func adaptiveCardBackground(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(white: 0.08) : .white
    }


    // Adaptive text colors
    static func adaptiveText(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .white : .black
    }

    static func adaptiveSecondaryText(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .white.opacity(0.78) : .black.opacity(0.78)
    }
    
    static func adaptiveTertiaryText(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .white.opacity(0.64) : .black.opacity(0.64)
    }
}

struct Squircle: InsettableShape {
    var cornerRadius: CGFloat
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let insetRect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let radius = min(cornerRadius, min(insetRect.width, insetRect.height) * 0.5)
        return RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: insetRect)
    }

    func inset(by amount: CGFloat) -> some InsettableShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
}

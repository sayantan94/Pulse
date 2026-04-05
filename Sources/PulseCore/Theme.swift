import SwiftUI

// Claude-inspired design tokens, adaptive for dark & light mode
public enum PulseTheme {
    // Claude's warm coral/terracotta accent
    public static let accent = Color(red: 0.85, green: 0.47, blue: 0.34)
    public static let accentNS = NSColor(red: 0.85, green: 0.47, blue: 0.34, alpha: 1.0)

    // Adaptive backgrounds
    public static func panelBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(white: 0.13)
            : Color(red: 0.98, green: 0.97, blue: 0.95)
    }

    public static func cardBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(white: 0.17)
            : Color.white
    }

    public static func hoverFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.06)
            : Color.black.opacity(0.035)
    }

    public static func border(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.10)
            : Color.black.opacity(0.09)
    }

    public static func divider(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.07)
    }

    public static func primaryText(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.9)
            : Color(white: 0.12)
    }

    public static func secondaryText(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.45)
            : Color.black.opacity(0.45)
    }

    public static func tertiaryText(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.30)
            : Color.black.opacity(0.30)
    }

    // Pill button styling (matches Claude's rounded bordered buttons)
    public static func pillBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.07)
            : Color.black.opacity(0.04)
    }

    public static func pillBorder(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.12)
            : Color.black.opacity(0.12)
    }

    // Input field styling
    public static func inputBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.06)
            : Color.black.opacity(0.03)
    }

    public static func inputBorder(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.10)
            : Color.black.opacity(0.10)
    }
}

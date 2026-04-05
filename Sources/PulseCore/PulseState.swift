import SwiftUI

public enum PulseState: String, Codable {
    case green, yellow, blue, orange, red, gray

    public var color: Color {
        switch self {
        case .green: return .green
        case .yellow: return .yellow
        case .blue: return .blue
        case .orange: return .orange
        case .red: return .red
        case .gray: return .gray
        }
    }

    // Adaptive colors tuned for dark/light mode contrast
    public func adaptiveColor(_ scheme: ColorScheme) -> Color {
        switch self {
        case .green:
            return scheme == .dark
                ? Color(red: 0.30, green: 0.78, blue: 0.47)
                : Color(red: 0.20, green: 0.68, blue: 0.37)
        case .yellow:
            return scheme == .dark
                ? Color(red: 0.96, green: 0.78, blue: 0.25)
                : Color(red: 0.82, green: 0.62, blue: 0.08)
        case .blue:
            return scheme == .dark
                ? Color(red: 0.40, green: 0.65, blue: 0.95)
                : Color(red: 0.25, green: 0.48, blue: 0.85)
        case .orange:
            return scheme == .dark
                ? Color(red: 0.95, green: 0.60, blue: 0.25)
                : Color(red: 0.85, green: 0.47, blue: 0.14)
        case .red:
            return scheme == .dark
                ? Color(red: 0.95, green: 0.35, blue: 0.32)
                : Color(red: 0.85, green: 0.25, blue: 0.22)
        case .gray:
            return scheme == .dark
                ? Color.white.opacity(0.30)
                : Color.black.opacity(0.25)
        }
    }

    public var nsColor: NSColor {
        switch self {
        case .green: return .systemGreen
        case .yellow: return .systemYellow
        case .blue: return .systemBlue
        case .orange: return .systemOrange
        case .red: return .systemRed
        case .gray: return .tertiaryLabelColor
        }
    }

    public var displayName: String {
        switch self {
        case .green: return "Running"
        case .yellow: return "Waiting"
        case .blue: return "Done"
        case .orange: return "Caution"
        case .red: return "Error"
        case .gray: return "Idle"
        }
    }

    public var priority: Int {
        switch self {
        case .red: return 4
        case .orange: return 3
        case .yellow: return 2
        case .blue: return 1
        case .green: return 1
        case .gray: return 0
        }
    }
}

public struct PulseMessage: Codable {
    public let state: PulseState
    public let label: String
    public var ttl: Int?
    public var sessionName: String?
    public var terminalPid: Int?

    enum CodingKeys: String, CodingKey {
        case state, label, ttl
        case sessionName = "session_name"
        case terminalPid = "terminal_pid"
    }
}

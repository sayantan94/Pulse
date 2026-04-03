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

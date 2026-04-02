import Foundation

public struct PulseIcon: Identifiable, Equatable {
    public var id: String { symbol }
    public let symbol: String
    public let label: String
}

public let availableIcons: [PulseIcon] = [
    PulseIcon(symbol: "paperclip", label: "Clippy"),
    PulseIcon(symbol: "sparkle", label: "Sparkle"),
    PulseIcon(symbol: "eye", label: "Eye"),
    PulseIcon(symbol: "bolt.fill", label: "Bolt"),
    PulseIcon(symbol: "waveform.path", label: "Wave"),
    PulseIcon(symbol: "heart.fill", label: "Heart"),
    PulseIcon(symbol: "shield.fill", label: "Shield"),
    PulseIcon(symbol: "bell.fill", label: "Bell"),
    PulseIcon(symbol: "antenna.radiowaves.left.and.right", label: "Signal"),
    PulseIcon(symbol: "circle.fill", label: "Dot"),
]

public final class PreferenceStore: ObservableObject {
    @Published public var iconSymbol: String = "paperclip"

    private static let prefsPath = NSHomeDirectory() + "/.pulse/prefs.json"

    public init() {
        load()
    }

    public func load() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: Self.prefsPath)),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else { return }
        iconSymbol = dict["icon"] ?? "paperclip"
    }

    public func setIcon(_ symbol: String) {
        iconSymbol = symbol
        save()
    }

    private func save() {
        let dict = ["icon": iconSymbol]
        guard let data = try? JSONEncoder().encode(dict) else { return }
        try? data.write(to: URL(fileURLWithPath: Self.prefsPath), options: .atomic)
    }
}

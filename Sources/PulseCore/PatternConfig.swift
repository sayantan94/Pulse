import Foundation

public enum PatternMode: String, Codable {
    case warn, block
}

public struct RiskyPattern: Codable, Identifiable {
    public var id: String { pattern }
    public var pattern: String
    public var label: String
    public var mode: PatternMode
}

public struct PatternConfig: Codable {
    public var blockByDefault: Bool
    public var patterns: [RiskyPattern]
}

public final class PatternStore: ObservableObject {
    @Published public var config: PatternConfig = PatternConfig(blockByDefault: false, patterns: [])

    private static let configPath = NSHomeDirectory() + "/.pulse/hooks/risky-patterns.json"
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    public init() {
        load()
    }

    public func load() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: Self.configPath)),
              let decoded = try? JSONDecoder().decode(PatternConfig.self, from: data) else { return }
        config = decoded
    }

    public func save() {
        guard let data = try? Self.encoder.encode(config) else { return }
        try? data.write(to: URL(fileURLWithPath: Self.configPath), options: .atomic)
    }

    public func toggleMode(for pattern: RiskyPattern) {
        guard let idx = config.patterns.firstIndex(where: { $0.pattern == pattern.pattern }) else { return }
        config.patterns[idx].mode = config.patterns[idx].mode == .block ? .warn : .block
        save()
    }

    public func toggleBlockByDefault() {
        config.blockByDefault.toggle()
        save()
    }

    public func removePattern(_ pattern: RiskyPattern) {
        config.patterns.removeAll { $0.pattern == pattern.pattern }
        save()
    }

    public func addPattern(pattern: String, label: String, mode: PatternMode = .warn) {
        config.patterns.append(RiskyPattern(pattern: pattern, label: label, mode: mode))
        save()
    }
}

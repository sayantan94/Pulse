import Foundation

public struct SessionInfo: Identifiable {
    public var id: String { sessionId }
    public let sessionId: String
    public let name: String
    public let state: PulseState
    public let label: String
    public let ttl: Int?
    public let terminalPid: Int?
    public let lastUpdated: Date

    public func focusTerminal() {
        guard let pid = terminalPid else { return }
        let script = "tell application \"System Events\" to set frontmost of (first process whose unix id is \(pid)) to true"
        DispatchQueue.global().async {
            let task = Process()
            task.launchPath = "/usr/bin/osascript"
            task.arguments = ["-e", script]
            try? task.run()
        }
    }
}

public final class SessionManager {
    public static let stateDirectory = "/tmp/pulse"

    private let directoryPath: String
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private let onChange: ([SessionInfo]) -> Void
    private var pendingScan: DispatchWorkItem?
    private var lastCleanup: Date = .distantPast

    public init(directoryPath: String = SessionManager.stateDirectory,
                onChange: @escaping ([SessionInfo]) -> Void) {
        self.directoryPath = directoryPath
        self.onChange = onChange
    }

    public func start() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: directoryPath) {
            try? fm.createDirectory(atPath: directoryPath, withIntermediateDirectories: true)
        }

        fileDescriptor = open(directoryPath, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete],
            queue: DispatchQueue.global(qos: .default)
        )

        source.setEventHandler { [weak self] in
            self?.debouncedScan()
        }

        source.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 { close(fd) }
        }

        self.source = source
        source.resume()
        DispatchQueue.global().async { [weak self] in self?.scanAndNotify() }
    }

    public func stop() {
        pendingScan?.cancel()
        source?.cancel()
        source = nil
    }

    public func removeSession(_ id: String) {
        let base = (directoryPath as NSString)
        try? FileManager.default.removeItem(atPath: base.appendingPathComponent("\(id).json"))
        try? FileManager.default.removeItem(atPath: base.appendingPathComponent("\(id).ts"))
    }

    // Debounce rapid FS events (hook writes .json + .ts back-to-back)
    private func debouncedScan() {
        pendingScan?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.scanAndNotify() }
        pendingScan = work
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.15, execute: work)
    }

    private let decoder = JSONDecoder()

    private func scanAndNotify() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: directoryPath) else { return }

        let now = Date()
        let shouldCleanup = now.timeIntervalSince(lastCleanup) > 60
        let base = directoryPath as NSString

        var sessions: [SessionInfo] = []
        for file in files where file.hasSuffix(".json") {
            let path = base.appendingPathComponent(file)
            guard let attrs = try? fm.attributesOfItem(atPath: path),
                  let modified = attrs[.modificationDate] as? Date else { continue }

            if shouldCleanup && now.timeIntervalSince(modified) > 300 {
                let sessionId = file.replacingOccurrences(of: ".json", with: "")
                try? fm.removeItem(atPath: path)
                try? fm.removeItem(atPath: base.appendingPathComponent("\(sessionId).ts"))
                continue
            }

            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                  let message = try? decoder.decode(PulseMessage.self, from: data) else { continue }

            let sessionId = file.replacingOccurrences(of: ".json", with: "")
            sessions.append(SessionInfo(
                sessionId: sessionId,
                name: message.sessionName ?? sessionId,
                state: message.state,
                label: message.label,
                ttl: message.ttl,
                terminalPid: message.terminalPid,
                lastUpdated: modified
            ))
        }

        if shouldCleanup { lastCleanup = now }

        sessions.sort { a, b in
            if a.state.priority != b.state.priority { return a.state.priority > b.state.priority }
            return a.lastUpdated > b.lastUpdated
        }

        DispatchQueue.main.async { [weak self] in self?.onChange(sessions) }
    }

    deinit { stop() }
}

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
            task.waitUntilExit()
        }
    }
}

public final class SessionManager {
    public static let stateDirectory = "/tmp/pulse"

    private let directoryPath: String
    private let onChange: ([SessionInfo]) -> Void
    private let decoder = JSONDecoder()
    private let queue = DispatchQueue(label: "pulse.session-manager")
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var pendingScan: DispatchWorkItem?
    private var ttlTimer: DispatchSourceTimer?
    private var lastCleanup: Date = .distantPast

    public init(directoryPath: String = SessionManager.stateDirectory,
                onChange: @escaping ([SessionInfo]) -> Void) {
        self.directoryPath = directoryPath
        self.onChange = onChange
    }

    public func start() {
        stop()

        let fm = FileManager.default
        if !fm.fileExists(atPath: directoryPath) {
            try? fm.createDirectory(atPath: directoryPath, withIntermediateDirectories: true)
        }

        fileDescriptor = open(directoryPath, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete],
            queue: queue
        )
        src.setEventHandler { [weak self] in self?.debouncedScan() }
        src.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 {
                close(fd)
                self?.fileDescriptor = -1
            }
        }
        source = src
        src.resume()

        // Periodic re-scan so TTL-based expiry works even without file changes
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 1, repeating: 1)
        timer.setEventHandler { [weak self] in self?.scanAndNotify() }
        ttlTimer = timer
        timer.resume()

        queue.async { [weak self] in self?.scanAndNotify() }
    }

    public func stop() {
        pendingScan?.cancel()
        ttlTimer?.cancel()
        ttlTimer = nil
        source?.cancel()
        source = nil
    }

    public func removeSession(_ id: String) {
        let base = directoryPath as NSString
        try? FileManager.default.removeItem(atPath: base.appendingPathComponent("\(id).json"))
        try? FileManager.default.removeItem(atPath: base.appendingPathComponent("\(id).ts"))
    }

    private func debouncedScan() {
        pendingScan?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.scanAndNotify() }
        pendingScan = work
        queue.asyncAfter(deadline: .now() + 0.15, execute: work)
    }

    private func scanAndNotify() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: directoryPath) else { return }

        let now = Date()
        let shouldCleanup = now.timeIntervalSince(lastCleanup) > 60
        let base = directoryPath as NSString

        var sessions: [SessionInfo] = []
        for file in files where file.hasSuffix(".json") {
            let sessionId = String(file.dropLast(5)) // strip ".json"
            let path = base.appendingPathComponent(file)

            guard let attrs = try? fm.attributesOfItem(atPath: path),
                  let modified = attrs[.modificationDate] as? Date else { continue }

            if shouldCleanup && now.timeIntervalSince(modified) > 300 {
                try? fm.removeItem(atPath: path)
                try? fm.removeItem(atPath: base.appendingPathComponent("\(sessionId).ts"))
                continue
            }

            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                  let message = try? decoder.decode(PulseMessage.self, from: data) else { continue }

            // If TTL is set and expired, treat as gray
            let effectiveState: PulseState
            if let ttl = message.ttl, now.timeIntervalSince(modified) > Double(ttl) {
                effectiveState = .gray
            } else {
                effectiveState = message.state
            }

            sessions.append(SessionInfo(
                sessionId: sessionId,
                name: message.sessionName ?? sessionId,
                state: effectiveState,
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

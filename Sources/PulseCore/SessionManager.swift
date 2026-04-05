import Foundation

// MARK: - Activity Event

public struct ActivityEvent: Identifiable {
    public let id: String
    public let timestamp: Date
    public let event: String
    public let detail: String

    public var icon: String {
        switch event {
        case "tool_done": return "hammer.fill"
        case "pre_tool": return "hammer"
        case "tool_fail": return "exclamationmark.triangle.fill"
        case "prompt": return "text.bubble"
        case "permission_req": return "lock.fill"
        case "denied": return "xmark.shield"
        case "blocked": return "shield.slash"
        case "risky": return "exclamationmark.shield"
        case "subagent_start": return "arrow.triangle.branch"
        case "subagent_stop": return "checkmark.circle"
        case "compact_start", "compact_done": return "arrow.triangle.2.circlepath"
        case "notification": return "bell.fill"
        case "stop": return "checkmark.circle.fill"
        case "error": return "xmark.circle.fill"
        case "session_start": return "play.circle.fill"
        case "session_end": return "stop.circle.fill"
        case "ask_user": return "questionmark.circle"
        case "cwd_changed": return "folder"
        case "task_created": return "plus.circle"
        case "task_done": return "checkmark.square"
        case "teammate_idle": return "person.fill.questionmark"
        case "instructions": return "doc.text"
        case "file_changed": return "doc.badge.arrow.up"
        case "config_change": return "gearshape"
        case "elicitation": return "rectangle.connected.to.line.below"
        case "elicitation_result": return "rectangle.connected.to.line.below"
        case "worktree_create": return "arrow.triangle.branch"
        case "worktree_remove": return "trash"
        default: return "circle.fill"
        }
    }

    public var displayName: String {
        switch event {
        case "tool_done": return detail
        case "pre_tool": return detail
        case "tool_fail": return "\(detail) failed"
        case "prompt": return "Prompt"
        case "permission_req": return "Permission: \(detail)"
        case "denied": return "Denied: \(detail)"
        case "blocked": return "Blocked"
        case "risky": return "Risky cmd"
        case "subagent_start": return "Agent: \(detail)"
        case "subagent_stop": return "Agent done"
        case "compact_start": return "Compacting"
        case "compact_done": return "Compacted"
        case "notification": return detail
        case "stop": return detail == "tool_limit" ? "Tool limit" : "Done"
        case "error": return "Error"
        case "session_start": return "Started"
        case "session_end": return "Ended"
        case "ask_user": return "Question"
        case "cwd_changed": return "Dir changed"
        case "task_created": return detail
        case "task_done": return detail
        case "teammate_idle": return "\(detail) idle"
        case "instructions": return detail
        case "file_changed": return detail
        case "config_change": return detail
        case "elicitation": return "MCP: \(detail)"
        case "elicitation_result": return "MCP reply"
        case "worktree_create": return "Worktree"
        case "worktree_remove": return "Worktree removed"
        default: return event
        }
    }

    public var timeAgo: String {
        let elapsed = Int(Date().timeIntervalSince(timestamp))
        if elapsed < 5 { return "now" }
        if elapsed < 60 { return "\(elapsed)s" }
        if elapsed < 3600 { return "\(elapsed / 60)m" }
        return "\(elapsed / 3600)h"
    }
}

// MARK: - Session Metadata

public struct SessionMeta {
    public let model: String?
    public let permissionMode: String?

    public var shortModel: String? {
        guard let m = model, !m.isEmpty else { return nil }
        return m
    }

    public var shortMode: String? {
        guard let pm = permissionMode, !pm.isEmpty else { return nil }
        switch pm {
        case "default": return "Default"
        case "plan": return "Plan"
        case "acceptEdits": return "Accept Edits"
        case "auto": return "Auto"
        case "dontAsk": return "Don't Ask"
        case "bypassPermissions": return "Bypass"
        default: return pm
        }
    }
}

// MARK: - Task Progress

public struct TaskProgress {
    public let created: Int
    public let completed: Int
    public let active: [(id: String, subject: String)]

    public var hasActivity: Bool { created > 0 }
    public var fraction: Double {
        guard created > 0 else { return 0 }
        return Double(completed) / Double(created)
    }
}

// MARK: - Session Info

public struct SessionInfo: Identifiable {
    public var id: String { sessionId }
    public let sessionId: String
    public let name: String
    public let state: PulseState
    public let label: String
    public let ttl: Int?
    public let terminalPid: Int?
    public let lastUpdated: Date
    public let toolStats: [String: Int]
    public let recentEvents: [ActivityEvent]
    public let startedAt: Date?
    public let meta: SessionMeta
    public let lastPrompt: String?
    public let tasks: TaskProgress

    public var duration: String? {
        guard let start = startedAt else { return nil }
        let elapsed = Int(Date().timeIntervalSince(start))
        if elapsed < 60 { return "\(elapsed)s" }
        if elapsed < 3600 { return "\(elapsed / 60)m \(elapsed % 60)s" }
        return "\(elapsed / 3600)h \((elapsed % 3600) / 60)m"
    }

    public var totalToolUses: Int {
        toolStats.values.reduce(0, +)
    }

    public var topTools: [(name: String, count: Int)] {
        toolStats.sorted { $0.value > $1.value }
            .prefix(6)
            .map { (name: $0.key, count: $0.value) }
    }

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

// MARK: - Session Manager

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
        for ext in ["json", "ts", "stats", "log", "start", "pid", "failures", "meta", "prompt", "tasks"] {
            try? FileManager.default.removeItem(atPath: base.appendingPathComponent("\(id).\(ext)"))
        }
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
            let sessionId = String(file.dropLast(5))
            let path = base.appendingPathComponent(file)

            guard let attrs = try? fm.attributesOfItem(atPath: path),
                  let modified = attrs[.modificationDate] as? Date else { continue }

            if shouldCleanup && now.timeIntervalSince(modified) > 300 {
                try? fm.removeItem(atPath: path)
                for ext in ["ts", "stats", "log", "start", "pid", "failures", "meta", "prompt", "tasks"] {
                    try? fm.removeItem(atPath: base.appendingPathComponent("\(sessionId).\(ext)"))
                }
                continue
            }

            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                  let message = try? decoder.decode(PulseMessage.self, from: data) else { continue }

            let effectiveState: PulseState
            if let ttl = message.ttl, now.timeIntervalSince(modified) > Double(ttl) {
                effectiveState = .gray
            } else {
                effectiveState = message.state
            }

            let toolStats = readToolStats(base.appendingPathComponent("\(sessionId).stats"))
            let recentEvents = readActivityLog(base.appendingPathComponent("\(sessionId).log"))
            let startedAt = readStartTime(base.appendingPathComponent("\(sessionId).start"))
            let meta = readMeta(base.appendingPathComponent("\(sessionId).meta"))
            let lastPrompt = readPrompt(base.appendingPathComponent("\(sessionId).prompt"))
            let tasks = readTasks(base.appendingPathComponent("\(sessionId).tasks"))

            sessions.append(SessionInfo(
                sessionId: sessionId,
                name: message.sessionName ?? sessionId,
                state: effectiveState,
                label: message.label,
                ttl: message.ttl,
                terminalPid: message.terminalPid,
                lastUpdated: modified,
                toolStats: toolStats,
                recentEvents: recentEvents,
                startedAt: startedAt,
                meta: meta,
                lastPrompt: lastPrompt,
                tasks: tasks
            ))
        }

        if shouldCleanup { lastCleanup = now }

        sessions.sort { a, b in
            if a.state.priority != b.state.priority { return a.state.priority > b.state.priority }
            return a.lastUpdated > b.lastUpdated
        }

        DispatchQueue.main.async { [weak self] in self?.onChange(sessions) }
    }

    // MARK: - File Parsers

    private func readToolStats(_ path: String) -> [String: Int] {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let dict = try? JSONDecoder().decode([String: Int].self, from: data) else {
            return [:]
        }
        return dict
    }

    private func readActivityLog(_ path: String) -> [ActivityEvent] {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }
        return content.split(separator: "\n").compactMap { line -> ActivityEvent? in
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let ts = json["ts"] as? TimeInterval,
                  let event = json["event"] as? String else { return nil }
            let detail = json["detail"] as? String ?? ""
            return ActivityEvent(
                id: "\(ts)-\(event)-\(detail)",
                timestamp: Date(timeIntervalSince1970: ts),
                event: event,
                detail: detail
            )
        }.suffix(10).reversed()
    }

    private func readStartTime(_ path: String) -> Date? {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
              let ts = TimeInterval(content) else { return nil }
        return Date(timeIntervalSince1970: ts)
    }

    private func readMeta(_ path: String) -> SessionMeta {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return SessionMeta(model: nil, permissionMode: nil)
        }
        return SessionMeta(
            model: json["model"] as? String,
            permissionMode: json["permission_mode"] as? String
        )
    }

    private func readPrompt(_ path: String) -> String? {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
              !content.isEmpty else { return nil }
        return content
    }

    private func readTasks(_ path: String) -> TaskProgress {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return TaskProgress(created: 0, completed: 0, active: [])
        }
        let created = json["created"] as? Int ?? 0
        let completed = json["completed"] as? Int ?? 0
        let activeArr = json["active"] as? [[String: String]] ?? []
        let active = activeArr.compactMap { item -> (id: String, subject: String)? in
            guard let id = item["id"], let subject = item["subject"] else { return nil }
            return (id: id, subject: subject)
        }
        return TaskProgress(created: created, completed: completed, active: active)
    }

    deinit { stop() }
}

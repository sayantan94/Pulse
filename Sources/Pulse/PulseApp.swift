import SwiftUI
import PulseCore

@main
struct PulseApp: App {
    @StateObject private var store = SessionStore()

    init() {
        // Ensure only one instance runs at a time
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
        if runningApps.count > 1 {
            NSApp.terminate(nil)
        }
        // Also check by process name for non-bundled builds
        let myPid = ProcessInfo.processInfo.processIdentifier
        let task = Process()
        task.launchPath = "/usr/bin/pgrep"
        task.arguments = ["-x", "Pulse"]
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        task.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let pids = output.split(separator: "\n").compactMap { Int32($0) }
        if pids.contains(where: { $0 != myPid }) {
            // Another Pulse is already running — kill it so we become the sole instance
            for pid in pids where pid != myPid {
                kill(pid, SIGTERM)
            }
            usleep(300_000) // 300ms for the other to exit
        }
    }

    var body: some Scene {
        MenuBarExtra {
            PulseMenuView(
                sessions: store.sessions,
                onDismiss: { store.dismissSession($0) },
                onIconChange: { store.updateIcon(symbol: $0) }
            )
        } label: {
            Image(nsImage: store.menuBarIcon)
        }
        .menuBarExtraStyle(.window)
    }
}

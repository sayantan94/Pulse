import SwiftUI
import PulseCore

@main
struct PulseApp: App {
    @StateObject private var store = SessionStore()

    var body: some Scene {
        MenuBarExtra {
            PulseMenuView(sessions: store.sessions) { session in
                store.dismissSession(session)
            }
        } label: {
            Image(nsImage: store.menuBarIcon)
        }
        .menuBarExtraStyle(.window)
    }
}

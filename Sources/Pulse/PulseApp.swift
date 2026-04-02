import SwiftUI
import PulseCore

@main
struct PulseApp: App {
    @StateObject private var store = SessionStore()

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

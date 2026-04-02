import SwiftUI

public struct PulseMenuView: View {
    public let sessions: [SessionInfo]
    public var onDismiss: ((SessionInfo) -> Void)?
    public var onIconChange: ((String) -> Void)?
    @State private var settingsCollapsed = false
    @StateObject private var patterns = PatternStore()
    @StateObject private var prefs = PreferenceStore()

    public init(sessions: [SessionInfo], onDismiss: ((SessionInfo) -> Void)? = nil, onIconChange: ((String) -> Void)? = nil) {
        self.sessions = sessions
        self.onDismiss = onDismiss
        self.onIconChange = onIconChange
    }

    private var active: [SessionInfo] { sessions.filter { $0.state != .gray } }

    public var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                Divider()

                if !active.isEmpty {
                    sessionsSection
                    Divider()
                }

                rulesSection

                Divider()
                footer
            }
        }
        .frame(width: 340)
        .frame(maxHeight: 500)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Pulse")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            if !active.isEmpty {
                Text("\(active.count) Active")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                Text("All Quiet")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Sessions

    private var sessionsSection: some View {
        VStack(spacing: 0) {
            ForEach(active) { session in
                SessionRow(session: session, onDismiss: onDismiss)
                if session.id != active.last?.id {
                    Divider().padding(.leading, 52)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Rules

    private var rulesSection: some View {
        VStack(spacing: 0) {
            // Section header (tap to collapse/expand)
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) { settingsCollapsed.toggle() }
                if !settingsCollapsed { patterns.load() }
            }) {
                HStack {
                    Image(systemName: settingsCollapsed ? "chevron.right" : "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 12)
                    Text("Rules")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(patterns.config.patterns.count)")
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !settingsCollapsed {
                IconPicker(prefs: prefs, onIconChange: onIconChange)
                Divider().padding(.leading, 16)
                SettingsView(patterns: patterns)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Quit Pulse") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Icon Picker

struct IconPicker: View {
    @ObservedObject var prefs: PreferenceStore
    var onIconChange: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Icon")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(availableIcons) { icon in
                        Button(action: {
                            prefs.setIcon(icon.symbol)
                            onIconChange?(icon.symbol)
                        }) {
                            Image(systemName: icon.symbol)
                                .font(.system(size: 13))
                                .frame(width: 28, height: 28)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(prefs.iconSymbol == icon.symbol ? Color.accentColor.opacity(0.15) : Color.clear)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(prefs.iconSymbol == icon.symbol ? Color.accentColor : Color.clear, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .help(icon.label)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Settings

struct SettingsView: View {
    @ObservedObject var patterns: PatternStore
    @State private var newPattern = ""
    @State private var newLabel = ""

    var body: some View {
        VStack(spacing: 0) {
            // Global toggle
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Block all by default")
                        .font(.system(size: 11, weight: .medium))
                    Text("Override all patterns to block")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { patterns.config.blockByDefault },
                    set: { _ in patterns.toggleBlockByDefault() }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)

            Divider().padding(.leading, 16)

            VStack(spacing: 0) {
                ForEach(patterns.config.patterns) { pat in
                    PatternRow(pattern: pat, patterns: patterns)
                }
            }

            Divider().padding(.leading, 16)

            // Add pattern
            HStack(spacing: 6) {
                TextField("regex", text: $newPattern)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(maxWidth: .infinity)
                TextField("label", text: $newLabel)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .frame(width: 50)
                Button(action: {
                    guard !newPattern.isEmpty else { return }
                    patterns.addPattern(
                        pattern: newPattern,
                        label: newLabel.isEmpty ? newPattern : newLabel,
                        mode: patterns.config.blockByDefault ? .block : .warn
                    )
                    newPattern = ""
                    newLabel = ""
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(newPattern.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }
}

struct PatternRow: View {
    let pattern: RiskyPattern
    @ObservedObject var patterns: PatternStore
    @State private var isHovered = false

    private var isBlocking: Bool { pattern.mode == .block }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isBlocking ? "shield.fill" : "exclamationmark.triangle")
                .font(.system(size: 9))
                .foregroundStyle(isBlocking ? .red : .orange)
                .frame(width: 14)

            Text(pattern.label)
                .font(.system(size: 11))
                .lineLimit(1)

            Spacer(minLength: 0)

            Button(action: { patterns.toggleMode(for: pattern) }) {
                Text(isBlocking ? "Block" : "Warn")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(isBlocking ? .red : .orange)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        Capsule().fill(isBlocking ? Color.red.opacity(0.1) : Color.orange.opacity(0.1))
                    )
            }
            .buttonStyle(.plain)

            if isHovered {
                Button(action: { patterns.removePattern(pattern) }) {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: SessionInfo
    var onDismiss: ((SessionInfo) -> Void)?
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(session.state.color.opacity(0.12))
                    .frame(width: 28, height: 28)
                Circle()
                    .fill(session.state.color)
                    .frame(width: 8, height: 8)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(session.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                Text("\(session.state.displayName) — \(session.label)")
                    .font(.system(size: 10))
                    .foregroundStyle(.primary.opacity(0.55))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                if session.terminalPid != nil {
                    Button(action: { session.focusTerminal() }) {
                        Image(systemName: "rectangle.portrait.and.arrow.forward")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Switch to terminal")
                }

                Button(action: { onDismiss?(session) }) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Dismiss session")
            }
            .opacity(isHovered ? 1 : 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.primary.opacity(0.04) : .clear)
        )
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}

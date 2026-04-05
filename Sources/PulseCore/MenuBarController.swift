import SwiftUI

public struct PulseMenuView: View {
    public let sessions: [SessionInfo]
    public var onDismiss: ((SessionInfo) -> Void)?
    public var onIconChange: ((String) -> Void)?
    @State private var settingsCollapsed = false
    @StateObject private var patterns = PatternStore()
    @StateObject private var prefs = PreferenceStore()
    @Environment(\.colorScheme) private var colorScheme

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
                sectionDivider

                if !active.isEmpty {
                    ForEach(active) { session in
                        PokedexCard(session: session, onDismiss: onDismiss)
                    }
                    sectionDivider
                } else {
                    emptyState
                    sectionDivider
                }

                rulesSection
                sectionDivider
                footer
            }
        }
        .background(PulseTheme.panelBackground(colorScheme))
        .frame(width: 360)
        .frame(maxHeight: 600)
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(PulseTheme.divider(colorScheme))
            .frame(height: 1)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(PulseTheme.accent.opacity(colorScheme == .dark ? 0.20 : 0.12))
                    .frame(width: 28, height: 28)
                Image(systemName: prefs.iconSymbol)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(PulseTheme.accent)
            }

            Text("Pulse")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(PulseTheme.primaryText(colorScheme))

            Spacer()

            if !active.isEmpty {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("\(active.count)")
                        .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(PulseTheme.primaryText(colorScheme))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 24))
                .foregroundStyle(PulseTheme.tertiaryText(colorScheme))
            Text("No active sessions")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(PulseTheme.secondaryText(colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Rules

    private var rulesSection: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) { settingsCollapsed.toggle() }
                if !settingsCollapsed { patterns.load() }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: settingsCollapsed ? "chevron.right" : "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(PulseTheme.tertiaryText(colorScheme))
                        .frame(width: 12)
                    Text("Rules")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(PulseTheme.secondaryText(colorScheme))
                    Spacer()
                    Text("\(patterns.config.patterns.count)")
                        .font(.system(size: 10, design: .rounded).monospacedDigit())
                        .foregroundStyle(PulseTheme.tertiaryText(colorScheme))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(PulseTheme.pillBackground(colorScheme))
                        )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !settingsCollapsed {
                IconPicker(prefs: prefs, onIconChange: onIconChange)
                Rectangle()
                    .fill(PulseTheme.divider(colorScheme))
                    .frame(height: 1)
                    .padding(.leading, 16)
                SettingsView(patterns: patterns)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button(action: { NSApplication.shared.terminate(nil) }) {
                HStack(spacing: 5) {
                    Image(systemName: "power")
                        .font(.system(size: 9, weight: .medium))
                    Text("Quit")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                }
                .foregroundStyle(PulseTheme.secondaryText(colorScheme))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(PulseTheme.pillBackground(colorScheme))
                )
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Pokedex Card

struct PokedexCard: View {
    let session: SessionInfo
    var onDismiss: ((SessionInfo) -> Void)?
    @State private var isHovered = false
    @State private var isExpanded = false
    @Environment(\.colorScheme) private var colorScheme

    private var stateColor: Color { session.state.adaptiveColor(colorScheme) }

    private var hasDetails: Bool {
        !session.toolStats.isEmpty || !session.recentEvents.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            cardHeader

            if isExpanded {
                if !session.toolStats.isEmpty {
                    statsBars
                }
                if !session.recentEvents.isEmpty {
                    movesSection
                }
            }

            // Expand/collapse toggle
            if hasDetails {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(PulseTheme.tertiaryText(colorScheme))
                        .frame(maxWidth: .infinity)
                        .frame(height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(PulseTheme.cardBackground(colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovered ? stateColor.opacity(0.3) : PulseTheme.border(colorScheme), lineWidth: 1)
        )
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }

    // MARK: - Card Header

    private var cardHeader: some View {
        VStack(spacing: 0) {
            // Row 1: Status orb + name + actions
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(stateColor.opacity(colorScheme == .dark ? 0.20 : 0.12))
                        .frame(width: 36, height: 36)
                    Circle()
                        .fill(stateColor)
                        .frame(width: 10, height: 10)
                }

                VStack(alignment: .leading, spacing: 3) {
                    sessionNameView

                    HStack(spacing: 5) {
                        // State badge
                        Text(session.state.displayName.uppercased())
                            .font(.system(size: 8, weight: .heavy, design: .rounded))
                            .foregroundStyle(colorScheme == .dark ? Color.black.opacity(0.85) : Color.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(stateColor))

                        // Permission mode badge
                        if let mode = session.meta.shortMode {
                            Text(mode)
                                .font(.system(size: 8, weight: .medium, design: .rounded))
                                .foregroundStyle(PulseTheme.secondaryText(colorScheme))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(PulseTheme.pillBackground(colorScheme)))
                        }
                    }

                    // Model on its own line
                    if let model = session.meta.shortModel {
                        Text(model)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(PulseTheme.tertiaryText(colorScheme))
                    }
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 4) {
                    if let dur = session.duration {
                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                                .font(.system(size: 8))
                            Text(dur)
                                .font(.system(size: 10, weight: .medium, design: .rounded).monospacedDigit())
                        }
                        .foregroundStyle(PulseTheme.secondaryText(colorScheme))
                    }

                    if session.totalToolUses > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "hammer.fill")
                                .font(.system(size: 8))
                            Text("\(session.totalToolUses)")
                                .font(.system(size: 10, weight: .medium, design: .rounded).monospacedDigit())
                        }
                        .foregroundStyle(PulseTheme.tertiaryText(colorScheme))
                    }
                }

                // Actions
                VStack(spacing: 4) {
                    if session.terminalPid != nil {
                        Button(action: { session.focusTerminal() }) {
                            Image(systemName: "rectangle.portrait.and.arrow.forward")
                                .font(.system(size: 10))
                                .foregroundStyle(PulseTheme.secondaryText(colorScheme))
                                .frame(width: 22, height: 22)
                                .background(RoundedRectangle(cornerRadius: 6).fill(PulseTheme.pillBackground(colorScheme)))
                        }
                        .buttonStyle(.plain)
                        .help("Switch to terminal")
                    }

                    Button(action: { onDismiss?(session) }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(PulseTheme.tertiaryText(colorScheme))
                            .frame(width: 22, height: 22)
                            .background(RoundedRectangle(cornerRadius: 6).fill(PulseTheme.pillBackground(colorScheme)))
                    }
                    .buttonStyle(.plain)
                    .help("Dismiss")
                }
                .opacity(isHovered ? 1 : 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            // Last prompt
            if let prompt = session.lastPrompt {
                Rectangle()
                    .fill(PulseTheme.divider(colorScheme))
                    .frame(height: 1)
                    .padding(.horizontal, 14)

                HStack(spacing: 6) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 9))
                        .foregroundStyle(PulseTheme.tertiaryText(colorScheme))
                    Text(prompt)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(PulseTheme.secondaryText(colorScheme))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }

            // Task progress
            if session.tasks.hasActivity {
                Rectangle()
                    .fill(PulseTheme.divider(colorScheme))
                    .frame(height: 1)
                    .padding(.horizontal, 14)

                HStack(spacing: 8) {
                    Image(systemName: "checklist")
                        .font(.system(size: 9))
                        .foregroundStyle(PulseTheme.tertiaryText(colorScheme))

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(PulseTheme.accent.opacity(colorScheme == .dark ? 0.15 : 0.10))
                                .frame(height: 5)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(PulseTheme.accent)
                                .frame(width: geo.size.width * session.tasks.fraction, height: 5)
                        }
                    }
                    .frame(height: 5)

                    Text("\(session.tasks.completed)/\(session.tasks.created)")
                        .font(.system(size: 10, weight: .medium, design: .rounded).monospacedDigit())
                        .foregroundStyle(PulseTheme.secondaryText(colorScheme))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Stats Bars (like Pokemon stats)

    private var statsBars: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(PulseTheme.divider(colorScheme))
                .frame(height: 1)
                .padding(.horizontal, 14)

            VStack(spacing: 5) {
                ForEach(session.topTools, id: \.name) { tool in
                    StatBar(
                        name: toolDisplayName(tool.name),
                        value: tool.count,
                        maxValue: session.topTools.first?.count ?? 1,
                        color: toolColor(tool.name)
                    )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Moves Section (Activity Log)

    private var movesSection: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(PulseTheme.divider(colorScheme))
                .frame(height: 1)
                .padding(.horizontal, 14)

            VStack(spacing: 0) {
                HStack {
                    Text("RECENT")
                        .font(.system(size: 8, weight: .heavy, design: .rounded))
                        .foregroundStyle(PulseTheme.tertiaryText(colorScheme))
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 4)

                ForEach(session.recentEvents.prefix(5)) { event in
                    MoveRow(event: event)
                }
            }
            .padding(.bottom, 8)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private var sessionNameView: some View {
        let name = session.name
        let parts = name.split(separator: "/")
        let leaf = parts.last.map(String.init) ?? name

        VStack(alignment: .leading, spacing: 2) {
            Text(leaf)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(PulseTheme.primaryText(colorScheme))
                .lineLimit(1)

            Text(name)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(PulseTheme.tertiaryText(colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func toolDisplayName(_ name: String) -> String {
        switch name {
        case "Bash": return "BASH"
        case "Read": return "READ"
        case "Edit": return "EDIT"
        case "Write": return "WRITE"
        case "Glob": return "GLOB"
        case "Grep": return "GREP"
        case "Agent": return "AGENT"
        default: return name.uppercased().prefix(6).description
        }
    }

    private func toolColor(_ name: String) -> Color {
        let dark = colorScheme == .dark
        switch name {
        case "Bash": return dark
            ? Color(red: 0.98, green: 0.65, blue: 0.35)
            : Color(red: 0.80, green: 0.45, blue: 0.15)
        case "Read": return dark
            ? Color(red: 0.45, green: 0.75, blue: 0.95)
            : Color(red: 0.20, green: 0.55, blue: 0.80)
        case "Edit": return dark
            ? Color(red: 0.55, green: 0.85, blue: 0.45)
            : Color(red: 0.30, green: 0.65, blue: 0.25)
        case "Write": return dark
            ? Color(red: 0.50, green: 0.82, blue: 0.52)
            : Color(red: 0.28, green: 0.62, blue: 0.30)
        case "Glob": return dark
            ? Color(red: 0.75, green: 0.60, blue: 0.92)
            : Color(red: 0.55, green: 0.38, blue: 0.75)
        case "Grep": return dark
            ? Color(red: 0.90, green: 0.55, blue: 0.72)
            : Color(red: 0.72, green: 0.35, blue: 0.52)
        case "Agent": return PulseTheme.accent
        default: return PulseTheme.accent
        }
    }
}

// MARK: - Stat Bar (Pokemon-style)

struct StatBar: View {
    let name: String
    let value: Int
    let maxValue: Int
    let color: Color
    @Environment(\.colorScheme) private var colorScheme

    private var fraction: CGFloat {
        guard maxValue > 0 else { return 0 }
        return CGFloat(value) / CGFloat(maxValue)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(name)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(PulseTheme.secondaryText(colorScheme))
                .frame(width: 40, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(colorScheme == .dark ? 0.15 : 0.10))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * fraction, height: 6)
                }
            }
            .frame(height: 6)

            Text("\(value)")
                .font(.system(size: 9, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(color)
                .frame(width: 24, alignment: .trailing)
        }
    }
}

// MARK: - Move Row (Activity Event)

struct MoveRow: View {
    let event: ActivityEvent
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: event.icon)
                .font(.system(size: 9))
                .foregroundStyle(PulseTheme.tertiaryText(colorScheme))
                .frame(width: 14)

            Text(event.displayName)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(PulseTheme.primaryText(colorScheme))
                .lineLimit(1)

            Spacer(minLength: 0)

            Text(event.timeAgo)
                .font(.system(size: 9, design: .rounded).monospacedDigit())
                .foregroundStyle(PulseTheme.tertiaryText(colorScheme))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 2)
    }
}

// MARK: - Icon Picker

struct IconPicker: View {
    @ObservedObject var prefs: PreferenceStore
    var onIconChange: ((String) -> Void)?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Icon")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(PulseTheme.secondaryText(colorScheme))
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(availableIcons) { icon in
                        let isSelected = prefs.iconSymbol == icon.symbol
                        Button(action: {
                            prefs.setIcon(icon.symbol)
                            onIconChange?(icon.symbol)
                        }) {
                            Image(systemName: icon.symbol)
                                .font(.system(size: 13))
                                .foregroundStyle(isSelected ? PulseTheme.accent : PulseTheme.secondaryText(colorScheme))
                                .frame(width: 32, height: 32)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(isSelected
                                            ? PulseTheme.accent.opacity(colorScheme == .dark ? 0.18 : 0.12)
                                            : PulseTheme.pillBackground(colorScheme))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isSelected ? PulseTheme.accent.opacity(0.5) : PulseTheme.pillBorder(colorScheme), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .help(icon.label)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Settings

struct SettingsView: View {
    @ObservedObject var patterns: PatternStore
    @State private var newPattern = ""
    @State private var newLabel = ""
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Block all by default")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(PulseTheme.primaryText(colorScheme))
                    Text("Override all patterns to block")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(PulseTheme.tertiaryText(colorScheme))
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { patterns.config.blockByDefault },
                    set: { _ in patterns.toggleBlockByDefault() }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(PulseTheme.accent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Rectangle()
                .fill(PulseTheme.divider(colorScheme))
                .frame(height: 1)
                .padding(.leading, 16)

            VStack(spacing: 0) {
                ForEach(patterns.config.patterns) { pat in
                    PatternRow(pattern: pat, patterns: patterns)
                }
            }

            Rectangle()
                .fill(PulseTheme.divider(colorScheme))
                .frame(height: 1)
                .padding(.leading, 16)

            HStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(PulseTheme.tertiaryText(colorScheme))
                    TextField("regex", text: $newPattern)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(PulseTheme.primaryText(colorScheme))
                    TextField("label", text: $newLabel)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(PulseTheme.primaryText(colorScheme))
                        .frame(width: 50)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(PulseTheme.inputBackground(colorScheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(PulseTheme.inputBorder(colorScheme), lineWidth: 1)
                )

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
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(newPattern.isEmpty ? PulseTheme.tertiaryText(colorScheme) : PulseTheme.accent)
                }
                .buttonStyle(.plain)
                .disabled(newPattern.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

struct PatternRow: View {
    let pattern: RiskyPattern
    @ObservedObject var patterns: PatternStore
    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    private var isBlocking: Bool { pattern.mode == .block }

    private var modeColor: Color {
        if isBlocking {
            return colorScheme == .dark
                ? Color(red: 0.95, green: 0.40, blue: 0.38)
                : Color(red: 0.80, green: 0.22, blue: 0.18)
        } else {
            return colorScheme == .dark
                ? Color(red: 0.98, green: 0.72, blue: 0.30)
                : Color(red: 0.78, green: 0.52, blue: 0.08)
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isBlocking ? "shield.fill" : "exclamationmark.triangle")
                .font(.system(size: 9))
                .foregroundStyle(modeColor)
                .frame(width: 14)

            Text(pattern.label)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(PulseTheme.primaryText(colorScheme))
                .lineLimit(1)

            Spacer(minLength: 0)

            Button(action: { patterns.toggleMode(for: pattern) }) {
                Text(isBlocking ? "Block" : "Warn")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(modeColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(modeColor.opacity(colorScheme == .dark ? 0.18 : 0.10))
                    )
                    .overlay(
                        Capsule().stroke(modeColor.opacity(0.25), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)

            if isHovered {
                Button(action: { patterns.removePattern(pattern) }) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(PulseTheme.tertiaryText(colorScheme))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? PulseTheme.hoverFill(colorScheme) : .clear)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}

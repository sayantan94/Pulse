import SwiftUI

public final class SessionStore: ObservableObject {
    @Published public var sessions: [SessionInfo] = []
    @Published public private(set) var menuBarIcon: NSImage

    private var manager: SessionManager?
    private var animTimer: Timer?
    private var spinAngle: Double = 0
    private var pulseOn = true
    private var pulseTickCount = 0

    private var icon: NSImage = NSImage()
    private var iconBold: NSImage = NSImage()
    private var idleIcon: NSImage = NSImage()
    private let iconSize: CGFloat = 22

    public var topState: PulseState {
        sessions.first(where: { $0.state != .gray })?.state ?? .gray
    }

    public init() {
        menuBarIcon = NSImage()
        loadIcon(symbol: PreferenceStore().iconSymbol)

        manager = SessionManager { [weak self] sessions in
            guard let self else { return }
            let wasAnimating = self.animTimer != nil
            self.sessions = sessions
            let needsAnim = self.topState != .gray
            if needsAnim && !wasAnimating { self.startAnimation() }
            else if !needsAnim && wasAnimating { self.stopAnimation() }
            self.refreshIcon()
        }
        manager?.start()
    }

    deinit {
        animTimer?.invalidate()
        manager?.stop()
    }

    public func updateIcon(symbol: String) {
        loadIcon(symbol: symbol)
        refreshIcon()
    }

    private func loadIcon(symbol: String) {
        let regular = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        let bold = NSImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        icon = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(regular) ?? NSImage()
        iconBold = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(bold) ?? NSImage()

        let s = iconSize
        let idle = NSImage(size: NSSize(width: s, height: s), flipped: false) { [icon] rect in
            let sz = icon.size
            icon.draw(in: NSRect(x: (s - sz.width) / 2, y: (s - sz.height) / 2, width: sz.width, height: sz.height),
                     from: .zero, operation: .sourceOver, fraction: 0.4)
            return true
        }
        idle.isTemplate = true
        idleIcon = idle
        menuBarIcon = idle
    }

    // MARK: - Animation

    private func startAnimation() {
        animTimer?.invalidate()
        animTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 12.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            switch self.topState {
            case .green:
                self.spinAngle += 15
                if self.spinAngle >= 360 { self.spinAngle -= 360 }
            case .orange, .red, .yellow:
                self.pulseTickCount += 1
                if self.pulseTickCount >= 6 {
                    self.pulseOn.toggle()
                    self.pulseTickCount = 0
                }
            case .gray:
                break
            }
            self.refreshIcon()
        }
    }

    private func stopAnimation() {
        animTimer?.invalidate()
        animTimer = nil
        pulseOn = true
        pulseTickCount = 0
        spinAngle = 0
        refreshIcon()
    }

    private func refreshIcon() {
        switch topState {
        case .gray:
            menuBarIcon = idleIcon
        case .green:
            menuBarIcon = renderSpinning(angle: spinAngle)
        case .orange, .red, .yellow:
            menuBarIcon = renderPulse(state: topState, on: pulseOn)
        }
    }

    // MARK: - Rendering

    private func renderSpinning(angle: Double) -> NSImage {
        let s = iconSize
        let image = NSImage(size: NSSize(width: s, height: s), flipped: true) { [icon] rect in
            let center = NSPoint(x: s / 2, y: s / 2)
            let arc = NSBezierPath()
            arc.appendArc(withCenter: center, radius: 9.5,
                         startAngle: CGFloat(angle), endAngle: CGFloat(angle) + 230, clockwise: false)
            arc.lineWidth = 1.5
            arc.lineCapStyle = .round
            NSColor.black.withAlphaComponent(0.4).setStroke()
            arc.stroke()
            let sz = icon.size
            let x = (s - sz.width) / 2
            let y = (s - sz.height) / 2
            icon.draw(in: NSRect(x: x, y: y, width: sz.width, height: sz.height))
            return true
        }
        image.isTemplate = true
        return image
    }

    private func renderPulse(state: PulseState, on: Bool) -> NSImage {
        let s = iconSize
        let alpha: CGFloat = on ? 1.0 : 0.2
        let image = NSImage(size: NSSize(width: s, height: s), flipped: false) { [iconBold] rect in
            let tinted = iconBold.copy() as! NSImage
            tinted.lockFocus()
            state.nsColor.withAlphaComponent(alpha).set()
            NSRect(origin: .zero, size: iconBold.size).fill(using: .sourceAtop)
            tinted.unlockFocus()
            let sz = tinted.size
            let x = (s - sz.width) / 2
            let y = (s - sz.height) / 2
            tinted.draw(in: NSRect(x: x, y: y, width: sz.width, height: sz.height))
            return true
        }
        image.isTemplate = false
        return image
    }

    // MARK: - Actions

    public func dismissSession(_ session: SessionInfo) {
        manager?.removeSession(session.sessionId)
    }
}

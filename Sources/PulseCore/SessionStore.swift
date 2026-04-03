import SwiftUI

public final class SessionStore: ObservableObject {
    @Published public var sessions: [SessionInfo] = []
    @Published public private(set) var menuBarIcon: NSImage

    private var manager: SessionManager?
    private var animTimer: Timer?
    private var isActiveAnimation = false
    private var spinAngle: Double = 0
    private var pulseOn = true
    private var pulseTickCount = 0
    private var breathePhase: Double = 0

    private var icon: NSImage = NSImage()
    private var iconBold: NSImage = NSImage()
    private let iconSize: CGFloat = 22

    public var topState: PulseState {
        sessions.first(where: { $0.state != .gray })?.state ?? .gray
    }

    public init() {
        menuBarIcon = NSImage()
        loadIcon(symbol: PreferenceStore().iconSymbol)
        startIdleTimer()

        manager = SessionManager { [weak self] sessions in
            guard let self else { return }
            self.sessions = sessions
            let state = self.topState
            if state != .gray && state != .blue && !self.isActiveAnimation {
                self.startAnimation()
            } else if (state == .gray || state == .blue) && self.isActiveAnimation {
                self.stopAnimation()
                self.startIdleTimer()
            }
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
        menuBarIcon = renderBreathe(phase: breathePhase)
    }

    // MARK: - Animation

    // Slow idle breathe (~2fps, subtle)
    private func startIdleTimer() {
        animTimer?.invalidate()
        animTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 8.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.breathePhase += 0.04
            if self.breathePhase >= 1.0 { self.breathePhase -= 1.0 }
            self.refreshIcon()
        }
    }

    // Active states (working/attention)
    private func startAnimation() {
        animTimer?.invalidate()
        isActiveAnimation = true
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
            case .blue, .gray:
                break
            }
            self.refreshIcon()
        }
    }

    private func stopAnimation() {
        animTimer?.invalidate()
        animTimer = nil
        isActiveAnimation = false
        pulseOn = true
        pulseTickCount = 0
        spinAngle = 0
    }

    private func refreshIcon() {
        switch topState {
        case .gray:
            menuBarIcon = renderBreathe(phase: breathePhase)
        case .green:
            menuBarIcon = renderSpinning(angle: spinAngle)
        case .blue:
            menuBarIcon = renderStatic(state: .blue)
        case .orange, .red, .yellow:
            menuBarIcon = renderPulse(state: topState, on: pulseOn)
        }
    }

    // MARK: - Rendering

    // Idle: slow color breathe (fades between muted blue and monochrome)
    private func renderBreathe(phase: Double) -> NSImage {
        let s = iconSize
        // Sine wave: 0→1→0 over one cycle, smooth
        let t = CGFloat(sin(phase * .pi * 2) * 0.5 + 0.5)
        let alpha: CGFloat = 0.3 + t * 0.3 // 0.3 → 0.6
        let tintAlpha: CGFloat = t * 0.6    // 0.0 → 0.6

        let image = NSImage(size: NSSize(width: s, height: s), flipped: false) { [icon] rect in
            // Draw base icon
            let sz = icon.size
            let x = (s - sz.width) / 2
            let y = (s - sz.height) / 2
            let drawRect = NSRect(x: x, y: y, width: sz.width, height: sz.height)

            icon.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: alpha)

            // Overlay soft blue tint
            if tintAlpha > 0.05 {
                let tinted = icon.copy() as! NSImage
                tinted.lockFocus()
                NSColor.systemCyan.withAlphaComponent(tintAlpha).set()
                NSRect(origin: .zero, size: sz).fill(using: .sourceAtop)
                tinted.unlockFocus()
                tinted.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: tintAlpha)
            }
            return true
        }
        image.isTemplate = false
        return image
    }

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

    private func renderStatic(state: PulseState) -> NSImage {
        let s = iconSize
        let image = NSImage(size: NSSize(width: s, height: s), flipped: false) { [iconBold] rect in
            let tinted = iconBold.copy() as! NSImage
            tinted.lockFocus()
            state.nsColor.withAlphaComponent(1.0).set()
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

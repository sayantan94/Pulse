import SwiftUI

public final class SessionStore: ObservableObject {
    @Published public var sessions: [SessionInfo] = []
    @Published public private(set) var menuBarIcon: NSImage

    private var manager: SessionManager?
    private var animTimer: Timer?
    private var spinAngle: Double = 0
    private var pulseOn = true
    private var pulseTickCount = 0

    // Cached assets -- loaded once
    private let sparkle: NSImage
    private let sparkleBold: NSImage
    private let idleIcon: NSImage
    private let iconSize: CGFloat = 22

    public var topState: PulseState {
        sessions.first(where: { $0.state != .gray })?.state ?? .gray
    }

    public init() {
        let regular = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        let bold = NSImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        sparkle = NSImage(systemSymbolName: "sparkle", accessibilityDescription: nil)?.withSymbolConfiguration(regular) ?? NSImage()
        sparkleBold = NSImage(systemSymbolName: "sparkle", accessibilityDescription: nil)?.withSymbolConfiguration(bold) ?? NSImage()

        let s: CGFloat = 22
        let idle = NSImage(size: NSSize(width: s, height: s), flipped: false) { [sparkle] rect in
            let sz = sparkle.size
            sparkle.draw(in: NSRect(x: (s - sz.width) / 2, y: (s - sz.height) / 2, width: sz.width, height: sz.height),
                        from: .zero, operation: .sourceOver, fraction: 0.4)
            return true
        }
        idle.isTemplate = true
        idleIcon = idle
        menuBarIcon = idle

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

    private func drawSparkleCentered(_ symbol: NSImage, in rect: NSRect) {
        let sz = symbol.size
        let x = (rect.width - sz.width) / 2
        let y = (rect.height - sz.height) / 2
        symbol.draw(in: NSRect(x: x, y: y, width: sz.width, height: sz.height))
    }

    private func renderSpinning(angle: Double) -> NSImage {
        let s = iconSize
        let image = NSImage(size: NSSize(width: s, height: s), flipped: true) { [sparkle] rect in
            let center = NSPoint(x: s / 2, y: s / 2)
            let arc = NSBezierPath()
            arc.appendArc(withCenter: center, radius: 9.5,
                         startAngle: CGFloat(angle), endAngle: CGFloat(angle) + 230, clockwise: false)
            arc.lineWidth = 1.5
            arc.lineCapStyle = .round
            // Black with template=true: macOS auto-flips for dark mode
            NSColor.black.withAlphaComponent(0.4).setStroke()
            arc.stroke()
            let sz = sparkle.size
            let x = (s - sz.width) / 2
            let y = (s - sz.height) / 2
            sparkle.draw(in: NSRect(x: x, y: y, width: sz.width, height: sz.height))
            return true
        }
        image.isTemplate = true
        return image
    }

    private func renderPulse(state: PulseState, on: Bool) -> NSImage {
        let s = iconSize
        let alpha: CGFloat = on ? 1.0 : 0.2
        let image = NSImage(size: NSSize(width: s, height: s), flipped: false) { [sparkleBold] rect in
            let tinted = sparkleBold.copy() as! NSImage
            tinted.lockFocus()
            state.nsColor.withAlphaComponent(alpha).set()
            NSRect(origin: .zero, size: sparkleBold.size).fill(using: .sourceAtop)
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

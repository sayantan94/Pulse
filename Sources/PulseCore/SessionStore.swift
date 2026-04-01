import AppKit
import SwiftUI

public final class SessionStore: ObservableObject {
    @Published public var sessions: [SessionInfo] = []
    @Published public var menuBarIcon: NSImage = NSImage()

    private var manager: SessionManager?
    private var animTimer: Timer?
    private var spinAngle: Double = 0
    private var pulseOn: Bool = true
    private var pulseTickCount: Int = 0

    public var topState: PulseState {
        sessions.first(where: { $0.state != .gray })?.state ?? .gray
    }

    public init() {
        menuBarIcon = renderSymbol(name: "sparkle", size: 14, weight: .regular, color: nil, alpha: 0.4)
        manager = SessionManager { [weak self] sessions in
            guard let self = self else { return }
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

    private func startAnimation() {
        animTimer?.invalidate()
        animTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 12.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let state = self.topState
            if state == .green {
                self.spinAngle += 15
                if self.spinAngle >= 360 { self.spinAngle -= 360 }
            }
            if state == .orange || state == .red || state == .yellow {
                self.pulseTickCount += 1
                // Toggle every 6 ticks (~0.5s on, 0.5s off)
                if self.pulseTickCount >= 6 {
                    self.pulseOn.toggle()
                    self.pulseTickCount = 0
                }
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
        let state = topState
        switch state {
        case .gray:
            menuBarIcon = renderSymbol(name: "sparkle", size: 14, weight: .regular, color: nil, alpha: 0.4)
        case .green:
            menuBarIcon = renderSpinning(angle: spinAngle)
        case .orange, .red, .yellow:
            let alpha: CGFloat = pulseOn ? 1.0 : 0.25
            menuBarIcon = renderSymbol(name: "sparkle", size: 14, weight: .bold, color: state.nsColor, alpha: alpha)
        }
    }

    // MARK: - Render SF Symbol to NSImage

    private func renderSymbol(name: String, size: CGFloat, weight: NSFont.Weight, color: NSColor?, alpha: CGFloat) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: size, weight: weight)
        guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else { return NSImage() }

        let s: CGFloat = 22
        let image = NSImage(size: NSSize(width: s, height: s), flipped: false) { rect in
            let symbolSize = symbol.size
            let x = (s - symbolSize.width) / 2
            let y = (s - symbolSize.height) / 2

            if let color = color {
                // Draw colored: tint the symbol
                let tinted = symbol.copy() as! NSImage
                tinted.lockFocus()
                color.withAlphaComponent(alpha).set()
                NSRect(origin: .zero, size: symbolSize).fill(using: .sourceAtop)
                tinted.unlockFocus()
                tinted.draw(in: NSRect(x: x, y: y, width: symbolSize.width, height: symbolSize.height))
            } else {
                // Draw as template (auto light/dark)
                symbol.draw(in: NSRect(x: x, y: y, width: symbolSize.width, height: symbolSize.height),
                           from: .zero, operation: .sourceOver, fraction: alpha)
            }
            return true
        }
        image.isTemplate = (color == nil)
        return image
    }

    private func renderSpinning(angle: Double) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        guard let symbol = NSImage(systemSymbolName: "sparkle", accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else { return NSImage() }

        let s: CGFloat = 22
        let image = NSImage(size: NSSize(width: s, height: s), flipped: true) { rect in
            // Spinning arc
            let center = NSPoint(x: s / 2, y: s / 2)
            let arc = NSBezierPath()
            arc.appendArc(withCenter: center, radius: 9.5,
                         startAngle: CGFloat(angle), endAngle: CGFloat(angle) + 230, clockwise: false)
            arc.lineWidth = 1.5
            arc.lineCapStyle = .round
            NSColor.black.withAlphaComponent(0.4).setStroke()
            arc.stroke()

            // Sparkle centered
            let symbolSize = symbol.size
            let x = (s - symbolSize.width) / 2
            let y = (s - symbolSize.height) / 2
            symbol.draw(in: NSRect(x: x, y: y, width: symbolSize.width, height: symbolSize.height))
            return true
        }
        image.isTemplate = true
        return image
    }

    // MARK: - Actions

    public func dismissSession(_ session: SessionInfo) {
        manager?.removeSession(session.sessionId)
    }
}

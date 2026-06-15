import AppKit
import SwiftUI
import Combine

final class FloatingPanelController {

    static let compactSize  = CGSize(width: 240, height: 176)
    static let expandedSize = CGSize(width: 240, height: 384)
    static let margin: CGFloat = 20

    private let ble: BLEManager
    private let engine: WorkoutEngine
    private let goalStore: GoalStore
    private let panelState = PanelState()
    private var panel: FloatingPanel?
    private var cancellables: Set<AnyCancellable> = []

    private var hoverTimer: Timer?
    private var hoverExitedAt: Date?

    init(ble: BLEManager, engine: WorkoutEngine, goalStore: GoalStore) {
        self.ble = ble
        self.engine = engine
        self.goalStore = goalStore
        panelState.isPinned = UserDefaults.standard.bool(forKey: "widget.pinned")
        buildPanel()
        observeBLEState()
        observeDragging()
        observePinning()
    }

    // MARK: - Setup

    private func buildPanel() {
        let rect  = NSRect(origin: .zero, size: Self.compactSize)
        let panel = FloatingPanel(contentRect: rect)

        let view    = FloatingPanelView(ble: ble, engine: engine,
                                        goalStore: goalStore, panelState: panelState)
        let hosting = NSHostingView(rootView: view)
        hosting.frame = rect
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting

        positionPanel(panel)
        self.panel = panel
    }

    private func positionPanel(_ panel: FloatingPanel) {
        guard let screen = NSScreen.main else { return }
        var origin = NSPoint(
            x: screen.visibleFrame.maxX - Self.compactSize.width - Self.margin,
            y: screen.visibleFrame.minY + Self.margin)

        // Restore where the user last dragged the widget, if still on a screen.
        let d = UserDefaults.standard
        if d.object(forKey: "widget.x") != nil {
            let saved = NSPoint(x: d.double(forKey: "widget.x"),
                                y: d.double(forKey: "widget.y"))
            let rect = NSRect(origin: saved, size: Self.compactSize)
            if NSScreen.screens.contains(where: { $0.visibleFrame.intersects(rect) }) {
                origin = saved
            }
        }
        panel.setFrame(NSRect(origin: origin, size: Self.compactSize), display: false)
    }

    private func observeDragging() {
        NotificationCenter.default
            .publisher(for: NSWindow.didMoveNotification)
            .compactMap { [weak self] note -> NSRect? in
                guard let panel = self?.panel,
                      (note.object as? NSWindow) === panel else { return nil }
                return panel.frame
            }
            .sink { frame in
                // Persist the compact-equivalent origin (bottom-right anchored)
                // so expand/collapse and restore all agree on the same spot.
                let d = UserDefaults.standard
                d.set(frame.maxX - Self.compactSize.width, forKey: "widget.x")
                d.set(frame.minY, forKey: "widget.y")
            }
            .store(in: &cancellables)
    }

    private func observeBLEState() {
        ble.$isConnected
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                connected ? self?.show() : self?.hide()
            }
            .store(in: &cancellables)
    }

    private func observePinning() {
        panelState.$isPinned
            .dropFirst()
            .sink { [weak self] pinned in
                UserDefaults.standard.set(pinned, forKey: "widget.pinned")
                if pinned {
                    self?.expand()
                } else if let panel = self?.panel,
                          !panel.frame.contains(NSEvent.mouseLocation) {
                    self?.collapse(animated: true)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Visibility

    func show() {
        guard let panel, !panel.isVisible else { return }
        positionPanel(panel)
        if panelState.isPinned { expand() }
        panel.alphaValue = 0
        panel.orderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
        startHoverTracking()
    }

    func hide() {
        guard let panel, panel.isVisible else { return }
        stopHoverTracking()
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.4
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self, weak panel] in
            panel?.orderOut(nil)
            self?.collapse(animated: false)
        })
    }

    // MARK: - Hover tracking
    //
    // SwiftUI's .onHover can't drive a window resize: resizing invalidates the
    // tracking area mid-animation, which fires a phantom exit and the panel
    // oscillates. Polling the global mouse location against the window frame
    // is immune to relayout, and a short exit-delay adds hysteresis.

    private func startHoverTracking() {
        hoverTimer?.invalidate()
        hoverTimer = .scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.checkHover()
        }
    }

    private func stopHoverTracking() {
        hoverTimer?.invalidate()
        hoverTimer = nil
        hoverExitedAt = nil
    }

    private func checkHover() {
        guard let panel else { return }

        if panelState.isPinned {
            hoverExitedAt = nil
            if !panelState.isExpanded { expand() }
            return
        }

        let inside = panel.frame.contains(NSEvent.mouseLocation)

        if inside {
            hoverExitedAt = nil
            if !panelState.isExpanded { expand() }
        } else if panelState.isExpanded {
            if let exitedAt = hoverExitedAt {
                if Date().timeIntervalSince(exitedAt) > 0.25 { collapse(animated: true) }
            } else {
                hoverExitedAt = Date()
            }
        }
    }

    // MARK: - Expansion
    //
    // The window is transparent, so it can jump to its final size instantly
    // (invisible) while SwiftUI animates the visible card inside it. The card
    // is bottom-aligned, so it grows upward from a fixed bottom-right anchor.

    private func expand() {
        guard let panel else { return }
        panel.setFrame(frameAnchored(to: Self.expandedSize, current: panel.frame),
                       display: true)
        panelState.isExpanded = true
    }

    private func collapse(animated: Bool) {
        guard let panel else { return }
        hoverExitedAt = nil
        panelState.isExpanded = false

        let shrink = { [weak self, weak panel] in
            guard let self, let panel, !self.panelState.isExpanded else { return }
            panel.setFrame(self.frameAnchored(to: Self.compactSize, current: panel.frame),
                           display: true)
        }
        // Let the card's collapse animation finish before the window shrinks.
        animated ? DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: shrink)
                 : shrink()
    }

    private func frameAnchored(to size: CGSize, current: NSRect) -> NSRect {
        NSRect(x: current.maxX - size.width,
               y: current.minY,
               width: size.width,
               height: size.height)
    }
}

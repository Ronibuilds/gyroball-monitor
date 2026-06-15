import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {

    let ble = BLEManager()
    let store = TrainingStore()
    let goalStore = GoalStore()
    // Lazy so it exists the moment the scene body (MenuBarExtra) is first
    // evaluated, which SwiftUI may do before applicationDidFinishLaunching.
    private(set) lazy var engine = WorkoutEngine(ble: ble, store: store, goalStore: goalStore)
    private(set) var panelController: FloatingPanelController?
    private var dashboardWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        panelController = FloatingPanelController(ble: ble, engine: engine, goalStore: goalStore)
        openDashboard()
    }

    // Double-clicking the app in Finder/Spotlight while it's already running.
    func applicationShouldHandleReopen(_ sender: NSApplication,
                                       hasVisibleWindows flag: Bool) -> Bool {
        openDashboard()
        return true
    }

    func openDashboard() {
        if dashboardWindow == nil {
            let window = NSWindow(
                contentViewController: NSHostingController(
                    rootView: DashboardView(ble: ble, engine: engine,
                                            goalStore: goalStore, store: store)))
            window.title = "Gyroball"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 960, height: 640))
            window.center()
            window.isReleasedWhenClosed = false
            window.delegate = self
            dashboardWindow = window
        }
        NSApp.setActivationPolicy(.regular)
        dashboardWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) === dashboardWindow else { return }
        NSApp.setActivationPolicy(.accessory)
    }
}

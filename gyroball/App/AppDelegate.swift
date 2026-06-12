import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {

    let ble = BLEManager()
    let store = SessionStore()
    private(set) var tracker: SessionTracker!
    private(set) var panelController: FloatingPanelController?
    private var dashboardWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        tracker = SessionTracker(ble: ble, store: store)
        panelController = FloatingPanelController(ble: ble, store: store)
        openDashboard()
    }

    func applicationWillTerminate(_ notification: Notification) {
        tracker?.finalize()
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
                    rootView: DashboardView(ble: ble, store: store)))
            window.title = "Gyroball"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 920, height: 600))
            window.center()
            window.isReleasedWhenClosed = false
            window.delegate = self
            dashboardWindow = window
        }
        // Show in the Dock and app switcher while the dashboard is open.
        NSApp.setActivationPolicy(.regular)
        dashboardWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) === dashboardWindow else { return }
        NSApp.setActivationPolicy(.accessory)
    }
}

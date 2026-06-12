import SwiftUI

@main
struct GyroballApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Gyroball", systemImage: "gyroscope") {
            MenuContent(
                ble: appDelegate.ble,
                store: appDelegate.store,
                openDashboard: { appDelegate.openDashboard() },
                resetSession: { appDelegate.tracker.discard() })
        }
        .menuBarExtraStyle(.menu)
    }
}

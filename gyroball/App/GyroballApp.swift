import SwiftUI

@main
struct GyroballApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Gyroball", systemImage: "gyroscope") {
            MenuContent(
                ble: appDelegate.ble,
                engine: appDelegate.engine,
                goalStore: appDelegate.goalStore,
                store: appDelegate.store,
                openDashboard: { appDelegate.openDashboard() },
                resetSet: { appDelegate.engine.resetCurrentSet(keepingCounter: true) })
        }
        .menuBarExtraStyle(.menu)
    }
}

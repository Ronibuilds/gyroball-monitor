import SwiftUI

struct MenuContent: View {
    @ObservedObject var ble: BLEManager
    @ObservedObject var store: SessionStore
    let openDashboard: () -> Void
    let resetSession: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
            Text(statusText)
                .foregroundStyle(.secondary)
        }

        Divider()

        Button("Open Dashboard…") { openDashboard() }

        Divider()

        if ble.isConnected {
            Text("Current  \(Fmt.rpm(ble.telemetry.rpm)) rpm")
            Text("Top  \(Fmt.rpm(ble.telemetry.topSpeed)) rpm")
            Text("Average  \(Fmt.rpm(ble.telemetry.averageRPM)) rpm")
            Text("Revolutions  \(Fmt.revs(ble.telemetry.totalRevolutions))")
            Text("Active time  \(Fmt.time(ble.telemetry.activeSeconds))")

            Divider()
        }

        Text("Today  \(Fmt.revs(store.todayRevolutions + ble.telemetry.totalRevolutions)) revs · \(Fmt.time(store.todaySeconds + ble.telemetry.activeSeconds))")
            .foregroundStyle(.secondary)

        if ble.lastRawValue > 0 {
            Text(String(format: "Raw %d → %.0f rpm",
                        ble.lastRawValue,
                        Telemetry.rpm(fromRaw: ble.lastRawValue) ?? 0))
                .foregroundStyle(.tertiary)
        }

        Divider()

        if ble.isConnected {
            Button("Reset session") { resetSession() }
        }

        Button("Quit Gyroball") { NSApplication.shared.terminate(nil) }
    }

    private var statusColor: Color {
        ble.isConnected ? (ble.telemetry.isActive ? .green : .yellow) : .secondary
    }

    private var statusText: String {
        if ble.isConnected {
            return ble.telemetry.isActive ? "Spinning" : "Connected — idle"
        }
        return "Scanning for NSD Workout…"
    }
}

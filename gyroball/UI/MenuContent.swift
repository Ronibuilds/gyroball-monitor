import SwiftUI

struct MenuContent: View {
    @ObservedObject var ble: BLEManager
    @ObservedObject var engine: WorkoutEngine
    @ObservedObject var goalStore: GoalStore
    @ObservedObject var store: TrainingStore
    let openDashboard: () -> Void
    let resetSet: () -> Void

    private var goal: Goal { goalStore.goal }

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(statusColor).frame(width: 7, height: 7)
            Text(statusText).foregroundStyle(.secondary)
        }

        Divider()

        Button("Open Dashboard…") { openDashboard() }

        Divider()

        if ble.isConnected {
            Text("Set \(min(engine.currentSetIndex + 1, goal.setsPerDay)) of \(goal.setsPerDay) · Arm \(engine.currentArmIndex + 1)")
            Text("Arm time  \(Fmt.clock(engine.activeArmSeconds)) / \(Fmt.clock(goal.secondsPerArm))")
            Text(String(format: "Current  %@ rpm  (target %@)",
                        Fmt.rpm(ble.telemetry.rpm), Fmt.rpm(goal.targetRPM)))
            Divider()
        }

        Text("Today  \(store.today.completedSets)/\(goal.setsPerDay) sets · \(Fmt.time(store.today.spinSeconds))")
            .foregroundStyle(.secondary)
        if store.streak(default: goal) > 0 {
            Text("Streak  \(store.streak(default: goal)) days").foregroundStyle(.secondary)
        }

        Divider()

        if ble.isConnected {
            Button("Reset current set") { resetSet() }
        }
        Button("Quit Gyroball") { NSApplication.shared.terminate(nil) }
    }

    private var statusColor: Color {
        ble.isConnected ? (ble.telemetry.isActive ? Theme.green : .yellow) : .secondary
    }

    private var statusText: String {
        guard ble.isConnected else { return "Scanning for NSD Workout…" }
        return ble.telemetry.isActive ? "Spinning" : "Connected — idle"
    }
}

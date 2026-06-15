import SwiftUI
import Charts

struct OverviewView: View {

    @ObservedObject var ble: BLEManager
    @ObservedObject var engine: WorkoutEngine
    @ObservedObject var goalStore: GoalStore
    @ObservedObject var store: TrainingStore

    private var goal: Goal { goalStore.goal }
    private var today: TrainingDay { store.today }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                statusHeader

                HStack(alignment: .top, spacing: 16) {
                    todayCard
                    goalCard
                }

                progressionCard
                consistencyCard
            }
            .padding(24)
        }
    }

    // MARK: - Status

    private var statusHeader: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(ble.isConnected ? (ble.telemetry.isActive ? Theme.green : .yellow) : .gray)
                .frame(width: 9, height: 9)
            Text(statusText)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            if store.streak(default: goal) > 0 {
                Label("\(store.streak(default: goal))-day streak",
                      systemImage: "flame.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.orange)
            }
        }
    }

    private var statusText: String {
        guard ble.isConnected else { return "Scanning for NSD Workout…" }
        guard ble.telemetry.isActive else { return "Connected — idle" }
        let set = min(engine.currentSetIndex + 1, goal.setsPerDay)
        return "Spinning · Set \(set), Arm \(engine.currentArmIndex + 1) — "
            + "\(Fmt.clock(engine.activeArmSeconds)) / \(Fmt.clock(goal.secondsPerArm))"
    }

    // MARK: - Today

    private var todayCard: some View {
        DashCard(title: "Today", systemImage: "calendar", accentColor: Theme.green) {
            HStack(spacing: 9) {
                ForEach(0..<goal.setsPerDay, id: \.self) { i in
                    setPill(i)
                }
            }
            .padding(.bottom, 4)

            HStack {
                MetricTile(label: "Sets",
                           value: "\(min(engine.currentSetIndex, goal.setsPerDay))",
                           unit: "/ \(goal.setsPerDay)")
                MetricTile(label: "Avg RPM",
                           value: today.avgRPM > 0 ? Fmt.rpm(today.avgRPM) : "—",
                           color: today.avgRPM > 0 ? Fmt.targetColor(today.avgRPM, target: goal.targetRPM) : .primary)
                MetricTile(label: "Time", value: Fmt.time(today.spinSeconds))
            }
        }
    }

    private func setPill(_ i: Int) -> some View {
        let done = i < engine.currentSetIndex
        let current = i == engine.currentSetIndex
        return ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(done ? Theme.green : Color.primary.opacity(0.06))
            if current {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Theme.blue, lineWidth: 2)
            }
            if done {
                Image(systemName: "checkmark").font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Text("\(i + 1)").font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(current ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
            }
        }
        .frame(width: 34, height: 34)
    }

    // MARK: - Goal (manual)

    private var goalCard: some View {
        DashCard(title: "Current goal", systemImage: "target", accentColor: .orange) {
            GoalStepper(label: "Target RPM",
                        value: Fmt.rpm(goal.targetRPM),
                        onDec: { goalStore.bumpRPM(-Goal.rpmStep) },
                        onInc: { goalStore.bumpRPM(Goal.rpmStep) })
            Divider().opacity(0.4)
            GoalStepper(label: "Time per arm",
                        value: Fmt.clock(goal.secondsPerArm),
                        onDec: { goalStore.bumpArm(-Goal.armStep) },
                        onInc: { goalStore.bumpArm(Goal.armStep) })
            Divider().opacity(0.4)
            GoalStepper(label: "Sets per day",
                        value: "\(goal.setsPerDay)",
                        onDec: { goalStore.bumpSets(-1) },
                        onInc: { goalStore.bumpSets(1) })
        }
    }

    // MARK: - Baseline progression

    private var progressionDays: [TrainingDay] {
        store.recentDays(42).filter { $0.avgRPM > 0 }
    }

    private var progressionCard: some View {
        DashCard(title: "Baseline progression", systemImage: "chart.line.uptrend.xyaxis") {
            HStack {
                SectionLabel(text: "Avg RPM per training day · last 6 weeks")
                Spacer()
            }
            if progressionDays.count < 2 {
                emptyHint("Train a few days to see your baseline trend.")
            } else {
                Chart {
                    RuleMark(y: .value("Target", goal.targetRPM))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(.secondary)
                        .annotation(position: .top, alignment: .leading) {
                            Text("Target \(Fmt.rpm(goal.targetRPM))")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    ForEach(progressionDays) { day in
                        AreaMark(x: .value("Day", day.date, unit: .day),
                                 y: .value("Avg RPM", day.avgRPM))
                            .foregroundStyle(.linearGradient(colors: [Theme.blue.opacity(0.22), .clear],
                                                             startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("Day", day.date, unit: .day),
                                 y: .value("Avg RPM", day.avgRPM))
                            .foregroundStyle(Theme.blue)
                            .interpolationMethod(.catmullRom)
                        PointMark(x: .value("Day", day.date, unit: .day),
                                  y: .value("Avg RPM", day.avgRPM))
                            .foregroundStyle(Theme.blue)
                            .symbolSize(28)
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 150)

                if let nudge = progressionNudge {
                    Text(nudge).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
        }
    }

    /// Encourage bumping the target after a sustained run at or above it.
    private var progressionNudge: String? {
        let recent = store.recentDays(7).filter { $0.completion(default: goal) >= 1 }
        let hitting = recent.filter { $0.avgRPM >= goal.targetRPM }.count
        guard hitting >= 5 else { return nil }
        return "You've met your goal at or above \(Fmt.rpm(goal.targetRPM)) RPM for \(hitting) of the last 7 days — consider bumping the target."
    }

    // MARK: - Consistency

    private var consistencyCard: some View {
        let days = store.recentDays(28)
        return DashCard(title: "Consistency", systemImage: "square.grid.3x3.fill") {
            HStack {
                SectionLabel(text: "Goal completion · last 28 days")
                Spacer()
            }
            HStack(spacing: 5) {
                ForEach(days) { day in
                    let c = day.completion(default: goal)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(heatColor(c))
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .help("\(Fmt.dayDate.string(from: day.date)) · \(day.completedSets)/\(day.goal(default: goal).setsPerDay) sets")
                }
            }
            HStack(spacing: 14) {
                legend(Theme.green, "Goal met")
                legend(Theme.green.opacity(0.4), "Partial")
                legend(Color.primary.opacity(0.06), "Rest / missed")
                Spacer()
            }
            .padding(.top, 2)
        }
    }

    private func heatColor(_ c: Double) -> Color {
        if c >= 1 { return Theme.green }
        if c > 0 { return Theme.green.opacity(0.25 + c * 0.4) }
        return Color.primary.opacity(0.06)
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 10, height: 10)
            Text(text).font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }

    private func emptyHint(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, minHeight: 80)
    }
}

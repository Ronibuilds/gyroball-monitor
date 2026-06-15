import SwiftUI
import Charts

struct DayDetailView: View {

    let day: TrainingDay
    @ObservedObject var store: TrainingStore
    @ObservedObject var goalStore: GoalStore
    let onDelete: () -> Void

    private var goal: Goal { day.goal(default: goalStore.goal) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                HStack(spacing: 16) {
                    MetricTile(label: "Sets completed",
                               value: "\(day.completedSets)", unit: "/ \(goal.setsPerDay)",
                               color: day.completedSets >= goal.setsPerDay ? Theme.green : .primary)
                    MetricTile(label: "Avg RPM", value: Fmt.rpm(day.avgRPM),
                               color: Fmt.targetColor(day.avgRPM, target: goal.targetRPM))
                    MetricTile(label: "Top RPM", value: Fmt.rpm(day.topRPM))
                    MetricTile(label: "Total time", value: Fmt.time(day.spinSeconds))
                }
                .padding(.horizontal, 18).padding(.vertical, 16)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(0.045)))

                SectionLabel(text: "Sets")
                ForEach(Array(day.sets.enumerated()), id: \.element.id) { idx, set in
                    setCard(idx: idx, set: set)
                }
            }
            .padding(24)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(Fmt.dayDate.string(from: day.date))
                    .font(.system(size: 22, weight: .semibold))
                Text("Goal: \(Fmt.rpm(goal.targetRPM)) RPM · \(Fmt.clock(goal.secondsPerArm))/arm · \(goal.setsPerDay) sets")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            Button(role: .destructive) {
                store.deleteDay(day); onDelete()
            } label: {
                Label("Delete day", systemImage: "trash")
            }
        }
    }

    private func setCard(idx: Int, set: WorkoutSet) -> some View {
        DashCard {
            HStack {
                Text("Set \(set.setIndex + 1)")
                    .font(.system(size: 14, weight: .semibold))
                if set.isComplete {
                    Label("Complete", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.green)
                } else {
                    Text("Partial").font(.system(size: 11, weight: .semibold)).foregroundStyle(.orange)
                }
                Spacer()
                Text(Fmt.time(set.spinSeconds)).font(.system(size: 12, design: .rounded))
                    .monospacedDigit().foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                ForEach(Array(set.arms.enumerated()), id: \.offset) { i, arm in
                    armColumn(index: i, arm: arm)
                }
            }

            if set.samples.count >= 2 {
                Chart(Array(set.samples.enumerated()), id: \.offset) { i, rpm in
                    AreaMark(x: .value("s", i), y: .value("RPM", rpm))
                        .foregroundStyle(.linearGradient(colors: [Theme.blue.opacity(0.2), .clear],
                                                         startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("s", i), y: .value("RPM", rpm))
                        .foregroundStyle(Theme.blue).interpolationMethod(.catmullRom)
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .chartXAxis(.hidden)
                .frame(height: 90)
            }
        }
    }

    private func armColumn(index: Int, arm: ArmSegment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: "Arm \(index + 1)")
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule().fill(arm.spinSeconds >= goal.secondsPerArm ? Theme.green : Theme.blue)
                        .frame(width: geo.size.width * min(1, arm.spinSeconds / max(1, goal.secondsPerArm)))
                }
            }
            .frame(height: 6)
            Text("\(Fmt.clock(arm.spinSeconds)) · \(Fmt.rpm(arm.avgRPM)) avg · \(Fmt.rpm(arm.topRPM)) top")
                .font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

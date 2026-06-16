import SwiftUI
import Charts

struct DayDetailView: View {
    let day: TrainingDay
    @ObservedObject var store: TrainingStore
    @ObservedObject var goalStore: GoalStore
    var onClose: () -> Void

    private var goal: Goal { day.goal(default: goalStore.goal) }
    private var prs: PRs { store.personalRecords() }
    private var isTopRPMPR: Bool {
        guard let pr = prs.topRPM else { return false }
        return abs(day.topRPM - pr.value) < 0.5 && Calendar.current.isDate(day.date, inSameDayAs: pr.date)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                DashCard(tier: .hero) {
                    HStack(spacing: 22) {
                        GaugeRing(progress: day.completion(default: goal),
                                  tint: day.completedSets >= goal.setsPerDay ? Theme.green : Theme.blue,
                                  lineWidth: 9) {
                            VStack(spacing: 0) {
                                Text("\(day.completedSets)").font(.system(size: 30, weight: .semibold, design: .rounded))
                                Text("/ \(goal.setsPerDay) sets").miniLabel()
                            }
                        }
                        .frame(width: 104, height: 104)

                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 16) {
                                MetricTile(label: "Avg RPM", value: Fmt.rpm(day.avgRPM),
                                           color: Fmt.targetColor(day.avgRPM, target: goal.targetRPM))
                                topRPMTile
                            }
                            HStack(spacing: 16) {
                                MetricTile(label: "Spin time", value: Fmt.time(day.spinSeconds))
                                MetricTile(label: "Goal", value: Fmt.rpm(goal.targetRPM), unit: "rpm")
                            }
                        }
                    }
                }

                SectionLabel(text: "Sets")
                if day.sets.isEmpty {
                    DashCard { EmptyState(symbol: "tray", title: "No sets this day") }
                } else {
                    ForEach(day.sets) { set in
                        NavigationLink(value: set) { setRow(set) }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) { store.deleteSet(set.id) } label: {
                                    Label("Delete set", systemImage: "trash")
                                }
                            }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle(Fmt.dayDate.string(from: day.date))
        .toolbar {
            ToolbarItem {
                Menu {
                    Button(role: .destructive) { store.deleteDay(day); onClose() } label: {
                        Label("Delete day", systemImage: "trash")
                    }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Fmt.dayDate.string(from: day.date)).font(.system(size: 22, weight: .semibold))
            Text("Goal: \(Fmt.rpm(goal.targetRPM)) RPM · \(Fmt.clock(goal.secondsPerArm))/arm · \(goal.setsPerDay) sets")
                .font(.callout).foregroundStyle(.secondary)
        }
    }

    private var topRPMTile: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                SectionLabel(text: "Top RPM")
                if isTopRPMPR {
                    Image(systemName: "trophy.fill").font(.system(size: 9)).foregroundStyle(.yellow)
                }
            }
            Text(Fmt.rpm(day.topRPM))
                .font(.system(size: 24, weight: .semibold, design: .rounded)).monospacedDigit()
                .foregroundStyle(Fmt.zoneColor(day.topRPM))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func setRow(_ set: WorkoutSet) -> some View {
        DashCard {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill((set.isComplete ? Theme.green : Color.orange).opacity(0.16))
                    Image(systemName: set.isComplete ? "checkmark" : "circle.dotted")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(set.isComplete ? Theme.green : .orange)
                }
                .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Set \(set.setIndex + 1)").font(.system(size: 14, weight: .semibold))
                    HStack(spacing: 4) {
                        ForEach(Array(set.arms.enumerated()), id: \.offset) { _, arm in
                            armChip(arm, secPerArm: set.secondsPerArm)
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Fmt.rpm(set.avgRPM)) avg")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Fmt.targetColor(set.avgRPM, target: set.targetRPM))
                    Text(Fmt.time(set.spinSeconds)).font(.caption).foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary)
            }
        }
    }

    private func armChip(_ arm: ArmSegment, secPerArm: TimeInterval) -> some View {
        Capsule()
            .fill(arm.spinSeconds >= secPerArm ? Theme.green : Theme.blue.opacity(0.6))
            .frame(width: 22, height: 5)
    }
}

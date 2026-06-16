import SwiftUI
import Charts

struct SetDetailView: View {
    let set: WorkoutSet
    @ObservedObject var store: TrainingStore
    @ObservedObject var goalStore: GoalStore
    @Environment(\.dismiss) private var dismiss

    private var target: Double { self.set.targetRPM }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                // Rev-counter hero: representative (avg) RPM on the absolute scale.
                DashCard(tier: .hero) {
                    HStack(spacing: 20) {
                        ZStack {
                            RevCounter(rpm: set.avgRPM, target: target, maxRPM: 10_000,
                                       armProgress: min(1, set.spinSeconds / max(1, set.secondsPerArm * 2)),
                                       active: set.avgRPM > 0, animated: false, showTargetLabel: false)
                            VStack(spacing: 1) {
                                Text(Fmt.rpm(set.avgRPM))
                                    .font(.system(size: 30, weight: .light, design: .rounded)).monospacedDigit()
                                    .foregroundStyle(Fmt.zoneColor(set.avgRPM))
                                Text("AVG RPM").miniLabel()
                            }
                        }
                        .frame(width: 168, height: 158)

                        VStack(alignment: .leading, spacing: 12) {
                            MetricTile(label: "Top RPM", value: Fmt.rpm(set.topRPM), color: Fmt.zoneColor(set.topRPM))
                            MetricTile(label: "Spin time", value: Fmt.time(set.spinSeconds))
                            MetricTile(label: "Vs target", value: Fmt.delta(set.avgRPM - target),
                                       color: Fmt.targetColor(set.avgRPM, target: target))
                        }
                    }
                }

                if set.samples.count >= 2 {
                    DashCard(title: "Speed trace", systemImage: "waveform.path.ecg") {
                        sampleTrace(set.samples)
                    }
                } else {
                    DashCard { EmptyState(symbol: "waveform.slash", title: "No live trace recorded for this set") }
                }

                SectionLabel(text: "Arms")
                ForEach(Array(set.arms.enumerated()), id: \.offset) { i, arm in
                    ArmRow(index: i, arm: arm, set: set)
                }
            }
            .padding(24)
        }
        .navigationTitle("Set \(set.setIndex + 1)")
        .toolbar {
            ToolbarItem {
                Menu {
                    Button(role: .destructive) { store.deleteSet(set.id); dismiss() } label: {
                        Label("Delete set", systemImage: "trash")
                    }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text("Set \(set.setIndex + 1)").font(.system(size: 22, weight: .semibold))
                if set.isComplete {
                    Label("Complete", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.green)
                } else {
                    Text("Partial").font(.system(size: 12, weight: .semibold)).foregroundStyle(.orange)
                }
            }
            Text("\(Fmt.dayDate.string(from: set.startedAt)) · goal \(Fmt.rpm(target)) RPM · \(Fmt.clock(set.secondsPerArm))/arm")
                .font(.callout).foregroundStyle(.secondary)
        }
    }

    private func sampleTrace(_ samples: [Double]) -> some View {
        Chart {
            RuleMark(y: .value("Target", target))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4])).foregroundStyle(.secondary)
            ForEach(Array(samples.enumerated()), id: \.offset) { i, rpm in
                AreaMark(x: .value("s", i), y: .value("RPM", rpm))
                    .foregroundStyle(.linearGradient(colors: [Theme.blue.opacity(0.2), .clear],
                                                     startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("s", i), y: .value("RPM", rpm))
                    .foregroundStyle(Theme.blue).interpolationMethod(.catmullRom)
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXAxis(.hidden)
        .frame(height: 150)
    }
}

// MARK: - Arm row (inline expandable)

private struct ArmRow: View {
    let index: Int
    let arm: ArmSegment
    let set: WorkoutSet
    @State private var expanded = false

    private var hitTarget: Bool { arm.spinSeconds >= set.secondsPerArm }

    var body: some View {
        DashCard {
            VStack(alignment: .leading, spacing: expanded ? 14 : 0) {
                Button { withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) { expanded.toggle() } } label: {
                    HStack(spacing: 12) {
                        SectionLabel(text: "Arm \(index + 1)")
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.primary.opacity(0.08))
                                Capsule().fill(hitTarget ? Theme.green : Theme.blue)
                                    .frame(width: geo.size.width * min(1, arm.spinSeconds / max(1, set.secondsPerArm)))
                            }
                        }
                        .frame(height: 6)
                        Text(Fmt.clock(arm.spinSeconds))
                            .font(.system(size: 12, design: .rounded)).monospacedDigit().foregroundStyle(.secondary)
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if expanded {
                    if arm.isEmpty {
                        EmptyState(symbol: "minus.circle", title: "This arm wasn't recorded.")
                    } else {
                        HStack(spacing: 20) {
                            ZStack {
                                RevCounter(rpm: arm.avgRPM, target: set.targetRPM, maxRPM: 10_000,
                                           armProgress: min(1, arm.spinSeconds / max(1, set.secondsPerArm)),
                                           active: arm.avgRPM > 0, animated: false, showTargetLabel: false)
                                VStack(spacing: 0) {
                                    Text(Fmt.rpm(arm.avgRPM))
                                        .font(.system(size: 24, weight: .light, design: .rounded)).monospacedDigit()
                                        .foregroundStyle(Fmt.zoneColor(arm.avgRPM))
                                    Text("AVG").miniLabel()
                                }
                            }
                            .frame(width: 132, height: 124)
                            VStack(alignment: .leading, spacing: 10) {
                                MetricTile(label: "Top RPM", value: Fmt.rpm(arm.topRPM), color: Fmt.zoneColor(arm.topRPM))
                                MetricTile(label: "Time", value: Fmt.clock(arm.spinSeconds),
                                           color: hitTarget ? Theme.green : .primary)
                            }
                        }
                    }
                }
            }
        }
    }
}

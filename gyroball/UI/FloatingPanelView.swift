import SwiftUI

/// The floating widget. Collapsed: a compact "current rep" readout (live RPM
/// vs target + the arm timer). Expanded: a progress ring with the live RPM at
/// its center, above a per-set tracker for the day.
struct FloatingPanelView: View {

    @ObservedObject var ble: BLEManager
    @ObservedObject var engine: WorkoutEngine
    @ObservedObject var goalStore: GoalStore
    @ObservedObject var panelState: PanelState

    private var goal: Goal { goalStore.goal }
    private var rpm: Double { ble.telemetry.rpm }
    private var isActive: Bool { ble.telemetry.isActive }
    private var tint: Color { isActive ? Fmt.targetColor(rpm, target: goal.targetRPM) : .secondary }
    private var dayDone: Bool { engine.currentSetIndex >= goal.setsPerDay }

    var body: some View {
        VStack(spacing: 0) {
            if panelState.isExpanded {
                expanded
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                collapsed
            }
        }
        .frame(width: 216)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(.white.opacity(0.10), lineWidth: 1))
        .overlay(alignment: .topTrailing) { pinButton }
        .shadow(color: .black.opacity(0.28), radius: 22, y: 8)
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: panelState.isExpanded)
    }

    // MARK: - Collapsed (compact "current rep")

    private var collapsed: some View {
        VStack(spacing: 14) {
            VStack(spacing: 5) {
                Text(isActive ? Fmt.rpm(rpm) : "—")
                    .font(.system(size: 46, weight: .ultraLight, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isActive ? AnyShapeStyle(tint) : AnyShapeStyle(.primary))
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4), value: rpm)
                HStack(spacing: 6) {
                    Text("RPM").miniLabel()
                    if isActive { DeltaChip(rpm: rpm, target: goal.targetRPM) }
                }
            }

            VStack(spacing: 10) {
                TargetBar(rpm: rpm, target: goal.targetRPM, active: isActive)
                ArmTimerBar(seconds: engine.activeArmSeconds,
                            target: goal.secondsPerArm,
                            armIndex: engine.currentArmIndex,
                            done: engine.currentArmDone)
            }
        }
        .padding(.top, 18)
        .padding(.bottom, 16)
        .padding(.horizontal, 18)
    }

    // MARK: - Expanded (ring + set tracker)

    private var expanded: some View {
        VStack(spacing: 0) {
            HStack {
                Text(dayDone ? "DAY COMPLETE" : "SET \(min(engine.currentSetIndex + 1, goal.setsPerDay)) · ARM \(engine.currentArmIndex + 1)")
                    .miniLabel()
                Spacer()
                Text("\(goal.setsPerDay) SETS").miniLabel()
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)

            ArmRing(rpm: rpm, target: goal.targetRPM, active: isActive,
                    progress: engine.armProgress(target: goal.secondsPerArm),
                    tint: tint, done: engine.currentArmDone)
                .frame(width: 152, height: 152)
                .padding(.top, 8)

            HStack(spacing: 4) {
                Text(Fmt.clock(engine.activeArmSeconds))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text("/ \(Fmt.clock(goal.secondsPerArm)) this arm")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)

            Divider().background(Theme.hairline).padding(.horizontal, 16).padding(.top, 12)

            SetTracker(goal: goal,
                       completedSets: engine.currentSetIndex,
                       currentArm: engine.currentArmIndex,
                       armSeconds: engine.armSeconds)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
    }

    // MARK: - Pin

    private var pinButton: some View {
        Button { panelState.isPinned.toggle() } label: {
            Image(systemName: panelState.isPinned ? "pin.fill" : "pin")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(panelState.isPinned ? AnyShapeStyle(.orange) : AnyShapeStyle(.tertiary))
                .padding(9)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(panelState.isExpanded ? 1 : 0)
        .help(panelState.isPinned ? "Unpin — collapse when not hovering" : "Pin expanded")
    }
}

// MARK: - Delta chip ("▲ +40")

private struct DeltaChip: View {
    let rpm: Double
    let target: Double

    var body: some View {
        let d = rpm - target
        let color = Fmt.targetColor(rpm, target: target)
        return HStack(spacing: 3) {
            Image(systemName: d >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                .font(.system(size: 6, weight: .black))
            Text(Fmt.delta(d))
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(color)
        .padding(.horizontal, 7).padding(.vertical, 2)
        .background(Capsule().fill(color.opacity(0.16)))
    }
}

// MARK: - Target-marked RPM bar

private struct TargetBar: View {
    let rpm: Double
    let target: Double
    let active: Bool

    var body: some View {
        let scaleMax = target * 1.5                 // target sits at ~67%
        let frac = active ? min(1, rpm / scaleMax) : 0
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.track)
                    Capsule()
                        .fill(Fmt.targetColor(rpm, target: target))
                        .frame(width: geo.size.width * frac)
                        .animation(.spring(response: 0.5), value: rpm)
                    Rectangle()                      // target tick
                        .fill(.white.opacity(0.85))
                        .frame(width: 2, height: 11)
                        .offset(x: geo.size.width * (target / scaleMax) - 1, y: -3)
                }
            }
            .frame(height: 5)
            HStack {
                Text("RPM").miniLabel()
                Spacer()
                Text("TARGET \(Fmt.rpm(target))").miniLabel()
            }
        }
    }
}

// MARK: - Arm timer bar

private struct ArmTimerBar: View {
    let seconds: TimeInterval
    let target: TimeInterval
    let armIndex: Int
    let done: Bool

    var body: some View {
        let frac = target > 0 ? min(1, seconds / target) : 0
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.track)
                    Capsule()
                        .fill(done ? Theme.green : Theme.blue)
                        .frame(width: geo.size.width * frac)
                        .animation(.linear(duration: 0.3), value: seconds)
                }
            }
            .frame(height: 5)
            HStack {
                Text("ARM \(armIndex + 1) · TIME").miniLabel()
                Spacer()
                if done {
                    Text("SWITCH ARMS").miniLabel(color: Theme.green)
                } else {
                    Text("\(Fmt.clock(seconds)) / \(Fmt.clock(target))").miniLabel()
                }
            }
        }
    }
}

// MARK: - Arm ring

private struct ArmRing: View {
    let rpm: Double
    let target: Double
    let active: Bool
    let progress: Double
    let tint: Color
    let done: Bool

    var body: some View {
        ZStack {
            Circle().stroke(Theme.track, lineWidth: 10)
            Circle()
                .trim(from: 0, to: max(0.001, progress))
                .stroke(done ? Theme.green : tint,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.3), value: progress)
            Circle()                                  // target marker at 12 o'clock
                .fill(.white.opacity(0.55))
                .frame(width: 5, height: 5)
                .offset(y: -71)

            VStack(spacing: 1) {
                Text(active ? Fmt.rpm(rpm) : "—")
                    .font(.system(size: 40, weight: .ultraLight, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(active ? AnyShapeStyle(tint) : AnyShapeStyle(.primary))
                    .contentTransition(.numericText())
                Text("RPM").miniLabel()
                if active {
                    DeltaChip(rpm: rpm, target: target).padding(.top, 4)
                }
            }
        }
    }
}

// MARK: - Per-set tracker rows

private struct SetTracker: View {
    let goal: Goal
    let completedSets: Int
    let currentArm: Int
    let armSeconds: [TimeInterval]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<goal.setsPerDay, id: \.self) { i in
                row(for: i)
            }
        }
    }

    @ViewBuilder
    private func row(for i: Int) -> some View {
        let isCurrent = i == completedSets
        let isDone = i < completedSets

        HStack(spacing: 8) {
            Text("\(i + 1)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(isCurrent ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                .frame(width: 14, alignment: .leading)

            HStack(spacing: 4) {
                ForEach(0..<2, id: \.self) { arm in
                    armBar(set: i, arm: arm, isCurrent: isCurrent, isDone: isDone)
                }
            }

            Group {
                if isDone {
                    Image(systemName: "checkmark").font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.green)
                } else if isCurrent {
                    Text("now").font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
                } else {
                    Color.clear
                }
            }
            .frame(width: 26, alignment: .trailing)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: 7)
            .fill(isCurrent ? Color.white.opacity(0.05) : .clear))
    }

    private func armBar(set i: Int, arm: Int, isCurrent: Bool, isDone: Bool) -> some View {
        let frac: Double = {
            if isDone { return 1 }
            if isCurrent {
                return min(1, armSeconds[arm] / max(1, goal.secondsPerArm))
            }
            return 0
        }()
        let live = isCurrent && arm == currentArm
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track)
                Capsule().fill(Theme.green)
                    .frame(width: geo.size.width * frac)
                    .animation(.linear(duration: 0.3), value: frac)
            }
            .overlay(live && frac < 1
                     ? Capsule().strokeBorder(Theme.blue.opacity(0.7), lineWidth: 1) : nil)
        }
        .frame(height: 6)
    }
}

// MARK: - Shared label style

private extension Text {
    func miniLabel(color: Color = Color.secondary.opacity(0.85)) -> some View {
        self.font(.system(size: 8.5, weight: .bold))
            .tracking(1.6)
            .foregroundStyle(color)
    }
}

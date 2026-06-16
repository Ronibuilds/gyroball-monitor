import SwiftUI

/// The floating widget. Collapsed: a compact "current rep" readout (live RPM
/// vs target + the arm timer). Expanded: the living rev-counter with the RPM at
/// its center, above a per-set tracker for the day.
struct FloatingPanelView: View {

    @ObservedObject var ble: BLEManager
    @ObservedObject var engine: WorkoutEngine
    @ObservedObject var goalStore: GoalStore
    @ObservedObject var panelState: PanelState

    private var goal: Goal { goalStore.goal }
    private var rpm: Double { ble.telemetry.rpm }
    private var isActive: Bool { ble.telemetry.isActive }
    private var numberColor: Color { isActive ? Fmt.zoneColor(rpm) : .secondary }
    private var dayDone: Bool { engine.currentSetIndex >= goal.setsPerDay }

    var body: some View {
        VStack(spacing: 0) {
            if panelState.isExpanded {
                expanded.transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                collapsed
            }
        }
        .frame(width: 216)
        // Guaranteed-dark substrate (scrim over material) so light text reads
        // over white / grey / black windows behind the panel.
        .background {
            let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
            shape
                .fill(LinearGradient(colors: [Color(white: 0.13).opacity(0.84),
                                              Color(white: 0.05).opacity(0.92)],
                                     startPoint: .top, endPoint: .bottom))
                .background(.ultraThinMaterial, in: shape)
        }
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(.white.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.32), radius: 22, y: 8)
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .environment(\.colorScheme, .dark)   // content is designed for a dark substrate
        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: panelState.isExpanded)
    }

    // MARK: - Collapsed (compact "current rep")

    private var collapsed: some View {
        VStack(spacing: 14) {
            VStack(spacing: 5) {
                Text(isActive ? Fmt.rpm(rpm) : "—")
                    .font(.system(size: 46, weight: .ultraLight, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isActive ? AnyShapeStyle(numberColor) : AnyShapeStyle(.primary))
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4), value: rpm)
                HStack(spacing: 6) {
                    Text("RPM").miniLabel()
                    if isActive { DeltaChip(rpm: rpm, target: goal.targetRPM) }
                }
            }
            VStack(spacing: 10) {
                TargetBar(rpm: rpm, target: goal.targetRPM, active: isActive)
                ArmTimerBar(seconds: engine.activeArmSeconds, target: goal.secondsPerArm,
                            armIndex: engine.currentArmIndex, done: engine.currentArmDone)
            }
        }
        .padding(.top, 18).padding(.bottom, 16).padding(.horizontal, 18)
    }

    // MARK: - Expanded (rev-counter + set tracker)

    private var expanded: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text(dayDone ? "DAY COMPLETE"
                     : "SET \(min(engine.currentSetIndex + 1, goal.setsPerDay)) · ARM \(engine.currentArmIndex + 1)")
                    .miniLabel()
                Spacer()
                Text("\(goal.setsPerDay) SETS").miniLabel()
                pinButton
            }
            .padding(.horizontal, 16).padding(.top, 13)

            ZStack {
                RevCounter(rpm: rpm, target: goal.targetRPM, maxRPM: 10_000,
                           armProgress: engine.armProgress(target: goal.secondsPerArm),
                           active: isActive)
                VStack(spacing: 1) {
                    Text(isActive ? Fmt.rpm(rpm) : "—")
                        .font(.system(size: 38, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(isActive ? AnyShapeStyle(numberColor) : AnyShapeStyle(.primary))
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4), value: rpm)
                    Text("RPM").miniLabel()
                    if isActive { DeltaChip(rpm: rpm, target: goal.targetRPM).padding(.top, 4) }
                }
                .offset(y: 6)
            }
            .frame(width: 208, height: 184)
            .padding(.top, 2)

            HStack(spacing: 4) {
                Text(Fmt.clock(engine.activeArmSeconds))
                    .font(.system(size: 14, weight: .semibold, design: .rounded)).monospacedDigit()
                Text("/ \(Fmt.clock(goal.secondsPerArm)) this arm")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }

            Divider().background(Theme.hairline).padding(.horizontal, 16).padding(.top, 12)

            SetTracker(goal: goal, completedSets: engine.currentSetIndex,
                       currentArm: engine.currentArmIndex, armSeconds: engine.armSeconds)
                .padding(.horizontal, 16).padding(.vertical, 10)
        }
    }

    // MARK: - Pin (sleek, in the header)

    private var pinButton: some View {
        Button { panelState.isPinned.toggle() } label: {
            Image(systemName: panelState.isPinned ? "pin.fill" : "pin")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(panelState.isPinned ? AnyShapeStyle(.orange) : AnyShapeStyle(.tertiary))
                .frame(width: 20, height: 20)
                .background(Circle().fill(.white.opacity(panelState.isPinned ? 0.08 : 0.04)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(panelState.isPinned ? "Unpin — collapse when not hovering" : "Pin expanded")
    }
}

// MARK: - Arm timer bar (widget-only)

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
                    Capsule().fill(done ? Theme.green : Theme.blue)
                        .frame(width: geo.size.width * frac)
                        .animation(.linear(duration: 0.3), value: seconds)
                }
            }
            .frame(height: 5)
            HStack {
                Text("ARM \(armIndex + 1) · TIME").miniLabel()
                Spacer()
                if done { Text("SWITCH ARMS").miniLabel(color: Theme.green) }
                else { Text("\(Fmt.clock(seconds)) / \(Fmt.clock(target))").miniLabel() }
            }
        }
    }
}

// MARK: - Per-set tracker (widget-only)

private struct SetTracker: View {
    let goal: Goal
    let completedSets: Int
    let currentArm: Int
    let armSeconds: [TimeInterval]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<goal.setsPerDay, id: \.self) { i in row(for: i) }
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
                    armBar(arm: arm, isCurrent: isCurrent, isDone: isDone)
                }
            }
            Group {
                if isDone {
                    Image(systemName: "checkmark").font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.green)
                } else if isCurrent {
                    Text("now").font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
                } else { Color.clear }
            }
            .frame(width: 26, alignment: .trailing)
        }
        .padding(.vertical, 4).padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: 7)
            .fill(isCurrent ? Color.white.opacity(0.05) : .clear))
    }

    private func armBar(arm: Int, isCurrent: Bool, isDone: Bool) -> some View {
        let frac: Double = isDone ? 1 : (isCurrent ? min(1, armSeconds[arm] / max(1, goal.secondsPerArm)) : 0)
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

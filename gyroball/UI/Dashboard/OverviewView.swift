import SwiftUI
import Charts

struct OverviewView: View {

    @ObservedObject var ble: BLEManager
    @ObservedObject var engine: WorkoutEngine
    @ObservedObject var goalStore: GoalStore
    @ObservedObject var store: TrainingStore
    var onSelectDay: (Date) -> Void

    private var goal: Goal { goalStore.goal }
    private var today: TrainingDay { store.today }
    private var live: Bool { ble.telemetry.isActive }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                statusHeader
                hero
                if !today.sets.isEmpty || engine.currentSetIndex > 0 { todayChips }
                prStrip
                progressionCard
                HStack(alignment: .top, spacing: 16) {
                    armBalanceCard
                    distributionCard
                }
                consistencyCard
                goalCard
            }
            .padding(24)
        }
    }

    // MARK: - Status

    private var statusHeader: some View {
        HStack(spacing: 9) {
            Circle().fill(ble.isConnected ? (live ? Theme.green : .yellow) : .gray)
                .frame(width: 9, height: 9)
            Text(statusText).font(.system(size: 15, weight: .semibold)).foregroundStyle(.secondary)
            Spacer()
            if store.streak(default: goal) > 0 {
                StreakBadge(count: store.streak(default: goal), best: store.longestStreak(default: goal))
            }
        }
    }

    private var statusText: String {
        guard ble.isConnected else { return "Scanning for NSD Workout…" }
        guard live else { return "Connected — idle" }
        return "Spinning · Set \(min(engine.currentSetIndex + 1, goal.setsPerDay)), Arm \(engine.currentArmIndex + 1) — "
            + "\(Fmt.clock(engine.activeArmSeconds)) / \(Fmt.clock(goal.secondsPerArm))"
    }

    // MARK: - Hero (live rev-counter ↔ idle completion ring)

    private var hero: some View {
        DashCard(tier: .hero) {
            HStack(spacing: 22) {
                ZStack {
                    if live {
                        RevCounter(rpm: ble.telemetry.rpm, target: goal.targetRPM, maxRPM: 10_000,
                                   armProgress: engine.armProgress(target: goal.secondsPerArm), active: true)
                        VStack(spacing: 1) {
                            Text(Fmt.rpm(ble.telemetry.rpm))
                                .font(.system(size: 36, weight: .light, design: .rounded)).monospacedDigit()
                                .foregroundStyle(Fmt.zoneColor(ble.telemetry.rpm))
                                .contentTransition(.numericText())
                            Text("RPM").miniLabel()
                            DeltaChip(rpm: ble.telemetry.rpm, target: goal.targetRPM).padding(.top, 3)
                        }
                    } else {
                        GaugeRing(progress: today.completion(default: goal),
                                  tint: today.completedSets >= goal.setsPerDay ? Theme.green : Theme.blue,
                                  lineWidth: 11, showTargetMarker: false) {
                            VStack(spacing: 1) {
                                if today.sets.isEmpty {
                                    Image(systemName: "bolt.slash").font(.system(size: 22)).foregroundStyle(.secondary)
                                    Text("NOT STARTED").miniLabel()
                                } else {
                                    Text("\(today.completedSets)").font(.system(size: 40, weight: .semibold, design: .rounded))
                                    Text("OF \(goal.setsPerDay) SETS").miniLabel()
                                }
                            }
                        }
                    }
                }
                .frame(width: 210, height: 190)

                VStack(alignment: .leading, spacing: 14) {
                    Text(live ? "Live session" : "Today").font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
                    HStack(spacing: 16) {
                        MetricTile(label: "Sets", value: "\(live ? engine.currentSetIndex : today.completedSets)", unit: "/ \(goal.setsPerDay)")
                        MetricTile(label: "Avg RPM", value: today.avgRPM > 0 ? Fmt.rpm(today.avgRPM) : "—",
                                   color: today.avgRPM > 0 ? Fmt.targetColor(today.avgRPM, target: goal.targetRPM) : .primary)
                    }
                    HStack(spacing: 16) {
                        MetricTile(label: "Spin time", value: Fmt.time(today.spinSeconds))
                        MetricTile(label: "Top RPM", value: today.topRPM > 0 ? Fmt.rpm(today.topRPM) : "—",
                                   color: today.topRPM > 0 ? Fmt.zoneColor(today.topRPM) : .primary)
                    }
                }
            }
        }
    }

    // MARK: - Today set chips

    private var todayChips: some View {
        DashCard(title: "Today's sets", systemImage: "checklist", accentColor: Theme.green) {
            HStack(spacing: 9) {
                ForEach(0..<goal.setsPerDay, id: \.self) { i in chip(i) }
                Spacer()
            }
        }
    }

    @ViewBuilder
    private func chip(_ i: Int) -> some View {
        let completedCount = live ? engine.currentSetIndex : today.completedSets
        let done = i < completedCount
        let current = live && i == engine.currentSetIndex
        if let set = today.sets.first(where: { $0.setIndex == i && $0.isComplete }) {
            NavigationLink(value: set) { chipBody(i, done: true, current: false) }.buttonStyle(.plain)
        } else {
            chipBody(i, done: done, current: current)
        }
    }

    private func chipBody(_ i: Int, done: Bool, current: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(done ? Theme.green : Color.primary.opacity(0.06))
            if current {
                RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.blue, lineWidth: 2)
            }
            if done {
                Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
            } else {
                Text("\(i + 1)").font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(current ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
            }
        }
        .frame(width: 36, height: 36)
    }

    // MARK: - PR strip

    private var prStrip: some View {
        let prs = store.personalRecords()
        return DashCard(title: "Personal records", systemImage: "trophy") {
            HStack(spacing: 14) {
                prTile("Top RPM", prs.topRPM.map { Fmt.rpm($0.value) } ?? "—",
                       color: prs.topRPM.map { Fmt.zoneColor($0.value) } ?? .primary, date: prs.topRPM?.date)
                Divider().frame(height: 34)
                prTile("Best set avg", prs.bestSetAvgRPM.map { Fmt.rpm($0.value) } ?? "—",
                       color: prs.bestSetAvgRPM.map { Fmt.zoneColor($0.value) } ?? .primary, date: prs.bestSetAvgRPM?.date)
                Divider().frame(height: 34)
                prTile("Longest arm", prs.longestArmHold.map { Fmt.clock($0.value) } ?? "—",
                       color: .primary, date: prs.longestArmHold?.date)
                Divider().frame(height: 34)
                prTile("Total sets", "\(store.totalSets)", color: .primary, date: nil)
            }
        }
    }

    private func prTile(_ label: String, _ value: String, color: Color, date: Date?) -> some View {
        Button { if let date { onSelectDay(Calendar.current.startOfDay(for: date)) } } label: {
            VStack(alignment: .leading, spacing: 4) {
                SectionLabel(text: label)
                Text(value).font(.system(size: 20, weight: .semibold, design: .rounded)).monospacedDigit().foregroundStyle(color)
            }
            .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
        }
        .buttonStyle(.plain).disabled(date == nil)
    }

    // MARK: - Progression

    private var progressionCard: some View {
        let trend = store.rpmTrend(days: 42)
        return DashCard(title: "Baseline progression", systemImage: "chart.line.uptrend.xyaxis") {
            HStack {
                SectionLabel(text: "Avg RPM per training day · last 6 weeks")
                Spacer()
                if trend.points.count >= 2 {
                    Text("\(Fmt.delta(trend.slopePerWeek))/wk")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(trend.slopePerWeek >= 0 ? Theme.green : .orange)
                }
            }
            if trend.points.count < 2 {
                EmptyState(symbol: "chart.line.uptrend.xyaxis", title: "Not enough data yet",
                           hint: "Train a few days to see your baseline trend.")
            } else {
                Chart {
                    RuleMark(y: .value("Target", goal.targetRPM))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4])).foregroundStyle(.secondary)
                        .annotation(position: .top, alignment: .leading) {
                            Text("Target \(Fmt.rpm(goal.targetRPM))").font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
                        }
                    ForEach(trend.points, id: \.date) { p in
                        AreaMark(x: .value("Day", p.date, unit: .day), y: .value("Avg", p.avgRPM))
                            .foregroundStyle(.linearGradient(colors: [Theme.blue.opacity(0.22), .clear], startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("Day", p.date, unit: .day), y: .value("Avg", p.avgRPM))
                            .foregroundStyle(Theme.blue).interpolationMethod(.catmullRom)
                        PointMark(x: .value("Day", p.date, unit: .day), y: .value("Avg", p.avgRPM))
                            .foregroundStyle(Fmt.targetColor(p.avgRPM, target: goal.targetRPM)).symbolSize(30)
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 150)
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .onTapGesture(coordinateSpace: .local) { loc in
                                let x = loc.x - geo[proxy.plotAreaFrame].origin.x
                                if let date: Date = proxy.value(atX: x) { selectNearestDay(date, in: trend.points) }
                            }
                    }
                }
                if let nudge = progressionNudge {
                    HStack {
                        Text(nudge).font(.system(size: 11)).foregroundStyle(.secondary)
                        Spacer()
                        Button("Bump target") { goalStore.bumpRPM(Goal.rpmStep) }
                            .buttonStyle(.borderedProminent).controlSize(.small).tint(Theme.green)
                    }
                }
            }
        }
    }

    private func selectNearestDay(_ date: Date, in points: [DayPoint]) {
        guard let nearest = points.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }) else { return }
        onSelectDay(nearest.date)
    }

    private var progressionNudge: String? {
        let recent = store.recentDays(7).filter { $0.completion(default: goal) >= 1 }
        let hitting = recent.filter { $0.avgRPM >= goal.targetRPM }.count
        guard hitting >= 5 else { return nil }
        return "Met your goal at/above \(Fmt.rpm(goal.targetRPM)) RPM for \(hitting) of the last 7 days."
    }

    // MARK: - Arm balance

    private var armBalanceCard: some View {
        let b = store.armBalance(days: 14)
        let hasData = b.armASeconds + b.armBSeconds > 0
        return DashCard(title: "Arm balance", systemImage: "arrow.left.arrow.right") {
            if !hasData {
                EmptyState(symbol: "arrow.left.arrow.right", title: "No arm data yet")
            } else {
                let shareA = b.timeSharePctA
                let balanced = abs(shareA - 0.5) < 0.05
                VStack(alignment: .leading, spacing: 10) {
                    GeometryReader { geo in
                        HStack(spacing: 2) {
                            Rectangle().fill(balanced ? Theme.blue : Theme.orange)
                                .frame(width: geo.size.width * shareA)
                            Rectangle().fill(balanced ? Theme.blue : Theme.blue.opacity(0.6))
                        }
                        .clipShape(Capsule())
                        .overlay(Rectangle().fill(.white.opacity(0.7)).frame(width: 1.5)
                            .frame(maxWidth: .infinity, alignment: .center))
                    }
                    .frame(height: 10)
                    HStack {
                        armLabel("Arm 1", b.armAAvgRPM, Int(shareA * 100))
                        Spacer()
                        armLabel("Arm 2", b.armBAvgRPM, Int((1 - shareA) * 100))
                    }
                    Text("The ball can't tell left from right — arms are detected in order.")
                        .font(.system(size: 9.5)).foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func armLabel(_ name: String, _ rpm: Double, _ pct: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionLabel(text: name)
            Text("\(pct)% · \(Fmt.rpm(rpm)) avg")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Fmt.targetColor(rpm, target: goal.targetRPM))
        }
    }

    // MARK: - RPM distribution

    private var distributionCard: some View {
        let bins = store.avgRPMDistribution(binWidth: 150)
        return DashCard(title: "RPM distribution", systemImage: "chart.bar.fill") {
            if bins.isEmpty {
                EmptyState(symbol: "chart.bar", title: "No sets logged yet")
            } else {
                Chart {
                    RuleMark(x: .value("Target", goal.targetRPM))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4])).foregroundStyle(.secondary)
                    ForEach(bins) { bin in
                        BarMark(x: .value("RPM", bin.center), y: .value("Sets", bin.count), width: .ratio(0.85))
                            .foregroundStyle(Fmt.zoneColor(bin.center)).cornerRadius(2)
                    }
                }
                .chartYAxis { AxisMarks(position: .leading) }
                .frame(height: 130)
            }
        }
    }

    // MARK: - Consistency

    private var consistencyCard: some View {
        let days = store.recentDays(28)
        return DashCard(title: "Consistency", systemImage: "square.grid.3x3.fill") {
            HStack {
                SectionLabel(text: "Goal completion · last 28 days")
                Spacer()
                Text("\(Int(store.adherenceRate(days: 28, default: goal) * 100))% adherence")
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
            }
            HStack(spacing: 5) {
                ForEach(days) { day in
                    Button { if !day.sets.isEmpty { onSelectDay(day.date) } } label: {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(heatColor(day.completion(default: goal)))
                            .frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
                            .help("\(Fmt.dayDate.string(from: day.date)) · \(day.completedSets)/\(day.goal(default: goal).setsPerDay) sets")
                    }
                    .buttonStyle(.plain).disabled(day.sets.isEmpty)
                }
            }
            HStack(spacing: 14) {
                legend(Theme.green, "Goal met"); legend(Theme.green.opacity(0.4), "Partial")
                legend(Color.primary.opacity(0.06), "Rest / missed"); Spacer()
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

    // MARK: - Goal editor

    private var goalCard: some View {
        DashCard(title: "Current goal", systemImage: "target", accentColor: .orange) {
            GoalStepper(label: "Target RPM", value: Fmt.rpm(goal.targetRPM),
                        onDec: { goalStore.bumpRPM(-Goal.rpmStep) }, onInc: { goalStore.bumpRPM(Goal.rpmStep) })
            Divider().opacity(0.4)
            GoalStepper(label: "Time per arm", value: Fmt.clock(goal.secondsPerArm),
                        onDec: { goalStore.bumpArm(-Goal.armStep) }, onInc: { goalStore.bumpArm(Goal.armStep) })
            Divider().opacity(0.4)
            GoalStepper(label: "Sets per day", value: "\(goal.setsPerDay)",
                        onDec: { goalStore.bumpSets(-1) }, onInc: { goalStore.bumpSets(1) })
        }
    }
}

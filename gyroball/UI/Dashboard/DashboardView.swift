import SwiftUI

struct DashboardView: View {

    @ObservedObject var ble: BLEManager
    @ObservedObject var engine: WorkoutEngine
    @ObservedObject var goalStore: GoalStore
    @ObservedObject var store: TrainingStore

    @State private var selection: SidebarItem? = .overview
    @State private var path = NavigationPath()

    enum SidebarItem: Hashable { case overview; case day(Date) }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            NavigationStack(path: $path) {
                root
                    .navigationDestination(for: WorkoutSet.self) { set in
                        SetDetailView(set: set, store: store, goalStore: goalStore)
                    }
            }
            .onChange(of: selection) { _ in path = NavigationPath() }
        }
        .frame(minWidth: 880, minHeight: 580)
        .navigationTitle("Gyroball")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                HStack(spacing: 8) {
                    Brand.logo.resizable().interpolation(.high).frame(width: 20, height: 20)
                    Text("Gyroball").font(.headline)
                }
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selection) {
            Label("Overview", systemImage: "gauge.with.dots.needle.bottom.50percent")
                .tag(SidebarItem.overview)

            if store.days.isEmpty {
                Section("Training days") {
                    Text("No training days yet").foregroundStyle(.tertiary).font(.callout)
                }
            } else {
                let groups = groupedDays()
                ForEach(groups, id: \.title) { group in
                    Section(group.title) {
                        ForEach(group.days) { day in
                            DayRow(day: day, goal: day.goal(default: goalStore.goal))
                                .tag(SidebarItem.day(day.date))
                                .contextMenu {
                                    Button { selection = .day(day.date) } label: { Label("Open", systemImage: "arrow.right.circle") }
                                    Button(role: .destructive) { store.deleteDay(day) } label: { Label("Delete day", systemImage: "trash") }
                                }
                        }
                    }
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 250)
    }

    private func groupedDays() -> [(title: String, days: [TrainingDay])] {
        let cal = Calendar.current
        let weekStart = cal.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let thisWeek = store.days.filter { $0.date >= weekStart }
        let earlier = store.days.filter { $0.date < weekStart }
        var out: [(String, [TrainingDay])] = []
        if !thisWeek.isEmpty { out.append(("This week", thisWeek)) }
        if !earlier.isEmpty { out.append(("Earlier", earlier)) }
        return out
    }

    // MARK: - Detail root

    @ViewBuilder private var root: some View {
        switch selection {
        case .day(let date):
            if let day = store.days.first(where: { $0.date == date }) {
                DayDetailView(day: day, store: store, goalStore: goalStore) { selection = .overview }
            } else {
                placeholder
            }
        default:
            OverviewView(ble: ble, engine: engine, goalStore: goalStore, store: store) {
                selection = .day($0)
            }
        }
    }

    private var placeholder: some View {
        Text("Select a day").foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Sidebar row

private struct DayRow: View {
    let day: TrainingDay
    let goal: Goal

    var body: some View {
        HStack(spacing: 10) {
            GaugeRing(progress: day.completion(default: goal),
                      tint: day.completion(default: goal) >= 1 ? Theme.green : Theme.blue,
                      lineWidth: 3, trackColor: Color.primary.opacity(0.12)) {
                if day.completion(default: goal) >= 1 {
                    Image(systemName: "checkmark").font(.system(size: 8, weight: .bold)).foregroundStyle(Theme.green)
                }
            }
            .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(Fmt.dayDate.string(from: day.date)).font(.callout)
                Text("\(day.completedSets)/\(goal.setsPerDay) sets · \(Fmt.rpm(day.avgRPM)) avg")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

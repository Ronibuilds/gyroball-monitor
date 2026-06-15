import SwiftUI

struct DashboardView: View {

    @ObservedObject var ble: BLEManager
    @ObservedObject var engine: WorkoutEngine
    @ObservedObject var goalStore: GoalStore
    @ObservedObject var store: TrainingStore

    @State private var selection: SidebarItem? = .overview

    enum SidebarItem: Hashable {
        case overview
        case day(Date)
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label("Overview", systemImage: "chart.xyaxis.line")
                    .tag(SidebarItem.overview)

                Section("Training days") {
                    if store.days.isEmpty {
                        Text("No training days yet")
                            .foregroundStyle(.tertiary).font(.callout)
                    }
                    ForEach(store.days) { day in
                        DayRow(day: day, goal: day.goal(default: goalStore.goal))
                            .tag(SidebarItem.day(day.date))
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 210, ideal: 240)
        } detail: {
            switch selection {
            case .day(let date):
                if let day = store.days.first(where: { $0.date == date }) {
                    DayDetailView(day: day, store: store, goalStore: goalStore) {
                        selection = .overview
                    }
                } else {
                    placeholder
                }
            default:
                OverviewView(ble: ble, engine: engine, goalStore: goalStore, store: store)
            }
        }
        .frame(minWidth: 820, minHeight: 540)
        .navigationTitle("Gyroball")
    }

    private var placeholder: some View {
        Text("Select a day")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Sidebar row

private struct DayRow: View {
    let day: TrainingDay
    let goal: Goal

    var body: some View {
        HStack(spacing: 10) {
            completionRing
            VStack(alignment: .leading, spacing: 2) {
                Text(Fmt.dayDate.string(from: day.date)).font(.callout)
                Text("\(day.completedSets)/\(goal.setsPerDay) sets · \(Fmt.rpm(day.avgRPM)) avg")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }

    private var completionRing: some View {
        let c = day.completion(default: goal)
        return ZStack {
            Circle().stroke(Color.primary.opacity(0.12), lineWidth: 3)
            Circle().trim(from: 0, to: max(0.001, c))
                .stroke(c >= 1 ? Theme.green : Theme.blue,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if c >= 1 {
                Image(systemName: "checkmark").font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Theme.green)
            }
        }
        .frame(width: 22, height: 22)
    }
}

import SwiftUI

struct DashboardView: View {

    @ObservedObject var ble: BLEManager
    @ObservedObject var store: SessionStore

    @State private var selection: SidebarItem? = .overview

    enum SidebarItem: Hashable {
        case overview
        case session(Int64)
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label("Overview", systemImage: "chart.xyaxis.line")
                    .tag(SidebarItem.overview)

                Section("Sessions") {
                    if store.sessions.isEmpty {
                        Text("No sessions yet")
                            .foregroundStyle(.tertiary)
                            .font(.callout)
                    }
                    ForEach(store.sessions) { session in
                        SessionRow(session: session)
                            .tag(SidebarItem.session(session.id))
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 230)
        } detail: {
            switch selection {
            case .session(let id):
                if let session = store.sessions.first(where: { $0.id == id }) {
                    SessionDetailView(session: session, store: store) {
                        selection = .overview
                    }
                } else {
                    placeholder
                }
            default:
                OverviewView(ble: ble, store: store)
            }
        }
        .frame(minWidth: 760, minHeight: 480)
        .navigationTitle("Gyroball")
    }

    private var placeholder: some View {
        Text("Select a session")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Sidebar row

private struct SessionRow: View {
    let session: WorkoutSession

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Fmt.sessionDate.string(from: session.startedAt))
                .font(.callout)
            Text("\(Fmt.revs(session.revolutions)) revs · \(Fmt.time(session.duration)) · top \(Fmt.rpm(session.topRPM))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

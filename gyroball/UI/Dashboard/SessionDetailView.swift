import SwiftUI
import Charts

struct SessionDetailView: View {

    let session: WorkoutSession
    let store: SessionStore
    let onDelete: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                HStack(spacing: 12) {
                    StatCard(title: "Top speed",
                             value: "\(Fmt.rpm(session.topRPM)) rpm",
                             icon: "flame",
                             color: .red)
                    StatCard(title: "Average",
                             value: "\(Fmt.rpm(session.avgRPM)) rpm",
                             icon: "gauge.medium",
                             color: .blue)
                    StatCard(title: "Revolutions",
                             value: Fmt.revs(session.revolutions),
                             icon: "arrow.triangle.2.circlepath",
                             color: .green)
                    StatCard(title: "Duration",
                             value: Fmt.time(session.duration),
                             icon: "clock",
                             color: .purple)
                }

                if session.samples.count >= 2 {
                    Text("Speed over time")
                        .font(.title3.weight(.semibold))
                    sessionChart
                        .frame(height: 220)
                        .padding(16)
                        .background(cardBackground(.blue))
                }
            }
            .padding(24)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(Fmt.sessionDate.string(from: session.startedAt))
                    .font(.title2.weight(.semibold))
                Text("Session")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(role: .destructive) {
                store.delete(session)
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var sessionChart: some View {
        Chart(Array(session.samples.enumerated()), id: \.offset) { i, rpm in
            AreaMark(x: .value("Seconds", i), y: .value("RPM", rpm))
                .foregroundStyle(
                    .linearGradient(colors: [.cyan.opacity(0.3), .clear],
                                    startPoint: .top, endPoint: .bottom))
            LineMark(x: .value("Seconds", i), y: .value("RPM", rpm))
                .foregroundStyle(
                    .linearGradient(colors: [.cyan, .blue],
                                    startPoint: .top, endPoint: .bottom))
                .interpolationMethod(.catmullRom)
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXAxisLabel("seconds", alignment: .trailing)
    }
}

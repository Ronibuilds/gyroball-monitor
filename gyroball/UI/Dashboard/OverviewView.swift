import SwiftUI
import Charts

struct OverviewView: View {

    @ObservedObject var ble: BLEManager
    @ObservedObject var store: SessionStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                statusHeader

                if ble.isConnected {
                    LiveCard(ble: ble)
                }

                sectionTitle("Today")
                HStack(spacing: 12) {
                    StatCard(title: "Revolutions",
                             value: Fmt.revs(store.todayRevolutions + ble.telemetry.totalRevolutions),
                             icon: "arrow.triangle.2.circlepath",
                             color: .green)
                    StatCard(title: "Active time",
                             value: Fmt.time(store.todaySeconds + ble.telemetry.activeSeconds),
                             icon: "clock",
                             color: .blue)
                    StatCard(title: "Sessions",
                             value: "\(store.todaySessions.count)",
                             icon: "list.bullet",
                             color: .purple)
                }

                sectionTitle("Last 14 days")
                dailyChart
                    .frame(height: 160)
                    .padding(16)
                    .background(cardBackground(.blue))

                sectionTitle("All time")
                HStack(spacing: 12) {
                    StatCard(title: "Top speed",
                             value: "\(Fmt.rpm(max(store.allTimeTopRPM, ble.telemetry.topSpeed))) rpm",
                             icon: "flame",
                             color: .red)
                    StatCard(title: "Total revs",
                             value: Fmt.revs(store.totalRevolutions),
                             icon: "infinity",
                             color: .green)
                    StatCard(title: "Total time",
                             value: Fmt.time(store.totalSeconds),
                             icon: "hourglass",
                             color: .blue)
                    StatCard(title: "Longest session",
                             value: Fmt.time(store.longestSession?.duration ?? 0),
                             icon: "trophy",
                             color: .orange)
                }
            }
            .padding(24)
        }
    }

    // MARK: - Pieces

    private var statusHeader: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(ble.isConnected ? (ble.telemetry.isActive ? .green : .yellow) : .gray)
                .frame(width: 9, height: 9)
            Text(ble.isConnected
                 ? (ble.telemetry.isActive ? "Spinning" : "Connected — idle")
                 : "Scanning for NSD Workout…")
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var dailyChart: some View {
        Chart(store.dailyHistory, id: \.day) { item in
            BarMark(
                x: .value("Day", item.day, unit: .day),
                y: .value("Revolutions", item.revs)
            )
            .foregroundStyle(
                .linearGradient(colors: [.cyan, .blue],
                                startPoint: .top, endPoint: .bottom))
            .cornerRadius(4)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 2)) { _ in
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                AxisGridLine()
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.title3.weight(.semibold))
    }
}

func cardBackground(_ color: Color) -> some View {
    RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(color.opacity(0.07))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(color.opacity(0.14), lineWidth: 1))
}

// MARK: - Live card

struct LiveCard: View {
    @ObservedObject var ble: BLEManager

    private var tint: Color {
        ble.telemetry.isActive ? Fmt.zoneColor(ble.telemetry.rpm) : .secondary
    }

    var body: some View {
        HStack(alignment: .center, spacing: 24) {
            VStack(spacing: 2) {
                Text(Fmt.rpm(ble.telemetry.rpm))
                    .font(.system(size: 56, weight: .ultraLight, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4), value: ble.telemetry.rpm)
                Text("RPM")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .tracking(3)
            }
            .frame(width: 170)

            Chart(Array(ble.rpmHistory.enumerated()), id: \.offset) { i, rpm in
                AreaMark(x: .value("t", i), y: .value("RPM", rpm))
                    .foregroundStyle(
                        .linearGradient(colors: [tint.opacity(0.3), .clear],
                                        startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("t", i), y: .value("RPM", rpm))
                    .foregroundStyle(tint)
                    .interpolationMethod(.catmullRom)
            }
            .chartXAxis(.hidden)
            .chartYScale(domain: .automatic(includesZero: false))
            .frame(height: 110)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(cardBackground(tint))
        .animation(.easeInOut(duration: 0.5), value: tint)
    }
}

// MARK: - Stat card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    var color: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 22, height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(color.opacity(0.16)))
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground(color))
    }
}

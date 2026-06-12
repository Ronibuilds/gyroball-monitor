import SwiftUI

struct FloatingPanelView: View {

    @ObservedObject var ble: BLEManager
    @ObservedObject var store: SessionStore
    @ObservedObject var panelState: PanelState

    var body: some View {
        VStack(spacing: 0) {
            rpmSection

            if panelState.isExpanded {
                expandedSection
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .frame(width: 200)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1))
        .overlay(alignment: .topTrailing) { pinButton }
        .shadow(color: .black.opacity(0.2), radius: 20, y: 6)
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: panelState.isExpanded)
    }

    // MARK: - Derived

    private var zoneColor: Color {
        ble.telemetry.isActive ? Fmt.zoneColor(ble.telemetry.rpm) : .secondary
    }

    /// Reference max for the progress bar: all-time best, with a sane floor.
    private var referenceMax: Double {
        max(store.allTimeTopRPM, ble.telemetry.topSpeed, 6000)
    }

    private var isNewBest: Bool {
        store.allTimeTopRPM > 0 && ble.telemetry.topSpeed > store.allTimeTopRPM
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

    // MARK: - Compact

    private var rpmSection: some View {
        VStack(spacing: 5) {
            Text(ble.telemetry.isActive ? Fmt.rpm(ble.telemetry.rpm) : "—")
                .font(.system(size: 48, weight: .ultraLight, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.4), value: ble.telemetry.rpm)

            Text("RPM")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .tracking(3)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule()
                        .fill(panelState.isExpanded ? AnyShapeStyle(.tertiary)
                                                    : AnyShapeStyle(zoneColor))
                        .frame(width: geo.size.width
                               * min(1, ble.telemetry.rpm / referenceMax))
                        .animation(.spring(response: 0.5), value: ble.telemetry.rpm)
                }
            }
            .frame(height: 3)
            .padding(.horizontal, 28)
        }
        .frame(height: 96)
    }

    // MARK: - Expanded

    private var expandedSection: some View {
        VStack(spacing: 0) {
            Divider().padding(.horizontal, 16)

            RPMGraphView(history: ble.rpmHistory, tint: zoneColor)
                .frame(height: 56)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

            Divider().padding(.horizontal, 16)

            HStack(spacing: 0) {
                StatCell(label: "TOP",
                         value: Fmt.rpm(ble.telemetry.topSpeed),
                         highlight: isNewBest)
                separator
                StatCell(label: "AVG",  value: Fmt.rpm(ble.telemetry.averageRPM))
                separator
                StatCell(label: "REVS", value: Fmt.revs(ble.telemetry.totalRevolutions))
            }
            .padding(.vertical, 9)

            Divider().padding(.horizontal, 16)

            HStack(spacing: 0) {
                StatCell(label: "TIME",
                         value: Fmt.time(ble.telemetry.activeSeconds))
                separator
                StatCell(label: "DAY REVS",
                         value: Fmt.revs(store.todayRevolutions + ble.telemetry.totalRevolutions))
                separator
                StatCell(label: "DAY TIME",
                         value: Fmt.time(store.todaySeconds + ble.telemetry.activeSeconds))
            }
            .padding(.vertical, 9)

            if isNewBest {
                Text("★ NEW BEST")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(.yellow)
                    .padding(.bottom, 8)
            }
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(.separator)
            .frame(width: 0.5, height: 28)
    }
}

// MARK: - StatCell

private struct StatCell: View {
    let label: String
    let value: String
    var highlight = false

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(highlight ? AnyShapeStyle(.yellow) : AnyShapeStyle(.primary))
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.quaternary)
                .tracking(1.5)
        }
        .frame(maxWidth: .infinity)
    }
}

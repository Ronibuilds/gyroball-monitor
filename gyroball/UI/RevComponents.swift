import SwiftUI

// Shared visual vocabulary used by both the floating widget and the dashboard,
// so a live session looks continuous between them.

// MARK: - Completion ring (generalized from the widget's old ArmRing)

/// A full-circle progress ring with arbitrary center content. The optional
/// target marker sits at 12 o'clock, its position computed from the frame
/// (never hardcoded), so it stays concentric at any size.
struct GaugeRing<Center: View>: View {
    var progress: Double
    var tint: Color
    var lineWidth: CGFloat = 10
    var trackColor: Color = Theme.track
    var showTargetMarker: Bool = false
    @ViewBuilder var center: () -> Center

    var body: some View {
        GeometryReader { geo in
            let d = min(geo.size.width, geo.size.height)
            ZStack {
                Circle().stroke(trackColor, lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: max(0.0001, min(1, progress)))
                    .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: progress)
                if showTargetMarker {
                    Circle().fill(.white.opacity(0.55))
                        .frame(width: 5, height: 5)
                        .offset(y: -(d / 2 - lineWidth / 2))
                }
                center()
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

// MARK: - Delta chip ("▲ +40")

struct DeltaChip: View {
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

struct TargetBar: View {
    let rpm: Double
    let target: Double
    var active: Bool = true
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
                    Rectangle()
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

// MARK: - Shared label style

extension Text {
    func miniLabel(color: Color = Color.secondary.opacity(0.85)) -> some View {
        self.font(.system(size: 8.5, weight: .bold))
            .tracking(1.6)
            .foregroundStyle(color)
    }
}

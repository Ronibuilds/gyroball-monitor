import SwiftUI

/// A "living" electronic rev-counter for macOS 13.
///
/// A 240° arc (gap at the bottom) of radial stripes painted in absolute RPM
/// zone colors. Stripes below the current RPM are lit; around the current value
/// they *bloom* (grow + brighten), and a marker rides the outer edge at the
/// current RPM — so it reads like a powering-up digital tach. A white notch
/// marks the target. The center is left clear for an RPM number overlay.
///
/// Geometry contract: a single `angle(for:)` maps RPM → arc angle, and every
/// element (stripes, marker, notch) derives from one center/radius, so nothing
/// is ever off-center regardless of frame size.
struct RevCounter: View {
    var rpm: Double
    var target: Double
    var maxRPM: Double = 10_000
    /// Arm-time progress, 0...1 (drives the slim inner arc).
    var armProgress: Double = 0
    /// When false, renders a dim idle dial with no bloom/marker.
    var active: Bool = true
    /// When false, draws a single static frame (for historical/detail views) —
    /// avoids a perpetual 30fps redraw when the value isn't changing.
    var animated: Bool = true
    var showTargetLabel: Bool = true

    private let startDeg = 150.0
    private let sweepDeg = 240.0
    private let stripeCount = 56
    private let sigma = 2.4   // bloom width, in stripes

    var body: some View {
        if active && animated {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                let pulse = 0.5 + 0.5 * sin(t * (2 * .pi / 1.1))
                dial(pulse: pulse)
            }
        } else {
            dial(pulse: 0.45, idle: !active)
        }
    }

    private func dial(pulse: Double, idle: Bool = false) -> some View {
        Canvas { ctx, size in
            let R = min(size.width, size.height) / 2 - 2
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let markerRoom = R * 0.13
            let maxStripe = R * 0.18
            let gap = R * 0.03
            let rc = R - markerRoom - maxStripe - gap        // circular-line radius

            drawArmArc(ctx, center: center, r: rc - R * 0.13, width: max(3, R * 0.05))
            drawBaseLine(ctx, center: center, r: rc, idle: idle)
            drawStripes(ctx, center: center, rc: rc, gap: gap, maxStripe: maxStripe, idle: idle)
            drawTargetNotch(ctx, center: center, rc: rc, gap: gap, maxStripe: maxStripe)
            if !idle { drawMarker(ctx, center: center, rc: rc, gap: gap, maxStripe: maxStripe, pulse: pulse) }
        }
    }

    // MARK: - Geometry

    private func angle(for value: Double) -> Double {
        startDeg + sweepDeg * (value / maxRPM).clamped(to: 0...1)
    }
    private func pt(_ c: CGPoint, _ r: CGFloat, _ deg: Double) -> CGPoint {
        let a = deg * .pi / 180
        return CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
    }
    private func arc(_ c: CGPoint, _ r: CGFloat, _ d0: Double, _ d1: Double) -> Path {
        var p = Path()
        p.addArc(center: c, radius: r,
                 startAngle: .degrees(d0), endAngle: .degrees(d1), clockwise: false)
        return p
    }

    // MARK: - Layers

    private func drawArmArc(_ ctx: GraphicsContext, center: CGPoint, r: CGFloat, width: CGFloat) {
        guard r > 0 else { return }
        ctx.stroke(arc(center, r, startDeg, startDeg + sweepDeg),
                   with: .color(Theme.track), style: .init(lineWidth: width, lineCap: .round))
        let p = armProgress.clamped(to: 0...1)
        if p > 0 {
            ctx.stroke(arc(center, r, startDeg, startDeg + sweepDeg * p),
                       with: .color(Theme.blue), style: .init(lineWidth: width, lineCap: .round))
        }
    }

    private func drawBaseLine(_ ctx: GraphicsContext, center: CGPoint, r: CGFloat, idle: Bool) {
        ctx.stroke(arc(center, r, startDeg, startDeg + sweepDeg),
                   with: .color(.white.opacity(0.12)), style: .init(lineWidth: 2))
        guard !idle, rpm > 0 else { return }
        ctx.stroke(arc(center, r, startDeg, angle(for: rpm)),
                   with: .color(Fmt.zoneColor(rpm).opacity(0.9)), style: .init(lineWidth: 2.5))
    }

    private func drawStripes(_ ctx: GraphicsContext, center: CGPoint,
                             rc: CGFloat, gap: CGFloat, maxStripe: CGFloat, idle: Bool) {
        let centerSeg = rpm / maxRPM * Double(stripeCount)
        let baseLen = maxStripe * 0.38
        for i in 0...stripeCount {
            let v = Double(i) / Double(stripeCount) * maxRPM
            let a = angle(for: v)
            let d = Double(i) - centerSeg
            let bloom = idle ? 0 : exp(-(d * d) / (2 * sigma * sigma))
            let lit = !idle && Double(i) <= centerSeg + 0.4

            let len = (lit ? baseLen : baseLen * 0.65) + maxStripe * 0.62 * bloom
            let width = (lit ? 3.0 : 2.3) + 2.6 * bloom
            let color: Color
            let opacity: Double
            if idle {
                color = .white; opacity = 0.10
            } else if lit {
                color = lerp(rgb(v), white, min(0.6, bloom * 0.8)); opacity = 1
            } else {
                color = lerp(dim, rgb(v), min(1, bloom * 1.2)); opacity = 0.45 + 0.5 * bloom
            }
            let r0 = rc + gap, r1 = rc + gap + len
            var s = Path(); s.move(to: pt(center, r0, a)); s.addLine(to: pt(center, r1, a))
            ctx.stroke(s, with: .color(color.opacity(opacity)),
                       style: .init(lineWidth: width, lineCap: .round))
        }
    }

    private func drawTargetNotch(_ ctx: GraphicsContext, center: CGPoint,
                                 rc: CGFloat, gap: CGFloat, maxStripe: CGFloat) {
        guard target > 0, target <= maxRPM else { return }
        let a = angle(for: target)
        var tick = Path()
        tick.move(to: pt(center, rc - 2, a))
        tick.addLine(to: pt(center, rc + gap + maxStripe * 0.9, a))
        ctx.stroke(tick, with: .color(.white.opacity(0.9)), style: .init(lineWidth: 2.5, lineCap: .round))
        if showTargetLabel {
            let lp = pt(center, rc + gap + maxStripe + 12, a)
            ctx.draw(ctx.resolve(Text("TARGET").font(.system(size: 7.5, weight: .bold))
                .foregroundColor(.white.opacity(0.7))), at: lp, anchor: .center)
        }
    }

    private func drawMarker(_ ctx: GraphicsContext, center: CGPoint,
                            rc: CGFloat, gap: CGFloat, maxStripe: CGFloat, pulse: Double) {
        guard rpm > 0 else { return }
        let a = angle(for: rpm)
        let c = Fmt.zoneColor(rpm)
        let mr = rc + gap + maxStripe + 8
        // pulsing glow dot
        let glowR = 5 + 3 * pulse
        ctx.fill(Path(ellipseIn: CGRect(x: pt(center, mr, a).x - glowR, y: pt(center, mr, a).y - glowR,
                                        width: glowR * 2, height: glowR * 2)),
                 with: .color(c.opacity(0.35 + 0.35 * pulse)))
        ctx.fill(Path(ellipseIn: CGRect(x: pt(center, mr, a).x - 3, y: pt(center, mr, a).y - 3,
                                        width: 6, height: 6)), with: .color(c))
        // caret pointing inward
        var caret = Path()
        caret.move(to: pt(center, rc + gap + maxStripe + 2, a))
        caret.addLine(to: pt(center, mr + 3, a - 2.4))
        caret.addLine(to: pt(center, mr + 3, a + 2.4))
        caret.closeSubpath()
        ctx.fill(caret, with: .color(.white))
    }

    // MARK: - Color blending (tuple-space so it works inside Canvas)

    private let white: (Double, Double, Double) = (1, 1, 1)
    private let dim: (Double, Double, Double) = (0.165, 0.165, 0.18)

    private func rgb(_ rpm: Double) -> (Double, Double, Double) {
        switch Fmt.zone(rpm) {
        case .warmup:  return (0.24, 0.86, 0.52)
        case .steady:  return (0.36, 0.62, 1.00)
        case .hard:    return (0.96, 0.77, 0.26)
        case .intense: return (0.96, 0.58, 0.27)
        case .max:     return (0.96, 0.34, 0.29)
        }
    }
    private func lerp(_ a: (Double, Double, Double), _ b: (Double, Double, Double), _ t: Double) -> Color {
        Color(red: a.0 + (b.0 - a.0) * t, green: a.1 + (b.1 - a.1) * t, blue: a.2 + (b.2 - a.2) * t)
    }
}

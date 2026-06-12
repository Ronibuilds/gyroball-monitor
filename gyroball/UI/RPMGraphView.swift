import SwiftUI

struct RPMGraphView: View {
    let history: [Double]
    var tint: Color = .accentColor

    var body: some View {
        Canvas { ctx, size in
            guard history.count >= 2 else { return }

            let maxVal = history.max() ?? 1
            let minVal = maxVal * 0.5
            let range  = maxVal - minVal
            guard range > 0 else { return }

            let step = size.width / CGFloat(history.count - 1)

            func point(at index: Int, rpm: Double) -> CGPoint {
                let x = CGFloat(index) * step
                let y = size.height * (1 - CGFloat((rpm - minVal) / range))
                return CGPoint(x: x, y: max(0, min(size.height, y)))
            }

            // Line path
            var line = Path()
            for (i, rpm) in history.enumerated() {
                let pt = point(at: i, rpm: rpm)
                i == 0 ? line.move(to: pt) : line.addLine(to: pt)
            }

            // Fill
            var fill = line
            fill.addLine(to: CGPoint(x: size.width, y: size.height))
            fill.addLine(to: CGPoint(x: 0, y: size.height))
            fill.closeSubpath()
            ctx.fill(fill, with: .color(tint.opacity(0.12)))

            // Stroke
            ctx.stroke(line, with: .color(tint),
                       style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

            // Live dot
            if let last = history.last {
                let pt  = point(at: history.count - 1, rpm: last)
                let dot = Path(ellipseIn: CGRect(x: pt.x - 3, y: pt.y - 3, width: 6, height: 6))
                ctx.fill(dot, with: .color(tint))
            }
        }
    }
}

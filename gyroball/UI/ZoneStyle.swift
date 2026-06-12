import SwiftUI

extension Fmt {
    /// User-tuned RPM zone palette: green → blue → yellow → orange → red.
    static func zoneColor(_ rpm: Double) -> Color {
        switch zone(rpm) {
        case .warmup:  return .green
        case .steady:  return .blue
        case .hard:    return .yellow
        case .intense: return .orange
        case .max:     return .red
        }
    }
}

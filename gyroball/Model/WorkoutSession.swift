import Foundation

struct WorkoutSession: Identifiable, Hashable {
    var id: Int64 = 0
    let startedAt: Date
    let duration: TimeInterval
    let topRPM: Double
    let avgRPM: Double
    let revolutions: Double
    /// RPM sampled at ~1 Hz over the active part of the session.
    let samples: [Double]
}

enum Fmt {
    static func revs(_ r: Double) -> String {
        r >= 10_000 ? String(format: "%.1fk", r / 1000)
                    : String(format: "%.0f", r)
    }

    static func time(_ t: TimeInterval) -> String {
        let s = Int(t)
        return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, (s / 60) % 60, s % 60)
                         : String(format: "%d:%02d", s / 60, s % 60)
    }

    static func rpm(_ r: Double) -> String {
        String(format: "%.0f", r)
    }

    static let sessionDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.doesRelativeDateFormatting = true
        return f
    }()

    /// Color zone for an RPM value, used to tint the widget and charts.
    static func zone(_ rpm: Double) -> ZoneColor {
        switch rpm {
        case ..<3500:  return .warmup     // green
        case ..<4500:  return .steady     // blue
        case ..<6000:  return .hard       // yellow
        case ..<7000:  return .intense    // orange
        default:       return .max        // red
        }
    }

    enum ZoneColor {
        case warmup, steady, hard, intense, max
    }
}

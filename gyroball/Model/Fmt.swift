import SwiftUI

/// Formatting helpers and the shared visual language (colors, zones) for the
/// whole app. Numbers, durations, and the target-relative palette all live here
/// so the widget, menu, and dashboard stay visually consistent.
enum Fmt {

    // MARK: - Numbers

    static func revs(_ r: Double) -> String {
        r >= 10_000 ? String(format: "%.1fk", r / 1000)
                    : String(format: "%.0f", r)
    }

    static func rpm(_ r: Double) -> String {
        String(format: "%.0f", r)
    }

    /// Signed delta, e.g. "+40" / "−120" (true minus glyph).
    static func delta(_ d: Double) -> String {
        let v = Int(d.rounded())
        if v == 0 { return "±0" }
        return v > 0 ? "+\(v)" : "−\(abs(v))"
    }

    // MARK: - Durations

    /// h:mm:ss past an hour, else m:ss.
    static func time(_ t: TimeInterval) -> String {
        let s = max(0, Int(t))
        return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, (s / 60) % 60, s % 60)
                         : String(format: "%d:%02d", s / 60, s % 60)
    }

    /// Always m:ss — used for the per-arm timer where minutes stay small.
    static func clock(_ t: TimeInterval) -> String {
        let s = max(0, Int(t.rounded()))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    static let dayDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        f.doesRelativeDateFormatting = true
        return f
    }()

    static let weekday: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    // MARK: - Target-relative palette
    //
    // During a workout the meaningful question isn't "what zone" but "am I at
    // or above my goal RPM". This drives the widget's live color.

    enum TargetState { case idle, below, near, onTarget }

    static func targetState(_ rpm: Double, target: Double) -> TargetState {
        guard rpm > 0 else { return .idle }
        if rpm >= target            { return .onTarget }
        if rpm >= target * 0.90      { return .near }
        return .below
    }

    static func targetColor(_ rpm: Double, target: Double) -> Color {
        switch targetState(rpm, target: target) {
        case .idle:     return .secondary
        case .below:    return .orange
        case .near:     return .yellow
        case .onTarget: return Theme.green
        }
    }
}

/// Central palette so the widget and dashboard share one identity.
enum Theme {
    static let green = Color(red: 0.24, green: 0.86, blue: 0.52)   // on-target / success
    static let blue  = Color(red: 0.36, green: 0.62, blue: 1.00)   // time / accent
    static let track = Color.white.opacity(0.10)                   // empty progress track
    static let hairline = Color.white.opacity(0.08)
}

import Foundation

/// The user's current training target. Set manually in the dashboard; the
/// widget, menu, and detection engine all read from it. Hypertrophy
/// progression = bumping `targetRPM` and/or `secondsPerArm` over time.
struct Goal: Codable, Equatable {
    var targetRPM: Double
    var secondsPerArm: TimeInterval
    var setsPerDay: Int

    static let `default` = Goal(targetRPM: 3500, secondsPerArm: 90, setsPerDay: 5)

    /// Total spin time a full set demands (both arms).
    var secondsPerSet: TimeInterval { secondsPerArm * 2 }

    /// The day is "done" once this much qualifying work is logged.
    var dailySeconds: TimeInterval { secondsPerSet * Double(setsPerDay) }

    // Sane bounds for the steppers.
    static let rpmRange: ClosedRange<Double> = 1500...8000
    static let rpmStep: Double = 100
    static let armRange: ClosedRange<TimeInterval> = 30...600
    static let armStep: TimeInterval = 15
    static let setsRange: ClosedRange<Int> = 1...12
}

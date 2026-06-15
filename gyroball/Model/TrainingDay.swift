import Foundation

/// One arm's work within a set. Arms are indexed 0/1 (the ball can't tell left
/// from right), detected automatically from pauses in the spin stream.
struct ArmSegment: Hashable, Codable {
    var spinSeconds: TimeInterval = 0
    var avgRPM: Double = 0
    var topRPM: Double = 0

    var isEmpty: Bool { spinSeconds <= 0 }
}

/// A completed (or in-progress) set: two arm segments plus the goal snapshot
/// captured when it was performed, so history reflects the target at the time.
struct WorkoutSet: Identifiable, Hashable {
    var id: Int64 = 0
    let startedAt: Date
    let setIndex: Int            // 0-based within its day
    let targetRPM: Double        // goal snapshot
    let secondsPerArm: TimeInterval
    let setsPerDay: Int
    var arms: [ArmSegment]       // always count 2
    var samples: [Double]        // ~1 Hz RPM across the whole set, for graphs

    var spinSeconds: TimeInterval { arms.reduce(0) { $0 + $1.spinSeconds } }
    var topRPM: Double { arms.map(\.topRPM).max() ?? 0 }

    /// Time-weighted average RPM across both arms.
    var avgRPM: Double {
        let total = spinSeconds
        guard total > 0 else { return 0 }
        return arms.reduce(0) { $0 + $1.avgRPM * $1.spinSeconds } / total
    }

    /// Did both arms reach the per-arm time target?
    var isComplete: Bool {
        arms.count == 2 && arms.allSatisfy { $0.spinSeconds >= secondsPerArm }
    }

    /// Did the set hold the RPM target on average? (Informational — completion
    /// is gated on time, not RPM, per the training model.)
    var hitRPM: Bool { avgRPM >= targetRPM }
}

/// All the sets performed on one calendar day, the primary record. Sets can be
/// spread across the day (morning/evening) and roll up here.
struct TrainingDay: Identifiable, Hashable {
    let date: Date               // start of day, local
    var sets: [WorkoutSet]

    var id: Date { date }

    var completedSets: Int { sets.filter(\.isComplete).count }
    var spinSeconds: TimeInterval { sets.reduce(0) { $0 + $1.spinSeconds } }
    var topRPM: Double { sets.map(\.topRPM).max() ?? 0 }

    var avgRPM: Double {
        let total = spinSeconds
        guard total > 0 else { return 0 }
        return sets.reduce(0) { $0 + $1.avgRPM * $1.spinSeconds } / total
    }

    /// The goal in force this day (taken from its sets, or the passed default).
    func goal(default fallback: Goal) -> Goal {
        guard let s = sets.first else { return fallback }
        return Goal(targetRPM: s.targetRPM, secondsPerArm: s.secondsPerArm, setsPerDay: s.setsPerDay)
    }

    /// How fully the day's goal was met, 0...1, capped at the target set count.
    func completion(default fallback: Goal) -> Double {
        let target = goal(default: fallback).setsPerDay
        guard target > 0 else { return 0 }
        return min(1, Double(completedSets) / Double(target))
    }
}

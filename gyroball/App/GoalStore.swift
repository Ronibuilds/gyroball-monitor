import Foundation
import Combine

/// Holds the current training goal, persisted to UserDefaults. Edited manually
/// from the dashboard; observed live by the widget and the detection engine.
final class GoalStore: ObservableObject {

    @Published var goal: Goal { didSet { save() } }

    private let key = "training.goal"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(Goal.self, from: data) {
            goal = decoded
        } else {
            goal = .default
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(goal) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    // MARK: - Stepper helpers (clamped)

    func bumpRPM(_ d: Double) {
        goal.targetRPM = (goal.targetRPM + d).clamped(to: Goal.rpmRange)
    }

    func bumpArm(_ d: TimeInterval) {
        goal.secondsPerArm = (goal.secondsPerArm + d).clamped(to: Goal.armRange)
    }

    func bumpSets(_ d: Int) {
        goal.setsPerDay = (goal.setsPerDay + d).clamped(to: Goal.setsRange)
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

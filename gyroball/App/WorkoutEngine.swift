import Foundation
import Combine

/// Turns the raw BLE spin stream into the live training structure: which set,
/// which arm, and how far into the per-arm target you are — fully automatically.
///
/// Detection model (no manual input):
///  • Active spinning accumulates time into the current arm.
///  • An arm is "done" once its accumulated spin time reaches the goal's
///    seconds-per-arm. Brief fumbles only pause the timer — they never skip ahead.
///  • Stopping the ball ends a *bout* (BLE goes idle). When you spin back up:
///      – if the current arm is already done → advance to the other arm;
///      – otherwise → keep accumulating the same arm.
///  • When the second arm reaches its target, the set is complete: it's
///    persisted and the next bout starts the next set.
final class WorkoutEngine: ObservableObject {

    // MARK: - Live published state (read by widget, menu, dashboard)

    /// 0-based index of the set currently in progress (== sets completed today).
    @Published private(set) var currentSetIndex = 0
    /// 0 or 1 — which arm of the current set is active.
    @Published private(set) var currentArmIndex = 0
    /// Accumulated spin time for each arm of the in-progress set.
    @Published private(set) var armSeconds: [TimeInterval] = [0, 0]
    /// The current arm has reached the per-arm time target ("switch arms").
    @Published private(set) var currentArmDone = false

    /// Seconds into the active arm, and progress 0...1 toward the target.
    var activeArmSeconds: TimeInterval { armSeconds[currentArmIndex] }
    func armProgress(target: TimeInterval) -> Double {
        target > 0 ? min(1, armSeconds[currentArmIndex] / target) : 0
    }

    // MARK: - Dependencies

    private let ble: BLEManager
    private let store: TrainingStore
    private let goalStore: GoalStore
    private var cancellables: Set<AnyCancellable> = []

    private var goal: Goal { goalStore.goal }

    // MARK: - Bout / accumulation state

    private var boutActive = false
    private var lastTickAt: Date?
    private var idleTimer: Timer?
    private var setStartedAt: Date?
    private var today = Calendar.current.startOfDay(for: Date())

    /// Per-arm running stats for the in-progress set.
    private var armRevSum: [Double] = [0, 0]   // Σ rpm·dt  → for time-weighted avg
    private var armTop: [Double] = [0, 0]
    private var samples: [Double] = []
    private var lastSampleAt: Date?

    private let maxGap: TimeInterval = 2.0     // packet gap beyond this isn't counted
    private let idleTimeout: TimeInterval = 3.0 // silence beyond this ends the bout

    init(ble: BLEManager, store: TrainingStore, goalStore: GoalStore) {
        self.ble = ble
        self.store = store
        self.goalStore = goalStore
        currentSetIndex = store.todayCompletedSets

        ble.packetTick
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rpm in self?.onTick(rpm) }
            .store(in: &cancellables)
    }

    // MARK: - Tick handling

    private func onTick(_ rpm: Double) {
        let now = Date()
        rollDayIfNeeded(now)

        if !boutActive {
            boutActive = true
            onResume()
        }

        if let last = lastTickAt {
            let dt = now.timeIntervalSince(last)
            if dt > 0, dt < maxGap, !currentSetFull {
                let arm = currentArmIndex
                armSeconds[arm] += dt
                armRevSum[arm] += rpm * dt
                checkArmCompletion()
            }
        }
        lastTickAt = now

        // Stats + ~1 Hz samples for the set graph.
        armTop[currentArmIndex] = max(armTop[currentArmIndex], rpm)
        if lastSampleAt == nil || now.timeIntervalSince(lastSampleAt!) >= 1.0 {
            samples.append(rpm)
            lastSampleAt = now
        }

        idleTimer?.invalidate()
        idleTimer = .scheduledTimer(withTimeInterval: idleTimeout, repeats: false) { [weak self] _ in
            self?.onBoutEnd()
        }
    }

    /// First tick of a fresh bout: advance the arm if the previous one finished.
    private func onResume() {
        if setStartedAt == nil { setStartedAt = Date() }
        if currentArmIndex == 0, armSeconds[0] >= goal.secondsPerArm {
            currentArmIndex = 1
        }
        refreshArmDone()
    }

    private func onBoutEnd() {
        boutActive = false
        lastTickAt = nil
        lastSampleAt = nil
    }

    private var currentSetFull: Bool {
        armSeconds[0] >= goal.secondsPerArm && armSeconds[1] >= goal.secondsPerArm
    }

    /// When the *second* arm reaches target, the set is complete.
    private func checkArmCompletion() {
        refreshArmDone()
        if currentArmIndex == 1, armSeconds[1] >= goal.secondsPerArm {
            completeSet()
        }
    }

    private func refreshArmDone() {
        currentArmDone = armSeconds[currentArmIndex] >= goal.secondsPerArm
    }

    // MARK: - Set lifecycle

    private func completeSet() {
        let g = goal
        let set = WorkoutSet(
            startedAt: setStartedAt ?? Date(),
            setIndex: currentSetIndex,
            targetRPM: g.targetRPM,
            secondsPerArm: g.secondsPerArm,
            setsPerDay: g.setsPerDay,
            arms: (0..<2).map { i in
                ArmSegment(spinSeconds: armSeconds[i],
                           avgRPM: armSeconds[i] > 0 ? armRevSum[i] / armSeconds[i] : 0,
                           topRPM: armTop[i])
            },
            samples: samples)
        store.add(set)

        currentSetIndex += 1
        resetCurrentSet(keepingCounter: true)
    }

    /// Clears the in-progress set's accumulators. Completed sets are untouched.
    func resetCurrentSet(keepingCounter: Bool = true) {
        if !keepingCounter { currentSetIndex = store.todayCompletedSets }
        currentArmIndex = 0
        armSeconds = [0, 0]
        armRevSum = [0, 0]
        armTop = [0, 0]
        samples = []
        setStartedAt = nil
        currentArmDone = false
        boutActive = false
        lastTickAt = nil
        lastSampleAt = nil
    }

    private func rollDayIfNeeded(_ now: Date) {
        let start = Calendar.current.startOfDay(for: now)
        guard start != today else { return }
        today = start
        resetCurrentSet(keepingCounter: false)
        currentSetIndex = 0
    }
}

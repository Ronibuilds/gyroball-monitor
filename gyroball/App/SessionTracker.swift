import Foundation
import Combine

/// Watches the live BLE stream and turns it into persisted workout sessions.
/// A session opens on the first packet and closes after `gracePeriod` without
/// packets, so the ball dropping BLE below ~1700 RPM and being spun back up
/// shortly after stays within one session.
final class SessionTracker {

    private let ble: BLEManager
    private let store: SessionStore

    private var sessionStart: Date?
    private var samples: [Double] = []
    private var lastSampleAt: Date?
    private var endTimer: Timer?
    private var cancellables: Set<AnyCancellable> = []

    private let gracePeriod: TimeInterval = 45
    private let minimumRevolutions: Double = 30

    init(ble: BLEManager, store: SessionStore) {
        self.ble = ble
        self.store = store

        ble.packetTick
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rpm in self?.handleTick(rpm) }
            .store(in: &cancellables)
    }

    private func handleTick(_ rpm: Double) {
        let now = Date()

        if sessionStart == nil {
            sessionStart = now
            samples = []
            lastSampleAt = nil
        }

        if lastSampleAt == nil || now.timeIntervalSince(lastSampleAt!) >= 1.0 {
            samples.append(rpm)
            lastSampleAt = now
        }

        endTimer?.invalidate()
        endTimer = .scheduledTimer(withTimeInterval: gracePeriod, repeats: false) { [weak self] _ in
            self?.finalize()
        }
    }

    /// Persists the current session (if it was a real workout) and resets.
    func finalize() {
        defer { discard() }
        guard let start = sessionStart else { return }

        let t = ble.telemetry
        guard t.totalRevolutions >= minimumRevolutions else { return }

        store.add(WorkoutSession(
            startedAt: start,
            duration: t.activeSeconds,
            topRPM: t.topSpeed,
            avgRPM: t.averageRPM,
            revolutions: t.totalRevolutions,
            samples: samples))
    }

    /// Throws away the current session without saving.
    func discard() {
        endTimer?.invalidate()
        endTimer = nil
        sessionStart = nil
        samples = []
        lastSampleAt = nil
        ble.resetSession()
    }
}

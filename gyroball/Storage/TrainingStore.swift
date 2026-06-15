import Foundation
import Combine

/// SQLite-backed store of completed sets, grouped into training days. Each set
/// row carries its two arm segments inline (there are always exactly two) plus
/// the goal snapshot it was performed against.
final class TrainingStore: ObservableObject {

    @Published private(set) var days: [TrainingDay] = []

    private let db: Database?
    private let cal = Calendar.current

    init() {
        // Single shared location (Application Support) — see Database.storeURL.
        db = Database.openShared()
        db?.run("""
            CREATE TABLE IF NOT EXISTS training_sets(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                started_at    REAL    NOT NULL,
                set_index     INTEGER NOT NULL,
                target_rpm    REAL    NOT NULL,
                sec_per_arm   REAL    NOT NULL,
                sets_per_day  INTEGER NOT NULL,
                arm0_seconds  REAL    NOT NULL,
                arm0_avg_rpm  REAL    NOT NULL,
                arm0_top_rpm  REAL    NOT NULL,
                arm1_seconds  REAL    NOT NULL,
                arm1_avg_rpm  REAL    NOT NULL,
                arm1_top_rpm  REAL    NOT NULL,
                samples       TEXT    NOT NULL DEFAULT '[]'
            )
            """)
        db?.run("CREATE INDEX IF NOT EXISTS idx_sets_started ON training_sets(started_at)")
        reload()
    }

    // MARK: - Writes

    func add(_ set: WorkoutSet) {
        let arm0 = set.arms.first ?? ArmSegment()
        let arm1 = set.arms.count > 1 ? set.arms[1] : ArmSegment()
        let samplesJSON = (try? JSONEncoder().encode(set.samples))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"

        let values: [Any] = [
            set.startedAt.timeIntervalSince1970, Int64(set.setIndex),
            set.targetRPM, set.secondsPerArm, Int64(set.setsPerDay),
            arm0.spinSeconds, arm0.avgRPM, arm0.topRPM,
            arm1.spinSeconds, arm1.avgRPM, arm1.topRPM, samplesJSON]

        db?.run("""
            INSERT INTO training_sets
              (started_at, set_index, target_rpm, sec_per_arm, sets_per_day,
               arm0_seconds, arm0_avg_rpm, arm0_top_rpm,
               arm1_seconds, arm1_avg_rpm, arm1_top_rpm, samples)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?)
            """, bind: values)
        reload()
    }

    func deleteSet(_ id: Int64) {
        db?.run("DELETE FROM training_sets WHERE id = ?", bind: [id])
        reload()
    }

    func deleteDay(_ day: TrainingDay) {
        for s in day.sets { db?.run("DELETE FROM training_sets WHERE id = ?", bind: [s.id]) }
        reload()
    }

    // MARK: - Read

    private func reload() {
        var rows: [WorkoutSet] = []
        db?.run("""
            SELECT id, started_at, set_index, target_rpm, sec_per_arm, sets_per_day,
                   arm0_seconds, arm0_avg_rpm, arm0_top_rpm,
                   arm1_seconds, arm1_avg_rpm, arm1_top_rpm, samples
            FROM training_sets ORDER BY started_at ASC
            """) { r in
            let samples = (try? JSONDecoder().decode([Double].self,
                                                     from: Data(r.string(12).utf8))) ?? []
            rows.append(WorkoutSet(
                id: r.int64(0),
                startedAt: Date(timeIntervalSince1970: r.double(1)),
                setIndex: Int(r.int64(2)),
                targetRPM: r.double(3),
                secondsPerArm: r.double(4),
                setsPerDay: Int(r.int64(5)),
                arms: [ArmSegment(spinSeconds: r.double(6), avgRPM: r.double(7), topRPM: r.double(8)),
                       ArmSegment(spinSeconds: r.double(9), avgRPM: r.double(10), topRPM: r.double(11))],
                samples: samples))
        }

        let grouped = Dictionary(grouping: rows) { cal.startOfDay(for: $0.startedAt) }
        days = grouped
            .map { TrainingDay(date: $0.key, sets: $0.value.sorted { $0.startedAt < $1.startedAt }) }
            .sorted { $0.date > $1.date }
    }

    // MARK: - Aggregates

    var today: TrainingDay {
        let start = cal.startOfDay(for: Date())
        return days.first { $0.date == start } ?? TrainingDay(date: start, sets: [])
    }

    /// Completed sets logged today — the engine resumes its counter from here.
    var todayCompletedSets: Int { today.completedSets }

    var allTimeTopRPM: Double { days.map(\.topRPM).max() ?? 0 }
    var totalSpinSeconds: TimeInterval { days.reduce(0) { $0 + $1.spinSeconds } }
    var totalSets: Int { days.reduce(0) { $0 + $1.sets.count } }

    /// Consecutive days (ending today or yesterday) where the goal was met.
    func streak(default goal: Goal) -> Int {
        var count = 0
        var cursor = cal.startOfDay(for: Date())
        let byDate = Dictionary(uniqueKeysWithValues: days.map { ($0.date, $0) })

        // Allow the streak to "hold" if today isn't done yet but yesterday was.
        if (byDate[cursor]?.completion(default: goal) ?? 0) < 1,
           let yest = cal.date(byAdding: .day, value: -1, to: cursor) {
            cursor = yest
        }
        while let day = byDate[cursor], day.completion(default: goal) >= 1 {
            count += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return count
    }

    /// One entry per day for the last `n` days, oldest first, zero-filled.
    func recentDays(_ n: Int) -> [TrainingDay] {
        let today = cal.startOfDay(for: Date())
        let byDate = Dictionary(uniqueKeysWithValues: days.map { ($0.date, $0) })
        return (0..<n).reversed().compactMap { offset in
            guard let date = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return byDate[date] ?? TrainingDay(date: date, sets: [])
        }
    }
}

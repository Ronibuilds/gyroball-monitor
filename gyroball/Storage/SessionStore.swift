import Foundation
import Combine

/// SQLite-backed store for workout sessions, plus the aggregates the UI shows.
final class SessionStore: ObservableObject {

    @Published private(set) var sessions: [WorkoutSession] = []

    private let db: Database?

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory,
                                           in: .userDomainMask)[0]
            .appendingPathComponent("Gyroball", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        db = Database(path: dir.appendingPathComponent("gyroball.sqlite").path)
        db?.run("""
            CREATE TABLE IF NOT EXISTS sessions(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                started_at REAL NOT NULL,
                duration REAL NOT NULL,
                top_rpm REAL NOT NULL,
                avg_rpm REAL NOT NULL,
                revolutions REAL NOT NULL,
                samples TEXT NOT NULL DEFAULT '[]'
            )
            """)
        db?.run("CREATE INDEX IF NOT EXISTS idx_sessions_started ON sessions(started_at)")
        reload()
    }

    // MARK: - CRUD

    func add(_ session: WorkoutSession) {
        let samplesJSON = (try? JSONEncoder().encode(session.samples))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"

        db?.run("""
            INSERT INTO sessions (started_at, duration, top_rpm, avg_rpm, revolutions, samples)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            bind: [session.startedAt.timeIntervalSince1970,
                   session.duration,
                   session.topRPM,
                   session.avgRPM,
                   session.revolutions,
                   samplesJSON])
        reload()
    }

    func delete(_ session: WorkoutSession) {
        db?.run("DELETE FROM sessions WHERE id = ?", bind: [session.id])
        reload()
    }

    private func reload() {
        var loaded: [WorkoutSession] = []
        db?.run("""
            SELECT id, started_at, duration, top_rpm, avg_rpm, revolutions, samples
            FROM sessions ORDER BY started_at DESC
            """) { row in
            let samples = (try? JSONDecoder().decode(
                [Double].self, from: Data(row.string(6).utf8))) ?? []
            loaded.append(WorkoutSession(
                id: row.int64(0),
                startedAt: Date(timeIntervalSince1970: row.double(1)),
                duration: row.double(2),
                topRPM: row.double(3),
                avgRPM: row.double(4),
                revolutions: row.double(5),
                samples: samples))
        }
        sessions = loaded
    }

    // MARK: - Aggregates

    var todaySessions: [WorkoutSession] {
        sessions.filter { Calendar.current.isDateInToday($0.startedAt) }
    }

    var todayRevolutions: Double { todaySessions.reduce(0) { $0 + $1.revolutions } }
    var todaySeconds: TimeInterval { todaySessions.reduce(0) { $0 + $1.duration } }

    var allTimeTopRPM: Double { sessions.map(\.topRPM).max() ?? 0 }
    var totalRevolutions: Double { sessions.reduce(0) { $0 + $1.revolutions } }
    var totalSeconds: TimeInterval { sessions.reduce(0) { $0 + $1.duration } }
    var longestSession: WorkoutSession? { sessions.max { $0.duration < $1.duration } }
    var bestSession: WorkoutSession? { sessions.max { $0.topRPM < $1.topRPM } }

    /// Revolutions per day for the last 14 days, oldest first, zero-filled.
    var dailyHistory: [(day: Date, revs: Double)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var byDay: [Date: Double] = [:]
        for s in sessions {
            byDay[cal.startOfDay(for: s.startedAt), default: 0] += s.revolutions
        }
        return (0..<14).reversed().compactMap { offset in
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return (day: day, revs: byDay[day] ?? 0)
        }
    }
}

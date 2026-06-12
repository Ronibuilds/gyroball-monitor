import Foundation
import SQLite3

/// Minimal wrapper around the system SQLite library — just enough for the
/// session store. Not thread-safe; call from the main thread only.
final class Database {

    private var db: OpaquePointer?
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    init?(path: String) {
        guard sqlite3_open(path, &db) == SQLITE_OK else {
            sqlite3_close(db)
            return nil
        }
    }

    deinit { sqlite3_close(db) }

    var lastInsertID: Int64 { sqlite3_last_insert_rowid(db) }

    /// Runs a single statement with `?` placeholders bound to the given values
    /// (Double, Int64, or String), invoking `row` for each result row.
    @discardableResult
    func run(_ sql: String,
             bind: [Any] = [],
             row: ((Statement) -> Void)? = nil) -> Bool {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }

        for (i, value) in bind.enumerated() {
            let idx = Int32(i + 1)
            switch value {
            case let v as Double: sqlite3_bind_double(stmt, idx, v)
            case let v as Int64:  sqlite3_bind_int64(stmt, idx, v)
            case let v as String: sqlite3_bind_text(stmt, idx, v, -1, Self.transient)
            default: break
            }
        }

        while true {
            switch sqlite3_step(stmt) {
            case SQLITE_ROW:  row?(Statement(stmt: stmt))
            case SQLITE_DONE: return true
            default:          return false
            }
        }
    }

    struct Statement {
        let stmt: OpaquePointer?

        func double(_ col: Int32) -> Double { sqlite3_column_double(stmt, col) }
        func int64(_ col: Int32)  -> Int64  { sqlite3_column_int64(stmt, col) }
        func string(_ col: Int32) -> String {
            sqlite3_column_text(stmt, col).map { String(cString: $0) } ?? ""
        }
    }
}

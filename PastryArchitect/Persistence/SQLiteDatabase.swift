import Foundation
#if canImport(SQLite3)
import SQLite3

final class SQLiteDatabase {
    private var db: OpaquePointer?
    private let path: String
    private let queue = DispatchQueue(label: "PastryArchitect.SQLite", qos: .userInitiated)

    init(path: String) throws {
        self.path = path
        try open()
        try createTables()
    }

    deinit {
        sqlite3_close(db)
    }

    private func open() throws {
        let directory = (path as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        if sqlite3_open(path, &db) != SQLITE_OK {
            throw DatabaseError.connectionFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    private func createTables() throws {
        let createSQL = """
        CREATE TABLE IF NOT EXISTS catalogue (
            id TEXT PRIMARY KEY,
            names_json TEXT NOT NULL,
            category TEXT NOT NULL,
            defaultUnit TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS recipes (
            id TEXT PRIMARY KEY,
            names_json TEXT NOT NULL,
            yieldAmount REAL,
            yieldUnit TEXT,
            instructions_json TEXT NOT NULL,
            ingredients_json TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS products (
            id TEXT PRIMARY KEY,
            names_json TEXT NOT NULL,
            description_json TEXT,
            components_json TEXT NOT NULL,
            assembly_instructions_json TEXT
        );
        CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY,
            value TEXT
        );
        """
        try execute(sql: createSQL)
    }

    func execute(sql: String, parameters: [Any] = []) throws {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        try bind(parameters: parameters, to: statement)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.executionFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    func query(sql: String, parameters: [Any] = [], rowHandler: ([String: Any?]) -> Void) throws {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        try bind(parameters: parameters, to: statement)
        while sqlite3_step(statement) == SQLITE_ROW {
            var row: [String: Any?] = [:]
            let columnCount = sqlite3_column_count(statement)
            for index in 0..<columnCount {
                let name = String(cString: sqlite3_column_name(statement, index))
                let type = sqlite3_column_type(statement, index)
                switch type {
                case SQLITE_TEXT:
                    if let text = sqlite3_column_text(statement, index) {
                        row[name] = String(cString: text)
                    }
                case SQLITE_INTEGER:
                    row[name] = Int(sqlite3_column_int64(statement, index))
                case SQLITE_FLOAT:
                    row[name] = sqlite3_column_double(statement, index)
                case SQLITE_NULL:
                    row[name] = nil
                default:
                    row[name] = nil
                }
            }
            rowHandler(row)
        }
    }

    private func bind(parameters: [Any], to statement: OpaquePointer?) throws {
        for (index, value) in parameters.enumerated() {
            let idx = Int32(index + 1)
            if let intVal = value as? Int {
                sqlite3_bind_int(statement, idx, Int32(intVal))
            } else if let doubleVal = value as? Double {
                sqlite3_bind_double(statement, idx, doubleVal)
            } else if let stringVal = value as? String {
                sqlite3_bind_text(statement, idx, stringVal, -1, SQLITE_TRANSIENT)
            } else if value is NSNull {
                sqlite3_bind_null(statement, idx)
            } else {
                throw DatabaseError.unsupportedType
            }
        }
    }
}
#endif

enum DatabaseError: Error, LocalizedError {
    case connectionFailed(String)
    case prepareFailed(String)
    case executionFailed(String)
    case unsupportedType

    var errorDescription: String? {
        switch self {
        case .connectionFailed(let msg): return "Connection failed: \(msg)"
        case .prepareFailed(let msg): return "Prepare failed: \(msg)"
        case .executionFailed(let msg): return "Execution failed: \(msg)"
        case .unsupportedType: return "Unsupported parameter type"
        }
    }
}

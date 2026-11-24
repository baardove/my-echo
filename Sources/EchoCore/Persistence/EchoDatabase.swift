import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public final class EchoDatabase: @unchecked Sendable {
    public let dbURL: URL
    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.echo.database", qos: .userInitiated)
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .secondsSince1970
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }()

    public init(dbURL: URL? = nil) throws {
        if let dbURL {
            self.dbURL = dbURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = appSupport.appendingPathComponent("Echo", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.dbURL = dir.appendingPathComponent("echo.sqlite")
        }

        if sqlite3_open(self.dbURL.path, &db) != SQLITE_OK {
            let msg = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error"
            throw NSError(domain: "Echo.DB", code: 1, userInfo: [NSLocalizedDescriptionKey: msg])
        }

        try executeSQL("""
            PRAGMA journal_mode = WAL;
            PRAGMA synchronous = NORMAL;

            CREATE TABLE IF NOT EXISTS sources (
                id TEXT PRIMARY KEY,
                json TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS tracks (
                id TEXT PRIMARY KEY,
                source_id TEXT NOT NULL,
                file_path TEXT NOT NULL,
                json TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_tracks_source ON tracks(source_id);

            CREATE TABLE IF NOT EXISTS playlists (
                id TEXT PRIMARY KEY,
                json TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS devices (
                id TEXT PRIMARY KEY,
                json TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS podcasts (
                id TEXT PRIMARY KEY,
                json TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS kv_settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            );
        """)
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    // MARK: - Sources

    public func loadSources() -> [LibrarySource] {
        queue.sync {
            fetchJSONRows(sql: "SELECT json FROM sources;", type: LibrarySource.self)
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    public func saveSource(_ source: LibrarySource) {
        queue.sync {
            upsertJSON(table: "sources", id: source.id.uuidString, value: source)
        }
    }

    public func deleteSource(id: UUID) {
        queue.sync {
            _ = runParamSQL("DELETE FROM tracks WHERE source_id = ?;", params: [id.uuidString])
            _ = runParamSQL("DELETE FROM sources WHERE id = ?;", params: [id.uuidString])
        }
    }

    // MARK: - Tracks

    public func loadAllTracks() -> [Track] {
        queue.sync {
            fetchJSONRows(sql: "SELECT json FROM tracks;", type: Track.self)
        }
    }

    public func replaceTracks(forSourceID sourceID: UUID, tracks: [Track]) {
        queue.sync {
            _ = execSimple("BEGIN TRANSACTION;")
            _ = runParamSQL("DELETE FROM tracks WHERE source_id = ?;", params: [sourceID.uuidString])

            let sql = "INSERT OR REPLACE INTO tracks (id, source_id, file_path, json) VALUES (?, ?, ?, ?);"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                for track in tracks {
                    guard let data = try? encoder.encode(track),
                          let jsonStr = String(data: data, encoding: .utf8) else { continue }
                    sqlite3_reset(stmt)
                    sqlite3_clear_bindings(stmt)
                    sqlite3_bind_text(stmt, 1, track.id, -1, SQLITE_TRANSIENT)
                    sqlite3_bind_text(stmt, 2, sourceID.uuidString, -1, SQLITE_TRANSIENT)
                    sqlite3_bind_text(stmt, 3, track.filePath, -1, SQLITE_TRANSIENT)
                    sqlite3_bind_text(stmt, 4, jsonStr, -1, SQLITE_TRANSIENT)
                    sqlite3_step(stmt)
                }
                sqlite3_finalize(stmt)
            }
            _ = execSimple("COMMIT;")
        }
    }

    // MARK: - Playlists

    public func loadPlaylists() -> [Playlist] {
        queue.sync {
            fetchJSONRows(sql: "SELECT json FROM playlists;", type: Playlist.self)
                .sorted { $0.createdAt < $1.createdAt }
        }
    }

    public func savePlaylist(_ playlist: Playlist) {
        queue.sync {
            upsertJSON(table: "playlists", id: playlist.id.uuidString, value: playlist)
        }
    }

    public func deletePlaylist(id: UUID) {
        queue.sync {
            _ = runParamSQL("DELETE FROM playlists WHERE id = ?;", params: [id.uuidString])
        }
    }

    // MARK: - Devices

    public func loadDevices() -> [DeviceProfile] {
        queue.sync {
            fetchJSONRows(sql: "SELECT json FROM devices;", type: DeviceProfile.self)
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    public func saveDevice(_ device: DeviceProfile) {
        queue.sync {
            upsertJSON(table: "devices", id: device.id.uuidString, value: device)
        }
    }

    public func deleteDevice(id: UUID) {
        queue.sync {
            _ = runParamSQL("DELETE FROM devices WHERE id = ?;", params: [id.uuidString])
        }
    }

    // MARK: - Podcasts

    public func loadPodcasts() -> [PodcastShow] {
        queue.sync {
            fetchJSONRows(sql: "SELECT json FROM podcasts;", type: PodcastShow.self)
                .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
    }

    public func savePodcast(_ show: PodcastShow) {
        queue.sync {
            upsertJSON(table: "podcasts", id: show.id.uuidString, value: show)
        }
    }

    public func deletePodcast(id: UUID) {
        queue.sync {
            _ = runParamSQL("DELETE FROM podcasts WHERE id = ?;", params: [id.uuidString])
        }
    }

    // MARK: - Key-Value Settings

    public func getSetting(_ key: String) -> String? {
        queue.sync {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_prepare_v2(db, "SELECT value FROM kv_settings WHERE key = ?;", -1, &stmt, nil) == SQLITE_OK else {
                return nil
            }
            sqlite3_bind_text(stmt, 1, key, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) == SQLITE_ROW, let cStr = sqlite3_column_text(stmt, 0) {
                return String(cString: cStr)
            }
            return nil
        }
    }

    public func setSetting(_ key: String, value: String) {
        queue.sync {
            _ = runParamSQL("INSERT OR REPLACE INTO kv_settings (key, value) VALUES (?, ?);", params: [key, value])
        }
    }

    // MARK: - SQLite Internals

    private func executeSQL(_ sql: String) throws {
        var errMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            let msg = errMsg.map { String(cString: $0) } ?? "SQLite execution failed"
            sqlite3_free(errMsg)
            throw NSError(domain: "Echo.DB", code: 2, userInfo: [NSLocalizedDescriptionKey: msg])
        }
    }

    @discardableResult
    private func execSimple(_ sql: String) -> Bool {
        sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK
    }

    @discardableResult
    private func runParamSQL(_ sql: String, params: [String]) -> Bool {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        for (i, p) in params.enumerated() {
            sqlite3_bind_text(stmt, Int32(i + 1), p, -1, SQLITE_TRANSIENT)
        }
        return sqlite3_step(stmt) == SQLITE_DONE
    }

    private func upsertJSON<T: Encodable>(table: String, id: String, value: T) {
        guard let data = try? encoder.encode(value),
              let jsonStr = String(data: data, encoding: .utf8) else { return }
        _ = runParamSQL("INSERT OR REPLACE INTO \(table) (id, json) VALUES (?, ?);", params: [id, jsonStr])
    }

    private func fetchJSONRows<T: Decodable>(sql: String, type: T.Type) -> [T] {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        var out: [T] = []
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return out }
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let cStr = sqlite3_column_text(stmt, 0),
               let data = String(cString: cStr).data(using: .utf8),
               let decoded = try? decoder.decode(T.self, from: data) {
                out.append(decoded)
            }
        }
        return out
    }
}

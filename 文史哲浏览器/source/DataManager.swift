import Foundation
import SQLite3

/// SQLITE_TRANSIENT 宏（C 头文件中的宏 Swift 不自动导入，需手动定义）
/// 表示 SQLite 应复制绑定字符串，而非持有指针
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// DataManager — 基于原生 SQLite C API 的轻量数据层（单例）
///
/// 设计要点：
/// - 零第三方依赖，仅用 SQLite3 C API，可适配 `swiftc -framework Cocoa` 编译
/// - 数据库位置：`~/Library/Application Support/WenShiZheBrowser/library.db`
/// - 所有方法返回 `Result<T, Error>`，便于调用方做错误处理
/// - 线程安全：内部使用串行队列序列化数据库访问
final class DataManager {

    // MARK: - 单例

    static let shared = DataManager()

    // MARK: - 错误类型

    enum DataError: Error, LocalizedError {
        case openFailed(String)
        case prepareFailed(String)
        case stepFailed(String)
        case notFound
        case invalidData

        var errorDescription: String? {
            switch self {
            case .openFailed(let msg): return "无法打开数据库：\(msg)"
            case .prepareFailed(let msg): return "SQL 准备失败：\(msg)"
            case .stepFailed(let msg): return "SQL 执行失败：\(msg)"
            case .notFound: return "记录不存在"
            case .invalidData: return "数据格式无效"
            }
        }
    }

    // MARK: - 数据模型

    struct Note {
        var id: Int64
        var url: String
        var content: String
        var scrollY: Double
        var tags: [String]
        var createdAt: Date

        /// 将 tags 数组编码为逗号分隔字符串
        var tagsJoined: String { tags.joined(separator: ",") }

        init(id: Int64 = 0, url: String, content: String,
             scrollY: Double = 0, tags: [String] = [], createdAt: Date = Date()) {
            self.id = id
            self.url = url
            self.content = content
            self.scrollY = scrollY
            self.tags = tags
            self.createdAt = createdAt
        }
    }

    // MARK: - 属性

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.wenshizhe.datamanager")

    /// 用户自定义数据库路径的存储键
    static let dbPathKey = "noteDBPath"

    /// 数据库文件 URL：优先使用用户自定义路径，否则使用默认 Application Support 路径
    var dbURL: URL {
        if let saved = UserDefaults.standard.string(forKey: Self.dbPathKey),
           !saved.isEmpty {
            return URL(fileURLWithPath: saved)
        }
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser

        let dir = base.appendingPathComponent("WenShiZheBrowser", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("library.db")
    }

    /// 当前数据库所在目录（供 UI 显示）
    var databaseDirectoryPath: String {
        dbURL.deletingLastPathComponent().path
    }

    // MARK: - 初始化

    private init() {
        open()
    }

    deinit {
        if let db = db { sqlite3_close(db) }
    }

    // MARK: - 打开与建表

    /// 迁移数据库到用户自定义路径（即时生效）
    /// - Parameter folderURL: 目标文件夹（数据库文件名为 library.db）
    func relocateDatabase(to folderURL: URL) -> Result<Void, Error> {
        queue.sync {
            let target = folderURL.appendingPathComponent("library.db")
            let oldPath = dbURL.path

            // 1. 关闭当前连接
            if let db = db { sqlite3_close(db); self.db = nil }

            // 2. 若目标不存在但旧库存在，复制数据文件（迁移已有笔记）
            if !FileManager.default.fileExists(atPath: target.path),
               FileManager.default.fileExists(atPath: oldPath) {
                do {
                    try FileManager.default.copyItem(at: URL(fileURLWithPath: oldPath), to: target)
                } catch {
                    // 复制失败则直接使用新位置（空库）
                    print("[DataManager] 复制旧库失败: \(error.localizedDescription)")
                }
            }

            // 3. 更新用户偏好
            UserDefaults.standard.set(target.path, forKey: Self.dbPathKey)

            // 4. 重新打开新位置
            open()
            return db != nil ? .success(()) : .failure(DataError.openFailed("relocate"))
        }
    }

    /// 恢复为默认存储位置（Application Support）
    func restoreDefaultLocation() -> Result<Void, Error> {
        queue.sync {
            if let db = db { sqlite3_close(db); self.db = nil }
            UserDefaults.standard.removeObject(forKey: Self.dbPathKey)
            open()
            return db != nil ? .success(()) : .failure(DataError.openFailed("restore"))
        }
    }

    private func open() {
        let path = dbURL.path
        if sqlite3_open(path, &db) != SQLITE_OK {
            let msg = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            print("[DataManager] 打开失败: \(msg)")
            db = nil
            return
        }
        createSchema()
    }

    private func createSchema() {
        let sql = """
        CREATE TABLE IF NOT EXISTS notes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            url TEXT NOT NULL,
            content TEXT NOT NULL,
            scrollY REAL DEFAULT 0,
            tags TEXT DEFAULT '',
            createdAt REAL DEFAULT 0
        );
        CREATE INDEX IF NOT EXISTS idx_notes_url ON notes(url);
        CREATE INDEX IF NOT EXISTS idx_notes_createdAt ON notes(createdAt);
        """
        _ = exec(sql)
    }

    /// 执行无返回值的 SQL
    @discardableResult
    private func exec(_ sql: String) -> Result<Void, Error> {
        var errMsg: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(db, sql, nil, nil, &errMsg) == SQLITE_OK else {
            let msg = errMsg.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(errMsg)
            return .failure(DataError.stepFailed(msg))
        }
        return .success(())
    }

    // MARK: - 时间转换

    private func toTimeInterval(_ date: Date) -> Double { date.timeIntervalSince1970 }
    private func fromTimeInterval(_ v: Double) -> Date { Date(timeIntervalSince1970: v) }

    // MARK: - CRUD: Create

    /// 插入一条笔记，成功后返回新记录 id
    func insertNote(url: String, content: String,
                    scrollY: Double = 0, tags: [String] = []) -> Result<Int64, Error> {
        queue.sync {
            guard let db = db else { return .failure(DataError.openFailed("db is nil")) }

            let sql = "INSERT INTO notes (url, content, scrollY, tags, createdAt) VALUES (?, ?, ?, ?, ?)"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                let msg = String(cString: sqlite3_errmsg(db))
                return .failure(DataError.prepareFailed(msg))
            }
            defer { sqlite3_finalize(stmt) }

            let now = toTimeInterval(Date())
            let tagsStr = tags.joined(separator: ",")

            sqlite3_bind_text(stmt, 1, url, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, content, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(stmt, 3, scrollY)
            sqlite3_bind_text(stmt, 4, tagsStr, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(stmt, 5, now)

            guard sqlite3_step(stmt) == SQLITE_DONE else {
                let msg = String(cString: sqlite3_errmsg(db))
                return .failure(DataError.stepFailed(msg))
            }
            return .success(sqlite3_last_insert_rowid(db))
        }
    }

    // MARK: - CRUD: Read

    /// 按 id 查询单条笔记
    func fetchNote(id: Int64) -> Result<Note, Error> {
        queue.sync {
            guard let db = db else { return .failure(DataError.openFailed("db is nil")) }

            let sql = "SELECT id, url, content, scrollY, tags, createdAt FROM notes WHERE id = ?"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                return .failure(DataError.prepareFailed(String(cString: sqlite3_errmsg(db))))
            }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_int64(stmt, 1, id)

            guard sqlite3_step(stmt) == SQLITE_ROW else { return .failure(DataError.notFound) }
            return .success(rowToNote(stmt!))
        }
    }

    /// 查询全部笔记，按创建时间倒序
    func fetchAllNotes() -> Result<[Note], Error> {
        queue.sync {
            guard let db = db else { return .failure(DataError.openFailed("db is nil")) }

            let sql = "SELECT id, url, content, scrollY, tags, createdAt FROM notes ORDER BY createdAt DESC"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                return .failure(DataError.prepareFailed(String(cString: sqlite3_errmsg(db))))
            }
            defer { sqlite3_finalize(stmt) }

            var notes: [Note] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                notes.append(rowToNote(stmt!))
            }
            return .success(notes)
        }
    }

    /// 按 URL 查询笔记（用于网页联动回溯）
    func fetchNotes(url: String) -> Result<[Note], Error> {
        queue.sync {
            guard let db = db else { return .failure(DataError.openFailed("db is nil")) }

            let sql = "SELECT id, url, content, scrollY, tags, createdAt FROM notes WHERE url = ? ORDER BY createdAt DESC"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                return .failure(DataError.prepareFailed(String(cString: sqlite3_errmsg(db))))
            }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_text(stmt, 1, url, -1, SQLITE_TRANSIENT)

            var notes: [Note] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                notes.append(rowToNote(stmt!))
            }
            return .success(notes)
        }
    }

    /// 按标签模糊查询（tags 字段以逗号分隔存储）
    func fetchNotes(tag: String) -> Result<[Note], Error> {
        queue.sync {
            guard let db = db else { return .failure(DataError.openFailed("db is nil")) }

            let sql = "SELECT id, url, content, scrollY, tags, createdAt FROM notes WHERE tags LIKE ? ORDER BY createdAt DESC"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                return .failure(DataError.prepareFailed(String(cString: sqlite3_errmsg(db))))
            }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_text(stmt, 1, "%\(tag)%", -1, SQLITE_TRANSIENT)

            var notes: [Note] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                notes.append(rowToNote(stmt!))
            }
            return .success(notes)
        }
    }

    /// 关键词全文搜索（LIKE 匹配 content/url）
    func searchNotes(keyword: String) -> Result<[Note], Error> {
        queue.sync {
            guard let db = db else { return .failure(DataError.openFailed("db is nil")) }

            let sql = """
            SELECT id, url, content, scrollY, tags, createdAt FROM notes
            WHERE content LIKE ? OR url LIKE ? OR tags LIKE ?
            ORDER BY createdAt DESC
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                return .failure(DataError.prepareFailed(String(cString: sqlite3_errmsg(db))))
            }
            defer { sqlite3_finalize(stmt) }

            let pattern = "%\(keyword)%"
            sqlite3_bind_text(stmt, 1, pattern, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, pattern, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, pattern, -1, SQLITE_TRANSIENT)

            var notes: [Note] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                notes.append(rowToNote(stmt!))
            }
            return .success(notes)
        }
    }

    // MARK: - CRUD: Update

    /// 更新笔记内容
    func updateNote(id: Int64, content: String) -> Result<Void, Error> {
        queue.sync {
            guard let db = db else { return .failure(DataError.openFailed("db is nil")) }

            let sql = "UPDATE notes SET content = ? WHERE id = ?"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                return .failure(DataError.prepareFailed(String(cString: sqlite3_errmsg(db))))
            }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_text(stmt, 1, content, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int64(stmt, 2, id)

            guard sqlite3_step(stmt) == SQLITE_DONE else {
                return .failure(DataError.stepFailed(String(cString: sqlite3_errmsg(db))))
            }
            return .success(())
        }
    }

    /// 更新滚动位置（网页联动，用于回溯上下文）
    func updateScrollPosition(id: Int64, y: Double) -> Result<Void, Error> {
        queue.sync {
            guard let db = db else { return .failure(DataError.openFailed("db is nil")) }

            let sql = "UPDATE notes SET scrollY = ? WHERE id = ?"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                return .failure(DataError.prepareFailed(String(cString: sqlite3_errmsg(db))))
            }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_double(stmt, 1, y)
            sqlite3_bind_int64(stmt, 2, id)

            guard sqlite3_step(stmt) == SQLITE_DONE else {
                return .failure(DataError.stepFailed(String(cString: sqlite3_errmsg(db))))
            }
            return .success(())
        }
    }

    /// 更新标签
    func updateTags(id: Int64, tags: [String]) -> Result<Void, Error> {
        queue.sync {
            guard let db = db else { return .failure(DataError.openFailed("db is nil")) }

            let sql = "UPDATE notes SET tags = ? WHERE id = ?"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                return .failure(DataError.prepareFailed(String(cString: sqlite3_errmsg(db))))
            }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_text(stmt, 1, tags.joined(separator: ","), -1, SQLITE_TRANSIENT)
            sqlite3_bind_int64(stmt, 2, id)

            guard sqlite3_step(stmt) == SQLITE_DONE else {
                return .failure(DataError.stepFailed(String(cString: sqlite3_errmsg(db))))
            }
            return .success(())
        }
    }

    // MARK: - CRUD: Delete

    /// 删除笔记
    func deleteNote(id: Int64) -> Result<Void, Error> {
        queue.sync {
            guard let db = db else { return .failure(DataError.openFailed("db is nil")) }

            let sql = "DELETE FROM notes WHERE id = ?"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                return .failure(DataError.prepareFailed(String(cString: sqlite3_errmsg(db))))
            }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_int64(stmt, 1, id)

            guard sqlite3_step(stmt) == SQLITE_DONE else {
                return .failure(DataError.stepFailed(String(cString: sqlite3_errmsg(db))))
            }
            return .success(())
        }
    }

    /// 清空所有笔记
    func clearAllNotes() -> Result<Void, Error> {
        queue.sync {
            guard db != nil else { return .failure(DataError.openFailed("db is nil")) }
            return exec("DELETE FROM notes")
        }
    }

    // MARK: - 行解析

    private func rowToNote(_ stmt: OpaquePointer) -> Note {
        let id = sqlite3_column_int64(stmt, 0)
        let url = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? ""
        let content = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? ""
        let scrollY = sqlite3_column_double(stmt, 3)
        let tagsRaw = sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? ""
        let created = sqlite3_column_double(stmt, 5)

        let tags = tagsRaw.isEmpty ? [] : tagsRaw.split(separator: ",").map(String.init)

        return Note(id: id, url: url, content: content,
                    scrollY: scrollY, tags: tags,
                    createdAt: fromTimeInterval(created))
    }
}

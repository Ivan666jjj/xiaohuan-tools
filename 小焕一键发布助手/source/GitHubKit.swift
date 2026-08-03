import Foundation
import Security

// ============================================================
// GitHubKit.swift — Keychain 安全存储 + GitHub API + Git 操作
// ============================================================

/// Token 安全存储（macOS Keychain，不落盘不写日志）
enum KeychainStore {
    private static let service = "com.xiaohuan.publish-assistant"
    private static let account = "github-token"

    static func save(_ token: String) -> Bool {
        delete() // 先清旧
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func delete() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess || true
    }
}

/// GitHub REST API 封装（验证 token / 获取用户信息）
enum GitHubAPI {
    static func verifyToken(_ token: String, completion: @escaping (Result<String, NSError>) -> Void) {
        var req = URLRequest(url: URL(string: "https://api.github.com/user")!)
        req.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: req) { data, resp, _ in
            guard let data = data else { completion(.failure(NSError(domain:"GitHub", code:-1, userInfo:[NSLocalizedDescriptionKey:"网络请求失败"]))); return }
            let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
            if status == 200 {
                if let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let login = j["login"] as? String {
                    completion(.success(login))
                } else {
                    completion(.failure(NSError(domain:"GitHub", code:-2, userInfo:[NSLocalizedDescriptionKey:"解析失败"])))
                }
            } else if status == 401 {
                completion(.failure(NSError(domain:"GitHub", code:401, userInfo:[NSLocalizedDescriptionKey:"Token 无效或已过期"])))
            } else {
                completion(.failure(NSError(domain:"GitHub", code:status, userInfo:[NSLocalizedDescriptionKey:"API 错误 HTTP \(status)"])))
            }
        }.resume()
    }

    /// 列出当前用户仓库（供绑定/选择）
    static func listRepos(_ token: String, completion: @escaping (Result<[String], NSError>) -> Void) {
        var req = URLRequest(url: URL(string: "https://api.github.com/user/repos?per_page=100&sort=updated")!)
        req.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: req) { data, resp, _ in
            guard let data = data else { completion(.failure(NSError(domain:"GitHub", code:-1, userInfo:[NSLocalizedDescriptionKey:"网络请求失败"]))); return }
            let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
            if status == 200, let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                let names = arr.compactMap { $0["name"] as? String }
                completion(.success(names))
            } else {
                completion(.failure(NSError(domain:"GitHub", code:status, userInfo:[NSLocalizedDescriptionKey:"无法获取仓库列表 (HTTP \(status))"])))
            }
        }.resume()
    }
}

/// Git 命令行封装（复用系统 git，走 SSH 免密）
struct GitRunner {
    /// 在指定目录执行 git 命令
    @discardableResult
    static func run(in dir: String, _ args: [String], log: ((String) -> Void)? = nil) -> (ok: Bool, out: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        p.arguments = args
        p.currentDirectoryURL = URL(fileURLWithPath: dir)
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        do { try p.run() } catch { return (false, "git 启动失败: \(error.localizedDescription)") }
        p.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let out = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !out.isEmpty { log?(out) }
        return (p.terminationStatus == 0, out)
    }

    static func isRepo(_ dir: String) -> Bool {
        let r = run(in: dir, ["rev-parse", "--is-inside-work-tree"])
        return r.ok && r.out == "true"
    }

    static func remoteURL(_ dir: String) -> String {
        let r = run(in: dir, ["remote", "get-url", "origin"])
        return r.ok ? r.out : ""
    }
}

/// 发布历史记录（UserDefaults）
struct HistoryStore {
    private static let key = "publish_history"
    static func add(_ entry: [String: String]) {
        var list = (UserDefaults.standard.array(forKey: key) as? [[String: String]]) ?? []
        list.insert(entry, at: 0)
        if list.count > 50 { list = Array(list.prefix(50)) }
        UserDefaults.standard.set(list, forKey: key)
    }
    static func all() -> [[String: String]] {
        (UserDefaults.standard.array(forKey: key) as? [[String: String]]) ?? []
    }
    static func clear() { UserDefaults.standard.removeObject(forKey: key) }
}

import Cocoa
import UniformTypeIdentifiers

// ============================================================
// AppDelegate.swift — 小焕一键发布助手 UI 与发布逻辑
// ============================================================

// MARK: - 拖拽接收视图

final class DropZoneView: NSView {
    var onFiles: (([URL]) -> Void)?
    private let label = NSTextField(labelWithString: "📦 拖入文件 / 文件夹\n或点击选择")
    private let bgLayer = CALayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.borderWidth = 2
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.04).cgColor
        registerForDraggedTypes([.fileURL])
        label.alignment = .center
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .secondaryLabelColor
        label.maximumNumberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        layer?.borderColor = NSColor.systemGreen.cgColor
        layer?.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.1).cgColor
        return .copy
    }
    override func draggingExited(_ sender: NSDraggingInfo?) {
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.04).cgColor
    }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.04).cgColor
        let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        if !urls.isEmpty { onFiles?(urls) }
        return true
    }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var dropZone: DropZoneView!
    var versionField: NSTextField!
    var noteField: NSTextField!
    var typeSeg: NSSegmentedControl!
    var logView: NSTextView!
    var publishBtn: NSButton!
    var statusLabel: NSTextField!
    var fileLabel: NSTextField!

    var pendingFiles: [URL] = []
    var isPublishing = false
    var releaseCheck: NSButton!

    // MARK: 生命周期

    func applicationDidFinishLaunching(_ n: Notification) {
        let rect = NSRect(x: 0, y: 0, width: 900, height: 620)
        window = NSWindow(contentRect: rect, styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.title = "🚀 小焕一键发布助手"
        window.minSize = NSSize(width: 760, height: 520)
        buildUI()
        window.center()
        window.makeKeyAndOrderFront(nil)
        log("✅ 就绪。左侧设置绑定仓库，拖入文件后点发布。")
    }

    // MARK: UI

    private func buildUI() {
        guard let content = window.contentView else { return }
        content.wantsLayer = true

        // 侧边栏
        let sidebar = NSVisualEffectView()
        sidebar.material = .sidebar
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(sidebar)

        let title = NSTextField(labelWithString: "🚀 发布助手")
        title.font = .boldSystemFont(ofSize: 15)
        title.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(title)

        let pubBtn = sideButton("📤 快速发布")
        pubBtn.tag = 0
        let histBtn = sideButton("📜 历史记录")
        histBtn.tag = 1
        let setBtn = sideButton("⚙️ 设置")
        setBtn.tag = 2
        for b in [pubBtn, histBtn, setBtn] {
            b.translatesAutoresizingMaskIntoConstraints = false
            sidebar.addSubview(b)
            b.target = self; b.action = #selector(sidebarAction(_:))
        }

        // 主区
        let main = NSView()
        main.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(main)

        // 头部
        let headLabel = NSTextField(labelWithString: "一键发布到 GitHub")
        headLabel.font = .boldSystemFont(ofSize: 18)
        headLabel.translatesAutoresizingMaskIntoConstraints = false
        main.addSubview(headLabel)

        statusLabel = NSTextField(labelWithString: "未绑定仓库")
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        main.addSubview(statusLabel)

        // 拖拽区
        dropZone = DropZoneView(frame: .zero)
        dropZone.translatesAutoresizingMaskIntoConstraints = false
        dropZone.onFiles = { [weak self] urls in self?.receiveFiles(urls) }
        main.addSubview(dropZone)

        fileLabel = NSTextField(labelWithString: "尚未选择文件")
        fileLabel.font = .systemFont(ofSize: 12)
        fileLabel.textColor = .secondaryLabelColor
        fileLabel.translatesAutoresizingMaskIntoConstraints = false
        main.addSubview(fileLabel)

        let chooseBtn = NSButton(title: "选择文件…", target: self, action: #selector(chooseFiles))
        chooseBtn.bezelStyle = .rounded
        chooseBtn.translatesAutoresizingMaskIntoConstraints = false
        main.addSubview(chooseBtn)

        // 表单行
        let verLabel = NSTextField(labelWithString: "版本号")
        verLabel.font = .systemFont(ofSize: 12)
        verLabel.translatesAutoresizingMaskIntoConstraints = false
        main.addSubview(verLabel)

        versionField = NSTextField(string: "v1.0")
        versionField.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        versionField.translatesAutoresizingMaskIntoConstraints = false
        main.addSubview(versionField)

        typeSeg = NSSegmentedControl(labels: ["Feature", "Fix", "Release"], trackingMode: .selectOne, target: nil, action: nil)
        typeSeg.selectedSegment = 0
        typeSeg.translatesAutoresizingMaskIntoConstraints = false
        main.addSubview(typeSeg)

        releaseCheck = NSButton(checkboxWithTitle: "📦 自动创建 Release", target: nil, action: nil)
        releaseCheck.state = .on
        releaseCheck.font = .systemFont(ofSize: 11)
        releaseCheck.toolTip = "发布安装包时自动在 GitHub 创建 Release 并上传"
        releaseCheck.translatesAutoresizingMaskIntoConstraints = false
        main.addSubview(releaseCheck)

        let noteLabel = NSTextField(labelWithString: "更新说明")
        noteLabel.font = .systemFont(ofSize: 12)
        noteLabel.translatesAutoresizingMaskIntoConstraints = false
        main.addSubview(noteLabel)

        noteField = NSTextField(string: "")
        noteField.placeholderString = "描述本次更新内容…"
        noteField.translatesAutoresizingMaskIntoConstraints = false
        main.addSubview(noteField)

        // 发布按钮
        publishBtn = NSButton(title: "🚀 发布到 GitHub", target: self, action: #selector(publish))
        publishBtn.bezelStyle = .rounded
        publishBtn.contentTintColor = .white
        publishBtn.wantsLayer = true
        publishBtn.layer?.backgroundColor = NSColor(calibratedRed: 0.14, green: 0.53, blue: 0.21, alpha: 1).cgColor
        publishBtn.layer?.cornerRadius = 8
        publishBtn.font = .boldSystemFont(ofSize: 14)
        publishBtn.translatesAutoresizingMaskIntoConstraints = false
        main.addSubview(publishBtn)

        // 日志
        let logLabel = NSTextField(labelWithString: "运行日志")
        logLabel.font = .systemFont(ofSize: 12)
        logLabel.textColor = .secondaryLabelColor
        logLabel.translatesAutoresizingMaskIntoConstraints = false
        main.addSubview(logLabel)

        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        logView = NSTextView()
        logView.isEditable = false
        logView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        logView.backgroundColor = NSColor(calibratedWhite: 0.08, alpha: 1)
        logView.textColor = .white
        scroll.documentView = logView
        main.addSubview(scroll)

        // 布局
        NSLayoutConstraint.activate([
            sidebar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            sidebar.topAnchor.constraint(equalTo: content.topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            sidebar.widthAnchor.constraint(equalToConstant: 180),

            title.topAnchor.constraint(equalTo: sidebar.topAnchor, constant: 20),
            title.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 16),
            pubBtn.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 24),
            pubBtn.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 12),
            pubBtn.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -12),
            histBtn.topAnchor.constraint(equalTo: pubBtn.bottomAnchor, constant: 6),
            histBtn.leadingAnchor.constraint(equalTo: pubBtn.leadingAnchor),
            histBtn.trailingAnchor.constraint(equalTo: pubBtn.trailingAnchor),
            setBtn.topAnchor.constraint(equalTo: histBtn.bottomAnchor, constant: 6),
            setBtn.leadingAnchor.constraint(equalTo: pubBtn.leadingAnchor),
            setBtn.trailingAnchor.constraint(equalTo: pubBtn.trailingAnchor),

            main.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            main.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            main.topAnchor.constraint(equalTo: content.topAnchor),
            main.bottomAnchor.constraint(equalTo: content.bottomAnchor),

            headLabel.topAnchor.constraint(equalTo: main.topAnchor, constant: 20),
            headLabel.leadingAnchor.constraint(equalTo: main.leadingAnchor, constant: 24),
            statusLabel.centerYAnchor.constraint(equalTo: headLabel.centerYAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: main.trailingAnchor, constant: -24),

            dropZone.topAnchor.constraint(equalTo: headLabel.bottomAnchor, constant: 16),
            dropZone.leadingAnchor.constraint(equalTo: main.leadingAnchor, constant: 24),
            dropZone.trailingAnchor.constraint(equalTo: main.trailingAnchor, constant: -24),
            dropZone.heightAnchor.constraint(equalToConstant: 130),

            fileLabel.topAnchor.constraint(equalTo: dropZone.bottomAnchor, constant: 10),
            fileLabel.leadingAnchor.constraint(equalTo: main.leadingAnchor, constant: 24),
            chooseBtn.centerYAnchor.constraint(equalTo: fileLabel.centerYAnchor),
            chooseBtn.trailingAnchor.constraint(equalTo: main.trailingAnchor, constant: -24),

            verLabel.topAnchor.constraint(equalTo: fileLabel.bottomAnchor, constant: 18),
            verLabel.leadingAnchor.constraint(equalTo: main.leadingAnchor, constant: 24),
            versionField.centerYAnchor.constraint(equalTo: verLabel.centerYAnchor),
            versionField.leadingAnchor.constraint(equalTo: verLabel.trailingAnchor, constant: 10),
            versionField.widthAnchor.constraint(equalToConstant: 110),
            typeSeg.centerYAnchor.constraint(equalTo: verLabel.centerYAnchor),
            typeSeg.leadingAnchor.constraint(equalTo: versionField.trailingAnchor, constant: 14),

            releaseCheck.centerYAnchor.constraint(equalTo: typeSeg.centerYAnchor),
            releaseCheck.leadingAnchor.constraint(equalTo: typeSeg.trailingAnchor, constant: 14),

            noteLabel.topAnchor.constraint(equalTo: verLabel.bottomAnchor, constant: 16),
            noteLabel.leadingAnchor.constraint(equalTo: main.leadingAnchor, constant: 24),
            noteField.centerYAnchor.constraint(equalTo: noteLabel.centerYAnchor),
            noteField.leadingAnchor.constraint(equalTo: noteLabel.trailingAnchor, constant: 10),
            noteField.trailingAnchor.constraint(equalTo: main.trailingAnchor, constant: -24),

            publishBtn.topAnchor.constraint(equalTo: noteField.bottomAnchor, constant: 18),
            publishBtn.trailingAnchor.constraint(equalTo: main.trailingAnchor, constant: -24),
            publishBtn.widthAnchor.constraint(equalToConstant: 170),
            publishBtn.heightAnchor.constraint(equalToConstant: 40),

            logLabel.topAnchor.constraint(equalTo: publishBtn.bottomAnchor, constant: 14),
            logLabel.leadingAnchor.constraint(equalTo: main.leadingAnchor, constant: 24),
            scroll.topAnchor.constraint(equalTo: logLabel.bottomAnchor, constant: 6),
            scroll.leadingAnchor.constraint(equalTo: main.leadingAnchor, constant: 24),
            scroll.trailingAnchor.constraint(equalTo: main.trailingAnchor, constant: -24),
            scroll.bottomAnchor.constraint(equalTo: main.bottomAnchor, constant: -20),
        ])
    }

    private func sideButton(_ title: String) -> NSButton {
        let b = NSButton(title: title, target: nil, action: nil)
        b.bezelStyle = .inline
        b.isBordered = false
        b.font = .systemFont(ofSize: 13)
        b.alignment = .left
        return b
    }

    // MARK: 日志

    func log(_ msg: String, isError: Bool = false) {
        DispatchQueue.main.async {
            let prefix = isError ? "❌ " : "· "
            let colored = NSMutableAttributedString(string: "\(prefix)\(msg)\n")
            colored.addAttribute(.foregroundColor,
                                 value: isError ? NSColor.systemRed : NSColor.systemGray,
                                 range: NSRange(location: 0, length: colored.length))
            self.logView.textStorage?.append(colored)
            self.logView.scrollToEndOfDocument(nil)
        }
    }

    // MARK: 文件接收

    func receiveFiles(_ urls: [URL]) {
        pendingFiles = urls
        let names = urls.map { $0.lastPathComponent }.joined(separator: "、")
        fileLabel.stringValue = "📦 \(urls.count) 个文件：\(names)"
        fileLabel.textColor = .labelColor
        log("收到文件：\(names)")
        autoVersion()
    }

    @objc func chooseFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.begin { [weak self] resp in
            guard resp == .OK else { return }
            self?.receiveFiles(panel.urls)
        }
    }

    private func autoVersion() {
        // 从文件名提取版本号，如 xxx-v1.2.3.dmg / 1.0.0 等
        for url in pendingFiles {
            let name = url.deletingPathExtension().lastPathComponent
            if let range = name.range(of: #"v?\d+\.\d+(\.\d+)?"#, options: .regularExpression) {
                versionField.stringValue = String(name[range])
                return
            }
        }
    }

    // MARK: 侧边栏

    @objc func sidebarAction(_ sender: NSButton) {
        switch sender.tag {
        case 1: showHistory()
        case 2: openSettings()
        default: break
        }
    }

    // MARK: 设置（Token + 仓库绑定）

    @objc func openSettings() {
        let alert = NSAlert()
        alert.messageText = "⚙️ 设置"
        alert.informativeText = "GitHub Token（存 Keychain，不落盘）："
        alert.addButton(withTitle: "验证并保存")
        alert.addButton(withTitle: "取消")

        let tf = NSTextField(frame: NSRect(x: 0, y: 0, width: 360, height: 24))
        tf.placeholderString = "ghp_..."
        if let t = KeychainStore.load() { tf.stringValue = t }
        alert.accessoryView = tf

        let resp = alert.runModal()
        guard resp == .alertFirstButtonReturn else { return }
        let token = tf.stringValue.trimmingCharacters(in: .whitespaces)
        guard !token.isEmpty else { return }

        log("正在验证 Token…")
        GitHubAPI.verifyToken(token) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let login):
                    _ = KeychainStore.save(token)
                    self?.log("✅ Token 有效，已连接 GitHub（@\(login)）")
                    self?.statusLabel.stringValue = "🔗 已连接 @\(login)"
                    self?.statusLabel.textColor = .systemGreen
                case .failure(let err):
                    self?.log(err.localizedDescription, isError: true)
                }
            }
        }
    }

    // MARK: 历史

    @objc func showHistory() {
        let list = HistoryStore.all()
        let text = list.isEmpty ? "暂无发布记录" : list.map { "\($0["time"] ?? "")  \($0["file"] ?? "")  \($0["msg"] ?? "")" }.joined(separator: "\n")
        let alert = NSAlert()
        alert.messageText = "📜 发布历史"
        alert.informativeText = text
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

    // MARK: 发布

    @objc func publish() {
        guard !isPublishing else { return }
        guard !pendingFiles.isEmpty else {
            log("请先拖入要发布的文件", isError: true); return
        }
        // 大文件警告（>100MB）
        let big = pendingFiles.filter { (try? FileManager.default.attributesOfItem(atPath: $0.path))?[.size] as? Int64 ?? 0 > 100 * 1024 * 1024 }
        if !big.isEmpty {
            let names = big.map { $0.lastPathComponent }.joined(separator: ", ")
            log("⚠️ 大文件(>100MB)：\(names)\n建议 Git LFS 或压缩", isError: true)
            let a = NSAlert()
            a.messageText = "检测到大文件"
            a.informativeText = "\(names)\nGitHub 限制单文件 ≤100MB，继续可能失败。"
            a.addButton(withTitle: "仍然继续")
            a.addButton(withTitle: "取消")
            if a.runModal() == .alertSecondButtonReturn { return }
        }
        // 仓库路径：默认工作区 xiaohuan-tools
        let repoPath = UserDefaults.standard.string(forKey: "repo_path")
            ?? "/Users/Admin/.reasonix/global-workspace/xiaohuan-tools"
        guard FileManager.default.fileExists(atPath: repoPath),
              GitRunner.isRepo(repoPath) else {
            log("仓库不可用：\(repoPath)\n请在设置中指定正确的本地仓库路径", isError: true)
            return
        }
        isPublishing = true
        publishBtn.isEnabled = false
        publishBtn.title = "发布中…"

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.doPublish(repoPath: repoPath)
        }
    }

    private func doPublish(repoPath: String) {
        DispatchQueue.main.async { self.log("== 开始发布 ==") }

        // 1. 复制文件到 安装包/ 目录（安装包类）或仓库根（源码类）
        let isPackage = pendingFiles.contains { ["dmg", "exe", "apk", "zip", "pkg"].contains($0.pathExtension.lowercased()) }
        let targetDir: String
        if isPackage {
            targetDir = (repoPath as NSString).appendingPathComponent("安装包")
            try? FileManager.default.createDirectory(atPath: targetDir, withIntermediateDirectories: true)
        } else {
            targetDir = repoPath
        }

        for url in pendingFiles {
            let dest = (targetDir as NSString).appendingPathComponent(url.lastPathComponent)
            do {
                if FileManager.default.fileExists(atPath: dest) {
                    try? FileManager.default.removeItem(atPath: dest)
                }
                try FileManager.default.copyItem(at: url, to: URL(fileURLWithPath: dest))
                DispatchQueue.main.async { self.log("已复制：\(url.lastPathComponent) → 安装包/") }
            } catch {
                DispatchQueue.main.async { self.log("复制失败：\(error.localizedDescription)", isError: true) }
                finishPublish(ok: false)
                return
            }
        }

        // 2. 生成 commit message
        let type = ["Feature", "Fix", "Release"][typeSeg.selectedSegment]
        let ver = versionField.stringValue.isEmpty ? "" : " \(versionField.stringValue)"
        let note = noteField.stringValue.trimmingCharacters(in: .whitespaces)
        let msg = "\(type)\(ver)\(note.isEmpty ? "" : ": \(note)")"
        let files = pendingFiles.map { $0.lastPathComponent }.joined(separator: ", ")

        // 3. git add / commit / pull --rebase / push
        let steps: [[String]] = [
            ["add", "-A"],
            ["commit", "-m", msg],
            ["pull", "--rebase", "--autostash"],
        ]
        for args in steps {
            let r = GitRunner.run(in: repoPath, args) { out in
                DispatchQueue.main.async { self.log(out) }
            }
            if !r.ok {
                DispatchQueue.main.async { self.log("git \(args[0]) 失败：\(r.out)", isError: true) }
                finishPublish(ok: false)
                return
            }
        }
        // push：失败指数退避重试 3 次
        var pushOK = false
        for attempt in 1...3 {
            DispatchQueue.main.async { self.log("git push（第 \(attempt)/3 次尝试）") }
            let r = GitRunner.run(in: repoPath, ["push"]) { out in
                DispatchQueue.main.async { self.log(out) }
            }
            if r.ok { pushOK = true; break }
            let wait = UInt32(2 * attempt)
            DispatchQueue.main.async { self.log("push 失败，\(wait)s 后重试…", isError: true) }
            sleep(wait)
        }
        if !pushOK {
            DispatchQueue.main.async { self.log("push 失败（已重试 3 次），请检查网络/凭据", isError: true) }
            finishPublish(ok: false)
            return
        }

        // 打 tag（版本号非空时）
        if !versionField.stringValue.isEmpty {
            let tag = versionField.stringValue.hasPrefix("v") ? versionField.stringValue : "v\(versionField.stringValue)"
            _ = GitRunner.run(in: repoPath, ["tag", tag])
            _ = GitRunner.run(in: repoPath, ["push", "origin", tag])
        }

        // 4. 记录历史
        HistoryStore.add(["time": Date().description.prefix(19).description,
                          "file": files, "msg": msg])
        DispatchQueue.main.async {
            self.log("✅ 发布成功：\(msg)")
            self.sendNotification(files: files)
        }
        // 5. 自动创建 GitHub Release（勾选 + 有 token + 有安装包时）
        if releaseCheck.state == .on, let token = KeychainStore.load(), isPackage {
            let asset = pendingFiles.first { ["dmg", "exe", "apk", "pkg"].contains($0.pathExtension.lowercased()) }?.path
            let tag = versionField.stringValue.isEmpty ? "latest" : (versionField.stringValue.hasPrefix("v") ? versionField.stringValue : "v\(versionField.stringValue)")
            let relName = "\(type)\(versionField.stringValue.isEmpty ? "" : " \(versionField.stringValue)")"
            DispatchQueue.main.async { self.log("📦 正在创建 GitHub Release…") }
            GitHubAPI.createRelease(token: token, repo: "Ivan666jjj/xiaohuan-tools",
                                    tag: tag, name: relName, body: note, assetPath: asset) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let url):
                        self.log("✅ Release 已创建：\(url)")
                    case .failure(let err):
                        self.log("Release 创建失败：\(err.localizedDescription)", isError: true)
                    }
                }
            }
        }
        finishPublish(ok: true)
    }

    private func finishPublish(ok: Bool) {
        DispatchQueue.main.async {
            self.isPublishing = false
            self.publishBtn.isEnabled = true
            self.publishBtn.title = "🚀 发布到 GitHub"
            if ok { self.pendingFiles = []; self.fileLabel.stringValue = "尚未选择文件"; self.fileLabel.textColor = .secondaryLabelColor }
        }
    }

    private func sendNotification(files: String) {
        let n = NSUserNotification()
        n.title = "🚀 发布成功"
        n.informativeText = "已推送：\(files)"
        NSUserNotificationCenter.default.deliver(n)
    }
}

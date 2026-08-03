import Cocoa

/// NotesWindow — 独立笔记窗口（纯代码构建，无 XIB/Storyboard）
///
/// 结构：
/// - NSSplitView：左侧 NSOutlineView（目录树），右侧 NSTextView（Markdown 编辑器）
/// - 标题栏透明，工具栏含「新建」「搜索」
/// - 通过闭包回调与 AppDelegate 通信
final class NotesWindow: NSWindow {

    // MARK: - 回调

    /// 新建笔记回调（参数：当前选中的 URL 上下文）
    var onCreateNote: ((String?) -> Void)?
    /// 笔记保存回调（参数：笔记内容）
    var onSaveNote: ((String) -> Void)?
    /// 搜索回调（参数：关键词）
    var onSearch: ((String) -> Void)?
    /// 导出笔记回调（由 AppDelegate 实现路径选择与文件写入）
    var onExport: (() -> Void)?

    // MARK: - UI 组件

    private let outlineView = NSOutlineView()
    private let textView = NSTextView()
    private let splitView = NSSplitView()
    private let searchField = NSSearchField()

    // MARK: - 数据

    /// 目录树数据源（简单结构：章节 -> 笔记标题）
    private struct Node {
        let title: String
        let children: [Node]
    }

    private var treeData: [Node] = []
    /// 当前上下文 URL（网页联动时由 AppDelegate 传入）
    var contextURL: String?

    // MARK: - 初始化

    convenience init() {
        self.init(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        title = "文献笔记"
        minSize = NSSize(width: 700, height: 450)
        titlebarAppearsTransparent = true
        isReleasedWhenClosed = false
        center()
        setupToolbar()
        buildUI()
    }

    // MARK: - 工具栏

    private func setupToolbar() {
        let toolbar = NSToolbar(identifier: "NotesToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconAndLabel
        self.toolbar = toolbar
    }

    // MARK: - UI 构建

    private func buildUI() {
        // 内容视图
        guard let content = contentView else { return }

        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(splitView)

        NSLayoutConstraint.activate([
            splitView.topAnchor.constraint(equalTo: content.topAnchor),
            splitView.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            splitView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
        ])

        // 左侧：目录树
        let leftPane = NSScrollView()
        leftPane.hasVerticalScroller = true
        leftPane.borderType = .noBorder

        outlineView.headerView = nil
        outlineView.delegate = self
        outlineView.dataSource = self
        outlineView.rowHeight = 26
        outlineView.addTableColumn(NSTableColumn(identifier: .init("main")))
        outlineView.outlineTableColumn = outlineView.tableColumns[0]

        leftPane.documentView = outlineView
        splitView.addArrangedSubview(leftPane)
        leftPane.widthAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true
        leftPane.widthAnchor.constraint(lessThanOrEqualToConstant: 320).isActive = true

        // 右侧：编辑器
        let rightPane = NSScrollView()
        rightPane.hasVerticalScroller = true
        rightPane.borderType = .noBorder

        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = NSFont(name: "Songti SC", size: 14) ?? .systemFont(ofSize: 14)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.delegate = self
        textView.string = "「\(contextURL ?? "新笔记")」\n\n在这里开始写作……"

        rightPane.documentView = textView
        splitView.addArrangedSubview(rightPane)

        splitView.setPosition(260, ofDividerAt: 0)
    }

    // MARK: - 数据刷新

    /// 从 DataManager 加载笔记并刷新目录树
    func reloadNotes(_ notes: [DataManager.Note]) {
        // 按日期分组为树节点
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        var groups: [String: [Node]] = [:]
        for note in notes {
            let day = formatter.string(from: note.createdAt)
            let title = note.content.components(separatedBy: "\n").first ?? "无标题"
            let preview = String(title.prefix(20))
            groups[day, default: []].append(Node(title: preview, children: []))
        }
        treeData = groups.keys.sorted(by: >).map { day in
            Node(title: "\(day) (\(groups[day]?.count ?? 0))", children: groups[day] ?? [])
        }
        outlineView.reloadData()
        outlineView.expandItem(nil, expandChildren: true)
    }

    // MARK: - 动作

    @objc func newNote(_ sender: Any?) {
        textView.string = ""
        textView.window?.makeFirstResponder(textView)
        onCreateNote?(contextURL)
    }

    @objc func saveNote(_ sender: Any?) {
        onSaveNote?(textView.string)
    }

    @objc func searchNotes(_ sender: Any?) {
        onSearch?(searchField.stringValue)
    }

    @objc func exportNotes(_ sender: Any?) {
        onExport?()
    }
}

// MARK: - NSToolbarDelegate

extension NotesWindow: NSToolbarDelegate {
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.init("new"), .init("save"), .init("export"), .init("search"), .space, .flexibleSpace]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.init("new"), .init("save"), .init("export"), .init("search"), .flexibleSpace]
    }

    func toolbar(_ toolbar: NSToolbar,
                 itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {

        switch itemIdentifier.rawValue {
        case "new":
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "新建"
            item.image = NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: nil)
            item.action = #selector(newNote(_:))
            item.target = self
            return item

        case "save":
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "保存"
            item.image = NSImage(systemSymbolName: "checkmark.circle", accessibilityDescription: nil)
            item.action = #selector(saveNote(_:))
            item.target = self
            return item

        case "search":
            searchField.placeholderString = "搜索笔记"
            searchField.target = self
            searchField.action = #selector(searchNotes(_:))
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "搜索"
            item.view = searchField
            return item

        case "export":
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "导出"
            item.image = NSImage(systemSymbolName: "square.and.arrow.up", accessibilityDescription: nil)
            item.action = #selector(exportNotes(_:))
            item.target = self
            item.toolTip = "导出全部笔记为 Markdown 文件"
            return item

        default:
            return nil
        }
    }
}

// MARK: - NSOutlineViewDataSource / Delegate

extension NotesWindow: NSOutlineViewDataSource, NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let node = item as? Node { return node.children.count }
        return treeData.count
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let node = item as? Node { return node.children[index] }
        return treeData[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        (item as? Node)?.children.isEmpty == false
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("cell")
        let label: NSTextField
        if let reused = outlineView.makeView(withIdentifier: id, owner: nil) as? NSTextField {
            label = reused
        } else {
            label = NSTextField(labelWithString: "")
            label.identifier = id
            label.font = .systemFont(ofSize: 13)
        }
        label.stringValue = (item as? Node)?.title ?? ""
        return label
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        let row = outlineView.selectedRow
        guard row >= 0, let node = outlineView.item(atRow: row) as? Node else { return }
        // 点击叶子节点时可在右侧展示对应笔记（此处示例为刷新文本）
        textView.string = node.title
    }
}

// MARK: - NSTextViewDelegate

extension NotesWindow: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        // 自动保存（防抖 800ms）
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(saveNote(_:)), object: nil)
        perform(#selector(saveNote(_:)), with: nil, afterDelay: 0.8)
    }
}

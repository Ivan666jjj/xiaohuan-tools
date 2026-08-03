import Cocoa
import PDFKit

/// PDFViewerWindow — 本地 PDF 阅读器（基于 PDFKit）
///
/// 特性：
/// - 内容视图为 PDFView
/// - 工具栏：上一页 / 下一页 / 缩放（+/-） / 搜索（findString 高亮跳转）
/// - 窗口关闭时释放 PDFDocument
final class PDFViewerWindow: NSWindow {

    // MARK: - 组件

    private let pdfView = PDFView()
    private var document: PDFDocument?

    private let prevBtn = NSButton()
    private let nextBtn = NSButton()
    private let zoomInBtn = NSButton()
    private let zoomOutBtn = NSButton()
    private let searchField = NSSearchField()
    private let pageLabel = NSTextField(labelWithString: "0 / 0")

    // MARK: - 初始化

    convenience init(pdfURL: URL) {
        self.init(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        title = pdfURL.lastPathComponent
        minSize = NSSize(width: 500, height: 400)
        isReleasedWhenClosed = false
        center()

        buildUI()
        openDocument(pdfURL)
    }

    // MARK: - UI 构建

    private func buildUI() {
        guard let content = contentView else { return }

        // 顶部工具栏条（自定义，避免 NSToolbar 在无边框场景的复杂度）
        let bar = NSVisualEffectView()
        bar.material = .titlebar
        bar.state = .active
        bar.blendingMode = .withinWindow
        bar.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(bar)

        // 上一页
        prevBtn.title = "◀"
        prevBtn.bezelStyle = .rounded
        prevBtn.target = self
        prevBtn.action = #selector(prevPage)
        prevBtn.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(prevBtn)

        // 下一页
        nextBtn.title = "▶"
        nextBtn.bezelStyle = .rounded
        nextBtn.target = self
        nextBtn.action = #selector(nextPage)
        nextBtn.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(nextBtn)

        // 页码
        pageLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        pageLabel.alignment = .center
        pageLabel.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(pageLabel)

        // 缩小
        zoomOutBtn.title = "−"
        zoomOutBtn.bezelStyle = .rounded
        zoomOutBtn.target = self
        zoomOutBtn.action = #selector(zoomOut)
        zoomOutBtn.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(zoomOutBtn)

        // 放大
        zoomInBtn.title = "+"
        zoomInBtn.bezelStyle = .rounded
        zoomInBtn.target = self
        zoomInBtn.action = #selector(zoomIn)
        zoomInBtn.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(zoomInBtn)

        // 搜索
        searchField.placeholderString = "在文档中搜索…"
        searchField.target = self
        searchField.action = #selector(performSearch)
        searchField.sendsSearchStringImmediately = false
        searchField.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(searchField)

        // PDFView
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.autoScales = true
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(pdfView)

        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: content.topAnchor),
            bar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            bar.heightAnchor.constraint(equalToConstant: 44),

            prevBtn.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            prevBtn.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 10),
            prevBtn.widthAnchor.constraint(equalToConstant: 32),

            nextBtn.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            nextBtn.leadingAnchor.constraint(equalTo: prevBtn.trailingAnchor, constant: 6),
            nextBtn.widthAnchor.constraint(equalToConstant: 32),

            pageLabel.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            pageLabel.leadingAnchor.constraint(equalTo: nextBtn.trailingAnchor, constant: 10),
            pageLabel.widthAnchor.constraint(equalToConstant: 70),

            zoomOutBtn.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            zoomOutBtn.leadingAnchor.constraint(equalTo: pageLabel.trailingAnchor, constant: 10),
            zoomOutBtn.widthAnchor.constraint(equalToConstant: 28),

            zoomInBtn.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            zoomInBtn.leadingAnchor.constraint(equalTo: zoomOutBtn.trailingAnchor, constant: 6),
            zoomInBtn.widthAnchor.constraint(equalToConstant: 28),

            searchField.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            searchField.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -12),
            searchField.widthAnchor.constraint(equalToConstant: 220),
            searchField.leadingAnchor.constraint(greaterThanOrEqualTo: zoomInBtn.trailingAnchor, constant: 16),

            pdfView.topAnchor.constraint(equalTo: bar.bottomAnchor),
            pdfView.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            pdfView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
        ])

        // 监听页面变化更新页码
        NotificationCenter.default.addObserver(
            self, selector: #selector(pageChanged),
            name: Notification.Name.PDFViewPageChanged,
            object: pdfView
        )
    }

    // MARK: - 文档操作

    private func openDocument(_ url: URL) {
        guard let doc = PDFDocument(url: url) else {
            let alert = NSAlert()
            alert.messageText = "无法打开 PDF"
            alert.informativeText = url.lastPathComponent
            alert.runModal()
            close()
            return
        }
        document = doc
        pdfView.document = doc
        updatePageLabel()
    }

    // MARK: - 工具栏动作

    @objc private func prevPage() {
        guard let page = pdfView.currentPage,
              let prev = pdfView.document?.page(at: page.pageRef?.pageNumber ?? 1 - 1) else { return }
        pdfView.go(to: prev)
    }

    @objc private func nextPage() {
        guard let page = pdfView.currentPage,
              let next = pdfView.document?.page(at: (page.pageRef?.pageNumber ?? 1) + 1) else { return }
        pdfView.go(to: next)
    }

    @objc private func zoomIn() {
        pdfView.scaleFactor *= 1.2
    }

    @objc private func zoomOut() {
        pdfView.scaleFactor /= 1.2
    }

    @objc private func pageChanged() {
        updatePageLabel()
    }

    private func updatePageLabel() {
        guard let doc = pdfView.document, let current = pdfView.currentPage else {
            pageLabel.stringValue = "0 / 0"
            return
        }
        let total = doc.pageCount
        let idx = doc.index(for: current) + 1
        pageLabel.stringValue = "\(idx) / \(total)"
    }

    // MARK: - 搜索

    @objc private func performSearch() {
        let keyword = searchField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !keyword.isEmpty, let doc = pdfView.document else { return }

        // 高亮全部匹配并跳转到第一个
        let selections = doc.findString(keyword, withOptions: .caseInsensitive)
        pdfView.highlightedSelections = selections

        if let first = selections.first {
            pdfView.go(to: first)
            pdfView.setCurrentSelection(first, animate: true)
        }
    }

    // MARK: - 释放

    override func close() {
        pdfView.highlightedSelections = nil
        pdfView.document = nil
        document = nil
        NotificationCenter.default.removeObserver(self)
        super.close()
    }
}

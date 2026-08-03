import Cocoa
import WebKit

/// AIAssistantPanel — 悬浮 AI 学术助手（独立 NSPanel）
///
/// 特性：
/// - 非激活状态可点击穿透（NSPanel + canBecomeKey 控制）
/// - 内嵌 WKWebView 加载本地 ai-chat.html
/// - 通过 evaluateJavaScript 发送用户输入
/// - 监听 JS 的 window.webkit.messageHandlers.aiAssistant.postMessage 接收 AI 回复
/// - 面板可拖拽，关闭时释放资源
final class AIAssistantPanel: NSPanel {

    // MARK: - JS Bridge 消息名

    static let messageName = "aiAssistant"

    // MARK: - 回调

    /// 用户发送消息回调（参数：消息文本），由外部（如 AppDelegate）接 AI 回复
    var onUserMessage: ((String) -> Void)?

    // MARK: - 组件

    private let webView = WKWebView()
    private let inputField = NSTextField()
    private var isShown = false

    // MARK: - 初始化

    convenience init() {
        let rect = NSRect(x: 0, y: 0, width: 360, height: 520)
        self.init(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        isOpaque = false
        backgroundColor = NSColor.clear
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        animationBehavior = .utilityWindow

        buildUI()
    }

    /// 点击穿透：仅在输入框聚焦时接收键盘
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // MARK: - UI

    private func buildUI() {
        guard let content = contentView else { return }

        // 圆角容器（视觉外壳）
        let shell = NSVisualEffectView()
        shell.material = .popover
        shell.state = .active
        shell.blendingMode = .behindWindow
        shell.wantsLayer = true
        shell.layer?.cornerRadius = 14
        shell.layer?.masksToBounds = true
        shell.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(shell)

        // 标题
        let titleLabel = NSTextField(labelWithString: "🤖 AI 学术助手")
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        shell.addSubview(titleLabel)

        // 关闭按钮
        let closeBtn = NSButton()
        closeBtn.title = "✕"
        closeBtn.bezelStyle = .inline
        closeBtn.isBordered = false
        closeBtn.font = .systemFont(ofSize: 12)
        closeBtn.target = self
        closeBtn.action = #selector(closePanel)
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        shell.addSubview(closeBtn)

        // WebView（聊天区）
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        shell.addSubview(webView)

        // 输入区
        inputField.placeholderString = "询问古文释义、生僻字、论文推荐…"
        inputField.font = .systemFont(ofSize: 12)
        inputField.bezelStyle = .roundedBezel
        inputField.target = self
        inputField.action = #selector(sendMessage)
        inputField.translatesAutoresizingMaskIntoConstraints = false
        shell.addSubview(inputField)

        NSLayoutConstraint.activate([
            shell.topAnchor.constraint(equalTo: content.topAnchor, constant: 8),
            shell.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -8),
            shell.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 8),
            shell.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -8),

            titleLabel.topAnchor.constraint(equalTo: shell.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: shell.leadingAnchor, constant: 14),

            closeBtn.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            closeBtn.trailingAnchor.constraint(equalTo: shell.trailingAnchor, constant: -10),
            closeBtn.widthAnchor.constraint(equalToConstant: 24),

            webView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            webView.leadingAnchor.constraint(equalTo: shell.leadingAnchor, constant: 10),
            webView.trailingAnchor.constraint(equalTo: shell.trailingAnchor, constant: -10),
            webView.bottomAnchor.constraint(equalTo: inputField.topAnchor, constant: -10),

            inputField.leadingAnchor.constraint(equalTo: shell.leadingAnchor, constant: 10),
            inputField.trailingAnchor.constraint(equalTo: shell.trailingAnchor, constant: -10),
            inputField.bottomAnchor.constraint(equalTo: shell.bottomAnchor, constant: -12),
            inputField.heightAnchor.constraint(equalToConstant: 30),
        ])

        setupScriptMessageHandler()
    }

    // MARK: - JS Bridge

    private func setupScriptMessageHandler() {
        let config = WKWebViewConfiguration()
        let userContent = WKUserContentController()
        userContent.add(self, name: Self.messageName)
        config.userContentController = userContent

        // 重新配置 webView（需在首次加载前）
        webView.configuration.userContentController.removeAllUserScripts()
        // 注：WKUserContentController 在初始化后不可替换，这里使用默认配置
        // 如需完全自定义，应在 init 中先构建 configuration
    }

    /// 加载本地 ai-chat.html
    func loadChatPage() {
        if let path = Bundle.main.path(forResource: "ai-chat", ofType: "html") {
            let url = URL(fileURLWithPath: path)
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            // 兜底：加载内嵌的极简聊天页
            let html = """
            <!DOCTYPE html><html><head><meta charset="utf-8">
            <style>body{font-family:-apple-system;padding:12px} .msg{margin:8px 0;padding:8px 12px;border-radius:8px}
            .user{background:#4a90d9;color:#fff;margin-left:30px}.ai{background:#eee;margin-right:30px}
            #box{height:340px;overflow-y:auto}</style></head><body>
            <div id="box"><div class="msg ai">你好，我是 AI 学术助手。选中网页文字或在下方提问。</div></div>
            <script>
            function addMsg(t, who){var d=document.createElement('div');d.className='msg '+who;d.textContent=t;
            document.getElementById('box').appendChild(d);document.getElementById('box').scrollTop=1e9}
            window.webkit.messageHandlers.\(Self.messageName).postMessage({type:'ready'});
            </script></body></html>
            """
            webView.loadHTMLString(html, baseURL: nil)
        }
    }

    /// 发送用户输入到 AI（供外部调用，如 Ollama 回复后）
    func sendUserMessage(_ text: String) {
        let escaped = text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        webView.evaluateJavaScript("addMsg('\(escaped)','user')", completionHandler: nil)
    }

    /// 接收 AI 回复并在面板显示
    func showAIResponse(_ text: String) {
        let escaped = text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        webView.evaluateJavaScript("addMsg('\(escaped)','ai')", completionHandler: nil)
    }

    // MARK: - 动作

    @objc private func sendMessage() {
        let text = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        sendUserMessage(text)
        inputField.stringValue = ""
        onUserMessage?(text)
    }

    @objc private func closePanel() {
        close()
        cleanup()
    }

    override func close() {
        super.close()
        cleanup()
    }

    /// 释放 WebView 资源，防止内存泄漏
    private func cleanup() {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: Self.messageName)
        webView.stopLoading()
        webView.loadHTMLString("", baseURL: nil)
        webView.navigationDelegate = nil
    }

    // MARK: - 展示

    /// 展示在屏幕中央偏下位置
    func present() {
        if let screen = NSScreen.main {
            let f = screen.visibleFrame
            setFrameOrigin(NSPoint(x: f.maxX - frame.width - 24,
                                   y: f.minY + 80))
        }
        makeKeyAndOrderFront(nil)
        isShown = true
        loadChatPage()
    }
}

// MARK: - WKScriptMessageHandler

extension AIAssistantPanel: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard message.name == Self.messageName else { return }
        if let dict = message.body as? [String: Any], let type = dict["type"] as? String {
            switch type {
            case "ready":
                // 页面就绪，可做初始化
                break
            default:
                break
            }
        }
        // 若 JS 直接回传文本（如选中的文字），转发给外部
        if let text = message.body as? String, !text.isEmpty {
            onUserMessage?(text)
        }
    }
}

// MARK: - WKNavigationDelegate

extension AIAssistantPanel: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        // 本地文件加载失败时静默，不弹窗
        print("[AIAssistant] 页面加载失败: \(error.localizedDescription)")
    }
}

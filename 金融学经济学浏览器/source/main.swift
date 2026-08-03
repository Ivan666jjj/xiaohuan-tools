import Cocoa

// ============================================================
// main.swift — 金融学经济学浏览器入口
// 复用文史哲浏览器架构：contentView = webView 直绘，不嵌套容器
// ============================================================

let app = NSApplication.shared
app.setActivationPolicy(.regular)

let delegate = AppDelegate()
app.delegate = delegate

app.activate(ignoringOtherApps: true)
app.run()

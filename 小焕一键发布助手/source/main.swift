import Cocoa

// ============================================================
// main.swift — 小焕一键发布助手 入口
// ============================================================

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.activate(ignoringOtherApps: true)
app.run()

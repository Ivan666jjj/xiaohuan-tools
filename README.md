<p align="center">
  <h1 align="center">🔧 小焕工具箱 Xiaohuan Tools</h1>
  <p align="center">
    macOS / Windows / Android 三端 · 数字人文向 AI 工具集
    <br>
    <img src="https://img.shields.io/badge/平台-macOS%20%7C%20Windows%20%7C%20Android-blue" alt="Platform">
    <img src="https://img.shields.io/badge/技术-Electron%20%7C%20Swift%20%7C%20Capacitor-green" alt="Tech">
    <img src="https://img.shields.io/badge/许可证-MIT-orange" alt="License">
    <img src="https://img.shields.io/badge/CI-GitHub%20Actions-brightgreen" alt="CI">
  </p>
</p>

---

## 🎯 项目定位

面向**数字人文与专业学习场景**的 AI 工具集——文科生自己造的生产力工具：

- **20+ 汉语言 AI 技能**：说文解字、诗词格律、古籍句读、声韵学、训诂、经学引证
- **专业学习浏览器**：为文史哲 / 金融经济学生定制（Swift 原生）
- **跨平台**：同一套代码打包 Mac `.dmg` + Windows `.exe` + Android `.apk`（CI 自动构建）

---

## 📦 包含模块

### 1. 🖥 小焕工具箱（主应用）

| 能力 | 说明 |
|---|---|
| 🌤 天气预测 | 双 API 竞速（wttr.in + Open-Meteo GFS）+ 北京地区校准 |
| 🔥 火烧云预测 | 日落前 30 分钟云量变化率评分 + 云走向判定 |
| 📜 说文解字 | 540 部首查询 + 42 常用字补充数据 |
| 📐 诗词格律 | 平仄检测 + 押韵对仗（王力《诗词格律》体系）|
| 🗣 音韵学 | 中古/上古音查询（歌部/支部等韵部）|
| 🍳 生活助手 | 菜谱推荐 + 食材匹配 |
| 💬 AI 对话 | DeepSeek API（超时重试 + 余额分级显示）|

**UI**：macOS 原生暗色 + 毛玻璃效果，流式打字机输出，⌘K 快捷面板。

### 2. 📚 文史哲浏览器（Swift + WKWebView）

面向古文字学/汉语言/历史/考古专业的原生浏览器：

- 汝窑天青书房风 UI、16 学术磁贴
- 文献笔记系统（SQLite）、AI 助手面板
- PDF 阅读器、汉典弹窗广告拦截

### 3. 📊 金融学经济学浏览器

- 交易大厅深色风、行情滚动条
- 金融术语翻译、数量级/汇率换算、复利计算器

### 4. 🔗 其他工具

- **一键发布助手**（Swift）：GitHub Release 自动化
- **小焕归类器**（Python）：桌面文件智能归类
- **转换工具**（Python）：繁简/竖排/格式转换

---

## 🛠 技术栈

| 层 | 技术 |
|---|---|
| 前端 | HTML + CSS + JavaScript |
| 桌面 | Electron 33（工具箱）、Swift + AppKit + WKWebView（浏览器）|
| 移动 | Capacitor（Android）|
| API | DeepSeek / Open-Meteo / wttr.in / 汉典 |
| 数据 | UserDefaults + SQLite |
| CI | GitHub Actions（三端自动构建）|

---

## 🚀 快速开始

### 下载安装包

| 平台 | 安装包 |
|---|---|
| macOS | `小焕工具箱-1.0.1-arm64.dmg` |
| Windows | `小焕工具箱 Setup 1.0.0.exe` |
| Android | `小焕工具箱-1.0.0.apk` |

### 从源码构建（工具箱）

```bash
# macOS / Windows
npm install
npm run build
# Android（Capacitor）
npx cap sync && npx cap open android
```

### 从源码构建（浏览器，macOS）

```bash
cd 文史哲浏览器/source
swiftc -framework Cocoa -framework WebKit -O main.swift AppDelegate.swift ClassicsData.swift
```

---

## 🎨 截图

> （替换为实际截图：主界面 / 浏览器 / 移动端）

```
[主界面截图]  [文史哲浏览器截图]  [移动端截图]
```

---

## 📄 文档

- [开发规格书](小焕工具箱/小焕工具箱-开发规格书.md)
- [使用说明（浏览器）](文史哲浏览器/使用说明.md)
- [API 余额功能](小焕工具箱/API余额查询功能.md)

---

## 📜 License

MIT License. Copyright © 2026 严小焕

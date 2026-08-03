# 📚 文史哲浏览器（小焕的学习浏览器）

> 为古文字学、汉语言文学、历史学、考古学专业学生打造的 macOS 学习浏览器
> Swift + AppKit + WKWebView ｜ macOS 12.0+

---

## ✨ 简介

一款**专门为文史哲专业学生设计**的浏览器。打开即用，内置大量学术网站入口，把「查字典 → 读古籍 → 记笔记 → 写论文」的研究链路整合在一起。

由**中国人民大学强基计划古文字学专业学生**严小焕开发。

## 🏺 设计理念：汝窑天青 · 书房风

- 米青灰背景 + 墨色文字，护眼且适合长时间阅读
- 楷体名言卡 + 宋体书名竖排，书卷气满满
- 自动跟随 macOS 深浅色模式

## 🧩 功能总览

| 模块 | 说明 |
|------|------|
| 🎯 智能磁贴 | 16 个学术网站（汉典/国学大师/小学堂/CText/知网/人大等），按专业方向切换 |
| 🔍 智能搜索 | 股票代码识别、6 引擎切换、⌘K 快捷聚焦 |
| 📝 文献笔记 | 独立窗口 + SQLite 存储 + 自定义存储位置 + Markdown 导出 |
| 🤖 AI 学术助手 | 古文翻译、生僻字解释（本地 Ollama） |
| 📄 PDF 阅读器 | 翻页 / 缩放 / 全文搜索高亮 |
| 🌐 整页翻译 | Google 翻译代理，中英双向 |
| 🖱 右键工具 | 学术搜索 / 翻译 / 繁简转换 / 收藏生词 / 生成引用 / 字数统计 |
| 📚 经典文本库 | 21 部经史子集 → CText 在线原文 |
| 🛡️ 广告拦截 | 通用规则 + 汉典网弹窗专项清理（不误伤生僻字） |

## 🖱 选中文字右键（学术利器）

```
🔍 在汉典 / 国学大师 / 小学堂 / CText / 互动百科 中搜索
🌐 翻译选中文字          🔄 繁简转换
⭐ 收藏生词               📝 保存为笔记
📖 生成引用格式（APA/GB7714）  🔢 统计本页字数
```

## ⌨️ 快捷键

| 键 | 功能 | 键 | 功能 |
|---|---|---|---|
| ⌘T | 新建标签 | ⌘W | 关闭标签 |
| ⌘L | 聚焦地址栏 | ⌘K | 聚焦搜索框 |
| ⌘[ ⌘] | 后退/前进 | ⌘R | 刷新 |
| ⌘N | 添加书签 | ⌘D | 打开便签 |

## 🔨 构建

```bash
cd 文史哲浏览器/source
swiftc -target arm64-apple-macosx13.0 -sdk $(xcrun --show-sdk-path) \
  -framework Cocoa -framework WebKit -framework PDFKit -lsqlite3 -O \
  -o "小焕的学习浏览器.app/Contents/MacOS/小焕的学习浏览器" \
  main.swift AppDelegate.swift ClassicsData.swift DataManager.swift \
  NotesWindow.swift AIAssistantPanel.swift PDFViewerWindow.swift
```

> 完整使用说明见 [`使用说明.md`](使用说明.md)

## 📄 协议

MIT License

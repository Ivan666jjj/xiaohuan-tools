# 🚀 小焕一键发布助手

> macOS 原生桌面应用 · 一键把应用 / Skill 发布到 GitHub
> Swift + AppKit ｜ macOS 12.0+

---

## ✨ 简介

把「选择文件 → 填版本号 → git 提交 → 推送 → 建 Release」这条繁琐链路，压缩成**一次拖拽 + 一次点击**。面向不熟悉命令行的文科生，也适合需要频繁发布的开发者。

由 **严小焕**（中国人民大学强基计划古文字学专业）开发。

## 🧩 功能

| 功能 | 说明 |
|------|------|
| 📦 拖拽发布 | 拖入 DMG / 源码 / Skill，自动识别类型归类到 `安装包/` |
| 🏷 版本自动提取 | 从文件名正则识别 `v1.2.3` 等版本号 |
| 🚀 一键发布 | 自动 `git add → commit → pull --rebase → push` |
| 🔐 Token 安全存储 | GitHub Token 存 **macOS Keychain**，不落盘不写日志 |
| 🎯 发布类型 | Feature / Fix / Release 三种语义 |
| 📜 发布历史 | 本地记录最近 50 次发布 |
| 🔁 冲突处理 | push 前自动 `pull --rebase --autostash` |

## 🖥 使用

1. 打开应用 → **⚙️ 设置** → 粘贴 GitHub Token → 验证（存 Keychain）
2. 把要发布的文件（DMG 安装包 / 源码文件夹）拖入窗口
3. 确认版本号（自动提取）→ 填更新说明 → **🚀 发布**
4. 完成弹通知，日志区实时滚动

## 🔨 构建

```bash
cd 小焕一键发布助手/source
swiftc -target arm64-apple-macosx13.0 -sdk $(xcrun --show-sdk-path) \
  -framework Cocoa -framework Security -O \
  -o "小焕一键发布助手.app/Contents/MacOS/小焕一键发布助手" \
  main.swift AppDelegate.swift GitHubKit.swift
```

## 👤 关于

**严小焕** · 中国人民大学强基计划 古文字学专业 ｜ 📧 1416578309@qq.com

## 📄 协议

MIT

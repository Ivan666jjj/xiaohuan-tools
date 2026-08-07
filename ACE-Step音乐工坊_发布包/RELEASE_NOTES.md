# ACE-Step 音乐工坊 v1.0.1

🎵 本地 AI 音乐生成工具 —— 100% 免费、本地运行、无限生成

## ✨ 更新内容 (v1.0.1)

- 🌏 **界面中文化**：默认中文界面（可在设置中切换英/日/韩）
- 🎨 全新 App 图标（音乐主题）
- 📦 一键安装器优化（自动中文化 + 多源下载）

## ✨ 功能

- 🎤 **中文人声歌曲**：4 分钟完整歌曲，支持中文歌词（`[verse]` `[chorus]` 结构标签）
- 🏮 **古风纯音乐**：古筝、笛子、琵琶等 1000+ 乐器风格
- 🎨 **Spotify 风格界面**：专业 UI，歌词编辑器、音轨库、播放列表
- ⚡ **本地运行**：MPS 加速（Apple Silicon），无需联网
- 📊 **实时进度**：生成进度条 + 队列位置

## 📥 安装

```bash
chmod +x install.sh && ./install.sh
```

自动完成：
1. 下载 ACE-Step 引擎（508MB）
2. 下载专业 UI（20MB）+ 自动中文化
3. 修复系统签名 + 安装依赖
4. 首次生成时自动下载模型（9.4GB）

## 🖥 系统要求

- macOS 13+（Apple Silicon M1/M2/M3/M4）
- 内存 16GB（推荐）
- 磁盘：引擎 1.6GB + 模型 9.4GB

## 📝 使用

1. 双击「ACE-Step音乐工坊」
2. 填 Caption（风格）+ Lyrics（中文歌词带结构标签）
3. 设时长（最大 8 分钟）→ 生成 → 试听/下载

## 🧩 文件清单

| 文件 | 说明 |
|---|---|
| `ACE-Step音乐工坊_Installer.dmg` | 拖拽安装包 |
| `install.sh` | 一键安装脚本 |
| `README.md` | 项目说明 |
| `AppIcon.icns` | 应用图标 |
| `zh_patch.diff` | 中文化补丁 |

## 🙏 致谢

- [ACE-Step](https://github.com/ace-step/ACE-Step-1.5) - AI 音乐生成模型
- [ace-step-ui](https://github.com/fspecii/ace-step-ui) - 专业界面

## 📄 License

MIT

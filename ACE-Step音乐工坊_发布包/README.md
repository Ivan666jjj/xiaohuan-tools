# 🎵 ACE-Step 音乐工坊

> 本地 AI 音乐生成工具 —— 100% 免费、本地运行、无限生成
> 基于 [ACE-Step 1.5](https://github.com/ace-step/ACE-Step-1.5) + [ace-step-ui](https://github.com/fspecii/ace-step-ui)

![AppIcon](AppIcon.icns)

## ✨ 功能

- 🎤 **中文人声歌曲**：4 分钟完整歌曲，支持中文歌词（`[verse]` `[chorus]` 结构标签）
- 🏮 **古风纯音乐**：古筝、笛子、琵琶等 1000+ 乐器风格，prompt 自由控制
- 🎨 **Spotify 风格界面**：专业 UI，歌词编辑器、音轨库、播放列表
- ⚡ **本地运行**：MPS 加速（Apple Silicon），无需联网、无限生成
- 📊 **实时进度**：生成进度条 + 队列位置

## 🖥 系统要求

- macOS 13+（Apple Silicon M1/M2/M3/M4）
- 内存 16GB（推荐）
- 磁盘空间：引擎 1.6GB + 模型 9.4GB（首次自动下载）

## 📥 安装

### 方法一：一键安装（推荐）

```bash
chmod +x install.sh && ./install.sh
```

自动完成：
1. 下载 ACE-Step 引擎（508MB）
2. 下载专业 UI（20MB）
3. 修复系统签名 + 安装依赖
4. 生成配置文件

### 方法二：手动

1. 双击 `ACE-Step音乐工坊.app`
2. 首次运行会自动启动所有服务

## 🚀 使用

1. 双击桌面「ACE-Step音乐工坊」
2. 填写：
   - **Caption**：风格描述（如"中国古筝，女声，古风，深情"）
   - **Lyrics**：中文歌词（带 `[verse]` `[chorus]` 标签）
   - **时长**：最大 8 分钟
3. 点击生成 → 等待 → 试听/下载

## ⚙️ 技术细节

| 组件 | 说明 |
|---|---|
| ACE-Step 1.5 | AI 音乐引擎（turbo DiT 4.5GB + 5Hz LM 3.5GB）|
| ace-step-ui | React + Vite 前端 + Node 后端 |
| MLX | Apple Silicon 原生加速 |

### 端口

| 服务 | 端口 |
|---|---|
| ACE-Step API | 8001 |
| UI 前端 | 3000 |
| UI 后端 | 3001 |

## 📝 歌词结构标签

```
[verse]  主歌（叙事）
[chorus] 副歌（高潮，重复）
[bridge] 桥段（转折）
[outro]  尾声
[instrumental] 纯器乐
```

## 🙏 致谢

- [ACE-Step](https://github.com/ace-step/ACE-Step-1.5) - AI 音乐生成模型
- [ace-step-ui](https://github.com/fspecii/ace-step-ui) - 专业界面
- 图标与封装：小焕

## 📄 License

MIT

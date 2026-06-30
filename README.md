<p align="center">
  <h1 align="center">🔧 小焕的工具</h1>
  <p align="center">
    macOS 实用小工具 · 图形界面 · 双击即用
    <br>
    支持 Apple Silicon (M 系列) 和 Intel Mac
  </p>
  <p align="center">
    <img src="https://img.shields.io/badge/平台-macOS-blue" alt="Platform">
    <img src="https://img.shields.io/badge/Python-3.8%2B-green" alt="Python">
    <img src="https://img.shields.io/badge/许可证-MIT-orange" alt="License">
  </p>
</p>

---

## 📦 包含工具

| 工具 | 功能 | 适用场景 |
|------|------|---------|
| **小焕归类器** | 选择文件夹 → 自动按内容分类整理 | 资料太多、桌面太乱、想归类文件 |
| **小焕的转换工具** | PDF 合并/拆分/提取/转图片、图片转 PDF、DOCX 转 PDF | 日常文档处理 |

---

## 🪜 安装步骤

### 第一步：安装 Python

打开终端，输入：

```bash
python3 --version
```

如果提示"找不到命令"，去 https://python.org 下载安装。

### 第二步：安装依赖

```bash
pip3 install -r requirements.txt
```

### 第三步：开始使用

找到对应工具的文件夹，**双击 `.command` 文件**即可运行。

或者用终端运行：

```bash
# 归类器
python3 归类器/classifier.py

# 转换工具
python3 转换工具/converter.py
```

---

## 📂 小焕归类器

智能识别文件名，自动归类到对应的文件夹：

| 分类 | 识别关键词 |
|------|-----------|
| 音韵学与文字学 | 音韵、说文、广韵、古音、声母、韵母等 |
| 古代汉语 | 古代汉语、文言、语法通论等 |
| 现代汉语 | 现代汉语、普通话、修辞、模拟题等 |
| 先秦文学 | 诗经、楚辞、论语、孟子、左传等 |
| 法学 | 民法、刑法、宪法、合同、侵权等 |
| 英语 | english、单词、ielts、cet 等 |
| 图片素材 | .png .jpg .gif .webp .bmp 等 |
| 读书报告与论文 | 读书报告、论文、文献综述等 |
| 更多… | 办公软件、影视、旅游、工具书等 |

**使用方法：** 双击运行 → 点击"选择文件夹" → 点击"开始归类"

---

## 🔧 小焕的转换工具

| 功能 | 说明 |
|------|------|
| 合并 PDF | 多个 PDF 合并为一个 |
| 拆分 PDF | 每页拆成一个单独的 PDF 文件 |
| 提取页面 | 指定页码范围，提取为新的 PDF |
| 图片转 PDF | 多张图片合并为一份 PDF |
| PDF 转文字 | 提取 PDF 中的文字内容（保存为 .txt）|
| DOCX 转 PDF | Word 文档转为 PDF（macOS 可用） |

**使用方法：** 双击运行 → 选择功能 → 选择文件 → 自动完成

---

## ⚙️ 技术要求

- macOS 系统（同时支持 Apple Silicon 和 Intel）
- Python 3.8 或更高版本
- 安装依赖：`pip3 install -r requirements.txt`

---

## 📄 许可证

MIT © 2026 严小焕 · 中国人民大学文学院强基古文字方向

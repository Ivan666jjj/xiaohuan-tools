<p align="center">
  <h1 align="center">🔧 小焕的工具 · Xiaohuan Tools</h1>
  <p align="center">
    实用小工具集合 — 天气校准 / 文件归类 / PDF 处理
    <br>
    全部免费开源 · 中国人民大学文学院强基古文字方向出品
  </p>
  <p align="center">
    <img src="https://img.shields.io/badge/平台-macOS%20%7C%20Windows%20%7C%20Linux-blue" alt="Platform">
    <img src="https://img.shields.io/badge/Python-3.8%2B-green" alt="Python">
    <img src="https://img.shields.io/badge/许可证-MIT-orange" alt="License">
    <img src="https://img.shields.io/badge/古籍爱好者-适用-brightgreen" alt="Guji">
  </p>
</p>

---

## 📦 包含工具
### 🎵 Mineradio-MacOS M芯片优化
专为 Apple Silicon (M1/M2/M3/M4) 优化，GPU 硬件加速 + 渲染优化，让 Mineradio 在 Mac 上流畅运行。
```
cd Mineradio-M芯片优化 && bash optimize-mineradio-m4.sh
```
原项目：[XxHuberrr/Mineradio](https://github.com/XxHuberrr/Mineradio)（GPL-3.0）


| 工具 | 功能 | 适合谁 | 平台 |
|------|------|--------|:----:|
| 🌤 **智能天气** | 多模型交叉验证天气预报，自动修正云量和降雨概率偏差 | 所有人，比手机天气更准 | macOS / Windows / Linux |
| 🏯 **北京天气校准版** | 专为北京海淀优化，内置 GFS 偏差校准系数 | 北京居民/海淀学生/圆明园周边 | macOS / Windows / Linux |
| 📂 **小焕归类器** | 选择文件夹 → 按文件名关键词自动分类整理 | 资料太多的学生/办公族 | macOS / Windows |
| 🔧 **小焕的转换工具** | PDF 合并/拆分/提取/转图片、图片转 PDF、DOCX 转 PDF | 需处理 PDF 的任何人 | macOS |

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
# 智能天气（全国通用）
python3 智能天气/smart_weather.py

# 北京天气（海淀校准版）
python3 智能天气/beijing_weather.py

# 归类器
python3 归类器/classifier.py

# 转换工具
python3 转换工具/converter.py
```

---

## 📂 小焕归类器 — 每个大学生都能用

智能识别文件名，把散乱的文件自动归类到对应文件夹。无论你是文科还是理科，都能找到对应的分类。

**使用方法：** 双击运行 → 点击"选择文件夹" → 选一个东西比较多的文件夹 → 点击"开始归类"

> 💡 **建议选什么文件夹？**
> - 你的"下载"文件夹（通常最乱）
> - 你的"桌面"（建议先把桌面文件移到一个新文件夹里再归类）
> - 一学期的"课程资料"文件夹
> - 写论文时的"参考资料"文件夹

> 💡 **Windows 用户请看这里：**
> 1. 进入 `归类器_Windows` 文件夹，双击 **小焕归类器.bat** 或 **小焕归类器.pyw**
> 2. 或者 **下载打包好的 .exe**（无需安装 Python）：
>    打开 https://github.com/Ivan666jjj/xiaohuan-tools/actions
>    点最新的 **打包 Windows exe** → 点 **小焕归类器_Windows** 下载 .exe 文件

### 分类说明（文理科通用）

| 分类 | 识别关键词（举例） | 适合 |
|:----|-------------------|:----:|
| 📚 课程学习 | 课件、讲义、课程、笔记、复习、重点 | 所有专业 |
| 📝 论文作业 | 论文、作业、报告、课题、实验、答辩 | 所有专业 |
| 🌍 英语学习 | english、单词、雅思、托福、cet、考研英语 | 所有专业 |
| 📖 人文社科 | 文学、历史、哲学、社会、心理、新闻、政治 | 文科同学 |
| ⚖️ 法学 | 民法、刑法、合同、法律、法治 | 法学方向 |
| 🔬 理工编程 | 数学、物理、代码、python、数据、算法 | 理工科同学 |
| 💼 求职办公 | 简历、面试、实习、excel、ppt | 所有专业 |
| 🖼️ 图片素材 | .png .jpg .gif .webp（按文件后缀） | 所有专业 |
| 🎬 影视娱乐 | 电影、剧集、综艺、纪录片、动漫 | 所有人 |
| 🏫 升学考研 | 考研、保研、复试、分数线 | 考研党 |
| ✈️ 旅游生活 | 旅游、攻略、酒店、机票、行程 | 所有人 |
| 📓 读书写作 | 读书笔记、读后感、书评、札记 | 所有专业 |

> 🔧 **分类不满足你的需求？可以自己修改**  
> 打开 `归类器/classifier.py`，找到 `RULES = [` 那一行，按这个格式加你自己的规则：
> ```python
> # 如果你想加一个"日语学习"分类：
> (['日语','五十音','日本語','jlpt','n1','n2','仮名','日文'], '日语学习'),
> ```
> 每个规则是一个 `(关键词列表， 文件夹名)` 对，文件名里包含任何一个关键词就会被自动归类到对应文件夹。
>
> **如果你想改已有分类的关键词：** 直接在列表里加就行，比如让"法学"也能识别"刑法总论"：
> ```python
> (['民法','刑法','刑法总论','诉讼法','宪法' ...
> ```
> 改完后保存，重新双击运行就能生效。

---

## 🔧 小焕的转换工具

| 功能 | 说明 |
|------|------|
| 合并 PDF | 多个 PDF 合并为一个 |
| 拆分 PDF | 每页拆成一个单独的 PDF 文件 |
| 提取页面 | 指定页码范围，提取为新的 PDF |
| 图片转 PDF | 多张图片合并为一份 PDF |
| PDF 转文字 | 提取 PDF 中的文字内容（保存为 .txt）|
| DOCX 转 PDF | Word 文档转为 PDF（全平台，macOS 效果最好） |

**使用方法：** 双击运行 → 选择功能 → 选择文件 → 自动完成

---

## ❓ 常见问题

<details>
<summary><b>Q: 双击 .command 文件弹出黄色三角形警告窗口，但功能正常？</b></summary>
这是因为 macOS 的安全机制阻止了从网络下载的脚本直接运行。解决方法是移除文件的"隔离标记"：

打开终端，输入以下命令（注意替换成你实际的文件路径）：
```bash
xattr -l /Applications/小焕归类器.command

xattr -d com.apple.quarantine /Applications/小焕归类器.command

chmod +x /Applications/小焕归类器.command
```
如果不知道文件在哪里，可以把 .command 文件直接拖到终端窗口里，它会自动填入路径。
</details>

<details>
<summary><b>Q: 双击 .command 文件没反应怎么办？</b></summary>
第一次运行时，macOS 可能会阻止未识别的开发者应用。解决方法：
1. 右键（或双指点击）.command 文件 → 选择"打开"
2. 会弹出一个对话框，点击"打开"即可
3. 如果还是没反应，打开终端输入：
   ```bash
   cd 对应工具的文件夹
   python3 classifier.py

   python3 converter.py
   ```
</details>

<details>
<summary><b>Q: 提示 "Python 找不到" 怎么办？</b></summary>
说明你没装 Python。去 https://python.org 下载安装，安装时务必勾选 "Add Python to PATH"。
</details>

<details>
<summary><b>Q: 安装依赖时出错怎么办？</b></summary>
打开终端，分别执行以下命令：
```bash
pip3 install --upgrade pip
pip3 install PyMuPDF Pillow
pip3 install python-docx fpdf2
```
如果有红字报错，可以截图发 Issue 或者搜索错误信息。
</details>

<details>
<summary><b>Q: 归类器把文件归错了怎么办？</b></summary>
关键词匹配做不到 100% 准确，分错是正常的。去对应的文件夹里，把文件手动拖到正确的文件夹就行。归类日志（归类日志.txt）会记录每个文件被移去了哪里。
</details>

<details>
<summary><b>Q: 归类器会把系统文件弄乱吗？</b></summary>
不会。归类器只会移动普通的文件（文档、图片、PDF 等），不会移动 .app、系统文件或隐藏文件。但建议不要直接对"桌面"整个文件夹归类，可以先把桌面文件移到一个新文件夹再归类。
</details>

<details>
<summary><b>Q: 两个不同文件同名怎么办？</b></summary>
归类器会自动处理：如果有同名文件，第二个会自动加上编号（如 笔记_1.docx、笔记_2.docx），不会覆盖原有文件。
</details>

<details>
<summary><b>Q: PDF 转文字转出来是空的怎么办？</b></summary>
说明这个 PDF 是扫描版（图片型），不是文字型。软件会自动检测到并询问你是否要用 OCR 识别。点"是"后会引导你安装 OCR 引擎，安装完成后再次点击"PDF 转文字"即可正常识别。
</details>

<details>
<summary><b>Q: DOCX 转 PDF 按钮点了然后呢？</b></summary>
软件会自动尝试多种方法转换：
- macOS：用系统自带的 textutil 转换（最快、排版最好）
- 如果装了 LibreOffice：用 LibreOffice 转换
- 以上都不行的话：用 Python 转成文字版 PDF（不带排版，但文字都在）
</details>

<details>
<summary><b>Q: 软件支持 Windows 或 Linux 吗？</b></summary>
<b>归类器有 Windows 版</b>：进入 `归类器_Windows` 文件夹，双击 `.bat` 或 `.pyw` 文件即可运行。<br><br>
转换工具目前主要支持 macOS，Windows 用户可以在终端执行：
```bash
python 转换工具\converter.py
```
PDF 合并、拆分、提取、图片转 PDF 等功能都能用，DOCX 转 PDF 会降级为文字版。
</details>

<details>
<summary><b>Q: 为什么打开软件后按钮是灰色的？</b></summary>
归类器需要先选择一个文件夹，按钮才会亮起。点击"选择文件夹"按钮选一个文件夹就行。
</details>

---

## ⚙️ 技术要求

- macOS 系统（同时支持 Apple Silicon 和 Intel）
- Python 3.8 或更高版本
- 安装依赖：`pip3 install -r requirements.txt`

---

## 📄 许可证

MIT © 2026 严小焕 · 中国人民大学文学院强基古文字方向

如有问题或建议，欢迎联系：**1416578309@qq.com**


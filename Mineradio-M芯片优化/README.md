# 🚀 Mineradio-MacOS M4 性能优化

> 专为 Apple Silicon (M1/M2/M3/M4) 全系列设计的 Mineradio 一键优化工具
自动检测芯片型号，匹配专属优化参数
> 原项目：[XxHuberrr/Mineradio](https://github.com/XxHuberrr/Mineradio)（GPL-3.0）
> Mac 移植：[YiIimini/Mineradio-MacOS](https://github.com/YiIimini/Mineradio-MacOS)

## 优化作者
**严小焕** · 中国人民大学 汉语言文学 · 数字人文方向
📧 1416578309@qq.com

**贡献内容：**
- 🔧 M4 芯片深度优化：GPU 硬件加速、渲染优化、内存管理，共 16 项 Chromium 参数
- 🎵 汽水音乐 API 集成（个人版）：登录 + 歌单导入 + 搜索 + 歌词（不公开分发）
- 📦 一键打包脚本：自动解包、注入、打包、清理，全自动化
- 🧹 缓存清理 + 维护脚本：延长使用体验

## 优化说明
本优化工具分为两个版本：

**公开版（本仓库）：** 包含 M1/M2/M3/M4 全系列性能优化脚本。下载后运行即可对本地安装的 Mineradio 进行 GPU 加速。

**个人完整版（未公开）：** 含汽水音乐 API 集成，仅供个人学习使用，不上传至 GitHub。

> 之所以不公开汽水音乐集成，是因为《反不正当竞争法》第 12 条及《计算机软件保护条例》第 24 条涉及技术措施规避风险。个人学习使用无碍，公开分发则存在法律风险。详见 `法律合规说明.md`。

## 优化效果
| 项目 | 优化前 | 优化后 |
|---|---|---|
| GPU 渲染 | 软件渲染（卡顿） | Vulkan + Skia 硬件加速 ✅ |
| 2D Canvas | 无加速 | 硬件加速 ✅ |
| 多线程光栅化 | 单线程 | 4 线程 ✅ |
| JIT | 内存占用高 | JITless 模式降低内存 ✅ |
| 零拷贝渲染 | 关闭 | 开启 ✅ |
| 后台限制 | 页面可能卡顿 | 关闭后台限制 ✅ |

## 使用方法

```bash
chmod +x optimize-mineradio-m4.sh
bash optimize-mineradio-m4.sh
```

输入管理员密码后自动完成全部优化。重新打开 Mineradio 即可体验。

## 版权说明
- 本优化仅修改 Info.plist 配置参数，不修改核心代码
- 原项目使用 GPL-3.0 协议，本优化以相同协议发布
- 已保留原作者版权声明
- 如原项目作者有异议，请联系删除

## 恢复方法
```bash
sudo cp "/Applications/Mineradio-MacOS.app/Contents/Resources/app.asar.backup" "/Applications/Mineradio-MacOS.app/Contents/Resources/app.asar"
sudo rm -f "/Applications/Mineradio-MacOS.app/Contents/Info.plist.backup"
```

# 🚀 Mineradio-MacOS M4 性能优化

> 专为 Apple Silicon (M1/M2/M3/M4) 设计的 Mineradio 一键优化工具
> 原项目：[XxHuberrr/Mineradio](https://github.com/XxHuberrr/Mineradio)（GPL-3.0）
> Mac 移植：[YiIimini/Mineradio-MacOS](https://github.com/YiIimini/Mineradio-MacOS)

## 优化作者
**严小焕** · 中国人民大学 汉语言文学 · 数字人文方向
📧 1416578309@qq.com

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

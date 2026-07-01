#!/bin/bash
# Mineradio Apple Silicon 全系列优化脚本 (自动检测芯片版本)
# 作者：严小焕 · GPL-3.0
# 自动适配 M1 / M2 / M3 / M4 / M5

APP="/Applications/Mineradio-MacOS.app"
ASAR="$APP/Contents/Resources/app.asar"
EXTRACT="/tmp/mineradio-extracted"

echo "=========================================="
echo "🔧 Mineradio-Apple Silicon 全系列优化"
echo "=========================================="

# ── 检测芯片型号 ──
CHIP=$(sysctl -n machdep.cpu.brand_string 2>/dev/null | grep -oE 'M[0-9]+' | head -1)
ARCH=$(uname -m)

if [ "$ARCH" != "arm64" ]; then
    echo "❌ 仅支持 Apple Silicon (M芯片) Mac, 当前架构: $ARCH"
    exit 1
fi
[ -z "$CHIP" ] && CHIP=$(system_profiler SPHardwareDataType 2>/dev/null | grep "Chip" | head -1 | grep -oE 'M[0-9]+')
[ -z "$CHIP" ] && CHIP="Apple Silicon"

# ── 芯片参数配置 ──
case $CHIP in
    M1) THREADS=4; MEM=3072; PROFILE="M1 - 能效优先"; EXTRA="" ;;
    M2) THREADS=4; MEM=4096; PROFILE="M2 - 均衡优化"; EXTRA="" ;;
    M3) THREADS=6; MEM=4096; PROFILE="M3 - 性能优先"; EXTRA="--enable-features=RayTracing" ;;
    M4) THREADS=8; MEM=6144; PROFILE="M4 - 性能全开"; EXTRA="--enable-features=RayTracing,AppleBI,MacSyscall" ;;

    *) THREADS=4; MEM=4096; PROFILE="$CHIP - 通用优化"; EXTRA="" ;;
esac

echo "🔍 检测到: $CHIP"
echo "📋 方案: $PROFILE ($THREADS 线程, ${MEM}MB)"
echo ""

# ── 准备 Node.js ──
if [ ! -f "/tmp/node-v22.0.0-darwin-arm64/bin/node" ]; then
    echo "📥 下载 Node.js..."
    curl -sL --max-time 60 "https://nodejs.org/dist/v22.0.0/node-v22.0.0-darwin-arm64.tar.gz" -o /tmp/node.tar.gz
    tar -xzf /tmp/node.tar.gz -C /tmp/ 2>/dev/null
fi
export PATH="/tmp/node-v22.0.0-darwin-arm64/bin:$PATH"
npm install -g asar 2>/dev/null

# ── 请求权限 ──
echo "⚠️ 需要管理员权限"
sudo -v

# ── 备份 + 解包 ──
sudo cp "$ASAR" "$ASAR.backup" 2>/dev/null
sudo rm -rf "$EXTRACT" 2>/dev/null
asar extract "$ASAR" "$EXTRACT"
echo "✅ 已解包"

# ── 写入芯片专属参数 ──
sudo /usr/bin/python3 -c "
import plistlib
pl = plistlib.load(open('/Applications/Mineradio-MacOS.app/Contents/Info.plist','rb'))
args = [
    '--enable-features=Vulkan,DefaultANGLEVulkan,CanvasOopRasterization,UseSkiaRenderer',
    '--disable-software-rasterizer', '--enable-gpu-rasterization', '--enable-zero-copy',
    '--ignore-gpu-blocklist', '--num-raster-threads=$THREADS',
    '--js-flags=--jitless --max-old-space-size=$MEM',
    '--enable-parallel-downloading', '--force-color-profile=srgb',
    '--enable-accelerated-2d-canvas',
]
if \"$EXTRA\": args.append(\"$EXTRA\")
pl['ElectronCommandLine'] = {'args': args}
plistlib.dump(pl, open('/Applications/Mineradio-MacOS.app/Contents/Info.plist','wb'))
print('✅ 优化参数已写入')
"

# ── 清理缓存 ──
rm -rf ~/Library/Application\ Support/mineradio-macos/Cache/* ~/Library/Caches/mineradio-macos 2>/dev/null

# ── 打包 ──
sudo asar pack "$EXTRACT" "$ASAR"
sudo rm -rf "$EXTRACT" 2>/dev/null

echo ""
echo "🎉 优化完成！"
echo "   芯片: $CHIP | 方案: $PROFILE"
echo "   线程: $THREADS | 内存: ${MEM}MB"
echo "   重新打开 Mineradio 即可"

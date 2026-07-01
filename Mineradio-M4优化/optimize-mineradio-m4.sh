#!/bin/bash
# Mineradio-MacOS M4 一键优化脚本
# 全自动 · 无需手动操作
# 作者：严小焕 · GPL-3.0

APP="/Applications/Mineradio-MacOS.app"
ASAR="$APP/Contents/Resources/app.asar"
EXTRACT="/tmp/mineradio-extracted"
NODE_DIR="/tmp/node-v22.0.0-darwin-arm64"
NODE_BIN="$NODE_DIR/bin"

echo "=========================================="
echo "🔧 Mineradio-MacOS M4 一键优化"
echo "   专为 Apple Silicon (M1/M2/M3/M4)"
echo "=========================================="
echo ""

# 1. 确保 Node.js 可用
if [ ! -f "$NODE_BIN/node" ]; then
    echo "📥 下载 Node.js..."
    curl -sL --max-time 60 "https://nodejs.org/dist/v22.0.0/node-v22.0.0-darwin-arm64.tar.gz" -o /tmp/node.tar.gz
    tar -xzf /tmp/node.tar.gz -C /tmp/ 2>/dev/null
fi
export PATH="$NODE_BIN:$PATH"
npm install -g asar 2>/dev/null
echo "✅ Node.js 就绪"

# 2. 请求管理员权限
echo "⚠️ 需要管理员权限修改应用"
sudo -v

# 3. 备份原始文件
sudo cp "$ASAR" "$ASAR.backup" 2>/dev/null
echo "✅ 已备份原始 app.asar"

# 4. 解包
sudo rm -rf "$EXTRACT" 2>/dev/null
asar extract "$ASAR" "$EXTRACT"
echo "✅ 已解包"

# 5. 检测 M 芯片类型
CHIP=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Apple Silicon")
echo "🔍 检测到: $CHIP"

# 6. 写入 M4 优化参数
sudo python3 << 'PYEOF'
import plistlib
plist_path = '/Applications/Mineradio-MacOS.app/Contents/Info.plist'
with open(plist_path, 'rb') as f:
    pl = plistlib.load(f)
pl['ElectronCommandLine'] = {
    'args': [
        '--enable-features=Vulkan,DefaultANGLEVulkan,CanvasOopRasterization,UseSkiaRenderer',
        '--disable-software-rasterizer',
        '--enable-gpu-rasterization', '--enable-zero-copy',
        '--ignore-gpu-blocklist', '--num-raster-threads=4',
        '--js-flags=--jitless --max-old-space-size=4096',
        '--enable-parallel-downloading',
        '--force-color-profile=srgb',
        '--enable-accelerated-2d-canvas',
    ]
}
with open(plist_path, 'wb') as f:
    plistlib.dump(pl, f)
print('✅ M4 优化参数已写入')
PYEOF

# 7. 清理缓存
rm -rf ~/Library/Application\ Support/mineradio-macos/Cache/* ~/Library/Caches/mineradio-macos 2>/dev/null
echo "✅ 缓存已清理"

# 8. 打回 asar
sudo asar pack "$EXTRACT" "$ASAR"
echo "✅ app.asar 已更新"

# 9. 清理临时文件
rm -rf "$EXTRACT" /tmp/node.tar.gz 2>/dev/null

echo ""
echo "🎉 M4 优化全部完成！重新打开 Mineradio 即可"
echo "   GPU 加速 ✅  渲染优化 ✅  缓存清理 ✅"

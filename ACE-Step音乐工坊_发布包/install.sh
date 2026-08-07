#!/usr/bin/env bash
# =====================================================
# ACE-Step 音乐工坊 · 一键安装器
# 自动下载并配置所有依赖（ACE-Step 引擎 + 模型 + UI）
# 适用于 macOS Apple Silicon (M1/M2/M3/M4)
# =====================================================

set -e
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

echo -e "${GREEN}== ACE-Step 音乐工坊 安装器 ==${NC}"
echo "目标: $HOME/ACE-Step"

# ---------- 路径 ----------
BASE="$HOME/ACE-Step"
PORTABLE="$BASE/portable/ACE-Step-1.5"
UI="$BASE/ace-step-ui"

mkdir -p "$BASE"

# ---------- 1. 下载 ACE-Step 便携包（508MB）----------
echo -e "\n${YELLOW}[1/4] 下载 ACE-Step 引擎（508MB）...${NC}"
if [ -d "$PORTABLE/python_embeded" ]; then
    echo "✅ 引擎已存在，跳过"
else
    cd "$BASE"
    curl -L -o ACE-Step-1.5.zip "https://files.acemusic.ai/acemusic/mac/ACE-Step-1.5.zip"
    echo "解压中..."
    mkdir -p portable
    unzip -q ACE-Step-1.5.zip -d portable/
    mv portable/ACE-Step-1.5 "$PORTABLE" 2>/dev/null || true
    rm -f ACE-Step-1.5.zip
    echo "✅ 引擎就位"
fi

# ---------- 2. 下载 ace-step-ui（20MB）----------
echo -e "\n${YELLOW}[2/4] 下载专业 UI 界面（20MB）...${NC}"
if [ -d "$UI/package.json" ] || [ -f "$UI/package.json" ]; then
    echo "✅ UI 已存在，跳过"
else
    cd "$BASE"
    curl -L -o ace-step-ui.zip "https://gh-proxy.com/https://github.com/fspecii/ace-step-ui/archive/refs/heads/main.zip"
    unzip -q ace-step-ui.zip
    mv ace-step-ui-main ace-step-ui
    rm -f ace-step-ui.zip
    echo "✅ UI 就位"
fi

# ---------- 3. 修复便携包 Python 签名 + 装依赖 ----------
echo -e "\n${YELLOW}[3/4] 配置运行环境...${NC}"
cd "$PORTABLE"
# 移除 quarantine（系统拦截）
xattr -dr com.apple.quarantine python_embeded/ 2>/dev/null || true
# ad-hoc 重签名
find python_embeded -type f \( -name "*.dylib" -o -perm +111 \) -exec codesign --force --sign - {} \; 2>/dev/null || true
echo "✅ 环境配置完成"

# 应用中文化补丁（默认中文界面）
echo "应用中文化补丁..."
if [ -f "$BASE/zh_patch.diff" ]; then
    cd "$UI" && git apply "$BASE/zh_patch.diff" 2>/dev/null || sed -i '' "s/stored === 'en' ? stored/stored === 'zh' ? stored/" context/I18nContext.tsx 2>/dev/null || true
fi
# 确保默认中文（兜底）
cd "$UI" && grep -q "return stored.*: 'zh'" context/I18nContext.tsx || sed -i '' "s/: 'en'/: 'zh'/" context/I18nContext.tsx 2>/dev/null || true
echo "✅ 中文界面已启用"

# UI 依赖（npm）
echo "安装 UI 依赖（首次约 2-5 分钟）..."
cd "$UI"
npm config set registry https://registry.npmmirror.com
npm install 2>&1 | tail -2
cd "$UI/server" && npm install 2>&1 | tail -2
echo "✅ UI 依赖就位"

# ---------- 4. 创建 .env ----------
echo -e "\n${YELLOW}[4/4] 创建配置文件...${NC}"
cat > "$UI/.env" << EOF
ACESTEP_PATH=$PORTABLE
PORT=3001
FRONTEND_PORT=3000
EOF
cat > "$PORTABLE/.env" << EOF
ACESTEP_CONFIG_PATH=acestep-v15-turbo
ACESTEP_LM_MODEL_PATH=acestep-5Hz-lm-1.7B
ACESTEP_LM_BACKEND=pt
ACESTEP_INIT_LLM=true
ACESTEP_DOWNLOAD_SOURCE=modelscope
EOF

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}✅ 安装完成！${NC}"
echo -e "首次生成音乐时，模型（约 9.4GB）会自动从魔搭下载"
echo -e "现在双击「ACE-Step音乐工坊」开始使用！"
echo -e "${GREEN}========================================${NC}"

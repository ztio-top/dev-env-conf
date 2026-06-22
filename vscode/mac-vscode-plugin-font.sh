#!/bin/bash

# ==============================================================================
# macOS 终极开发环境自动化部署脚本 (纯净基座版)
# 特性: 幂等性、Homebrew 自动接管、静默安装字体、VS Code 环境同步
# ==============================================================================

# 开启严格模式 (遇到错误继续执行，方便跑完全程，但会给出颜色提示)
set -u

# 定义 UI 颜色
CYAN='\033[1;36m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m' # 清除颜色

echo -e "${CYAN}=== 🚀 启动 macOS 开发环境纯净基座构建 ===${NC}"

# ==========================================
# 🌟. 核心包管理器：Homebrew
# ==========================================
if ! command -v brew &> /dev/null; then
    echo -e "${YELLOW}[INFO] 未检测到 Homebrew，开始从官方源自动编译安装...${NC}"
    # 官方全自动安装脚本，会自动处理 Apple Silicon 的 /opt/homebrew 路径映射
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # 提示用户手动将 brew 写入 zshrc（以防脚本执行环境变量未实时刷新）
    echo -e "${YELLOW}⚠️ 注意：如果是全新安装的 Homebrew，请根据终端最后的提示，执行 eval 激活命令。${NC}"
else
    echo -e "${GREEN}[OK] Homebrew 已就绪。${NC}"
fi

# ==========================================
# 🌟. 终端视觉底座：Nerd Font
# ==========================================
echo -e "${CYAN}\n=== 正在核对终端字体引擎 ===${NC}"
# 检查是否已安装该字体 (通过 brew list 验证幂等性)
if brew list --cask font-fira-code-nerd-font &> /dev/null; then
    echo -e "${GREEN}[OK] FiraCode Nerd Font 已经安装，跳过。${NC}"
else
    echo -e "${YELLOW}[INFO] 正在通过 Homebrew Cask 静默安装极客字体...${NC}"
    brew install --cask font-fira-code-nerd-font
fi

# ==========================================
# 🌟. 终端格式化引擎：shfmt

if ! command -v shfmt &> /dev/null; then
    echo "正在安装 shfmt..."
    brew install shfmt
else
    echo "shfmt 已安装，跳过。"
fi

# ==========================================
# 🌟. VS Code 全栈与 AI 插件链
# ==========================================
echo -e "${CYAN}\n=== 开始同步 VS Code 插件生态 ===${NC}"

extensions=(
    "charliermarsh.ruff"                 # Python 极速格式化与代码检查
    "ms-python.python"                   # Python 核心支持
    "ms-python.vscode-pylance"           # Python 严格类型推断
    "esbenp.prettier-vscode"             # 前端、JSON、Markdown 统一排版规范
    "redhat.vscode-yaml"                 # YAML 格式化与 Docker Compose 校验
    "foxundermoon.shell-format"          # Bash/Zsh 脚本格式化与对齐
    "ms-vscode.PowerShell"               # 跨平台自动化脚本支持
    "ms-azuretools.vscode-docker"        # Dockerfile 格式化与容器管理
    "ms-vscode-remote.remote-containers" # 容器化开发核心
    "ms-vscode-remote.remote-ssh"        # 远端物理机直连
    "Continue.continue"                  # 本地大模型接入利器
    "saoudrizwan.claude-dev"             # Cline: 本地 AI Agent
)

# 防呆检查：确保用户已经将 code 命令注入了 Mac 的系统环境变量
if command -v code &> /dev/null; then
    for ext in "${extensions[@]}"; do
        echo -e "正在挂载: ${YELLOW}$ext${NC}"
        code --install-extension "$ext" --force > /dev/null
    done
    echo -e "${GREEN}[OK] 插件同步完成！${NC}"
else
    echo -e "${RED}[ERROR] 找不到 'code' 命令。${NC}"
    echo -e "👉 请先打开 VS Code，按下 Cmd+Shift+P，输入并执行 'Install code command in PATH'，然后再运行此脚本。"
fi

# ==========================================
# 收尾
# ==========================================
echo -e "${GREEN}\n=========================================================${NC}"
echo -e "${GREEN}🎉 macOS 纯净开发基座初始化完毕！${NC}"
echo -e "${GREEN}下一步指引：${NC}"
echo -e "🌟. 打开 VS Code，按下 ${YELLOW}Cmd + Shift + P${NC}，打开 ${YELLOW}settings.json${NC}。"
echo -e "🌟. 将我们之前定稿的【终极防呆配置】全文覆盖进去。"
echo -e "🌟. 彻底重启 VS Code，感受零报错的极速编码体验。"
echo -e "${GREEN}=========================================================${NC}"

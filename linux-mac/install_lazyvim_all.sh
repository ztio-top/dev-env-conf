#!/usr/bin/env bash

# 遇到错误时退出
set -e

echo "========================================================"
echo "  LazyVim All-in-One 终极安装脚本 (macOS & Linux) v3.0  "
echo "  包含: 依赖自动检测安装 + Neovim配置环境隔离与初始化   "
echo "========================================================"

OS="$(uname -s)"

# --- 辅助函数 ---
is_installed() { command -v "$1" &> /dev/null; }

check_nvim_version() {
    if ! is_installed nvim; then return 1; fi
    local version=$(nvim --version | head -n 1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "0.0.0")
    local valid=$(awk -v ver="$version" -v req="0.11.2" '
        BEGIN { split(ver, v, "."); split(req, r, "."); 
        if (v[1]>r[1] || (v[1]==r[1] && v[2]>r[2]) || (v[1]==r[1] && v[2]==r[2] && v[3]>=r[3])) print 1; else print 0; }')
    [ "$valid" -eq 1 ] && return 0 || return 1
}

# ==========================================
# 第一阶段：系统级依赖与工具安装
# ==========================================
echo -e "\n[1/3] 🔍 检查并安装系统级依赖..."

if [ "$OS" = "Darwin" ]; then
    echo "🍏 识别为 macOS 系统，使用 Homebrew 安装工具链..."
    if ! is_installed brew; then
        echo "❌ 未检测到 Homebrew，请先安装 Homebrew。"
        exit 1
    fi

    # 动态收集缺失的包
    BREW_PKGS=()
    is_installed git || BREW_PKGS+=("git")
    is_installed curl || BREW_PKGS+=("curl")
    is_installed rg || BREW_PKGS+=("ripgrep")
    is_installed fd || BREW_PKGS+=("fd")
    is_installed fzf || BREW_PKGS+=("fzf")
    is_installed lazygit || BREW_PKGS+=("lazygit")
    check_nvim_version || BREW_PKGS+=("neovim")

    if [ ${#BREW_PKGS[@]} -gt 0 ]; then
        echo "📦 正在安装缺失工具: ${BREW_PKGS[*]}..."
        brew install "${BREW_PKGS[@]}"
    else
        echo "✅ 所有工具均已就绪，跳过安装。"
    fi

elif [ "$OS" = "Linux" ]; then
    echo "🐧 识别为 Linux 系统，准备环境..."
    if ! is_installed apt; then
        echo "❌ 目前 Linux 自动安装逻辑仅支持 Debian/Ubuntu (apt)，请手动安装依赖。"
        exit 1
    fi

    APT_PKGS=()
    is_installed git || APT_PKGS+=("git")
    is_installed curl || APT_PKGS+=("curl")
    is_installed gcc || APT_PKGS+=("build-essential")
    is_installed rg || APT_PKGS+=("ripgrep")
    is_installed fzf || APT_PKGS+=("fzf")
    if ! is_installed fd && ! is_installed fdfind; then APT_PKGS+=("fd-find"); fi

    if [ ${#APT_PKGS[@]} -gt 0 ]; then
        echo "📦 正在使用 apt 安装基础工具: ${APT_PKGS[*]}..."
        sudo apt update -y
        sudo apt install -y "${APT_PKGS[@]}"
    else
         echo "✅ 基础工具已安装。"
    fi

    # Linux 下处理 Lazygit (Apt源往往太老或没有)
    if ! is_installed lazygit; then
        echo "🚀 正在下载最新版 Lazygit..."
        LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
        curl -sLo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
        tar xf lazygit.tar.gz lazygit
        sudo install lazygit /usr/local/bin
        rm lazygit.tar.gz lazygit
        echo "✅ Lazygit 安装完成。"
    fi

    # Linux 下处理 Neovim (强制要求 >= 0.11.2，Apt源通常只有 0.9)
    if ! check_nvim_version; then
        echo "🚀 正在从官方预编译包安装最新版 Neovim..."
        curl -sLO https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz
        sudo rm -rf /opt/nvim
        sudo tar -C /opt -xzf nvim-linux64.tar.gz
        sudo ln -sf /opt/nvim-linux64/bin/nvim /usr/local/bin/nvim
        rm nvim-linux64.tar.gz
        echo "✅ Neovim 安装完成。"
    fi
else
    echo "❌ 错误: 未知操作系统 ($OS)"
    exit 1
fi

# ==========================================
# 第二阶段：权限修复 (防止 E739 报错)
# ==========================================
echo -e "\n[2/3] 🔐 校验本地目录权限..."
# 确保当前用户拥有自己 home 目录下关键文件夹的所有权
sudo chown -R $(whoami) "$HOME/.local" "$HOME/.config" "$HOME/.cache" 2>/dev/null || true

# ==========================================
# 第三阶段：LazyVim 幂等化部署
# ==========================================
echo -e "\n[3/3] 🚀 部署 LazyVim 配置..."

NVIM_CONFIG="$HOME/.config/nvim"
NVIM_SHARE="$HOME/.local/share/nvim"
NVIM_STATE="$HOME/.local/state/nvim"
NVIM_CACHE="$HOME/.cache/nvim"

if [ -f "$NVIM_CONFIG/lua/config/lazy.lua" ]; then
    echo "✨ 检测到 LazyVim 已安装。脚本满足幂等性，跳过克隆与覆盖。"
else
    # 备份逻辑
    BACKUP_SUFFIX=".bak_$(date +%Y%m%d_%H%M%S)"
    backup_if_exists() {
        if [ -e "$1" ]; then
            mv "$1" "${1}${BACKUP_SUFFIX}"
            echo "📦 备份旧数据: $1 -> ${1}${BACKUP_SUFFIX}"
        fi
    }
    
    if [ -e "$NVIM_CONFIG" ] || [ -e "$NVIM_SHARE" ] || [ -e "$NVIM_STATE" ] || [ -e "$NVIM_CACHE" ]; then
        echo "🔄 正在备份旧的 Neovim 配置..."
        backup_if_exists "$NVIM_CONFIG"
        backup_if_exists "$NVIM_SHARE"
        backup_if_exists "$NVIM_STATE"
        backup_if_exists "$NVIM_CACHE"
    fi

    # 克隆官方 Starter
    echo "📥 克隆 LazyVim Starter..."
    git clone https://github.com/LazyVim/starter "$NVIM_CONFIG"
    rm -rf "$NVIM_CONFIG/.git"
    echo "✅ LazyVim 初始架构部署完毕。"
fi

echo -e "\n========================================================"
echo "🎉 安装全流程结束！环境已达到完美状态。"
echo "👉 请在终端输入 nvim 启动，首次启动会自动下载高阶插件。"
echo "========================================================"
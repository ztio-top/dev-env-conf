#!/usr/bin/env bash

# 设置遇到错误即刻停止运行，并开启管道错误传递
set -eo pipefail

# 定义颜色输出，方便阅读
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}==> 开始执行 macOS 15 Python 开发环境幂等配置...${NC}"

# 1. 检查并安装 Xcode Command Line Tools (Homebrew 和编译 Python 必备)
if xcode-select -p &>/dev/null; then
	echo -e "${GREEN}[OK] Xcode Command Line Tools 已安装。${NC}"
else
	echo -e "${YELLOW}[!] 正在触发安装 Xcode Command Line Tools...${NC}"
	xcode-select --install
	echo -e "${YELLOW}请在弹出的系统窗口中完成安装后，再次运行此脚本！${NC}"
	exit 1
fi

# 2. 检查并安装 Homebrew
if command -v brew &>/dev/null; then
	echo -e "${GREEN}[OK] Homebrew 已安装。${NC}"
else
	echo -e "${YELLOW}[!] 未检测到 Homebrew，正在安装...${NC}"
	NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# 根据芯片架构，将 Homebrew 临时加载到当前脚本的 PATH 中
if [[ $(uname -m) == 'arm64' ]]; then
	eval "$(/opt/homebrew/bin/brew shellenv)"
else
	eval "$(/usr/local/bin/brew shellenv)"
fi

# 3. 检查并安装 Pyenv 及 Python 编译依赖
echo -e "${BLUE}==> 检查并安装 pyenv 及必要的 C 语言编译依赖...${NC}"
# brew install 本身是幂等的，如果已安装会自动跳过
brew install openssl readline sqlite3 xz zlib tcl-tk pyenv

# 4. 幂等配置 ~/.zshrc
ZSHRC="$HOME/.zshrc"
#确保文件存在
touch "$ZSHRC"

echo -e "${BLUE}==> 配置 ~/.zshrc 环境变量...${NC}"

if grep -q 'export PYENV_ROOT="$HOME/.pyenv"' "$ZSHRC"; then
	echo -e "${GREEN}[OK] PYENV_ROOT 已配置。${NC}"
else
	echo 'export PYENV_ROOT="$HOME/.pyenv"' >>"$ZSHRC"
	echo "已追加 PYENV_ROOT"
fi

if grep -q 'export PATH="$PYENV_ROOT/bin:$PATH"' "$ZSHRC"; then
	echo -e "${GREEN}[OK] pyenv PATH 已配置。${NC}"
else
	echo '[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"' >>"$ZSHRC"
	echo "已追加 pyenv PATH"
fi

if grep -q 'eval "$(pyenv init -)"' "$ZSHRC"; then
	echo -e "${GREEN}[OK] pyenv init 已配置。${NC}"
else
	echo 'eval "$(pyenv init -)"' >>"$ZSHRC"
	echo "已追加 pyenv init"
fi

# 将 pyenv 加载到当前脚本的上下文中，以便后续执行 pyenv 命令
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# 5. 安装默认的 Python 版本
PYTHON_VERSION="3.11.9" # 推荐 3.11 兼容性极佳
echo -e "${BLUE}==> 检查 Python ${PYTHON_VERSION}...${NC}"

if pyenv versions --bare | grep -q "^${PYTHON_VERSION}$"; then
	echo -e "${GREEN}[OK] Python ${PYTHON_VERSION} 已经通过 pyenv 安装。${NC}"
else
	echo -e "${YELLOW}[!] 正在编译安装 Python ${PYTHON_VERSION} (这可能需要几分钟时间)...${NC}"
	pyenv install $PYTHON_VERSION
fi

# 无论如何，确保设置为全局默认
pyenv global $PYTHON_VERSION
echo -e "${GREEN}[OK] 系统的全局 Python 版本已接管为: $(python --version)${NC}"

# 6. 生成一个示例虚拟环境项目 (如果不存在)
DEMO_DIR="$HOME/python_demo_project"
if [ -d "$DEMO_DIR" ]; then
	echo -e "${GREEN}[OK] 示例项目目录 $DEMO_DIR 已存在，跳过创建。${NC}"
else
	echo -e "${BLUE}==> 正在创建示例虚拟环境项目...${NC}"
	mkdir -p "$DEMO_DIR"
	cd "$DEMO_DIR"
	python -m venv .venv
	echo -e "${GREEN}[OK] 虚拟环境已在 $DEMO_DIR/.venv 创建。${NC}"
fi

echo -e "${GREEN}======================================================${NC}"
echo -e "${GREEN}配置全部完成！${NC}"
echo -e "要使终端配置立即生效，请执行: ${YELLOW}source ~/.zshrc${NC} (或者重启终端)"
echo -e "要激活体验虚拟环境，请执行:   ${YELLOW}cd ~/python_demo_project && source .venv/bin/activate${NC}"
echo -e "${GREEN}======================================================${NC}"

#!/bin/bash
# 02_optimize_zsh.sh
# 职责：验证依赖并向当前用户的 ~/.zshrc 中注入幂等配置。无需 root 权限。

set -e

echo -e "\033[36m======================================\033[0m"
echo -e "\033[36m       [User] Zsh 幂等优化与增强      \033[0m"
echo -e "\033[36m======================================\033[0m"

# ---------------------------------------------------------
# 阶段一：严格的前置依赖检测
# ---------------------------------------------------------
echo "正在检测必要组件是否已就绪..."
MISSING_DEPS=0

# 辅助函数：检测命令是否存在
check_cmd() {
	if ! command -v "$1" &>/dev/null; then
		echo -e "\033[31m[✗] 缺失核心命令: $1\033[0m"
		MISSING_DEPS=1
	else
		echo -e "\033[32m[✓] 核心命令就绪: $1\033[0m"
	fi
}

# 辅助函数：检测文件路径是否存在
check_file() {
	if [ ! -f "$1" ]; then
		echo -e "\033[31m[✗] 缺失核心文件: $1\033[0m"
		MISSING_DEPS=1
	else
		echo -e "\033[32m[✓] 核心文件就绪: $1\033[0m"
	fi
}

check_cmd zsh
check_cmd starship
check_cmd zoxide
# 检查 Ubuntu apt 源安装的插件路径
check_file "/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
check_file "/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

if [ $MISSING_DEPS -ne 0 ]; then
	echo -e "\n\033[31m[!] 严重错误：检测到缺失必要组件，禁止生成优化代码以防止破坏环境。\033[0m"
	echo -e "\033[33m请先执行 '01_install_deps.sh' 安装基础环境后再运行此脚本。\033[0m"
	exit 1
fi

# ---------------------------------------------------------
# 阶段二：配置注入 (幂等操作)
# ---------------------------------------------------------
# 备份现有的 .zshrc
ZSHRC="$HOME/.zshrc"
if [ -f "$ZSHRC" ]; then
	cp "$ZSHRC" "${ZSHRC}.backup_$(date +%Y%m%d_%H%M%S)"
	echo "✓ 已将现有的 .zshrc 备份至 ${ZSHRC}.backup_..."
else
	touch "$ZSHRC"
	echo "✓ 创建了新的 .zshrc 文件"
fi

# 定义幂等写入函数
append_if_not_exists() {
	local marker="$1"
	local content="$2"

	# 利用 MARKER 标记判断是否已经写入过
	if grep -q "MARKER: $marker" "$ZSHRC"; then
		echo "  - 配置块 [$marker] 已存在，跳过写入"
	else
		echo "  + 正在注入配置块 [$marker]"
		echo "" >>"$ZSHRC"
		echo "# >>> MARKER: $marker >>>" >>"$ZSHRC"
		echo "$content" >>"$ZSHRC"
		echo "# <<< MARKER: $marker <<<" >>"$ZSHRC"
		echo "" >>"$ZSHRC"
	fi
}

echo -e "\n\033[33m开始向 $ZSHRC 注入配置...\033[0m"

# 1. Zsh 原生行为与补全优化 (修复了转义符问题)
ZSH_BEHAVIOR="# 忽略大小写的自动补全
autoload -Uz compinit && compinit
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# 历史记录管理优化
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt APPEND_HISTORY          # 追加历史记录而不覆盖
setopt INC_APPEND_HISTORY      # 命令执行后立即追加历史
setopt HIST_IGNORE_ALL_DUPS    # 忽略重复写入的历史记录
setopt HIST_REDUCE_BLANKS      # 移除命令中多余的空格"
append_if_not_exists "ZSH_BEHAVIOR" "$ZSH_BEHAVIOR"

# 2. 常用系统级别名 (修复了转义符问题)
ALIAS_CONFIG="alias ll='ls -al --color=auto'
alias c='clear'
alias ip='curl -s ifconfig.me; echo'"
append_if_not_exists "ALIASES" "$ALIAS_CONFIG"

# 3. 智能目录跳转 zoxide (使用单引号包裹，防止提前展开)
append_if_not_exists "ZOXIDE" 'eval "$(zoxide init zsh)"'

# 4. Starship 提示符 (使用单引号包裹，防止提前展开)
append_if_not_exists "STARSHIP" 'eval "$(starship init zsh)"'

# 5. Ubuntu 原生高亮与建议插件
PLUGINS_CONFIG="source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
append_if_not_exists "ZSH_PLUGINS_LAST" "$PLUGINS_CONFIG"

echo -e "\033[32m======================================\033[0m"
echo -e "\033[32m🎉 Zsh 优化完成！请执行 'source ~/.zshrc' 或重新登录终端。\033[0m"
echo -e "\033[32m======================================\033[0m"

#!/bin/bash

# 设置错误时退出
set -e

echo "=========================================="
echo "开始优化 macOS 15+ Zsh 环境 (幂等脚本)"
echo "=========================================="

# 1. 检查并确保 Homebrew 已安装
if ! command -v brew &>/dev/null; then
	echo "提示: 未检测到 Homebrew，正在为您安装..."
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
	echo "✓ 检测到 Homebrew 已安装"
fi

# 确保当前环境能使用 brew (兼容 Apple Silicon 与其他架构)
BREW_BIN=$(command -v brew || echo "/opt/homebrew/bin/brew")
eval "$($BREW_BIN shellenv)"

# 2. 声明需要安装的包列表
PACKAGES=(starship zsh-autosuggestions zsh-syntax-highlighting zoxide)

echo "检查并安装所需的组件..."
for pkg in "${PACKAGES[@]}"; do
	if brew list "$pkg" &>/dev/null; then
		echo "✓ $pkg 已经安装，跳过"
	else
		echo "正在安装 $pkg..."
		brew install "$pkg"
	fi
done

# 3. 备份现有的 .zshrc
ZSHRC="$HOME/.zshrc"
if [ -f "$ZSHRC" ]; then
	cp "$ZSHRC" "${ZSHRC}.backup_$(date +%Y%m%d_%H%M%S)"
	echo "✓ 已将现有的 .zshrc 备份至 ${ZSHRC}.backup_..."
else
	touch "$ZSHRC"
	echo "✓ 创建了新的 .zshrc 文件"
fi

# 4. 定义幂等写入函数 (核心 - 移除 echo -e 以确保 macOS 兼容性)
append_if_not_exists() {
	local marker="$1"
	local content="$2"

	if grep -q "MARKER: $marker" "$ZSHRC"; then
		echo "✓ 配置块 [$marker] 已存在，跳过写入"
	else
		echo "正在写入配置块 [$marker]..."
		echo "" >>"$ZSHRC"
		echo "# >>> MARKER: $marker >>>" >>"$ZSHRC"
		echo "$content" >>"$ZSHRC"
		echo "# <<< MARKER: $marker <<<" >>"$ZSHRC"
		echo "" >>"$ZSHRC"
	fi
}

# 5. 组装并写入各项配置

# 5.1 环境配置
ENV_CONFIG='# 加载 Homebrew 环境
eval "$(/opt/homebrew/bin/brew shellenv)"

# 优化语言设置
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"'
append_if_not_exists "HOMEBREW_ENV" "$ENV_CONFIG"

# 5.2 Zsh 原生行为与补全
ZSH_BEHAVIOR='# 忽略大小写的自动补全
autoload -Uz compinit && compinit
zstyle '\'':completion:*'\'' matcher-list '\''m:{a-zA-Z}={A-Za-z}'\''

# 历史记录优化
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt APPEND_HISTORY          # 追加历史
setopt INC_APPEND_HISTORY      # 立即追加历史
setopt HIST_IGNORE_ALL_DUPS    # 忽略重复
setopt HIST_REDUCE_BLANKS      # 移除多余空格'
append_if_not_exists "ZSH_BEHAVIOR" "$ZSH_BEHAVIOR"

# 5.3 智能目录跳转 (zoxide)
append_if_not_exists "ZOXIDE" 'eval "$(zoxide init zsh)"'

# 5.4 常用别名 (Alias)
ALIAS_CONFIG='alias ll="ls -alGh"
alias c="clear"
alias ip="curl -s ifconfig.me; echo"'
append_if_not_exists "ALIASES" "$ALIAS_CONFIG"

# 5.5 Starship 提示符
append_if_not_exists "STARSHIP" 'eval "$(starship init zsh)"'

# 5.6 高亮与历史建议 (必须放在最后，优化启动速度)
# 使用 ${HOMEBREW_PREFIX} 替代 $(brew --prefix) 消除子进程开销
PLUGINS_CONFIG='source ${HOMEBREW_PREFIX}/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source ${HOMEBREW_PREFIX}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh'
append_if_not_exists "ZSH_PLUGINS_LAST" "$PLUGINS_CONFIG"

echo "=========================================="
echo "🎉 优化完成！请运行 'source ~/.zshrc' 或重启终端使配置生效。"
echo "=========================================="

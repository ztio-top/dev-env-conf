#!/bin/bash

# 定义标记，用于实现幂等性（防止重复添加）
START_MARKER="# >>> tabby cwd reporting start >>>"
END_MARKER="# >>> tabby cwd reporting end >>>"

echo "正在优化并配置 Tabby CWD 路径汇报..."

# ==================== 1. Bash 配置 (~/.bashrc) ====================
BASH_RC="$HOME/.bashrc"
if [ -f "$BASH_RC" ]; then
	if ! grep -q "$START_MARKER" "$BASH_RC"; then
		cat <<EOF >>"$BASH_RC"

$START_MARKER
# 优化原因：放入 .bashrc 确保每次交互式 Shell 动态解析，支持 tmux/screen
if [ -n "\$PS1" ]; then
    export PS1="\$PS1\\[\\e]1337;CurrentDir="'\$(pwd)\\a\\]'
fi
$END_MARKER
EOF
		echo "[✓] 已成功配置 Bash (~/.bashrc)"
	else
		echo "[i] Bash 已配置过，跳过。"
	fi
fi

# ==================== 2. Zsh 配置 (~/.zshrc) ====================
ZSH_RC="$HOME/.zshrc"
if [ -f "$ZSH_RC" ]; then
	if ! grep -q "$START_MARKER" "$ZSH_RC"; then
		cat <<'EOF' >>"$ZSH_RC"

# >>> tabby cwd reporting start >>>
# 优化原因：使用 add-zsh-hook 替代直接定义 precmd，防止覆盖 Oh My Zsh 等主题钩子
autoload -Uz add-zsh-hook
__tabby_cwd_reporting() {
    echo -n -e "\x1b]1337;CurrentDir=$(pwd)\x07"
}
add-zsh-hook precmd __tabby_cwd_reporting
# >>> tabby cwd reporting end >>>
EOF
		echo "[✓] 已成功配置 Zsh (~/.zshrc)"
	else
		echo "[i] Zsh 已配置过，跳过。"
	fi
fi

# ==================== 3. Fish 配置 (~/.config/fish/config.fish) ====================
FISH_DIR="$HOME/.config/fish"
FISH_CONF="$FISH_DIR/config.fish"
if [ -d "$FISH_DIR" ] || [ -f "$FISH_CONF" ]; then
	mkdir -p "$FISH_DIR"
	if [ ! -f "$FISH_CONF" ] || ! grep -q "$START_MARKER" "$FISH_CONF"; then
		cat <<'EOF' >>"$FISH_CONF"

# >>> tabby cwd reporting start >>>
function __tabby_working_directory_reporting --on-event fish_prompt
    echo -en "\e]1337;CurrentDir=$PWD\x7"
end
# >>> tabby cwd reporting end >>>
EOF
		echo "[✓] 已成功配置 Fish ($FISH_CONF)"
	else
		echo "[i] Fish 已配置过，跳过。"
	fi
fi

echo "=========================================="
echo "[✓] 配置完成！请重启终端或运行 'source' 命令使其生效。"

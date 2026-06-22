#!/bin/bash

# 遇到错误立即停止运行
set -e

START_MARKER="# >>> shellcrash proxy alias start >>>"
END_MARKER="# >>> shellcrash proxy alias end >>>"

echo "正在自动配置 ShellCrash 终端代理快捷别名 (适配 Bash/Zsh/Fish)..."

# ==================== 1. Bash 配置 (~/.bashrc) ====================
BASH_RC="$HOME/.bashrc"
if [ -f "$BASH_RC" ]; then
	if ! grep -q "$START_MARKER" "$BASH_RC"; then
		cat <<'EOF' >>"$BASH_RC"

# >>> shellcrash proxy alias start >>>
alias proxy_on='export http_proxy=http://192.168.2.3:7890; export https_proxy=http://192.168.2.3:7890; export all_proxy=socks5://192.168.2.3:7890; echo -e "\033[32m[✓] 终端代理已开启 (192.168.2.3:7890)\033[0m"'
alias proxy_off='unset http_proxy https_proxy all_proxy; echo -e "\033[33m[!] 终端代理已关闭\033[0m"'
# >>> shellcrash proxy alias end >>>
EOF
		echo "[✓] 已成功配置 Bash (~/.bashrc)"
	else
		echo "[i] Bash 别名已存在，跳过。"
	fi
fi

# ==================== 2. Zsh 配置 (~/.zshrc) ====================
ZSH_RC="$HOME/.zshrc"
if [ -f "$ZSH_RC" ]; then
	if ! grep -q "$START_MARKER" "$ZSH_RC"; then
		cat <<'EOF' >>"$ZSH_RC"

# >>> shellcrash proxy alias start >>>
alias proxy_on='export http_proxy=http://192.168.2.3:7890; export https_proxy=http://192.168.2.3:7890; export all_proxy=socks5://192.168.2.3:7890; echo -e "\033[32m[✓] 终端代理已开启 (192.168.2.3:7890)\033[0m"'
alias proxy_off='unset http_proxy https_proxy all_proxy; echo -e "\033[33m[!] 终端代理已关闭\033[0m"'
# >>> shellcrash proxy alias end >>>
EOF
		echo "[✓] 已成功配置 Zsh (~/.zshrc)"
	else
		echo "[i] Zsh 别名已存在，跳过。"
	fi
fi

# ==================== 3. Fish 配置 (~/.config/fish/config.fish) ====================
FISH_DIR="$HOME/.config/fish"
FISH_CONF="$FISH_DIR/config.fish"
if [ -d "$FISH_DIR" ] || [ -f "$FISH_CONF" ]; then
	mkdir -p "$FISH_DIR"
	if [ ! -f "$FISH_CONF" ] || ! grep -q "$START_MARKER" "$FISH_CONF"; then
		cat <<'EOF' >>"$FISH_CONF"

# >>> shellcrash proxy alias start >>>
# 优化原因：适配 Fish Shell 特有语法 (set -gx / set -e)
alias proxy_on="set -gx http_proxy http://192.168.2.3:7890; set -gx https_proxy http://192.168.2.3:7890; set -gx all_proxy socks5://192.168.2.3:7890; echo -e '\e[32m[✓] 终端代理已开启 (192.168.2.3:7890)\e[0m'"
alias proxy_off="set -e http_proxy https_proxy all_proxy; echo -e '\e[33m[!] 终端代理已关闭\e[0m'"
# >>> shellcrash proxy alias end >>>
EOF
		echo "[✓] 已成功配置 Fish ($FISH_CONF)"
	else
		echo "[i] Fish 别名已存在，跳过。"
	fi
fi

echo "=========================================="
echo "[✓] 快捷别名注入完成！此脚本具有完全的幂等性，重复运行不会污染系统。"
echo "[提示] 请重启终端或对相应的 rc 文件执行 source 命令使别名即刻生效。"

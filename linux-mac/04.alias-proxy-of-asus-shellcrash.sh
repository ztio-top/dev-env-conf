#!/bin/bash

# 遇到错误立即停止运行
set -e

START_MARKER="# >>> shellcrash proxy alias start >>>"
END_MARKER="# >>> shellcrash proxy alias end >>>"

# 生成当前时间戳，用于备份文件后缀 (格式: YYYYMMDD_HHMMSS)
BACKUP_SUFFIX=$(date +%Y%m%d_%H%M%S)

# ==================== 0. 解析代理地址参数 ====================
# 设置默认的代理地址
PROXY_ADDR="192.168.2.3:7890"

# 如果执行此安装脚本时附带了参数 (例如: ./setup.sh 127.0.0.1:7890)，则覆盖默认地址
if [ -n "$1" ]; then
	PROXY_ADDR="$1"
	echo -e "\033[36m[i] 检测到自定义参数，默认代理地址已设定为: ${PROXY_ADDR}\033[0m"
else
	echo -e "\033[36m[i] 未提供参数，使用默认代理地址: ${PROXY_ADDR}\033[0m"
	echo -e "\033[36m    (提示: 若需修改默认值，请运行 ./脚本名.sh <IP:端口> 进行覆盖)\033[0m"
fi

echo "正在自动配置 ShellCrash 终端代理快捷命令 (适配 Bash/Zsh/Fish)..."

# 备份与清理旧配置的辅助函数
prepare_file() {
	local target_file="$1"
	if [ -f "$target_file" ]; then
		# 1. 核心新增：在进行任何修改前，先对原文件进行备份
		cp "$target_file" "${target_file}.bak_${BACKUP_SUFFIX}"
		echo "[✓] 已成功备份 $target_file 至 ${target_file}.bak_${BACKUP_SUFFIX}"

		# 2. 如果检测到旧配置先将其删除，确保完全的幂等性与可覆盖性
		if grep -q "$START_MARKER" "$target_file"; then
			# 使用 .tmp_sed 临时后缀以确保在 macOS 和 Linux 下的 sed 兼容性
			sed -i.tmp_sed '/# >>> shellcrash proxy alias start >>>/,/# >>> shellcrash proxy alias end >>>/d' "$target_file"
			rm -f "${target_file}.tmp_sed"
			echo "[i] 已清理 $target_file 中的旧版配置，准备写入新配置..."
		fi
	fi
}

# ==================== 1. Bash 配置 (~/.bashrc) ====================
BASH_RC="$HOME/.bashrc"
if [ -f "$BASH_RC" ]; then
	prepare_file "$BASH_RC"
	# 注意：\${1:-${PROXY_ADDR}} 表示终端运行时若未传参则回退至安装时指定的默认值
	cat <<EOF >>"$BASH_RC"

$START_MARKER
# 使用函数替代 alias，以便支持在终端输入时动态传入代理地址参数
proxy_on() {
    local addr="\${1:-${PROXY_ADDR}}"
    export http_proxy="http://\$addr"
    export https_proxy="http://\$addr"
    export all_proxy="socks5://\$addr"
    echo -e "\\033[32m[✓] 终端代理已开启 (\$addr)\\033[0m"
}
alias proxy_off='unset http_proxy https_proxy all_proxy; echo -e "\\033[33m[!] 终端代理已关闭\\033[0m"'
$END_MARKER
EOF
	echo "[✓] 已成功配置 Bash (~/.bashrc)"
fi

# ==================== 2. Zsh 配置 (~/.zshrc) ====================
ZSH_RC="$HOME/.zshrc"
if [ -f "$ZSH_RC" ]; then
	prepare_file "$ZSH_RC"
	cat <<EOF >>"$ZSH_RC"

$START_MARKER
# 使用函数替代 alias，以便支持在终端输入时动态传入代理地址参数
proxy_on() {
    local addr="\${1:-${PROXY_ADDR}}"
    export http_proxy="http://\$addr"
    export https_proxy="http://\$addr"
    export all_proxy="socks5://\$addr"
    echo -e "\\033[32m[✓] 终端代理已开启 (\$addr)\\033[0m"
}
alias proxy_off='unset http_proxy https_proxy all_proxy; echo -e "\\033[33m[!] 终端代理已关闭\\033[0m"'
$END_MARKER
EOF
	echo "[✓] 已成功配置 Zsh (~/.zshrc)"
fi

# ==================== 3. Fish 配置 (~/.config/fish/config.fish) ====================
FISH_DIR="$HOME/.config/fish"
FISH_CONF="$FISH_DIR/config.fish"
if [ -d "$FISH_DIR" ] || [ -f "$FISH_CONF" ]; then
	mkdir -p "$FISH_DIR"
	if [ -f "$FISH_CONF" ]; then
		prepare_file "$FISH_CONF"
	fi
	cat <<EOF >>"$FISH_CONF"

$START_MARKER
# 优化原因：适配 Fish Shell 特有语法 (set -gx / set -e)，并改用 function 支持动态传参
function proxy_on
    set -l addr "\$argv[1]"
    if test -z "\$addr"
        set addr "${PROXY_ADDR}"
    end
    set -gx http_proxy "http://\$addr"
    set -gx https_proxy "http://\$addr"
    set -gx all_proxy "socks5://\$addr"
    echo -e "\\e[32m[✓] 终端代理已开启 (\$addr)\\e[0m"
end
alias proxy_off="set -e http_proxy https_proxy all_proxy; echo -e '\\e[33m[!] 终端代理已关闭\\e[0m'"
$END_MARKER
EOF
	echo "[✓] 已成功配置 Fish ($FISH_CONF)"
fi

echo "=========================================="
echo "[✓] 快捷命令注入完成！安全备份已就绪。"
echo "[提示] 请重启终端或对相应的 rc 文件执行 source 命令使配置即刻生效。"

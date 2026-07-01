#!/bin/bash

# ==========================================
# 在这里修改你的 SSH 服务器列表原文
# windows Git Bash、Linux、macOS 都可以直接运行此脚本来更新 SSH 配置文件
# ==========================================
# 您可以随时在这里新增、修改、删除服务器配置
SSH_CONFIG_BLOCK=$(
	cat <<'EOF'
Host ASUS-RT-AC86U
    HostName 192.168.2.3
    User zt
    Port 22
Host nas
    HostName 192.168.2.4
    User zt
    Port 22
Host mac-studio
    HostName 192.168.2.5
    User ztio
    Port 22
Host pve
    HostName 192.168.2.6
    User root
    Port 22
Host pve.ubuntu-ai
    HostName 192.168.2.7
    User ztio
    Port 22
Host hp.pve
    HostName 192.168.2.8
    User root
    Port 22
Host hp.pve.ubuntu-ai
    HostName 192.168.2.9
    User root
    Port 22
Host pi1
    HostName 192.168.2.10
    User zt
    Port 22
Host pi2
    HostName 192.168.2.11
    User pi
    Port 22
EOF
)

# 用于保证幂等性和支持重复更新的标记范围（请勿修改）
MARKER_START="# --- BEGIN MANAGED SSH HOSTS ---"
MARKER_END="# --- END MANAGED SSH HOSTS ---"

# 适配各系统的家目录路径
SSH_DIR="$HOME/.ssh"
CONFIG_FILE="$SSH_DIR/config"
TMP_FILE="$CONFIG_FILE.tmp"
# 备份文件名：带时间戳，精确到秒，方便回滚
BACKUP_FILE="$CONFIG_FILE.bak.$(date +%Y%m%d%H%M%S)"

echo "[*] 开始同步 SSH 客户端配置..."

# 1. 确保 .ssh 目录存在并具备安全权限
if [ ! -d "$SSH_DIR" ]; then
	mkdir -p "$SSH_DIR"
	echo "[+] 创建了不存在的 SSH 目录: $SSH_DIR"
fi
chmod 700 "$SSH_DIR"

# 2. 如果 config 文件存在，先进行备份；如果不存在则直接创建
if [ -f "$CONFIG_FILE" ]; then
	cp "$CONFIG_FILE" "$BACKUP_FILE"
	echo "[+] 备份成功：已将当前配置备份至 $BACKUP_FILE"
else
	touch "$CONFIG_FILE"
	echo "[+] 未检测到原配置文件，已新建 $CONFIG_FILE"
fi

# 3. 核心幂等性与更新逻辑：
# 清理可能已经存在的旧标记块，将原配置文件的其余内容提取到临时文件中
# 使用标准的 sed 语法，完美兼容 Linux、macOS (BSD sed) 和 Windows Git Bash
sed "/^$MARKER_START$/,/^$MARKER_END$/d" "$CONFIG_FILE" >"$TMP_FILE"

# 4. 精细化格式处理：
# 确保如果原文件有内容且末尾没有换行，先补一个换行；如果是空文件则不补，防止生成无意义空行
if [ -s "$TMP_FILE" ]; then
	# 检查最后一个字符是否为换行符
	if [ "$(tail -c1 "$TMP_FILE" 2>/dev/null)" != "" ]; then
		echo "" >>"$TMP_FILE"
	fi
fi

# 5. 将更新后的脚本内服务器列表追加到临时文件中
echo "$MARKER_START" >>"$TMP_FILE"
echo "$SSH_CONFIG_BLOCK" >>"$TMP_FILE"
echo "$MARKER_END" >>"$TMP_FILE"

# 6. 用处理好的临时文件安全地覆盖原配置文件，并设置 600 权限
mv "$TMP_FILE" "$CONFIG_FILE"
chmod 600 "$CONFIG_FILE"

echo "[√] SSH 配置文件已成功更新/同步至: $CONFIG_FILE"

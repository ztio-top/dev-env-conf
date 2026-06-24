#!/bin/bash
# 01_install_deps.sh
# 职责：安装 Zsh 及相关依赖，修改默认 Shell。需要 sudo 权限。

set -e

echo -e "\033[36m======================================\033[0m"
echo -e "\033[36m     [Root] Zsh 系统级依赖安装脚本    \033[0m"
echo -e "\033[36m======================================\033[0m"

# 1. 检查 root 权限
if [ "$EUID" -ne 0 ]; then
	echo -e "\033[31m[!] 错误: 请使用 sudo 运行此依赖安装脚本\033[0m"
	exit 1
fi

# 2. 网络代理配置 (继承原有的旁路由配置，保障国内下载顺畅)
# export http_proxy=http://192.168.2.3:7890
# export https_proxy=http://192.168.2.3:7890

# 3. 安装系统级依赖
echo -e "\033[33m[1/3] 更新软件源并安装基础环境与插件...\033[0m"
apt-get update
# 安装 Zsh、必备工具，以及 Ubuntu 软件仓库自带的 Zsh 插件
apt-get install -y zsh curl git zsh-autosuggestions zsh-syntax-highlighting zoxide

# 4. 安装现代提示符 Starship
echo -e "\033[33m[2/3] 检查并安装 Starship...\033[0m"
if ! command -v starship &>/dev/null; then
	# 使用代理下载并静默安装至 /usr/local/bin
	curl -sS https://starship.rs/install.sh | sh -s -- -y
else
	echo -e "\033[32m[✓] Starship 已安装，跳过\033[0m"
fi

# 5. 切换目标用户的默认 Shell
# 智能获取目标用户：如果用 sudo 执行，获取原用户；如果直接 root 执行，则为 root
TARGET_USER="${SUDO_USER:-$USER}"
echo -e "\033[33m[3/3] 正在将用户 '$TARGET_USER' 的默认 Shell 切换为 Zsh...\033[0m"
chsh -s $(which zsh) "$TARGET_USER"

echo -e "\033[32m======================================\033[0m"
echo -e "\033[32m[✓] 系统级环境准备完毕！\033[0m"
echo -e "\033[32m请确保当前处于 '$TARGET_USER' 用户身份下，再执行优化脚本。\033[0m"
echo -e "\033[32m======================================\033[0m"

#!/bin/bash

# 遇到错误立即停止运行
set -e

echo -e "\033[36m======================================\033[0m"
echo -e "\033[36m    自动安装 Zsh 与 Oh My Zsh 脚本    \033[0m"
echo -e "\033[36m======================================\033[0m"

# 1. 检查是否具有 root/sudo 权限
if [ "$EUID" -ne 0 ]; then
	echo -e "\033[31m[!] 请使用 sudo 运行此脚本 (例如: sudo bash install_zsh.sh)\033[0m"
	exit 1
fi

# 2. 更新软件源并安装依赖
echo -e "\033[33m[1/4] 正在更新软件源并安装 zsh, curl, git...\033[0m"
apt-get update
# 使用 apt-get 和 -y 保证在脚本中安静、无交互地运行
apt-get install -y zsh curl git

# 3. 确定目标用户并更改默认 Shell
# 如果是通过 sudo 执行，则获取真实的登录用户名，否则使用当前用户
TARGET_USER="${SUDO_USER:-$USER}"

echo -e "\033[33m[2/4] 正在将用户 '$TARGET_USER' 的默认 Shell 切换为 Zsh...\033[0m"
chsh -s $(which zsh) "$TARGET_USER"

# 4. 自动安装 Oh My Zsh (无人值守模式)
echo -e "\033[33m[3/4] 正在为用户 '$TARGET_USER' 安装 Oh My Zsh...\033[0m"

# 切换到目标用户的身份去下载和安装，确保配置文件生成在正确的 ~/.zshrc 中
su - "$TARGET_USER" -c '
  # 【注入你的旁路由代理】确保在 su 内部也能走代理
  export http_proxy=http://192.168.2.3:7890
  export https_proxy=http://192.168.2.3:7890
  export all_proxy=socks5://192.168.2.3:7890

  # 设置变量避免安装脚本主动进入 zsh 或请求更改 shell（引起脚本阻塞）
  export RUNZSH=no
  export CHSH=no

  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    echo -e "\033[32m[✓] Oh My Zsh 安装成功！\033[0m"
  else
    echo -e "\033[32m[✓] 发现 ~/.oh-my-zsh 目录已存在，跳过重新安装。\033[0m"
  fi
'

echo -e "\033[36m======================================\033[0m"
echo -e "\033[32m[✓] 全部安装和配置均已完成！\033[0m"
echo -e "\033[35m[提示] 请关闭当前终端窗口并重新打开，或者输入 'su - $TARGET_USER' 即可体验 Zsh。\033[0m"
echo -e "\033[36m======================================\033[0m"

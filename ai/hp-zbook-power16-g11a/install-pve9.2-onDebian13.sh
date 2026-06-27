#!/usr/bin/env bash
# 开启遇到错误即退出的模式
set -e

echo "========================================================="
echo "  Proxmox VE (PVE) 9.x on Debian 13 (Trixie) 自动安装脚本  "
echo "  特点: 幂等性设计，支持重复执行，无交互静默安装"
echo "========================================================="

# 1. 检查 Root 权限
if [[ $EUID -ne 0 ]]; then
   echo "❌ 错误: 此脚本必须以 root 用户运行。请使用 sudo su 切换或直接使用 root 登录。" 
   exit 1
fi

# 2. 检查主机名解析 (防止网络配置问题导致安装失败)
CURRENT_IP=$(hostname --ip-address || echo "error")
if [[ "$CURRENT_IP" == "127.0.1.1" ]] || [[ "$CURRENT_IP" == "error" ]]; then
    echo "❌ 错误: 主机名解析不正确，当前指向 127.0.1.1 或无法解析。"
    echo "请检查 /etc/hosts，确保你的主机名指向了真实的局域网静态 IP。"
    exit 1
fi
echo "✅ 主机名解析检查通过: $CURRENT_IP"

# 3. 安装基础依赖
echo "📦 正在检查并安装基础依赖..."
apt-get update -qq
apt-get install -y -qq curl wget gnupg2 software-properties-common

# 4. 添加 PVE GPG 密钥 (幂等)
KEY_URL="https://enterprise.proxmox.com/debian/proxmox-release-trixie.gpg"
KEY_PATH="/etc/apt/trusted.gpg.d/proxmox-release-trixie.gpg"

if [ ! -f "$KEY_PATH" ]; then
    echo "🔑 正在下载并添加 Proxmox 官方 GPG 密钥..."
    wget -q "$KEY_URL" -O "$KEY_PATH"
else
    echo "✅ Proxmox GPG 密钥已存在，跳过添加。"
fi

# 5. 添加 PVE 无订阅版软件源 (幂等)
REPO_FILE="/etc/apt/sources.list.d/pve-install-repo.list"
REPO_LINE="deb [arch=amd64] http://download.proxmox.com/debian/pve trixie pve-no-subscription"

if [ ! -f "$REPO_FILE" ] || ! grep -q "^$REPO_LINE" "$REPO_FILE"; then
    echo "🌐 正在配置 PVE 无订阅版软件源..."
    echo "$REPO_LINE" > "$REPO_FILE"
else
    echo "✅ PVE 软件源已配置，跳过添加。"
fi

# 6. 预配置 Postfix，实现无交互静默安装
# 避免安装时弹出粉红色的 Postfix 配置界面打断脚本
echo "⚙️  正在预配置 Postfix 邮件服务 (Local Only)..."
export DEBIAN_FRONTEND=noninteractive
debconf-set-selections <<< "postfix postfix/main_mailer_type select Local only"
debconf-set-selections <<< "postfix postfix/mailname string $(hostname -f)"

# 7. 更新系统并安装 PVE 核心套件
echo "🚀 正在拉取最新包列表并全量升级系统..."
apt-get update -qq
apt-get full-upgrade -y -qq

echo "🛠️ 正在安装 Proxmox VE 及其核心组件 (这可能需要几分钟)..."
apt-get install -y -qq proxmox-ve postfix open-iscsi chrony

# 8. 卸载 os-prober (PVE 官方建议，避免引发虚拟机引导冲突)
if dpkg -l | grep -q "^ii  os-prober"; then
    echo "🧹 正在移除不推荐的 os-prober 软件包..."
    apt-get remove -y -qq os-prober
else
    echo "✅ os-prober 未安装或已移除，跳过。"
fi

# 9. 完成提示
echo "========================================================="
echo "🎉 安装流程执行完毕！"
echo ""
echo "PVE 的定制内核已经安装完成。为了让新内核生效，你需要重启服务器。"
echo "重启后，请在浏览器中访问以下地址登录 PVE 控制面板："
echo "👉 https://${CURRENT_IP}:8006"
echo ""
echo "你可以现在输入 'reboot' 来重启服务器。"
echo "========================================================="
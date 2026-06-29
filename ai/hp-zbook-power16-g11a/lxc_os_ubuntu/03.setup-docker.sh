#!/bin/bash
set -e

echo "====================================================="
echo "  Ubuntu 24.04: Docker Engine 自动化安装脚本         "
echo "====================================================="

# 1. 权限检查
if [ "$EUID" -ne 0 ]; then
	echo "❌ 错误: 请使用 root 用户权限运行此脚本。"
	exit 1
fi

# 2. 基础依赖检查与更新
echo -e "\n📦 检查系统依赖..."
apt update -y
apt install -y curl wget ca-certificates gnupg

# 3. 幂等安装 Docker
echo -e "\n🐳 检查 Docker 运行环境..."
if command -v docker &>/dev/null; then
	echo "⏭️  [跳过] Docker 已经安装，当前版本: $(docker --version)"
else
	echo "⚙️ 未检测到 Docker，正在从官方源拉取并安装..."
	curl -fsSL https://get.docker.com -o get-docker.sh
	sh get-docker.sh
	rm get-docker.sh
	echo "✅ Docker 安装成功！"
fi

# 4. 配置开机自启
echo -e "\n⚙️ 配置 Docker 服务状态..."
systemctl enable --now docker
systemctl status docker --no-pager | grep Active

echo "====================================================="
echo "🎉 Docker 环境部署完毕！"
echo "====================================================="

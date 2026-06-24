#!/bin/bash

# ==============================================================================
# AI 核心节点自动化部署脚本 (针对 Ubuntu Minimized + RTX 3090 设计)
# 特性: 幂等性、静默安装、阶段日志、异常阻断
# ==============================================================================

# 开启严格模式：遇到任何错误立即退出，未定义的变量报错，管道中任何一个失败即全失败
set -euo pipefail

# ==========================================
# 0. 全局环境变量与日志函数配置
# ==========================================
# 强制所有 apt 操作非交互式，避免弹窗卡死脚本
export DEBIAN_FRONTEND=noninteractive
export APT_OPT="-y -qq -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold"

# [核心优化] 定义推荐的 NVIDIA 驱动版本（无头服务器版，极度稳定）
# 使用ubuntu-drivers devices命令查看是否有新server版本驱动可用，如果有，建议更新此变量以获得更好的性能和兼容性
NVIDIA_DRIVER_PKG="nvidia-driver-595"

# 定义带颜色的日志输出函数
log_info() { echo -e "\n\033[1;32m[INFO] === $1 ===\033[0m"; }
log_warn() { echo -e "\n\033[1;33m[WARN] === $1 ===\033[0m"; }

# 确保脚本以 root 权限运行
if [ "$EUID" -ne 0 ]; then
	echo -e "\033[1;31m请使用 sudo 执行此脚本：sudo ./ai_init.sh\033[0m"
	exit 1
fi

log_info "脚本启动：开始 AI 核心环境自动化构建"

# ==========================================
# 1. 基础系统网络与排错工具箱
# ==========================================
log_info "阶段 1/5：补全 Minimized 缺失的基础工具"
apt-get update $APT_OPT
# pciutils(包含lspci), software-properties-common(管理PPA必备), curl/wget(下载利器), tmux(防断网神嚣)
# [优化] 加入 ubuntu-drivers-common 作为常驻排错工具，方便未来手动查询最新驱动列表
apt-get install $APT_OPT \
	curl wget vim git htop tmux pciutils \
	software-properties-common apt-transport-https ca-certificates gnupg lsb-release \
	ubuntu-drivers-common

# ==========================================
# 2. 内核编译环境构建 (NVIDIA驱动强依赖)
# ==========================================
log_info "阶段 2/5：准备底层编译环境 (Build Essentials & Kernel Headers)"
# 只有匹配当前系统内核版本的 headers，DKMS 才能成功编译闭源显卡驱动
apt-get install $APT_OPT build-essential dkms linux-headers-$(uname -r)

# ==========================================
# 3. 核心：NVIDIA 显卡驱动安装
# ==========================================
log_info "阶段 3/5：配置 NVIDIA 闭源驱动"
if ! command -v nvidia-smi &>/dev/null; then
	# 安装最推荐的无头(headless)服务器版本驱动, 手动指定了版本，避免 ubuntu-drivers 自动安装过旧或过新的版本导致兼容性问题
	# headless 版本不会安装多余的桌面 GUI 依赖，极其适合纯算力节点
	log_info "正在直接拉取并编译 $NVIDIA_DRIVER_PKG (耗时较长，请耐心等待)..."
	apt-get install $APT_OPT $NVIDIA_DRIVER_PKG

else
	log_warn "检测到 nvidia-smi 已存在，跳过显卡驱动安装，保证幂等性。"
fi

# ==========================================
# 4. 容器化基础设施：Docker Engine (官方源)
# ==========================================
log_info "阶段 4/5：安装官方最新版 Docker Engine"
if ! command -v docker &>/dev/null; then
	# 卸载可能存在的旧版/残缺版
	apt-get remove $APT_OPT docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc || true

	# 导入 Docker 官方 GPG 密钥并添加官方仓库
	install -m 0755 -d /etc/apt/keyrings
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
	chmod a+r /etc/apt/keyrings/docker.asc
	echo \
		"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" |
		tee /etc/apt/sources.list.d/docker.list >/dev/null

	apt-get update $APT_OPT
	apt-get install $APT_OPT docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
else
	log_warn "检测到 Docker 已安装，跳过 Docker 安装。"
fi

# ==========================================
# 5. 高维融合：NVIDIA Container Toolkit (让Docker调用GPU)
# ==========================================
log_info "阶段 5/5：配置 NVIDIA Docker 容器工具链与权限"
# [核心修复] 避免 grep -q 和 pipefail 引起的 SIGPIPE 陷阱，改用 command -v 检测核心可执行文件
if ! command -v nvidia-ctk &>/dev/null; then
	curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor --yes -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
	curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list |
		sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' |
		tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

	apt-get update $APT_OPT
	apt-get install $APT_OPT nvidia-container-toolkit

	# 配置 Docker 默认使用 NVIDIA runtime 并重启服务
	nvidia-ctk runtime configure --runtime=docker
	# systemctl restart docker
else
	log_warn "检测到 NVIDIA Container Toolkit 已配置，跳过。"
fi

# ---------------------------------------------------------
log_info "附加配置：注入 Docker 守护进程级网络代理"
DOCKER_PROXY_DIR="/etc/systemd/system/docker.service.d"
DOCKER_PROXY_FILE="${DOCKER_PROXY_DIR}/http-proxy.conf"

# 幂等操作：直接创建目录并覆盖写入最新的代理配置
mkdir -p "$DOCKER_PROXY_DIR"
cat <<EOF >"$DOCKER_PROXY_FILE"
[Service]
Environment="HTTP_PROXY=http://192.168.2.3:7890"
Environment="HTTPS_PROXY=http://192.168.2.3:7890"
Environment="NO_PROXY=localhost,127.0.0.1,::1"
EOF
log_info "Docker 全局代理已部署至：$DOCKER_PROXY_FILE"

# 防御性编程：重载 systemd 守护进程以应用代理，并确保 Docker 开机自启
systemctl daemon-reload

# 防御性编程：确保服务绝对开机自启并应用最新配置
systemctl enable docker
systemctl restart docker

# 核心修正：识别真实身份，加入 Docker 免密组
if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
	if ! id -nG "$SUDO_USER" | grep -qw "docker"; then
		usermod -aG docker "$SUDO_USER"
		log_info "安全授权：已将原用户 '$SUDO_USER' 加入 docker 组。重启后可免 sudo 执行 docker 命令。"
	else
		log_warn "用户 '$SUDO_USER' 已经是 docker 组成员，跳过授权。"
	fi
fi

# ==========================================
# 6. (可选) 网络魔法：Tailscale
# ==========================================
log_info "附加阶段：安装 Tailscale (SD-WAN 网络层)"
if ! command -v tailscale &>/dev/null; then
	curl -fsSL https://tailscale.com/install.sh | sh
else
	log_warn "检测到 Tailscale 已安装，跳过。"
fi

# ==========================================
# 清理与收尾
# ==========================================
log_info "执行系统清理与收尾工作..."
apt-get autoremove $APT_OPT
apt-get clean $APT_OPT

log_info "========================================================="
log_info "🎉 AI 节点基础环境部署完成！"
log_info "⚠️  请注意：NVIDIA 驱动需要重启后才能被内核正式接管！"
log_info "请执行命令：sudo reboot"
log_info "重启后，敲击 'nvidia-smi' 验证 RTX 3090 是否就绪。"
log_info "随后可执行 'sudo tailscale up' 接入你的高维网络。"
log_info "========================================================="

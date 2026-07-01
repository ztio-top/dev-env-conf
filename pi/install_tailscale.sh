#!/bin/bash
# Tailscale 幂等安装与配置脚本 (适用 Raspberry Pi OS / Debian)
# 包含：自动更新、自动推断网段、Sysctl 转发持久化、网卡 UDP GRO 优化持久化

# 颜色输出配置
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=================================================${NC}"
echo -e "${GREEN}      Tailscale 自动化安装与极致优化脚本         ${NC}"
echo -e "${GREEN}=================================================${NC}"

# 1. 前置权限检查
if [ "$EUID" -ne 0 ]; then
	echo -e "${RED}[错误] 请使用 sudo 或 root 权限运行此脚本。${NC}"
	exit 1
fi

# 2. 更新系统软件包
echo -e "${YELLOW}[+] 正在更新系统软件包列表并执行升级...${NC}"
echo -e "${YELLOW}    (根据网络情况可能需要一些时间，请耐心等待)${NC}"
apt update && apt upgrade -y
echo -e "${GREEN}[+] 系统软件包更新完成。${NC}"
echo ""

# 3. 幂等安装 Tailscale
if ! command -v tailscale &>/dev/null; then
	echo -e "${YELLOW}[+] 未检测到 Tailscale，正在自动安装...${NC}"
	curl -fsSL https://tailscale.com/install.sh | sh
	echo -e "${GREEN}[+] Tailscale 安装完成。${NC}"
else
	echo -e "${GREEN}[+] 检测到 Tailscale 已安装，跳过安装步骤。${NC}"
fi

# 4. 推测本机局域网段与默认网卡
# 严谨处理：加上 head -n 1 防止存在多个默认路由时报错
DEFAULT_IFACE=$(ip route | grep default | head -n 1 | awk '{print $5}')
if [ -n "$DEFAULT_IFACE" ]; then
	# 获取该网卡对应的网段，例如 192.168.1.0/24
	NETWORK_CIDR=$(ip route | grep -v default | grep "$DEFAULT_IFACE" | head -n 1 | awk '{print $1}')
fi

if [ -z "$NETWORK_CIDR" ]; then
	NETWORK_CIDR="无法自动推测，请手动输入"
fi

# 5. 交互式配置 Subnets 与 性能优化
TAILSCALE_ARGS=""
echo ""
read -p "是否需要将此设备配置为子网路由器 (Subnet Router)? [y/N]: " ENABLE_SUBNET

if [[ "$ENABLE_SUBNET" =~ ^[Yy]$ ]]; then
	echo -e "${YELLOW}[*] 推测到当前局域网段为: ${NETWORK_CIDR}${NC}"
	read -p "请确认网段 (输入 y 使用推测网段，或直接输入自定义网段如 10.0.0.0/24): " CIDR_INPUT

	if [[ -z "$CIDR_INPUT" || "$CIDR_INPUT" =~ ^[Yy]$ ]]; then
		FINAL_CIDR=$NETWORK_CIDR
	else
		FINAL_CIDR=$CIDR_INPUT
	fi

	echo -e "${GREEN}[+] 最终确认使用网段: $FINAL_CIDR${NC}"

	# --- 5.1 幂等配置 sysctl IP 转发 ---
	SYSCTL_CONF="/etc/sysctl.d/99-tailscale.conf"
	echo -e "${YELLOW}[+] 正在配置系统 IP 转发...${NC}"

	# 检查并追加 IPv4
	if ! grep -q "^net.ipv4.ip_forward = 1" "$SYSCTL_CONF" 2>/dev/null; then
		echo 'net.ipv4.ip_forward = 1' | tee -a "$SYSCTL_CONF" >/dev/null
		echo -e "  -> 已追加 IPv4 转发配置"
	else
		echo -e "  -> IPv4 转发已配置，跳过"
	fi

	if ! grep -q "^net.ipv6.conf.all.forwarding = 1" "$SYSCTL_CONF" 2>/dev/null; then
		echo 'net.ipv6.conf.all.forwarding = 1' | tee -a "$SYSCTL_CONF" >/dev/null
		echo -e "  -> 已追加 IPv6 转发配置"
	else
		echo -e "  -> IPv6 转发已配置，跳过"
	fi

	# 立即生效
	sysctl -p "$SYSCTL_CONF" >/dev/null

	# --- 5.2 幂等配置网卡 UDP GRO 优化 ---
	echo -e "${YELLOW}[+] 正在配置 UDP GRO 转发优化 (消除吞吐量警告)...${NC}"

	# 确保 ethtool 已安装
	if ! command -v ethtool &>/dev/null; then
		echo -e "  -> 正在安装 ethtool..."
		apt install ethtool -y >/dev/null
	fi

	if [ -n "$DEFAULT_IFACE" ]; then
		# 立即生效
		ethtool -K "$DEFAULT_IFACE" rx-udp-gro-forwarding on rx-gro-list off 2>/dev/null
		echo -e "  -> 已对当前网卡 [$DEFAULT_IFACE] 开启 UDP GRO 优化"

		# 幂等写入 Systemd 服务以保证开机自启生效
		SERVICE_FILE="/etc/systemd/system/tailscale-udp-gro.service"
		cat <<EOF >"$SERVICE_FILE"
[Unit]
Description=Tailscale UDP GRO Optimization for $DEFAULT_IFACE
After=network.target

[Service]
Type=oneshot
# 使用完整路径，树莓派系统通常在 /sbin/ethtool 或 /usr/sbin/ethtool
ExecStart=/bin/sh -c 'ethtool -K $DEFAULT_IFACE rx-udp-gro-forwarding on rx-gro-list off || true'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
		# 重载 systemd 并启用服务 (这里可以随意重复执行，符合幂等性)
		systemctl daemon-reload
		systemctl enable tailscale-udp-gro.service >/dev/null 2>&1
		echo -e "  -> 已写入并激活 Systemd 守护任务，重启不失效"
	else
		echo -e "${RED}  -> 无法识别默认网卡，跳过 UDP 优化${NC}"
	fi

	# 拼接 Tailscale 参数
	TAILSCALE_ARGS="--advertise-routes=$FINAL_CIDR"
else
	echo -e "${YELLOW}[+] 已跳过 Subnet Router 及其相关优化配置。${NC}"
fi

# 6. 启动或更新 Tailscale 状态
echo ""
echo -e "${YELLOW}[+] 正在应用 Tailscale 配置并拉起服务...${NC}"
echo -e "执行命令: tailscale up $TAILSCALE_ARGS"

# 运行 Tailscale
tailscale up $TAILSCALE_ARGS

echo ""
echo -e "${GREEN}=================================================${NC}"
echo -e "${GREEN}      Tailscale 配置执行完毕！                   ${NC}"
if [[ "$ENABLE_SUBNET" =~ ^[Yy]$ ]]; then
	echo -e "${YELLOW}提示: 作为子网路由器，请不要忘记前往 Tailscale Admin Console网页端批准(Approve)此设备的路由宣告！${NC}"
fi
echo -e "${GREEN}=================================================${NC}"

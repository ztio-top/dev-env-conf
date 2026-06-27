#!/usr/bin/env bash
# 开启遇到错误即退出的模式
set -e

echo "========================================================="
echo "  Proxmox VE (PVE) 9.x on Debian 13 自动安装脚本  "
echo "  特点: 幂等性、代理继承、严格复刻 PVE 官方 LVM 命名"
echo "========================================================="

# 1. 检查 Root 权限
if [[ $EUID -ne 0 ]]; then
	echo "❌ 错误: 此脚本必须以 root 用户运行。"
	echo "👉 提示: 请使用 'sudo -E ./install_pve.sh' 运行，以保留代理环境变量！"
	exit 1
fi

# 2. 代理环境变量继承与配置
# 使用 trap 确保脚本无论成功还是失败退出，都会清理临时的 apt 代理文件
TEMP_APT_PROXY="/etc/apt/apt.conf.d/99proxy_temp"
trap 'rm -f $TEMP_APT_PROXY' EXIT

if [ -n "$http_proxy" ] || [ -n "$https_proxy" ] || [ -n "$HTTP_PROXY" ] || [ -n "$HTTPS_PROXY" ]; then
	echo "🌐 检测到代理环境变量，正在为系统和 APT 配置代理..."
	# 统一转换变量
	PROXY_HTTP="${http_proxy:-$HTTP_PROXY}"
	PROXY_HTTPS="${https_proxy:-$HTTPS_PROXY}"

	# 临时写入 apt 配置，保证后续 apt-get 命令全部走代理
	echo "Acquire::http::Proxy \"$PROXY_HTTP\";" >"$TEMP_APT_PROXY"
	echo "Acquire::https::Proxy \"$PROXY_HTTPS\";" >>"$TEMP_APT_PROXY"

	export http_proxy="$PROXY_HTTP"
	export https_proxy="$PROXY_HTTPS"
	export ALL_PROXY="$PROXY_HTTP"
	echo "✅ 代理配置已应用: $PROXY_HTTP"
else
	echo "ℹ️ 未检测到任何代理环境变量 (http_proxy/https_proxy)，将直连网络。"
	echo "  (若你需要代理，请按 Ctrl+C 中断，export 代理后再使用 sudo -E 运行此脚本)"
	sleep 3
fi

# 3. EFI 分区安全检测
echo "🔍 正在扫描 EFI 分区布局..."
echo "---------------------------------------------------------"
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,PARTTYPE | grep -E "part|disk" | grep -v "lvm"
echo "---------------------------------------------------------"
echo "⚠️  请确认上述设备中，Windows EFI 分区未被错误覆盖。"
read -p "❓ 确认 EFI 布局无误，继续安装？(y/N): " CONFIRM_EFI
[[ ! "$CONFIRM_EFI" =~ ^[Yy]$ ]] && {
	echo "用户中断。"
	exit 0
}

# 3. 检查主机名解析
CURRENT_IP=$(hostname --ip-address || echo "error")
if [[ "$CURRENT_IP" == "127.0.1.1" ]] || [[ "$CURRENT_IP" == "error" ]]; then
	echo "❌ 错误: 主机名解析不正确，当前指向 127.0.1.1 或无法解析。"
	echo "请检查 /etc/hosts，确保你的主机名指向了真实的局域网静态 IP。"
	exit 1
fi
echo "✅ 主机名解析检查通过: $CURRENT_IP"

# 4. 安装基础依赖
echo "📦 正在检查并安装基础依赖..."
apt-get update -qq
# 增加了 parted 和 bc，用于后续自动计算和划分磁盘分区
apt-get install -y -qq curl wget gnupg2 lvm2 parted bc

# 5. 添加 PVE GPG 密钥
KEY_URL="https://enterprise.proxmox.com/debian/proxmox-release-trixie.gpg"
KEY_PATH="/etc/apt/trusted.gpg.d/proxmox-release-trixie.gpg"
if [ ! -f "$KEY_PATH" ]; then
	echo "🔑 正在下载并添加 Proxmox 官方 GPG 密钥..."
	wget -q "$KEY_URL" -O "$KEY_PATH"
else
	echo "✅ Proxmox GPG 密钥已存在。"
fi

# 6. 添加 PVE 软件源
REPO_FILE="/etc/apt/sources.list.d/pve-install-repo.list"
REPO_LINE="deb [arch=amd64] http://download.proxmox.com/debian/pve trixie pve-no-subscription"
if [ ! -f "$REPO_FILE" ] || ! grep -q "^$REPO_LINE" "$REPO_FILE"; then
	echo "🌐 正在配置 PVE 无订阅版软件源..."
	echo "$REPO_LINE" >"$REPO_FILE"
else
	echo "✅ PVE 软件源已配置。"
fi

# 7. 预配置 Postfix (无交互静默安装)
echo "⚙️  正在预配置 Postfix 邮件服务 (Local Only)..."
export DEBIAN_FRONTEND=noninteractive
debconf-set-selections <<<"postfix postfix/main_mailer_type select Local only"
debconf-set-selections <<<"postfix postfix/mailname string $(hostname -f)"

# 8. 安装 PVE 核心套件
echo "🚀 正在全量升级系统并安装 Proxmox VE 核心套件 (这可能需要几分钟)..."
apt-get update -qq
apt-get full-upgrade -y -qq
apt-get install -y -qq proxmox-ve postfix open-iscsi chrony

# 9. 严格命名的 LVM-Thin 交互配置
echo ""
echo "💽 开始探测系统存储状态 (准备配置与官方同名的 pve-data 池)..."
if pvesm status 2>/dev/null | grep -q "local-lvm"; then
	echo "✅ 存储 local-lvm 已在 PVE 中注册，无需重复配置。"
else
	VG_NAME=""
	TARGET_DISK=""
	PROPOSED_ACTION=""
	WARNING_MSG=""

	ROOT_MNT=$(findmnt -n -o SOURCE /)
	echo "   [探测] 根目录挂载点为: $ROOT_MNT"

	# 探测策略 A：检查现有的 LVM
	if [[ "$ROOT_MNT" == /dev/mapper/* ]]; then
		ROOT_VG=$(lvs --noheadings -o vg_name "$ROOT_MNT" | tr -d ' ' | head -n1)
		# 防止获取空值报错
		VG_FREE=$(vgs --noheadings -o vg_free --units g "$ROOT_VG" 2>/dev/null | tr -d ' gG<>' | head -n1 || echo "0")
		echo "   [探测] 发现根目录使用 LVM，所属卷组 (VG): [$ROOT_VG]，剩余可用空间: ${VG_FREE}G"

		if (($(echo "$VG_FREE > 10" | bc -l))); then
			VG_NAME="$ROOT_VG"
			PROPOSED_ACTION="在现有卷组 [$VG_NAME] 中，创建名为 [data] 的 Thin 池。"
			if [[ "$VG_NAME" != "pve" ]]; then
				WARNING_MSG="⚠️ 警告: 你的根目录 VG 名字是 '$VG_NAME' 而不是 'pve'。如果在里面创建 data 池，底层显示的将是 '${VG_NAME}-data'，无法做到和官方完全一致的 'pve-data'。由于根目录 VG 无法在线改名，这是受限于你安装 Debian 时的分区命名。"
			else
				WARNING_MSG="🎯 完美匹配: 你的 VG 名字已经是 'pve'，创建出来的结构将与官方完全一致！"
			fi
		else
			echo "   [探测] ⚠️ 当前 VG 剩余空间不足 10G，放弃在此 VG 内创建。"
		fi
	fi

	# 探测策略 B：物理磁盘未分配空间
	if [ -z "$VG_NAME" ]; then
		if [[ "$ROOT_MNT" == /dev/mapper/* ]]; then
			ROOT_PART=$(pvs --noheadings -o pv_name $(lvs --noheadings -o vg_name "$ROOT_MNT" | tr -d ' ' | head -n1) | tr -d ' ' | head -n1)
			ROOT_DISK=$(lsblk -no pkname "$ROOT_PART" | head -n1)
		else
			ROOT_DISK=$(lsblk -no pkname "$ROOT_MNT" | head -n1)
		fi
		ROOT_DISK="/dev/$ROOT_DISK"
		TARGET_DISK="$ROOT_DISK"

		echo "   [探测] 发现根目录所在物理主磁盘为: $TARGET_DISK"
		PROPOSED_ACTION="尝试在 [$TARGET_DISK] 划分剩余所有空间，新建名为 [pve] 的卷组，并创建名为 [data] 的 Thin 池。"
		WARNING_MSG="🎯 完美匹配: 这将生成原汁原味的 'pve-data' 底层架构！"
	fi

	# --- 交互确认 ---
	echo ""
	echo "========================================================="
	echo "⚠️  LVM-Thin 存储操作确认"
	echo "👉 拟执行操作: $PROPOSED_ACTION"
	if [ -n "$WARNING_MSG" ]; then echo -e "$WARNING_MSG"; fi
	echo "========================================================="
	read -p "❓ 是否允许执行上述操作？(输入 y 确认，输入 n 跳过): " CONFIRM_LVM

	if [[ "$CONFIRM_LVM" =~ ^[Yy]$ ]]; then
		# 路线 A
		if [ -n "$VG_NAME" ]; then
			echo "⏳ 正在 [$VG_NAME] 创建 LVM-Thin 池 (data)..."
			lvcreate -l 100%FREE --type thin-pool --thinpool data "$VG_NAME" -y >/dev/null 2>&1

		# 路线 B
		elif [ -n "$TARGET_DISK" ]; then
			echo "⏳ 正在 $TARGET_DISK 划分新分区..."
			set +e
			fdisk "$TARGET_DISK" <<EOF >/dev/null 2>&1
n



t

8e
w
EOF
			set -e
			partprobe "$TARGET_DISK"
			sleep 2

			NEW_PART=$(lsblk -rn -o NAME "$TARGET_DISK" | tail -n 1)
			NEW_PART="/dev/$NEW_PART"

			echo "⏳ 正在 $NEW_PART 创建官方同名的卷组 'pve' ..."
			if pvcreate "$NEW_PART" >/dev/null 2>&1; then
				vgcreate pve "$NEW_PART" >/dev/null 2>&1
				VG_NAME="pve"
				echo "⏳ 正在 [pve] 创建名为 'data' 的 LVM-Thin 池..."
				lvcreate -l 100%FREE --type thin-pool --thinpool data "$VG_NAME" -y >/dev/null 2>&1
			else
				echo "❌ 失败：无法在 $TARGET_DISK 划分分区或创建 PV。"
				VG_NAME=""
			fi
		fi

		# 挂载到 PVE 存储配置表
		if [ -n "$VG_NAME" ] && lvs "$VG_NAME/data" >/dev/null 2>&1; then
			echo "⏳ 正在将 'local-lvm' 注册到 PVE 面板..."
			pvesm add lvmthin local-lvm --vgname "$VG_NAME" --thinpool data --content rootdir,images >/dev/null 2>&1 || true
			echo "🎉 LVM-Thin (local-lvm) 配置成功！"
		fi
	else
		echo "⏭️  跳过 LVM-Thin 自动配置。"
	fi
fi

# 10. 移除 os-prober
if dpkg -l | grep -q "^ii  os-prober"; then
	echo "🧹 移除不推荐的 os-prober..."
	apt-get remove -y -qq os-prober
fi

echo "========================================================="
echo "🎉 PVE 9.2 安装执行完毕！请运行 'reboot' 重启生效。"
echo "========================================================="

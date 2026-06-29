#!/bin/bash
set -e
set -o pipefail

echo "====================================================="
echo "  PVE 最终版: AMD 780M iGPU/KFD 动态直通注入脚本     "
echo "====================================================="

# 1. 基础环境与权限检测
if [ "$EUID" -ne 0 ]; then
	echo "❌ 请使用 root 权限"
	exit 1
fi
# if ! lsmod | grep -qw amdgpu; then
# 	echo "❌ 未检测到 amdgpu 驱动"
# 	exit 1
# fi
# 2. 硬件级别验证 (不再依赖 lsmod，直接查 PCI 设备状态)
echo "🔍 正在扫描 AMD GPU 硬件..."
if lspci -k | grep -A 3 -E "(VGA|Display)" | grep -q "Kernel driver in use: amdgpu"; then
	echo "✅ [通过] 检测到 AMD GPU，且 Kernel driver 正在使用 amdgpu。"
else
	echo "❌ 错误: 未能在 PCI 总线找到使用 amdgpu 驱动的设备。"
	echo "   如果你的显卡能正常工作，请检查 lspci -k | grep -A 3 -E '(VGA|Display)' 的输出。"
	exit 1
fi

# 2. 获取容器 ID 参数
LXC_ID=$1
if [ -z "$LXC_ID" ]; then read -p "👉 请输入容器 ID (例如 100): " LXC_ID; fi
CONF_FILE="/etc/pve/lxc/${LXC_ID}.conf"
if [ ! -f "$CONF_FILE" ]; then
	echo "❌ 容器配置不存在"
	exit 1
fi

# 3. 动态探测设备路径 (card, render, kfd)
AMD_CARD=""
for sys_card in /sys/class/drm/card*; do
	if [ -L "$sys_card/device/driver" ] && [ "$(basename $(readlink -f "$sys_card/device/driver"))" = "amdgpu" ]; then
		AMD_CARD=$(basename "$sys_card")
		break
	fi
done
AMD_RENDER=$(ls /sys/class/drm/$AMD_CARD/device/drm 2>/dev/null | grep -E '^renderD[0-9]+' | head -n 1)
KFD_DEV_NUM=$(cat /sys/class/kfd/dev 2>/dev/null || echo "510:0") # 默认值，通常会自动读取

# 提取设备主次号
CARD_DEV_NUM=$(cat /sys/class/drm/$AMD_CARD/dev)
RENDER_DEV_NUM=$(cat /sys/class/drm/$AMD_RENDER/dev)

# 4. 获取组 ID
VIDEO_GID=$(getent group video | cut -d: -f3)
RENDER_GID=$(getent group render | cut -d: -f3)
[ -z "$VIDEO_GID" ] || [ -z "$RENDER_GID" ] && {
	echo "❌ 组ID获取失败"
	exit 1
}

# 5. 幂等更新 /etc/subgid (这是关键，防止多次写入)
for gid in $VIDEO_GID $RENDER_GID; do
	grep -q "root:$gid:1" /etc/subgid || echo "root:$gid:1" >>/etc/subgid
done

# 6. 生成注入配置块
BLOCK_MARKER="# --- AMD 780M iGPU/KFD Passthrough ---"
BLOCK_END="# ----------------------------------------"

# 动态计算 idmap (处理 video 和 render 组顺序)
if [ "$VIDEO_GID" -gt "$RENDER_GID" ]; then
	G1=$RENDER_GID
	G2=$VIDEO_GID
else
	G1=$VIDEO_GID
	G2=$RENDER_GID
fi

MAP_BLOCK=$(
	cat <<EOF
$BLOCK_MARKER
lxc.cgroup2.devices.allow: c $CARD_DEV_NUM rwm
lxc.cgroup2.devices.allow: c $RENDER_DEV_NUM rwm
lxc.cgroup2.devices.allow: c $KFD_DEV_NUM rwm
lxc.mount.entry: /dev/dri/$AMD_CARD dev/dri/$AMD_CARD none bind,optional,create=file
lxc.mount.entry: /dev/dri/$AMD_RENDER dev/dri/$AMD_RENDER none bind,optional,create=file
lxc.mount.entry: /dev/kfd dev/kfd none bind,optional,create=file
lxc.idmap: u 0 100000 65536
lxc.idmap: g 0 100000 $G1
lxc.idmap: g $G1 $G1 1
lxc.idmap: g $((G1 + 1)) $((100000 + G1 + 1)) $((G2 - G1 - 1))
lxc.idmap: g $G2 $G2 1
lxc.idmap: g $((G2 + 1)) $((100000 + G2 + 1)) $((65536 - G2 - 1))
$BLOCK_END
EOF
)

# 7. 注入到配置文件 (使用 sed 进行幂等替换)
echo "⚙️ 正在向 $CONF_FILE 注入配置..."
sed -i "/^$BLOCK_MARKER$/,/^$BLOCK_END$/d" "$CONF_FILE"
echo "$MAP_BLOCK" >>"$CONF_FILE"

echo "====================================================="
echo "🎉 容器 $LXC_ID 的 780M 直通配置已成功更新并写入！"
echo "⚠️  极其重要：请在 PVE 网页端将该容器【彻底关机 (Shutdown)】，"
echo "   然后再【开机 (Start)】，千万不要使用重启 (Restart)！"
echo "====================================================="

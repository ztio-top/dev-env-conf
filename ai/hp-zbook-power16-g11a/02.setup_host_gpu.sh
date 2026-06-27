#!/bin/bash
# 开启遇到错误即退出的严格模式
set -e

echo "====================================================="
echo "  PVE 9.2 Host: AMD 780M iGPU 动态映射与配置脚本     "
echo "====================================================="

# 1. 检查是否为 root 用户执行
if [ "$EUID" -ne 0 ]; then
	echo "❌ 错误: 请使用 root 用户权限运行此脚本。"
	exit 1
fi

# 2. 检查 amdgpu 驱动是否已加载
if ! lsmod | grep -qw amdgpu; then
	echo "❌ 错误: 未检测到 amdgpu 内核模块，驱动未加载。"
	exit 1
fi
echo "✅ [通过] amdgpu 内核驱动已加载。"

# 3. 动态寻找 AMD 显卡的 card 设备节点
AMD_CARD=""
for sys_card in /sys/class/drm/card*; do
	if [ -L "$sys_card/device/driver" ]; then
		DRIVER_NAME=$(basename $(readlink -f "$sys_card/device/driver"))
		if [ "$DRIVER_NAME" = "amdgpu" ]; then
			AMD_CARD=$(basename "$sys_card")
			break
		fi
	fi
done

if [ -z "$AMD_CARD" ]; then
	echo "❌ 错误: 未能找到绑定到 amdgpu 驱动的显卡设备 (cardX)。"
	exit 1
fi
echo "✅ [通过] 成功定位 AMD 核显主设备节点: /dev/dri/$AMD_CARD"

# 4. 动态寻找对应的 render 设备节点
AMD_RENDER=$(ls /sys/class/drm/$AMD_CARD/device/drm 2>/dev/null | grep -E '^renderD[0-9]+' | head -n 1 || true)
if [ -z "$AMD_RENDER" ]; then
	echo "❌ 错误: 未能找到 $AMD_CARD 对应的 render 节点。"
	exit 1
fi
echo "✅ [通过] 成功定位 AMD 核显渲染节点: /dev/dri/$AMD_RENDER"

# 5. 自动获取设备的主次设备号 (Major:Minor)
CARD_DEV_NUM=$(cat /sys/class/drm/$AMD_CARD/dev)
RENDER_DEV_NUM=$(cat /sys/class/drm/$AMD_RENDER/dev)

# 6. 获取 video 和 render 组的 GID
VIDEO_GID=$(getent group video | cut -d: -f3)
RENDER_GID=$(getent group render | cut -d: -f3)

if [ -z "$VIDEO_GID" ] || [ -z "$RENDER_GID" ]; then
	echo "❌ 错误: 无法获取 video 或 render 组的 GID，请检查系统用户组。"
	exit 1
fi
echo "✅ [通过] 提取到系统组 ID -> video: $VIDEO_GID, render: $RENDER_GID"

# 7. 幂等更新 /etc/subgid
update_subgid() {
	local group_name=$1
	local gid=$2
	local entry="root:${gid}:1"
	local subgid_file="/etc/subgid"

	if grep -q "^${entry}$" "$subgid_file"; then
		echo "⏭️  [跳过] /etc/subgid 已包含 $group_name ($gid) 的映射。"
	else
		echo "$entry" >>"$subgid_file"
		echo "✅ [完成] 已将 $group_name ($gid) 的映射写入 /etc/subgid。"
	fi
}

update_subgid "video" "$VIDEO_GID"
update_subgid "render" "$RENDER_GID"

echo ""
echo "====================================================="
echo "🎉 宿主机阶段配置完成！这是为你量身定制的 LXC 配置："
echo "====================================================="
echo "请使用 'nano /etc/pve/lxc/<你的容器ID>.conf' 编辑配置文件，"
echo "并将以下内容粘贴到文件的最末尾："
echo ""
echo "# --- AMD 780M iGPU Passthrough ---"
echo "lxc.cgroup2.devices.allow: c $CARD_DEV_NUM rwm"
echo "lxc.cgroup2.devices.allow: c $RENDER_DEV_NUM rwm"
echo "lxc.mount.entry: /dev/dri/$AMD_CARD dev/dri/$AMD_CARD none bind,optional,create=file"
echo "lxc.mount.entry: /dev/dri/$AMD_RENDER dev/dri/$AMD_RENDER none bind,optional,create=file"
echo ""
echo "# UID/GID Mapping"
echo "lxc.idmap: u 0 100000 65536"
echo "lxc.idmap: g 0 100000 $VIDEO_GID"
echo "lxc.idmap: g $VIDEO_GID $VIDEO_GID 1"
echo "lxc.idmap: g $((VIDEO_GID + 1)) 1000$((VIDEO_GID + 1)) $((RENDER_GID - VIDEO_GID - 1))"
echo "lxc.idmap: g $RENDER_GID $RENDER_GID 1"
echo "lxc.idmap: g $((RENDER_GID + 1)) 100$((RENDER_GID + 1)) $((65536 - RENDER_GID - 1))"
echo "# ---------------------------------"
echo ""
echo "⚠️ 注意：以上 idmap 规则是根据你当前宿主机 video=${VIDEO_GID}, render=${RENDER_GID} 自动精确计算生成的。"

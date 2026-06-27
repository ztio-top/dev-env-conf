#!/bin/bash
# 开启遇到错误即退出的严格模式
set -e

echo "====================================================="
echo "  PVE 9.2 Host: AMD 780M iGPU Stage 1 Check & Prep   "
echo "====================================================="

# 1. 检查是否为 root 用户执行
if [ "$EUID" -ne 0 ]; then
	echo "❌ 错误: 请使用 root 用户权限运行此脚本。"
	exit 1
fi

# 2. 检查 amdgpu 驱动是否已加载
if ! lsmod | grep -qw amdgpu; then
	echo "❌ 错误: 未检测到 amdgpu 内核模块，请检查 PVE 宿主机的内核或 BIOS 设置。"
	exit 1
fi
echo "✅ [通过] amdgpu 驱动已成功加载。"

# 3. 检查字符设备文件是否存在
if [ ! -c /dev/dri/card0 ] || [ ! -c /dev/dri/renderD128 ]; then
	echo "❌ 错误: 未能在 /dev/dri/ 下找到 card0 或 renderD128 设备。"
	exit 1
fi
echo "✅ [通过] 显卡设备文件 (card0, renderD128) 存在。"

# 4. 获取 video 和 render 组的 GID
VIDEO_GID=$(getent group video | cut -d: -f3)
RENDER_GID=$(getent group render | cut -d: -f3)

if [ -z "$VIDEO_GID" ] || [ -z "$RENDER_GID" ]; then
	echo "❌ 错误: 无法获取 video 或 render 组的 GID。"
	exit 1
fi
echo "ℹ️  [信息] 提取到的 GID -> video: $VIDEO_GID, render: $RENDER_GID"

# 5. 幂等更新 /etc/subgid (为无特权 LXC 容器做准备)
# 函数：如果映射不存在，则添加映射
update_subgid() {
	local group_name=$1
	local gid=$2
	local entry="root:${gid}:1"
	local subgid_file="/etc/subgid"

	# 检查文件中是否已经包含该条目 (精确匹配)
	if grep -q "^${entry}$" "$subgid_file"; then
		echo "⏭️  [跳过] /etc/subgid 已包含 $group_name ($gid) 的映射，无需重复添加。"
	else
		echo "$entry" >>"$subgid_file"
		echo "✅ [完成] 已将 $group_name ($gid) 的映射写入 /etc/subgid。"
	fi
}

update_subgid "video" "$VIDEO_GID"
update_subgid "render" "$RENDER_GID"

echo "====================================================="
echo "🎉 宿主机阶段检查与配置已全部完成！"
echo "你可以继续去创建你的 Ubuntu 24.04 容器了。"
echo "====================================================="

#!/bin/bash

# 自动寻找第一个可用的背光设备目录
B_DIR=$(ls -d /sys/class/backlight/* 2>/dev/null | head -n 1)

if [ -z "$B_DIR" ]; then
	echo "错误: 未找到背光控制节点，请确认 EDATEC 屏幕驱动是否已正确加载。"
	exit 1
fi

case "$1" in
off)
	# 方案 A: 亮度调至 0
	echo 0 | sudo tee "$B_DIR/brightness" >/dev/null

	# 方案 B: 改变电源状态 (4 为关闭，0 为开启。如果方案 A 没彻底黑屏，可以取消下面这行的注释)
	# echo 4 | sudo tee "$B_DIR/bl_power" > /dev/null

	echo "屏幕背光已关闭 (省电模式)"
	;;
on)
	# 获取屏幕支持的最大亮度
	MAX_B=$(cat "$B_DIR/max_brightness")

	# 恢复亮度
	echo "$MAX_B" | sudo tee "$B_DIR/brightness" >/dev/null

	# 恢复电源状态
	# echo 0 | sudo tee "$B_DIR/bl_power" > /dev/null

	echo "屏幕背光已开启"
	;;
*)
	echo "用法: $0 {on|off}"
	exit 1
	;;
esac

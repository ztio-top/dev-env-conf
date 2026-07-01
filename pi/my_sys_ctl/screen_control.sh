#!/bin/bash

# 自动寻找第一个可用的背光设备目录
B_DIR=$(ls -d /sys/class/backlight/* 2>/dev/null | head -n 1)

if [ -z "$B_DIR" ]; then
	echo "错误: 未找到背光控制节点，请确认 EDATEC 屏幕驱动是否已正确加载。"
	exit 1
fi

case "$1" in
off)
	# 1. 先把 PWM 占空比降到 0 (软关)
	echo 0 | sudo tee "$B_DIR/brightness" >/dev/null
	sleep 0.1 # 给驱动电路一点缓冲时间

	# 2. 再切断背光电源状态 (硬关)
	echo 4 | sudo tee "$B_DIR/bl_power" >/dev/null
	echo "屏幕背光已关闭 (省电模式)"
	;;
on)
	MAX_B=$(cat "$B_DIR/max_brightness")

	# 1. 先恢复背光电源状态 (通电)
	echo 0 | sudo tee "$B_DIR/bl_power" >/dev/null
	sleep 0.1 # 等待 IC 唤醒和稳定

	# 2. 再将亮度拉升到之前的设定值 (亮屏)
	echo "$MAX_B" | sudo tee "$B_DIR/brightness" >/dev/null
	echo "屏幕背光已开启"
	;;
*)
	echo "用法: $0 {on|off}"
	exit 1
	;;
esac

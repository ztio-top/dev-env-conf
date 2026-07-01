#!/bin/bash
#
# ============================================================
# ED-HMI3010-101C / Raspberry Pi 5 检测工具
#
# Version : 2.0
# Author  : ChatGPT
#
# 作用：
#   自动检测 Raspberry Pi + ED-HMI3010 的所有显示、
#   背光、GPIO、DSI、触摸等信息。
#
# 使用：
#   chmod +x check_ed_hmi_v2.sh
#   ./check_ed_hmi_v2.sh | tee result.txt
#
# ============================================================

echo
echo "======================================================"
echo " ED-HMI3010-101C Hardware Diagnose Tool v2.0"
echo "======================================================"
echo

##############################################
# 系统信息
##############################################

echo "========== 系统 =========="
cat /etc/os-release
echo

echo "========== Kernel =========="
uname -a
echo

echo "========== CPU =========="
cat /proc/cpuinfo
echo

echo "========== Model =========="
cat /proc/device-tree/model
echo

##############################################
# Boot 参数
##############################################

echo "========== cmdline =========="
cat /boot/firmware/cmdline.txt 2>/dev/null
echo

echo "========== config.txt =========="
cat /boot/firmware/config.txt 2>/dev/null
echo

##############################################
# GPIO
##############################################

echo "========== pinctrl =========="
if command -v pinctrl >/dev/null; then
	pinctrl get
else
	echo "pinctrl not installed"
fi
echo

##############################################
# GPIO info
##############################################

echo "========== gpioinfo =========="
if command -v gpioinfo >/dev/null; then
	gpioinfo
else
	echo "gpioinfo not installed"
fi
echo

##############################################
# I2C
##############################################

echo "========== I2C Device =========="
ls /dev/i2c* 2>/dev/null
echo

echo "========== I2C Detect =========="
if command -v i2cdetect >/dev/null; then
	for bus in /dev/i2c-*; do
		BUS=${bus##*-}
		echo "------ BUS $BUS ------"
		i2cdetect -y $BUS
		echo
	done
fi

##############################################
# Backlight
##############################################

echo "========== Backlight =========="

if [ -d /sys/class/backlight ]; then

	for BL in /sys/class/backlight/*; do

		echo
		echo "Backlight : $BL"

		ls -l $BL

		echo

		for f in actual_brightness \
			brightness \
			max_brightness \
			bl_power \
			type \
			scale \
			power/runtime_status; do
			if [ -f "$BL/$f" ]; then
				echo "------ $f ------"
				cat "$BL/$f"
				echo
			fi
		done

	done

else
	echo "No backlight found."
fi

##############################################
# DRM
##############################################

echo
echo "========== DRM =========="

find /sys/class/drm | sort

echo

for f in /sys/class/drm/card*-*/status; do
	echo "$f"
	cat "$f"
	echo
done

##############################################
# Connector
##############################################

echo "========== modetest =========="

if command -v modetest >/dev/null; then
	modetest -c
else
	echo "modetest not installed."
fi

echo

##############################################
# 输入设备
##############################################

echo "========== Input =========="

cat /proc/bus/input/devices

echo

ls -l /dev/input

echo

##############################################
# evtest
##############################################

echo "========== evtest =========="

if command -v evtest >/dev/null; then

	for dev in /dev/input/event*; do
		echo
		echo "$dev"
		timeout 1 evtest "$dev" 2>/dev/null | head
	done

else
	echo "evtest not installed."
fi

##############################################
# Device Tree
##############################################

echo
echo "========== Device Tree =========="

find /proc/device-tree -iname "*goodix*" 2>/dev/null

find /proc/device-tree -iname "*panel*" 2>/dev/null

find /proc/device-tree -iname "*backlight*" 2>/dev/null

find /proc/device-tree -iname "*dsi*" 2>/dev/null

echo

##############################################
# Overlay
##############################################

echo "========== Overlay =========="

ls /proc/device-tree/chosen/overlays 2>/dev/null

echo

##############################################
# Dmesg
##############################################

echo "========== Dmesg Display =========="

dmesg | grep -Ei \
	"drm|dsi|panel|goodix|touch|backlight|gpio|i2c|gt9|ili|edid" | tail -500

echo

##############################################
# Systemd
##############################################

echo "========== Services =========="

systemctl --type=service | grep -Ei \
	"way|display|weston|lightdm|gdm|sddm|seat|vnc"

echo

##############################################
# Session
##############################################

echo "========== Session =========="

echo "XDG_SESSION_TYPE=$XDG_SESSION_TYPE"

loginctl show-session $XDG_SESSION_ID -p Type 2>/dev/null

echo

##############################################
# vcgencmd
##############################################

echo "========== vcgencmd =========="

if command -v vcgencmd >/dev/null; then

	vcgencmd version

	echo

	vcgencmd get_config int

	echo

	vcgencmd measure_temp

	echo

	vcgencmd get_throttled

fi

echo

##############################################
# lsmod
##############################################

echo "========== Kernel Module =========="

lsmod | grep -Ei \
	"goodix|panel|drm|backlight|gpio|i2c"

echo

##############################################
# DRM Debug
##############################################

echo "========== DRM Debug =========="

for p in /sys/kernel/debug/dri/*; do

	echo "$p"

	ls "$p"

	echo

done 2>/dev/null

##############################################
# 完成
##############################################

echo
echo "======================================================"
echo " Diagnose Finished"
echo "======================================================"
echo

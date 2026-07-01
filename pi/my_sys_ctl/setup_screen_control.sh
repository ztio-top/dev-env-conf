#!/bin/bash

# 确保脚本在发生错误时退出
set -e

echo "=========================================="
echo " 开始配置树莓派 5b / ED-HMI3010 自动息屏方案"
echo "=========================================="

# 1. 获取当前脚本所在的绝对路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTROL_SCRIPT="${SCRIPT_DIR}/screen_control.sh"
AUTOSTART_DIR="${HOME}/.config/wayfire.ini.d"
AUTOSTART_CONF="${AUTOSTART_DIR}/90-swayidle.ini"

# 2. 检查并安装 swayidle (幂等设计：apt 会自动跳过已安装的软件)
echo "[1/4] 检查并安装 swayidle..."
if ! command -v swayidle &>/dev/null; then
	sudo apt update && sudo apt install -y swayidle
else
	echo "-> swayidle 已经安装，跳过。"
fi

# 3. 检查并确保核心控制脚本 screen_control.sh 存在且具有执行权限
echo "[2/4] 验证控制脚本 ${CONTROL_SCRIPT}..."
if [ ! -f "$CONTROL_SCRIPT" ]; then
	echo "警告: 未在当前目录找到 screen_control.sh，正在自动创建默认版本..."
	cat <<'EOF' >"$CONTROL_SCRIPT"
#!/bin/bash
# 自动寻找第一个可用的背光设备目录
B_DIR=$(ls -d /sys/class/backlight/* 2>/dev/null | head -n 1)

if [ -z "$B_DIR" ]; then
    echo "错误: 未找到背光控制节点。"
    exit 1
fi

case "$1" in
    off)
	    # 方案 A: 亮度调至 0
        echo 0 | sudo tee "$B_DIR/brightness" > /dev/null
		# 方案 B: 改变电源状态 (4 为关闭，0 为开启。如果方案 A 没彻底黑屏，可以取消下面这行的注释)
		# echo 4 | sudo tee "$B_DIR/bl_power" > /dev/null

		echo "屏幕背光已关闭 (省电模式)"
        ;;
    on)
        MAX_B=$(cat "$B_DIR/max_brightness")
		# 恢复亮度
        echo "$MAX_B" | sudo tee "$B_DIR/brightness" > /dev/null
		# 恢复电源状态
		# echo 0 | sudo tee "$B_DIR/bl_power" > /dev/null
		echo "屏幕背光已开启"
        ;;
	*)
		echo "用法: $0 {on|off}"
esac
EOF
fi
chmod +x "$CONTROL_SCRIPT"
echo "-> 控制脚本已就绪。"

# 4. 配置 Wayfire 自启动 (幂等设计：直接覆盖独立配置文件或通过独立文件管理)
echo "[3/4] 配置 Wayland (Wayfire) 开机自启监听..."

# 树莓派 Debian 12 支持在 wayfire.ini.d 目录放入独立的配置片段，避免破坏主配置文件
mkdir -p "$AUTOSTART_DIR"

# 定义自启动指令（设置 300 秒/5分钟无操作自动息屏，有操作时亮屏）
# 使用绝对路径确保后台运行时能正确找到脚本
IDLE_CMD="swayidle -w timeout 300 '${CONTROL_SCRIPT} off' resume '${CONTROL_SCRIPT} on'"

cat <<EOF >"$AUTOSTART_CONF"
[autostart]
swayidle_timeout = ${IDLE_CMD}
EOF

echo "-> 自启配置文件已生成/更新: ${AUTOSTART_CONF}"

# 5. 立即在当前会话中启动（幂等设计：先杀掉旧的再启动新的，防止多实例冲突）
echo "[4/4] 激活当前会话的 swayidle 监听..."
if pgrep -x "swayidle" >/dev/null; then
	echo "-> 发现正在运行的 swayidle 实例，正在重置..."
	pkill -x "swayidle" || true
	sleep 1
fi

# 在后台启动 swayidle 监听
eval "$IDLE_CMD" &

echo "=========================================="
echo " 配置完成！"
echo " 当前设置：5分钟 (300秒) 无操作将自动关闭硬件背光省电。"
echo " 提示：键鼠操作或触摸屏幕即可恢复亮屏。"
echo "=========================================="

#!/bin/bash
set -e

echo "=========================================="
echo " 开始配置纯终端 (TTY) 环境的自动硬件息屏"
echo "=========================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTROL_SCRIPT="${SCRIPT_DIR}/screen_control.sh"
DAEMON_PY="${SCRIPT_DIR}/cli_idle_monitor.py"
SERVICE_FILE="/etc/systemd/system/screen-idle.service"

# 1. 安装底层输入监听依赖
echo "[1/4] 安装 python3-evdev..."
sudo apt update
sudo apt install -y python3-evdev

# 2. 确保之前的控制脚本存在且可用
if [ ! -f "$CONTROL_SCRIPT" ]; then
	echo "错误: 未找到 screen_control.sh，请确保它们在同一目录。"
	exit 1
fi

# 3. 生成 Python 守护进程脚本
echo "[2/4] 生成底层输入监听器..."
cat <<EOF >"$DAEMON_PY"
#!/usr/bin/env python3
import evdev
import select
import time
import subprocess
import sys
import glob

# 配置区
TIMEOUT = 300  # 息屏超时时间(秒)
CONTROL_CMD = "${CONTROL_SCRIPT}"

def get_input_devices():
    """获取所有输入设备(键盘、触摸屏等)"""
    devices = [evdev.InputDevice(path) for path in evdev.list_devices()]
    return {dev.fd: dev for dev in devices}

def main():
    devices = get_input_devices()
    if not devices:
        print("未检测到任何输入设备(键盘或触摸屏)，监听退出。")
        sys.exit(1)

    print(f"开始监听 {len(devices)} 个输入设备，超时时间: {TIMEOUT}s")

    screen_on = True
    last_event_time = time.time()

    while True:
        try:
            # 动态检查设备变化(例如热插拔键盘)
            current_fds = set(devices.keys())
            actual_fds = set([dev.fd for dev in [evdev.InputDevice(p) for p in evdev.list_devices()]])

            if current_fds != actual_fds:
                devices = get_input_devices()

            # 使用 select 阻塞等待输入事件，最大阻塞时间 1 秒
            r, w, x = select.select(devices.keys(), [], [], 1.0)

            if r:
                # 发生了输入事件（敲击键盘或触摸屏幕）
                for fd in r:
                    for event in devices[fd].read():
                        if event.type == evdev.ecodes.EV_KEY or event.type == evdev.ecodes.EV_ABS:
                            last_event_time = time.time()
                            if not screen_on:
                                subprocess.run([CONTROL_CMD, "on"])
                                screen_on = True
            else:
                # 没有任何输入，检查是否超时
                if screen_on and (time.time() - last_event_time) > TIMEOUT:
                    subprocess.run([CONTROL_CMD, "off"])
                    screen_on = False

        except OSError:
            # 设备断开时的容错处理
            time.sleep(1)
            devices = get_input_devices()
        except KeyboardInterrupt:
            break

if __name__ == "__main__":
    main()
EOF
chmod +x "$DAEMON_PY"

# 4. 注册为 systemd 服务 (幂等配置)
echo "[3/4] 配置 systemd 后台服务..."
sudo bash -c "cat << EOF > $SERVICE_FILE
[Unit]
Description=CLI Screen Idle Monitor
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 $DAEMON_PY
Restart=always
RestartSec=3
User=root

[Install]
WantedBy=multi-user.target
EOF"

# 5. 启动服务
echo "[4/4] 启动并启用服务..."
sudo systemctl daemon-reload
sudo systemctl enable screen-idle.service
sudo systemctl restart screen-idle.service

echo "=========================================="
echo " 配置完成！"
echo " 守护进程已作为系统服务运行。"
echo " 你可以使用以下命令查看日志："
echo " journalctl -u screen-idle.service -f"
echo "=========================================="

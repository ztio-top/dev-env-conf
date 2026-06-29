#!/bin/bash

# ==============================================================================
# PVE 笔记本工作站优化脚本 (HP ZBook)
# 功能: 1. 自动熄屏 (consoleblank)  2. 禁用合盖休眠 (HandleLidSwitch)
# 特性: 幂等性设计、自动备份、双向日志记录 (控制台 + Log文件)
# ==============================================================================

# 定义日志文件路径
LOG_FILE="/var/log/pve_zbook_optimization_$(date +%Y%m%d).log"

# 定义配置项值
BLANK_TIME="300" # 屏幕熄灭时间，单位：秒

# 初始化日志记录功能 (同时输出到屏幕和文件)
log_msg() {
	local time_stamp=$(date +'%Y-%m-%d %H:%M:%S')
	echo -e "[$time_stamp] $1" | tee -a "$LOG_FILE"
}

log_msg "============================================="
log_msg "开始执行 PVE (HP ZBook) 优化配置脚本"
log_msg "日志文件存放于: $LOG_FILE"
log_msg "============================================="

# ------------------------------------------------------------------------------
# 辅助函数：文件备份
# ------------------------------------------------------------------------------
backup_file() {
	local target_file=$1
	if [ -f "$target_file" ]; then
		local backup_file="${target_file}.bak_$(date +%Y%m%d_%H%M%S)"
		cp "$target_file" "$backup_file"
		log_msg "[备份] 已成功备份文件: $target_file -> $backup_file"
	else
		log_msg "[跳过] 文件不存在，无需备份: $target_file"
	fi
}

# ==============================================================================
# 任务 1: 配置内核引导参数 (自动熄屏)
# ==============================================================================
UPDATE_GRUB=0
UPDATE_BOOT=0

# 场景 A: 检查并配置 GRUB 引导
if [ -f "/etc/default/grub" ]; then
	log_msg "[检测] 发现 GRUB 配置文件，准备处理..."
	if grep -q "consoleblank=" "/etc/default/grub"; then
		log_msg "[幂等] GRUB 已经包含 consoleblank 参数，无需重复添加。"
	else
		backup_file "/etc/default/grub"
		# 使用 sed 在 GRUB_CMDLINE_LINUX_DEFAULT 的值内部末尾追加参数
		sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 consoleblank='"$BLANK_TIME"'"/' /etc/default/grub
		log_msg "[修改] 已向 /etc/default/grub 注入 consoleblank=$BLANK_TIME"
		log_msg "[详情] 当前 GRUB_CMDLINE 核心参数: $(grep '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub)"
		UPDATE_GRUB=1
	fi
fi

# 场景 B: 检查并配置 systemd-boot (ZFS 常见)
if [ -f "/etc/kernel/cmdline" ]; then
	log_msg "[检测] 发现 systemd-boot 配置文件 (cmdline)，准备处理..."
	if grep -q "consoleblank=" "/etc/kernel/cmdline"; then
		log_msg "[幂等] cmdline 已经包含 consoleblank 参数，无需重复添加。"
	else
		backup_file "/etc/kernel/cmdline"
		# 在第一行的末尾直接追加配置
		sed -i '1 s/$/ consoleblank='"$BLANK_TIME"'/' /etc/kernel/cmdline
		log_msg "[修改] 已向 /etc/kernel/cmdline 追加 consoleblank=$BLANK_TIME"
		log_msg "[详情] 当前 cmdline 内容: $(cat /etc/kernel/cmdline)"
		UPDATE_BOOT=1
	fi
fi

# ==============================================================================
# 任务 2: 配置合盖不休眠 (systemd-logind)
# ==============================================================================
LOGIND_CONF="/etc/systemd/logind.conf"
RESTART_LOGIND=0

if [ -f "$LOGIND_CONF" ]; then
	log_msg "[检测] 发现 $LOGIND_CONF，准备配置合盖策略..."
	backup_done=0 # 标记当前运行是否已经备过份，防止多次循环产生多个备份

	# 定义需要修改的三个合盖参数
	LID_SETTINGS=("HandleLidSwitch" "HandleLidSwitchExternalPower" "HandleLidSwitchDocked")

	for setting in "${LID_SETTINGS[@]}"; do
		# 检查是否已经是生效状态 (未被注释且值为 ignore)
		if grep -q "^${setting}=ignore" "$LOGIND_CONF"; then
			log_msg "[幂等] ${setting}=ignore 已经正确配置生效，无需修改。"
		else
			if [ $backup_done -eq 0 ]; then
				backup_file "$LOGIND_CONF"
				backup_done=1
			fi

			# 1. 如果是被注释掉的 (如 #HandleLidSwitch=suspend)，则替换并取消注释
			if grep -qi "^#${setting}=" "$LOGIND_CONF"; then
				sed -i "s/^#${setting}=.*/${setting}=ignore/" "$LOGIND_CONF"
			# 2. 如果存在但值不是 ignore (如 HandleLidSwitch=suspend)，则直接替换
			elif grep -qi "^${setting}=" "$LOGIND_CONF"; then
				sed -i "s/^${setting}=.*/${setting}=ignore/" "$LOGIND_CONF"
			# 3. 如果文件里完全没有这行，则追加到文件末尾
			else
				echo "${setting}=ignore" >>"$LOGIND_CONF"
			fi

			log_msg "[修改] 已将 $LOGIND_CONF 中的策略修改为: ${setting}=ignore"
			RESTART_LOGIND=1
		fi
	done
else
	log_msg "[警告] 未找到 $LOGIND_CONF，跳过合盖休眠配置。"
fi

# ==============================================================================
# 任务 3: 应用更改 (更新引导和重启服务)
# ==============================================================================

if [ $UPDATE_GRUB -eq 1 ]; then
	log_msg "[执行] 正在更新 GRUB 引导记录 (update-grub)..."
	update-grub | tee -a "$LOG_FILE"
fi

if [ $UPDATE_BOOT -eq 1 ]; then
	log_msg "[执行] 正在更新 systemd-boot (proxmox-boot-tool refresh)..."
	proxmox-boot-tool refresh | tee -a "$LOG_FILE"
fi

if [ $RESTART_LOGIND -eq 1 ]; then
	log_msg "[执行] 正在重启 systemd-logind 服务以应用合盖策略..."
	systemctl restart systemd-logind
	log_msg "[状态] systemd-logind 服务重启完成。"
fi

log_msg "============================================="
log_msg "脚本执行完毕！"
if [ $UPDATE_GRUB -eq 1 ] || [ $UPDATE_BOOT -eq 1 ]; then
	log_msg ">> 提示: 内核引导参数已修改，你需要执行 'reboot' 重启系统后屏幕自动熄屏才能生效。"
fi
log_msg "合盖策略已即时生效，可以放心地合上 ZBook 的屏幕了。"
log_msg "============================================="
exit 0

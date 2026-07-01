#!/bin/bash

# ==============================================================================
# PVE 笔记本工作站 (HP ZBook) 全面优化脚本 v2.0
# 功能: 1. 自动熄屏 2. 禁用合盖休眠 3. 修复 EFI 引导警告
# 特性: 绝对幂等性、动态清理内核参数、自动备份、双向日志
# ==============================================================================

LOG_FILE="/var/log/pve_zbook_optimization_$(date +%Y%m%d).log"
BLANK_TIME="300"

# ------------------------------------------------------------------------------
# 基础函数：双向日志与备份
# ------------------------------------------------------------------------------
log_msg() {
	local time_stamp=$(date +'%Y-%m-%d %H:%M:%S')
	echo -e "[$time_stamp] $1" | tee -a "$LOG_FILE"
}

backup_file() {
	local target_file=$1
	if [ -f "$target_file" ]; then
		local backup_file="${target_file}.bak_$(date +%Y%m%d_%H%M%S)"
		cp -p "$target_file" "$backup_file"
		log_msg "[备份] 已备份: $target_file -> ${backup_file##*/}"
	fi
}

log_msg "====================================================="
log_msg "🚀 开始执行 PVE (HP ZBook) 全面优化配置脚本"
log_msg "====================================================="

UPDATE_GRUB=0
UPDATE_BOOT=0

# ==============================================================================
# 任务 1: 修复 GRUB EFI 移动介质引导警告 (幂等)
# ==============================================================================
# 确保安装了 debconf-utils 以便查询当前状态
if ! command -v debconf-get-selections &>/dev/null; then
	apt-get install -y debconf-utils >/dev/null 2>&1
fi

if debconf-get-selections | grep -q "grub2/force_efi_extra_removable[[:space:]]*boolean[[:space:]]*true"; then
	log_msg "[幂等] EFI 引导修复 (force_efi_extra_removable) 已应用，跳过。"
else
	log_msg "[修复] 发现未配置 force_efi_extra_removable，正在修复 EFI 引导警告..."
	echo 'grub-efi-amd64 grub2/force_efi_extra_removable boolean true' | debconf-set-selections -v -u >>"$LOG_FILE" 2>&1
	DEBIAN_FRONTEND=noninteractive apt-get install -y --reinstall grub-efi-amd64 >>"$LOG_FILE" 2>&1
	UPDATE_BOOT=1
	log_msg "[状态] EFI 引导警告修复完成。"
fi

# ==============================================================================
# 任务 2: 注入自动熄屏参数 (兼容 GRUB & systemd-boot)
# ==============================================================================

# 场景 A: 处理 /etc/default/grub
GRUB_FILE="/etc/default/grub"
if [ -f "$GRUB_FILE" ]; then
	log_msg "[检测] 发现 GRUB 配置文件，准备处理..."
	if grep -q "consoleblank=" "$GRUB_FILE"; then
		log_msg "[幂等] GRUB 配置文件已包含 consoleblank，跳过。"
	else
		backup_file "$GRUB_FILE"
		# 使用 sed 在 GRUB_CMDLINE_LINUX_DEFAULT 的值内部末尾追加参数
		sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 consoleblank='"$BLANK_TIME"'"/' "$GRUB_FILE"
		log_msg "[修改] 已向 $GRUB_FILE 注入 consoleblank=$BLANK_TIME"
		log_msg "[详情] 当前 GRUB_CMDLINE 核心参数: $(grep '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub)"
		UPDATE_GRUB=1
	fi
fi

# 场景 B: 处理 proxmox-boot-tool 专用的 /etc/kernel/cmdline
CMDLINE_FILE="/etc/kernel/cmdline"

# 1. 如果文件不存在，或者文件内错误地包含了 BOOT_IMAGE/initrd，我们需要重新生成一个纯净版
if [ ! -f "$CMDLINE_FILE" ] || grep -qE "(BOOT_IMAGE|initrd)=" "$CMDLINE_FILE"; then
	log_msg "[清理] 发现 $CMDLINE_FILE 不存在或包含版本脏数据，正在重新生成..."
	backup_file "$CMDLINE_FILE"
	# 从 /proc/cmdline 提取当前参数，剥离 BOOT_IMAGE 和 initrd，利用 xargs 清理多余空格
	cat /proc/cmdline | sed -E 's/(BOOT_IMAGE|initrd)=[^ ]+//g' | xargs >"$CMDLINE_FILE"
	log_msg "[状态] 已生成纯净的基础内核参数。"
fi

# 2. 检查纯净后的 cmdline 是否包含 consoleblank
if grep -q "consoleblank=" "$CMDLINE_FILE"; then
	log_msg "[幂等] $CMDLINE_FILE 已包含 consoleblank，跳过。"
else
	backup_file "$CMDLINE_FILE"
	sed -i "s/$/ consoleblank=$BLANK_TIME/" "$CMDLINE_FILE"
	log_msg "[修改] 已向 $CMDLINE_FILE 追加 consoleblank=$BLANK_TIME"
	UPDATE_BOOT=1
fi

# ==============================================================================
# 任务 3: 配置合盖不休眠 (systemd-logind)
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
			log_msg "[幂等] $setting=ignore 已正确生效，跳过。"
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
# 任务 4: 触发配置生效
# ==============================================================================
log_msg "-----------------------------------------------------"

if [ $UPDATE_GRUB -eq 1 ]; then
	log_msg "[执行] 更新 GRUB 引导记录 (update-grub)..."
	update-grub 2>&1 | tee -a "$LOG_FILE"
fi

if [ $UPDATE_BOOT -eq 1 ]; then
	log_msg "[执行] 正在更新 systemd-boot (proxmox-boot-tool refresh)..."
	proxmox-boot-tool refresh 2>&1 | tee -a "$LOG_FILE"
fi

if [ $RESTART_LOGIND -eq 1 ]; then
	log_msg "[执行] 正在重启 systemd-logind 服务以应用合盖策略..."
	systemctl restart systemd-logind
	log_msg "[状态] systemd-logind 服务重启完成。"
fi

if [ $UPDATE_GRUB -eq 0 ] && [ $UPDATE_BOOT -eq 0 ] && [ $RESTART_LOGIND -eq 0 ]; then
	log_msg "✅ 检测到所有配置均已处于最优状态，未对系统进行任何修改。"
else
	log_msg "✅ 配置已更新！"
	if [ $UPDATE_GRUB -eq 1 ] || [ $UPDATE_BOOT -eq 1 ]; then
		log_msg "⚠️  内核参数已变更，请在方便时执行 'reboot' 以使自动熄屏生效。"
	fi
fi

log_msg "====================================================="
exit 0

#!/usr/bin/env bash

# 遇到错误立即停止执行
set -e

# 设置非交互式前端，防止 apt 弹出蓝底白字的选择提示
export DEBIAN_FRONTEND=noninteractive

echo "===================================================="
echo " 开始配置 Minimized Ubuntu 开发运维基础环境..."
echo "===================================================="

# 1. 更新系统源并升级基础组件
echo ">>> [1/4] 正在更新系统软件包列表并升级..."
sudo apt-get update && sudo apt-get upgrade -y -o Dpkg::Options::="--force-confold"

# 2. 安装开发与运维核心基础工具
echo ">>> [2/4] 正在安装常用工具 (分门别类进行安装)..."

sudo apt-get install -y -o Dpkg::Options::="--force-confold" \
	`# ---- 基础系统与安全依赖 ----` \
	software-properties-common \
	apt-transport-https \
	ca-certificates \
	gnupg \
	lsb-release \
	\
	`# ---- 核心终端与开发工具 ----` \
	curl \
	wget \
	vim \
	git \
	tmux \
	\
	`# ---- 网络诊断与调试工具 ----` \
	net-tools \
	iputils-ping \
	dnsutils \
	\
	`# ---- 压缩、解压与文件同步 ----` \
	unzip \
	zip \
	rsync \
	\
	`# ---- 系统性能监测 ----` \
	htop

# ==========================================
# 3. 自动化配置 Tmux 黄金生存指南 (幂等写入)
# ==========================================
echo ">>> [3/4] 正在配置 Tmux 最佳实践环境..."

# 识别真实的非 root 用户主目录
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME=$(eval echo "~$TARGET_USER")
TMUX_CONF="$TARGET_HOME/.tmux.conf"

echo "目标配置文件: $TMUX_CONF (用户: $TARGET_USER)"

# 创建临时文件用于存放黄金配置片段
TMP_CONF=$(mktemp)
cat <<'EOF' >"$TMP_CONF"
# === BEGIN TMUX GOLDEN CONFIG ===
# 核心与翻页设置
set -g mouse on
setw -g mode-keys vi
set -g history-limit 50000
set -g default-terminal "screen-256color"

# 修改前缀键为 Ctrl+a
set -g prefix C-a
unbind C-b
bind C-a send-prefix

# 从 1 开始编号与自动重排
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on

# 直觉化拆分窗格
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
unbind '"'
unbind %

# Alt+方向键 免前缀切换窗格
bind -n M-Left select-pane -L
bind -n M-Right select-pane -R
bind -n M-Up select-pane -U
bind -n M-Down select-pane -D

# 快捷键 Prefix+e 同步窗格
bind e setw synchronize-panes

# 状态栏美化 (Dracula 暗黑风格)
set -g status-justify left
set -g status-bg "#282a36"
set -g status-fg "#f8f8f2"
set -g status-interval 2
set -g status-left "#[bg=#6272a4,fg=#f8f8f2] ❐ #S #[bg=#282a36,fg=#6272a4] "
set -g status-left-length 30
set -g status-right "#[fg=#6272a4]#[bg=#6272a4,fg=#f8f8f2] 📁 #{=21:pane_current_path} #[fg=#ff79c6]#[bg=#ff79c6,fg=#282a36] ⏰ %Y-%m-%d %H:%M "
set -g status-right-length 150
setw -g window-status-current-format "#[fg=#282a36,bg=#ff79c6]#[fg=#282a36,bg=#ff79c6,bold] #I:#W #[fg=#ff79c6,bg=#282a36]"
setw -g window-status-format "#[fg=#f8f8f2,bg=#282a36]  #I:#W  "
# === END TMUX GOLDEN CONFIG ===
EOF

# 幂等性处理：如果文件已存在且包含该配置块，先将其剥离，避免重复追加
if [ -f "$TMUX_CONF" ]; then
	# 使用 sed 移除可能已存在的旧配置块
	sed -i '/# === BEGIN TMUX GOLDEN CONFIG ===/,/# === END TMUX GOLDEN CONFIG ===/d' "$TMUX_CONF"
fi

# 将新配置追加到文件中
cat "$TMP_CONF" >>"$TMUX_CONF"
rm -f "$TMP_CONF"

# 修复文件权限，确保所属权回归原用户，而不是变成 root
chown "$TARGET_USER":"$(id -gn "$TARGET_USER")" "$TMUX_CONF"

echo "✔ Tmux 配置已成功应用/更新。"

echo "===================================================="
echo "🎉 恭喜！开发运维环境初始化成功！"
echo "已安装: Git, Curl, Tmux, Htop, Net-tools"
echo "===================================================="

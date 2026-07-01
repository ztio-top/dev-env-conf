#!/bin/bash
# Open WebUI 满血版部署及 Systemd 服务配置脚本

set -e

echo "--- 1. 安装 uv 和基础依赖 ---"
# 幂等安装 uv
if ! command -v uv &>/dev/null; then
	curl -LsSf https://astral.sh/uv/install.sh | sh
	# 修复了这里的环境变量路径
	source $HOME/.local/bin/env
fi
apt update && apt install -y build-essential python3-dev

echo "--- 2. 环境初始化 (uv) ---"
cd ~
mkdir -p open-webui-full
cd open-webui-full

# 幂等初始化环境
if [ ! -d ".venv" ]; then
	uv venv
fi
source .venv/bin/activate

echo "--- 3. 安装 ROCm 版 PyTorch (满血核心) ---"
# uv 会自动跳过已安装的包，实现幂等
uv pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.0

echo "--- 4. 安装 Open WebUI ---"
uv pip install open-webui

echo "--- 5. 生成启动脚本 (包含 AMD 环境伪装) ---"
# 使用 cat 覆盖原有脚本，确保始终是最新的
cat <<'EOF' >start_webui.sh
#!/bin/bash
# 自动加载环境并启动
cd "$(dirname "$0")"
source .venv/bin/activate

# AMD 核显架构强制指定 (780M 为 RDNA3)
export HSA_OVERRIDE_GFX_VERSION=11.0.0

# 🚀 [修复 GPU Hang 的魔法指令] 禁用 SDMA 内存直接访问，解决 APU 显存搬运崩溃
export HSA_ENABLE_SDMA=0

# 🚀 [修复 显存碎片化] 优化 PyTorch 的显存分配机制，防止 OOM 和 Hang
export PYTORCH_HIP_ALLOC_CONF="garbage_collection_threshold:0.8,max_split_size_mb:128"

# 本地 Ollama 指向
export OLLAMA_BASE_URL=http://127.0.0.1:11434

# 🚀 关键修复：设置 Hugging Face 国内镜像源，解决启动崩溃
export HF_ENDPOINT=https://hf-mirror.com

# 启动 Open WebUI
open-webui serve
EOF

chmod +x start_webui.sh

echo "--- 6. 配置 Systemd 后台服务 ---"
SERVICE_FILE="/etc/systemd/system/open-webui.service"
WORK_DIR="$HOME/open-webui-full"

# 幂等性：覆盖写入服务配置，动态获取当前用户的 HOME 目录
cat <<EOF >"$SERVICE_FILE"
[Unit]
Description=Open WebUI Daemon (AMD ROCm Optimized)
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$WORK_DIR
ExecStart=$WORK_DIR/start_webui.sh
# 崩溃自动重启机制，完美替代 while true
Restart=always
RestartSec=3
# 确保服务能找到系统基础命令
Environment=PATH=$WORK_DIR/.venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

[Install]
WantedBy=multi-user.target
EOF

# 应用 Systemd 更改
systemctl daemon-reload
systemctl enable open-webui.service
systemctl restart open-webui.service

echo "================================================================"
echo "🎉 部署完成！Open WebUI 已作为后台服务运行。"
echo "👉 查看实时日志运行: journalctl -u open-webui -f"
echo "👉 查看服务状态运行: systemctl status open-webui"
echo "================================================================"

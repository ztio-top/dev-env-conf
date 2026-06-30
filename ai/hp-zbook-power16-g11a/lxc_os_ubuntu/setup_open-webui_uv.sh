#!/bin/bash
# Open WebUI 满血版部署脚本 (基于 uv)

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
# 本地 Ollama 指向
export OLLAMA_BASE_URL=http://127.0.0.1:11434

# 🚀 关键修复：设置 Hugging Face 国内镜像源，解决启动崩溃
export HF_ENDPOINT=https://hf-mirror.com

# 启动 Open WebUI
open-webui serve
EOF

chmod +x start_webui.sh
echo "部署完成！现在运行 ./start_webui.sh 即可开启满血模式。"

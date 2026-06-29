#!/bin/bash
# 开启严格模式：遇到错误即退出，且严格捕获管道 (|) 中的任何报错
set -e
set -o pipefail

echo "====================================================="
echo "  Ubuntu 24.04: Ollama 原生部署与 GPU 加速脚本 (坚不可摧版) "
echo "====================================================="

# 1. 权限检查
if [ "$EUID" -ne 0 ]; then
	echo "❌ 错误: 请使用 root 用户权限运行此脚本。"
	exit 1
fi

# 2. 基础依赖检测
echo -e "\n📦 检查系统依赖..."
if ! command -v curl &>/dev/null || ! command -v zstd &>/dev/null; then
	echo "⚙️ 检测到缺失 curl 或 zstd，正在安装基础依赖..."
	apt update -y
	apt install -y curl zstd
	echo "✅ 基础依赖 (curl, zstd) 安装完成。"
else
	echo "✅ 基础依赖已满足。"
fi

# 3. 严格幂等安装 Ollama 本体 (双重校验)
echo -e "\n🦙 检查 Ollama 安装状态..."
# 只有当 ollama 命令存在，且 systemd 服务文件也存在时，才认为安装完整
if command -v ollama &>/dev/null && [ -f "/etc/systemd/system/ollama.service" ]; then
	echo "⏭️  [跳过] Ollama 已完整安装，当前版本: $(ollama --version | head -n 1)"
else
	echo "⚙️ 未检测到完整的 Ollama 环境，正在执行官方安装..."
	curl -fsSL https://ollama.com/install.sh | sh
	echo "✅ Ollama 本体安装成功！"
fi

# 4. 配置 AMD 780M 硬件加速与网络监听
echo -e "\n🛠️ 配置硬件加速与网络服务..."
OLLAMA_SERVICE_DIR="/etc/systemd/system/ollama.service.d"
OLLAMA_OVERRIDE_FILE="$OLLAMA_SERVICE_DIR/override.conf"

# 确保目录存在
mkdir -p "$OLLAMA_SERVICE_DIR"

# 注入覆盖配置
cat <<EOF >"$OLLAMA_OVERRIDE_FILE"
[Service]
Environment="OLLAMA_HOST=0.0.0.0"
Environment="HSA_OVERRIDE_GFX_VERSION=11.0.0"
EOF
echo "✅ Systemd 配置写入完成: $OLLAMA_OVERRIDE_FILE"

# 5. 重载服务使配置生效
echo -e "\n🔄 重新加载并重启 Ollama 服务..."
systemctl daemon-reload
systemctl restart ollama
systemctl enable ollama

echo "====================================================="
echo "🎉 Ollama 部署与 GPU 调优完毕！"
echo "====================================================="

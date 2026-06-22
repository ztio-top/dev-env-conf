#!/bin/bash

set -e
# 幂等安装 shfmt
if ! command -v shfmt &>/dev/null; then
	echo "[INFO] 正在安装 shfmt..."
	sudo apt-get update && sudo apt-get install -y shfmt
else
	echo "[INFO] shfmt 已安装，跳过。"
fi
# VS Code Server 插件同步脚本 for Remote-SSH 环境
# 包含全栈与 AI 扩展的完整列表
extensions=(
	"charliermarsh.ruff"                                  # Python 极速格式化与代码检查
	"ms-python.python"                                    # Python 核心支持
	"ms-python.vscode-pylance"                            # Python 严格类型推断
	"esbenp.prettier-vscode"                              # 前端、JSON、Markdown 统一排版规范
	"redhat.vscode-yaml"                                  # YAML 格式化与 Docker Compose 语法校验
	"mkhl.shfmt"                                          # Bash/Zsh 脚本格式化与对齐"
	"timonwong.shellcheck"                                # Bash/Zsh 脚本静态分析与防呆提示
	"ms-vscode.PowerShell"                                # PowerShell 核心支持与防呆格式化
	"ms-azuretools.vscode-docker"                         # Dockerfile 格式化与容器管理
	"ahmadalli.vscode-nginx-config"                       # Nginx 配置文件高亮与格式化
	"AaaaronZhou.nginx-config-formatter-vscode-extension" # Nginx 配置文件格式化工具

	# --- 远程与容器化开发三剑客 ---  Remote 插件是“客户端”插件，而不是“服务端”插件。 不要安装到server端，否则会导致 VS Code 无法正确识别和使用 Remote 功能。
	# "ms-vscode-remote.remote-containers"  # Dev Containers (容器化开发环境核心)
	# "ms-vscode-remote.remote-ssh"         # Remote - SSH (直连物理节点/虚拟机的神器)
	# "ms-vscode-remote.remote-wsl"         # WSL (完美打通 Win11 本地 Linux 子系统)

	# --- 本地 AI 算力接入 ---
	"Continue.continue"      # 本地大模型接入利器 (极佳的代码补全与问答体验)
	"saoudrizwan.claude-dev" # Cline: 强大的本地 AI Agent (可自动执行终端命令与改写文件)
)

echo -e "\033[1;36m开正在为 Remote-SSH 环境同步 VS Code 扩展......\033[0m"

# 幂等安装 VS Code 插件
# 我们检查是否安装过 VS Code Server，没有的话不执行以免报错
if [ -d "$HOME/.vscode-server" ]; then
	for ext in "${extensions[@]}"; do
		echo -e "\033[1;33m正在同步: $ext\033[0m"
		# --install-extension 本身就是幂等的，但我们加一层静默检查会更优雅
		code --install-extension "$ext" --force >/dev/null 2>&1 && echo "[SYNC] $ext 已同步"
	done
else
	echo "[WARN] 未检测到 VS Code Server，请先通过 SSH 连接一次服务器。"
fi

echo -e "\033[1;32m环境插件同步完成！\033[0m"

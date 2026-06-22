#!/bin/bash

# 包含全栈与 AI 扩展的完整列表
extensions=(
    "charliermarsh.ruff",                 # Python 极速格式化与代码检查
    "ms-python.python",                   # Python 核心支持
    "ms-python.vscode-pylance",           # Python 严格类型推断
    "esbenp.prettier-vscode",             # 前端、JSON、Markdown 统一排版规范
    "redhat.vscode-yaml",                 # YAML 格式化与 Docker Compose 语法校验
    "foxundermoon.shell-format",          # Bash/Zsh 脚本格式化与对齐
    "ms-vscode.PowerShell",               # PowerShell 核心支持与防呆格式化
    "ms-azuretools.vscode-docker",        # Dockerfile 格式化与容器管理
    "ms-vscode-remote.remote-containers", # Dev Containers (容器化开发环境核心)

    # --- 远程与容器化开发三剑客 ---
    "ms-vscode-remote.remote-containers", # Dev Containers (容器化开发环境核心)
    "ms-vscode-remote.remote-ssh",        # Remote - SSH (直连物理节点/虚拟机的神器)
    "ms-vscode-remote.remote-wsl",        # WSL (完美打通 Win11 本地 Linux 子系统)

    # --- 本地 AI 算力接入 ---
    "Continue.continue",                  # 本地大模型接入利器 (极佳的代码补全与问答)
    "saoudrizwan.claude-dev"              # Cline: 强大的本地 AI Agent (自动化终端与改写文件)
    "Continue.continue",                  # 本地大模型接入利器 (极佳的代码补全与问答体验)
    "saoudrizwan.claude-dev"              # Cline: 强大的本地 AI Agent (可自动执行终端命令与改写文件)
)

echo -e "\033[1;36m开始批量同步 VS Code 环境插件...\033[0m"

for ext in "${extensions[@]}"; do
    echo -e "\033[1;33m正在安装: $ext\033[0m"
    code --install-extension "$ext" --force
done

echo -e "\033[1;32m环境插件同步完成！\033[0m"

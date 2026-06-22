#!/bin/bash

# 包含全栈与 AI 扩展的完整列表
extensions=(
    "charliermarsh.ruff"
    "ms-python.python"
    "ms-python.vscode-pylance"
    "esbenp.prettier-vscode"
    "redhat.vscode-yaml"
    "foxundermoon.shell-format"
    "ms-vscode.PowerShell"
    "ms-azuretools.vscode-docker"
    "ms-vscode-remote.remote-containers"
    "Continue.continue"
    "saoudrizwan.claude-dev"
)

echo -e "\033[1;36m开始批量同步 VS Code 环境插件...\033[0m"

for ext in "${extensions[@]}"; do
    echo -e "\033[1;33m正在安装: $ext\033[0m"
    code --install-extension "$ext" --force
done

echo -e "\033[1;32m环境插件同步完成！\033[0m"

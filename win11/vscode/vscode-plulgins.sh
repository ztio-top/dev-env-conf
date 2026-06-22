#!/bin/bash

extensions=(
    "charliermarsh.ruff"
    "ms-python.python"
    "ms-python.vscode-pylance"
    "esbenp.prettier-vscode"
    "redhat.vscode-yaml"
    "foxundermoon.shell-format"
    "ms-azuretools.vscode-docker"
    "ms-vscode-remote.remote-containers"
)

echo "开始批量安装 VS Code 必备插件..."

for ext in "${extensions[@]}"; do
    echo "正在安装: $ext"
    code --install-extension "$ext" --force
done

echo "所有环境插件安装完毕！"

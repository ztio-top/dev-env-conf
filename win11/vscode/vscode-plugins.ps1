# 定义我们需要安装的 VS Code 核心环境插件列表
$extensions = @(
    "charliermarsh.ruff",           # Python 极速格式化与代码检查
    "ms-python.python",             # Python 核心支持
    "ms-python.vscode-pylance",     # Python 严格类型推断 (配合基础检查使用)
    "esbenp.prettier-vscode",       # 前端、JSON、Markdown 统一排版规范
    "redhat.vscode-yaml",           # YAML 格式化与 Docker Compose 语法校验
    "foxundermoon.shell-format",    # Shell 脚本格式化与对齐
    "ms-azuretools.vscode-docker",  # Dockerfile 格式化与容器高亮
    "ms-vscode-remote.remote-containers" # Dev Containers 核心插件（强烈推荐）
)

Write-Host "开始批量安装 VS Code 必备插件..." -ForegroundColor Cyan

foreach ($ext in $extensions) {
    Write-Host "正在安装: $ext" -ForegroundColor Yellow
    # 调用 VS Code CLI 执行安装。如果已安装，它会自动跳过或更新
    code --install-extension $ext --force
}

Write-Host "所有环境插件安装/更新完毕！请重启 VS Code 以使配置完全生效。" -ForegroundColor Green

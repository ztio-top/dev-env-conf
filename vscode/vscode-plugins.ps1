# 定义涵盖后端、前端、运维、容器与 AI 接入的终极插件列表
$extensions = @(
    "charliermarsh.ruff",                 # Python 极速格式化与代码检查
    "ms-python.python",                   # Python 核心支持
    "ms-python.vscode-pylance",           # Python 严格类型推断
    "esbenp.prettier-vscode",             # 前端、JSON、Markdown 统一排版规范
    "redhat.vscode-yaml",                 # YAML 格式化与 Docker Compose 语法校验
    "foxundermoon.shell-format",          # Bash/Zsh 脚本格式化与对齐
    "ms-vscode.PowerShell",               # PowerShell 核心支持与防呆格式化
    "ms-azuretools.vscode-docker",        # Dockerfile 格式化与容器管理

    # --- 远程与容器化开发三剑客 ---
    "ms-vscode-remote.remote-containers", # Dev Containers (容器化开发环境核心)
    "ms-vscode-remote.remote-ssh",        # Remote - SSH (直连物理节点/虚拟机的神器)
    "ms-vscode-remote.remote-wsl",        # WSL (完美打通 Win11 本地 Linux 子系统)

    # --- 本地 AI 算力接入 ---
    "Continue.continue",                  # 本地大模型接入利器 (极佳的代码补全与问答体验)
    "saoudrizwan.claude-dev"              # Cline: 强大的本地 AI Agent (可自动执行终端命令与改写文件)
)

Write-Host "开始批量安装 VS Code 终极环境插件..." -ForegroundColor Cyan

foreach ($ext in $extensions) {
    Write-Host "正在安装: $ext" -ForegroundColor Yellow
    # 调用 VS Code CLI 执行安装。如果已安装，它会自动跳过或更新
    code --install-extension $ext --force
}

Write-Host "所有环境插件安装/更新完毕！请重启 VS Code 以使配置完全生效。" -ForegroundColor Green

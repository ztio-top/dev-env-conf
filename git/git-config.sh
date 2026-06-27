#!/bin/bash

# 🌟. 基础身份信息 (请替换为你自己的信息)
git config --global user.name "ztio"
git config --global user.email "ztio.top@gmail.com"

# 🌟. 编辑器设置
git config --global core.editor "code --wait"

# 🌟. 默认分支名称
git config --global init.defaultBranch main

# 🌟. 默认显示路径前缀
git config --global status.relativePaths false

# 🌟. 排序
# 提交历史排序
git config --global branch.sort -committerdate
# 标签排序
git config --global tag.sort version:refname

# 🌟. 工作流与合并策略
# 始终使用 rebase 来拉取代码，保持历史记录线性整洁
git config --global pull.rebase true
# 自动处理换行符 (针对 macOS/Linux 开发环境，保持 LF)
git config --global core.autocrlf input

# 🌟. 冲突处理
# 使用 zdiff3 风格的冲突标记，提供更清晰的冲突上下文
git config --global rerere.enabled true
# 自动更新 rerere (Reuse Recorded Resolution)，自动重用冲突解决记录，确保冲突解决方案始终是最新的
git config --global rerere.autoupdate true
# 使用 zdiff3 风格的冲突标记，提供更清晰的冲突上下文
git config --global merge.conflictstyle zdiff3

# 🌟. 推送与交互优化
# simple 模式：只推送当前分支到对应的上游分支
git config --global push.default simple
# 自动设置远程分支，简化首次推送流程
git config --global push.autoSetupRemote true
# 开启色彩显示
git config --global color.ui auto
# 启用提交签名 (如果你有 GPG 密钥，建议开启)
# git config --global commit.gpgsign true

# 🌟. 拉取优化
# 自动修剪远程分支，保持本地分支列表干净
git config --global fetch.prune true
# 自动暂存未提交的更改，避免拉取时的冲突
git config --global rebase.autoStash true
# 仅允许快进合并，保持历史记录清晰
# git config --global merge.ff only

# 🌟. 全局忽略文件配置
GITIGNORE_GLOBAL="$HOME/.gitignore_global"

if [ ! -f "$GITIGNORE_GLOBAL" ]; then
	cat >"$GITIGNORE_GLOBAL" <<'EOF'
# macOS
.DS_Store

# Windows
Thumbs.db

# IDE
.idea/
.vscode/

# Vim
*.swp

# Python
.venv/
__pycache__/
EOF
fi
# 设置全局忽略文件路径
git config --global core.excludesfile "$GITIGNORE_GLOBAL"

# 🌟. 凭证管理 (根据操作系统调整)
# macOS 使用 osxkeychain，Linux 可选 cache 或 store
if [[ "$OSTYPE" == "darwin"* ]]; then
	git config --global credential.helper osxkeychain
elif grep -qiE "(microsoft|wsl)" /proc/version 2>/dev/null; then
	git config --global credential.helper manager
elif git help -a | grep -q credential-libsecret; then
	git config --global credential.helper libsecret
else
	git config --global credential.helper store
fi

# 🌟. 生产力别名 (Aliases) - 极大提升效率
# 查看精简的提交历史
git config --global alias.lg \
	"log --graph --abbrev-commit --decorate \
--format=format:'%C(bold blue)%h%C(reset) \
- %C(bold cyan)(%ar)%C(reset) \
%C(white)%s%C(reset) \
%C(dim white)- %an%C(reset)%C(auto)%d%C(reset)' \
--all"
# 快速查看状态
git config --global alias.st status
# 快速切换分支
git config --global alias.co checkout
# 快速切换分支
git config --global alias.sw switch
# 快速提交
git config --global alias.cm "commit -m"
# 获取最新并变基
git config --global alias.pl "pull --rebase"
# 查看分支
git config --global alias.br branch
# 撤销上一次提交 (保留代码和暂存)
git config --global alias.uncommit "reset --soft HEAD~1"
# 撤销上一次提交 (保留代码但取消暂存)
git config --global alias.undo "reset --mixed HEAD~1"
# 查看最后一次提交
git config --global alias.last "log -1 HEAD"
# 快速修正上一次提交 (不修改提交信息)
git config --global alias.amend "commit --amend --no-edit"
# 查看所有分支的提交历史
git config --global alias.ll \
	"log --graph --decorate --oneline --all"
# 显示当前分支
git config --global alias.current "branch --show-current"
# 最近20条日志
git config --global alias.hist \
	"log --graph --decorate --oneline -20"

echo "Git 配置已完成。 查看所有设置。"

echo
echo "===== Git Config ====="
git config --list --show-origin

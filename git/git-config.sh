#!/bin/bash

# 🌟. 基础身份信息 (请替换为你自己的信息)
git config --global user.name "ztio"
git config --global user.email "ztio.top@gmail.com"

# 🌟. 默认分支名称
git config --global init.defaultBranch main

# 🌟. 工作流与合并策略
# 始终使用 rebase 来拉取代码，保持历史记录线性整洁
git config --global pull.rebase true
# 启用 rerere (Reuse Recorded Resolution)，自动重用冲突解决记录
git config --global rerere.enabled true
# 自动处理换行符 (针对 macOS/Linux 开发环境，保持 LF)
git config --global core.autocrlf input

# 🌟. 推送与交互优化
# simple 模式：只推送当前分支到对应的上游分支
git config --global push.default simple
# 开启色彩显示
git config --global color.ui auto
# 启用提交签名 (如果你有 GPG 密钥，建议开启)
# git config --global commit.gpgsign true

# 🌟. 凭证管理 (根据操作系统调整)
# macOS 使用 osxkeychain，Linux 可选 cache 或 store
if [[ "$OSTYPE" == "darwin"* ]]; then
    git config --global credential.helper osxkeychain
else
    git config --global credential.helper cache
fi

# 🌟. 生产力别名 (Aliases) - 极大提升效率
# 查看精简的提交历史
git config --global alias.lg "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
# 快速查看状态
git config --global alias.st status
# 快速切分支
git config --global alias.co checkout
# 快速提交
git config --global alias.cm "commit -m"
# 获取最新并变基
git config --global alias.pl "pull --rebase"
# 查看分支
git config --global alias.br branch
# 撤销上一次提交 (保留代码)
git config --global alias.uncommit "reset --soft HEAD~1"

echo "Git 配置已完成。你可以运行 'git config --list' 查看所有设置。"

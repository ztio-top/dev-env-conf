#!/bin/bash

# 1. 检查是否传入了目标参数
if [ -z "$1" ]; then
    echo "用法: $0 <Host | user@IP>"
    echo "示例: $0 myserver"
    echo "示例: $0 root@192.168.1.10"
    exit 1
fi

TARGET="$1"
KEY_PATH="$HOME/.ssh/id_ed25519.pub"

# 2. 检查本地 Ed25519 公钥文件是否存在
if [ ! -f "$KEY_PATH" ]; then
    echo "❌ 错误: 找不到公钥文件 $KEY_PATH"
    echo "💡 提示: 请先使用 'ssh-keygen -t ed25519' 命令生成密钥对。"
    exit 1
fi

# 读取公钥内容
PUB_KEY=$(cat "$KEY_PATH")

echo "🚀 准备将公钥同步至目标机器: $TARGET ..."
echo "🔒 如果尚未配置免密，系统接下来将提示您输入目标机器的登录密码。"
echo "------------------------------------------------------------------"

# 3. 通过 SSH 执行远程命令（包含幂等性检查）
# - 创建 ~/.ssh 目录并设置 700 权限
# - 创建 authorized_keys 文件并设置 600 权限
# - 使用 grep -qF 精确检查公钥是否已存在
# - 如果不存在则追加，存在则跳过
ssh "$TARGET" "
    mkdir -p ~/.ssh && chmod 700 ~/.ssh &&
    touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys &&
    if grep -qF \"$PUB_KEY\" ~/.ssh/authorized_keys; then
        echo '✨ 公钥已存在于目标机器的 authorized_keys 中，无需重复添加 (幂等跳过)。'
    else
        echo \"$PUB_KEY\" >> ~/.ssh/authorized_keys
        echo '✅ 公钥已成功追加到目标机器！'
    fi
"

# 4. 检查执行结果
if [ $? -eq 0 ]; then
    echo "------------------------------------------------------------------"
    echo "🎉 操作完成！您现在可以尝试运行 'ssh $TARGET' 来验证免密登录。"
else
    echo "------------------------------------------------------------------"
    echo "❌ 操作失败。请检查您的网络连接、目标地址或密码是否正确。"
fi
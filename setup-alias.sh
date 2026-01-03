#!/bin/bash

# 获取脚本所在的绝对路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 要添加的alias命令
ALIAS1="alias activate-clash='source $SCRIPT_DIR/activate'"
ALIAS2="alias select-node='$SCRIPT_DIR/select-node.sh'"

# 获取bashrc文件路径
BASHRC="$HOME/.bashrc"

# 检查bashrc文件是否存在
if [ ! -f "$BASHRC" ]; then
    echo "错误: $BASHRC 文件不存在!"
    exit 1
fi

# 检查第一个alias是否已存在
if grep -q "alias activate-clash='source " "$BASHRC"; then
    echo "✓ alias activate-clash 已存在于 $BASHRC"
else
    # 添加第一个alias
    echo "$ALIAS1" >> "$BASHRC"
    echo "✓ alias activate-clash 已添加到 $BASHRC"
fi

# 检查第二个alias是否已存在
if grep -q "alias select-node='" "$BASHRC"; then
    echo "✓ alias select-node 已存在于 $BASHRC"
else
    # 添加第二个alias
    echo "$ALIAS2" >> "$BASHRC"
    echo "✓ alias select-node 已添加到 $BASHRC"
fi

# 提示用户刷新配置
echo ""
echo "✨ 配置已完成!"
echo "请执行以下命令刷新bashrc配置:"
echo "  source $BASHRC"
echo "或重新打开终端窗口以应用新的alias命令。"
echo ""
echo "使用方法:"
echo "  activate-clash   # 启动clash代理"
echo "  select-node      # 选择代理节点"

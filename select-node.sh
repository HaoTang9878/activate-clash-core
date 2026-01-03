#!/bin/bash

# 获取节点列表并显示，让用户选择
echo "=== Clash节点选择器 ==="
echo ""

# 定义代理组名称 - 使用正确的硬编码名称
PROXY_GROUP="🔥ChatGPT"

# 获取当前节点信息
echo "当前节点组：$PROXY_GROUP"
CURRENT_NODE=$(curl -s http://127.0.0.1:9090/proxies/$PROXY_GROUP | python3 -c "import json; print(json.loads(input())['now'])")
echo "当前选中节点：$CURRENT_NODE"
echo ""

# 获取可用节点列表
NODES_JSON=$(curl -s http://127.0.0.1:9090/proxies/$PROXY_GROUP)
NODES_LIST=$(echo $NODES_JSON | python3 -c "import json; data = json.loads(input()); print('\n'.join(data['all']))")

# 将节点列表转换为数组
IFS=$'\n' read -r -d '' -a NODES_ARRAY <<< "$NODES_LIST"
NODE_COUNT=${#NODES_ARRAY[@]}
LAST_INDEX=$((NODE_COUNT - 1))

# 显示节点列表，带数字索引
echo "可用节点列表："
echo "----------------"
for i in "${!NODES_ARRAY[@]}"; do
    # 高亮显示当前选中的节点
    if [ "${NODES_ARRAY[$i]}" == "$CURRENT_NODE" ]; then
        echo -e "\033[1;32m[$i] ${NODES_ARRAY[$i]}\033[0m"  # 绿色高亮
    else
        echo "[$i] ${NODES_ARRAY[$i]}"
    fi
done

echo "----------------"
echo ""

# 循环直到用户输入有效
while true; do
    # 获取用户输入
    echo -n "请输入要切换的节点编号 (0-$LAST_INDEX)："
    read -r NODE_INDEX
    
    # 检查是否为空输入
    if [ -z "$NODE_INDEX" ]; then
        echo -e "\033[1;33m提示：请输入节点编号，或按Ctrl+C退出\033[0m"
        continue
    fi
    
    # 验证输入是否为数字
    if ! [[ "$NODE_INDEX" =~ ^[0-9]+$ ]]; then
        echo -e "\033[1;31m错误：请输入有效的数字！\033[0m"
        continue
    fi
    
    # 验证输入的数字是否在有效范围内
    if [ "$NODE_INDEX" -lt 0 ] || [ "$NODE_INDEX" -gt "$LAST_INDEX" ]; then
        echo -e "\033[1;31m错误：节点编号超出范围 (0-$LAST_INDEX)！\033[0m"
        continue
    fi
    
    # 输入有效，退出循环
    break
done

# 获取用户选择的节点名称
SELECTED_NODE="${NODES_ARRAY[$NODE_INDEX]}"
echo ""
echo "正在切换到节点：$SELECTED_NODE"
echo "----------------"

# 使用curl命令切换节点
curl -s -X PUT -d "{\"name\": \"$SELECTED_NODE\"}" http://127.0.0.1:9090/proxies/$PROXY_GROUP

# 验证切换结果
sleep 1
NEW_CURRENT_NODE=$(curl -s http://127.0.0.1:9090/proxies/$PROXY_GROUP | python3 -c "import json; print(json.loads(input())['now'])")

echo "----------------"
if [ "$NEW_CURRENT_NODE" == "$SELECTED_NODE" ]; then
    echo -e "\033[1;32m切换成功！\033[0m"
    echo "当前节点：$NEW_CURRENT_NODE"
    # 测试代理连接
    EXIT_IP=$(curl -s ifconfig.me)
    echo "出口IP：$EXIT_IP"
else
    echo -e "\033[1;31m切换失败！\033[0m"
    echo "当前节点：$NEW_CURRENT_NODE"
    echo "预期节点：$SELECTED_NODE"
fi

echo ""
echo "=== 操作完成 ==="

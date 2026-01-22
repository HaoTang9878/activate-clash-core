#!/bin/bash

# 彩色输出定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 默认配置文件和路径
# 当通过 source 命令执行时，$0 指向当前 shell，所以使用 BASH_SOURCE 来获取脚本路径
if [ -n "$BASH_SOURCE" ]; then
    SCRIPT_PATH="$BASH_SOURCE"
else
    SCRIPT_PATH="$0"
fi
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
DEFAULT_CONFIG="${BASE_DIR}/configs/config.yaml"
CONFIG_DIR="${BASE_DIR}/configs"

# 从配置文件获取API地址和代理端口
get_api_info() {
    local config_file="${1:-$DEFAULT_CONFIG}"
    
    # 处理配置文件路径
    if [ -n "$1" ]; then
        # 如果提供了配置文件名，检查是相对路径还是绝对路径
        if [[ "$1" != /* ]]; then
            # 相对路径，加上配置目录前缀
            local temp_config="${CONFIG_DIR}/$1"
            # 如果文件不存在，尝试加上 .yaml 后缀
            if [ -f "$temp_config" ]; then
                config_file="$temp_config"
            elif [ -f "${temp_config}.yaml" ]; then
                config_file="${temp_config}.yaml"
            fi
        fi
    fi
    
    # 检查配置文件是否存在
    if [ ! -f "$config_file" ]; then
        echo -e "${RED}错误：配置文件 '$config_file' 不存在！${NC}"
        echo -e "${BLUE}配置文件目录：${CONFIG_DIR}${NC}"
        return 1
    fi
    
    # 从配置文件读取 external-controller
    local controller_line=$(grep -i "external-controller" "$config_file" 2>/dev/null)
    if [ -n "$controller_line" ]; then
        # 使用简单的方法提取值，去掉空格
        CONTROLLER=$(echo "$controller_line" | awk -F 'external-controller:' '{print $2}' | sed 's/^ *//; s/ *$//')
    else
        CONTROLLER="127.0.0.1:9090"
    fi
    
    # 提取 IP 和端口
    API_IP=$(echo "$CONTROLLER" | cut -d: -f1)
    API_PORT=$(echo "$CONTROLLER" | cut -d: -f2)
    
    # 处理密码认证（如果有）
    local secret_line=$(grep -i "secret" "$config_file" 2>/dev/null)
    if [ -n "$secret_line" ]; then
        SECRET=$(echo "$secret_line" | awk -F 'secret:' '{print $2}' | sed 's/^ *//; s/ *$//')
        API_AUTH="-H 'Authorization: Bearer $SECRET'"
    else
        API_AUTH=""
    fi
    
    # 从配置文件获取代理端口
    local mixed_port_line=$(grep -i "mixed-port" "$config_file" 2>/dev/null)
    local port_line=$(grep -i "port" "$config_file" 2>/dev/null | grep -v "external-controller" | grep -v "socks-port" | grep -v "redir-port")
    
    if [ -n "$mixed_port_line" ]; then
        PROXY_PORT=$(echo "$mixed_port_line" | awk -F 'mixed-port:' '{print $2}' | sed 's/^ *//; s/ *$//')
    elif [ -n "$port_line" ]; then
        PROXY_PORT=$(echo "$port_line" | awk -F 'port:' '{print $2}' | sed 's/^ *//; s/ *$//')
    else
        PROXY_PORT="7890"
    fi
    
    echo -e "${BLUE}API 地址：${NC}http://$CONTROLLER"
    echo -e "${BLUE}配置文件：${NC}$config_file"
    echo -e "${BLUE}代理端口：${NC}$PROXY_PORT"
    return 0
}

# 获取所有代理组
get_proxy_groups() {
    local url="http://$CONTROLLER/proxies"
    
    # 测试API连接
    if ! curl -s $API_AUTH "$url" > /dev/null 2>&1; then
        echo -e "${RED}错误：无法连接到 Clash API！${NC}"
        echo -e "${YELLOW}提示：请确保 Clash 已启动且 API 配置正确。${NC}"
        return 1
    fi
    
    # 获取代理组列表
    PROXY_GROUPS=$(curl -s $API_AUTH "$url" | python3 -c "
import json
data = json.loads(input())
groups = []
for name, proxy in data['proxies'].items():
    if proxy['type'] == 'Selector' or proxy['type'] == 'URLTest' or proxy['type'] == 'Fallback':
        groups.append(name)
print('\\n'.join(groups))")
    
    if [ -z "$PROXY_GROUPS" ]; then
        echo -e "${RED}错误：未找到可用的代理组！${NC}"
        return 1
    fi
    
    return 0
}

# 主程序
echo -e "${CYAN}=== Clash节点选择器 ===${NC}"
echo ""

# 获取API信息
get_api_info || exit 1

# 确保配置文件路径可用
global_config_file="$DEFAULT_CONFIG"

# 获取代理组列表
echo -e "${BLUE}正在获取代理组列表...${NC}"
get_proxy_groups || exit 1

# 将代理组转换为数组
IFS=$'\n' read -r -d '' -a GROUPS_ARRAY <<< "$PROXY_GROUPS"

# 优先查找 "节点选择" 或 "Proxy" 代理组作为默认
target_group=""
for group in "${GROUPS_ARRAY[@]}"; do
    if [[ "$group" == "节点选择" || "$group" == "Proxy" ]]; then
        target_group="$group"
        break
    fi
done

# 显示代理组列表并让用户选择
if [ -n "$target_group" ]; then
    # 找到目标代理组，直接使用
    PROXY_GROUP="$target_group"
    # echo -e "${BLUE}自动进入主代理组：${NC}$PROXY_GROUP"
elif [ ${#GROUPS_ARRAY[@]} -eq 1 ]; then
    # 只有一个代理组，直接使用
    PROXY_GROUP="${GROUPS_ARRAY[0]}"
    echo -e "${BLUE}检测到 1 个代理组，自动选择：${NC}$PROXY_GROUP"
elif [ ${#GROUPS_ARRAY[@]} -eq 0 ]; then
    echo -e "${RED}错误：未找到可用的代理组！${NC}"
    exit 1
else
    # 多个代理组且未找到默认组，让用户选择
    echo -e "${BLUE}可用代理组列表：${NC}"
    echo "----------------"
    for i in "${!GROUPS_ARRAY[@]}"; do
        echo "[$i] ${GROUPS_ARRAY[$i]}"
    done
    echo "----------------"
    echo ""
    
    # 循环直到用户输入有效
    while true; do
        echo -ne "${YELLOW}请选择代理组编号 (0-$(( ${#GROUPS_ARRAY[@]} - 1 )))：${NC}"
        read -r GROUP_INDEX
        
        # 检查是否为空输入
        if [ -z "$GROUP_INDEX" ]; then
            echo -e "${YELLOW}提示：请输入代理组编号，或按Ctrl+C退出${NC}"
            continue
        fi
        
        # 验证输入是否为数字
        if ! [[ "$GROUP_INDEX" =~ ^[0-9]+$ ]]; then
            echo -e "${RED}错误：请输入有效的数字！${NC}"
            continue
        fi
        
        # 验证输入的数字是否在有效范围内
        if [ "$GROUP_INDEX" -lt 0 ] || [ "$GROUP_INDEX" -ge "${#GROUPS_ARRAY[@]}" ]; then
            echo -e "${RED}错误：代理组编号超出范围 (0-$(( ${#GROUPS_ARRAY[@]} - 1 )))！${NC}"
            continue
        fi
        
        # 输入有效，退出循环
        break
    done
    
    PROXY_GROUP="${GROUPS_ARRAY[$GROUP_INDEX]}"
fi

echo ""
echo -e "${BLUE}当前节点组：${NC}$PROXY_GROUP"

# 获取当前节点信息
url="http://$CONTROLLER/proxies/$PROXY_GROUP"
CURRENT_NODE=$(curl -s $API_AUTH "$url" | python3 -c "import json; data = json.loads(input()); print(data.get('now', '未知'))")
echo -e "${BLUE}当前选中节点：${NC}$CURRENT_NODE"
echo ""

# 获取可用节点列表
NODES_JSON=$(curl -s $API_AUTH "$url")
NODES_LIST=$(echo "$NODES_JSON" | python3 -c "import json; data = json.loads(input()); print('\n'.join(data.get('all', [])))")

# 将节点列表转换为数组
IFS=$'\n' read -r -d '' -a NODES_ARRAY <<< "$NODES_LIST"
NODE_COUNT=${#NODES_ARRAY[@]}

if [ $NODE_COUNT -eq 0 ]; then
    echo -e "${RED}错误：未找到可用的节点！${NC}"
    exit 1
fi

LAST_INDEX=$((NODE_COUNT - 1))

# 显示节点列表，带数字索引
 echo -e "${BLUE}可用节点列表：${NC}"
 echo "----------------"
 # 过滤并显示实际代理节点
 real_nodes=()
 real_nodes_indices=()
 
 # 重置节点计数器
 node_counter=0
 
 for i in "${!NODES_ARRAY[@]}"; do
     node="${NODES_ARRAY[$i]}"
     # 跳过非实际代理节点
     if [[ "$node" == "节点选择" || "$node" == "剩余流量："* || "$node" == "套餐到期："* || "$node" == "DIRECT" || "$node" == "REJECT" ]]; then
         continue
     fi
     
     real_nodes+=("$node")
     real_nodes_indices+=("$i")
     
     # 高亮显示当前选中的节点
     if [ "$node" == "$CURRENT_NODE" ]; then
         echo -e "${GREEN}[$node_counter] $node${NC}"  # 绿色高亮
     else
         echo "[$node_counter] $node"
     fi
     
     # 增加节点计数器
     ((node_counter++))
 done

echo "----------------"
echo ""

# 循环直到用户输入有效
max_index=$((node_counter - 1))
if [ $max_index -lt 0 ]; then
    echo -e "${RED}错误：未找到可用的实际代理节点！${NC}"
    exit 1
fi

while true; do
    # 获取用户输入
    echo -ne "${YELLOW}请输入要切换的节点编号 (0-$max_index)：${NC}"
    read -r USER_INDEX
    
    # 检查是否为空输入
    if [ -z "$USER_INDEX" ]; then
        echo -e "${YELLOW}提示：请输入节点编号，或按Ctrl+C退出${NC}"
        continue
    fi
    
    # 验证输入是否为数字
    if ! [[ "$USER_INDEX" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}错误：请输入有效的数字！${NC}"
        continue
    fi
    
    # 验证输入的数字是否在有效范围内
    if [ "$USER_INDEX" -lt 0 ] || [ "$USER_INDEX" -gt "$max_index" ]; then
        echo -e "${RED}错误：节点编号超出范围 (0-$max_index)！${NC}"
        continue
    fi
    
    # 输入有效，退出循环
    break

done

# 获取用户选择的节点名称和原始索引
REAL_INDEX="${real_nodes_indices[$USER_INDEX]}"
SELECTED_NODE="${NODES_ARRAY[$REAL_INDEX]}"
echo -e "${BLUE}选择的节点：${NC}$SELECTED_NODE (原始索引: $REAL_INDEX)"
echo ""
echo -e "${BLUE}正在切换到节点：${NC}$SELECTED_NODE"
echo "----------------"

# 使用curl命令切换节点
if curl -s -X PUT $API_AUTH -d "{\"name\": \"$SELECTED_NODE\"}" "$url" > /dev/null 2>&1; then
    # 验证切换结果
    echo -e "${YELLOW}等待节点切换完成...${NC}"
    sleep 2  # 增加等待时间，确保切换生效
    
    # 重新获取当前节点信息
    proxy_info=$(curl -s $API_AUTH "$url")
    NEW_CURRENT_NODE=$(echo "$proxy_info" | python3 -c "import json; print(json.loads(input()).get('now', ''))")
    ALL_PROXIES=$(echo "$proxy_info" | python3 -c "import json; data = json.loads(input()); print('\\n'.join(data.get('all', [])))")
    
    echo "----------------"
    
    # 获取当前代理IP
    echo -e "${YELLOW}正在检测新IP...${NC}"
    current_ip=$(curl -s --connect-timeout 5 --proxy http://127.0.0.1:$PROXY_PORT ifconfig.me)
    
    if [ -n "$current_ip" ]; then
        echo -e "${GREEN}✓ 切换成功！${NC}"
        echo -e "${BLUE}当前节点：${NC}$SELECTED_NODE"
        echo -e "${BLUE}当前IP：${NC}$current_ip"
    else
        echo -e "${RED}✗ 切换可能成功，但无法获取IP${NC}"
    fi
else
    echo -e "${RED}✗ 切换失败：无法连接到 Clash API！${NC}"
fi

echo ""
echo -e "${CYAN}=== 操作完成 ===${NC}"

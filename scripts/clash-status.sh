#!/bin/bash

# 彩色输出定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# 脚本名称
SCRIPT_NAME="$(basename "$0")"

# 基础路径设置
BASE_DIR="$(dirname "$(dirname "$0")")"
SCRIPT_DIR="${BASE_DIR}/scripts"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/runtime.sh"
CONFIG_DIR="${BASE_DIR}/configs"
LOG_DIR="${BASE_DIR}/logs"
CLASH_BIN="${BASE_DIR}/clash"

# 默认日志文件
DEFAULT_LOG="${LOG_DIR}/clash.log"

# 默认配置文件
DEFAULT_CONFIG="${CONFIG_DIR}/config.yaml"

# 显示帮助信息
function show_help() {
    echo -e "${CYAN}=== Clash 状态管理器 ===${NC}"
    echo ""
    echo -e "${BLUE}功能：${NC}"
    echo -e "  检查和管理 Clash 运行状态，包括进程管理、日志查看、代理测试等"
    echo ""
    echo -e "${BLUE}用法：${NC}"
    echo -e "  $SCRIPT_NAME [命令] [选项]"
    echo ""
    echo -e "${BLUE}命令：${NC}"
    echo -e "  ${BLUE}status${NC}          显示 Clash 运行状态"
    echo -e "  ${BLUE}start${NC}           启动 Clash 服务"
    echo -e "  ${BLUE}stop${NC}            停止 Clash 服务"
    echo -e "  ${BLUE}restart${NC}         重启 Clash 服务"
    echo -e "  ${BLUE}logs${NC}            查看 Clash 日志"
    echo -e "  ${BLUE}env${NC}             显示代理环境变量"
    echo -e "  ${BLUE}test${NC}            测试代理连接"
    echo -e "  ${BLUE}help${NC}            显示帮助信息"
    echo ""
    echo -e "${BLUE}示例：${NC}"
    echo -e "  $SCRIPT_NAME status               # 查看 Clash 状态"
    echo -e "  $SCRIPT_NAME logs -f              # 实时查看日志"
    echo -e "  $SCRIPT_NAME restart              # 重启 Clash 服务"
    echo -e "  $SCRIPT_NAME start config_1.yaml  # 使用指定配置文件启动"
    echo ""
    exit 0
}

# 检查Clash是否正在运行
function is_clash_running() {
    if pgrep -x "clash" > /dev/null; then
        return 0  # 正在运行
    else
        return 1  # 未运行
    fi
}

# 获取Clash进程ID
function get_clash_pid() {
    pgrep -x "clash"
}

# 获取Clash进程信息
function get_clash_process_info() {
    ps -ef | grep -E "[c]lash" | head -1
}

# 从配置文件获取API地址
get_api_address() {
    local config_file="${1:-$DEFAULT_CONFIG}"
    
    # 检查配置文件是否存在
    if [ ! -f "$config_file" ]; then
        echo -e "${YELLOW}警告：配置文件 '$config_file' 不存在，使用默认API地址${NC}"
        echo "127.0.0.1:9090"
        return
    fi
    
    local controller
    controller=$(get_clash_config_value "$config_file" "external-controller")
    echo "${controller:-127.0.0.1:9090}"
}

# 显示Clash运行状态
function show_status() {
    echo -e "${CYAN}=== Clash 运行状态 ===${NC}"
    echo ""
    
    if is_clash_running; then
        local pid=$(get_clash_pid)
        local process_info=$(get_clash_process_info)
        
        echo -e "${GREEN}✓ Clash 正在运行！${NC}"
        echo -e "${BLUE}进程 ID：${NC}$pid"
        echo -e "${BLUE}进程信息：${NC}$process_info"
        
        # 检查日志文件
        local log_files=($(ls -1 "${LOG_DIR}/clash"*.log 2>/dev/null))
        if [ ${#log_files[@]} -gt 0 ]; then
            echo -e "${BLUE}日志文件：${NC}"
            for log in "${log_files[@]}"; do
                local size=$(du -h "$log" | cut -f1)
                local log_name=$(basename "$log")
                echo -e "  ${log_name} (${size})"
            done
        fi
        
        # 检查环境变量
        echo -e "${BLUE}代理环境变量：${NC}"
        if [ -n "$http_proxy" ]; then
            echo -e "  http_proxy: ${GREEN}$http_proxy${NC}"
        else
            echo -e "  http_proxy: ${RED}未设置${NC}"
        fi
        
        if [ -n "$https_proxy" ]; then
            echo -e "  https_proxy: ${GREEN}$https_proxy${NC}"
        else
            echo -e "  https_proxy: ${RED}未设置${NC}"
        fi
        
        # 检查API连接
        echo -e "${BLUE}API 连接：${NC}"
        local api_controller=$(get_api_address)
        local api_url="http://$api_controller"
        local api_secret=$(get_clash_config_value "$DEFAULT_CONFIG" "secret")
        local api_auth_args=()
        if [ -n "$api_secret" ]; then
            api_auth_args=(-H "Authorization: Bearer $api_secret")
        fi
        local status_code=$(curl --noproxy '*' -s -o /dev/null -w "%{http_code}" \
            "${api_auth_args[@]}" "$api_url/proxies" 2>/dev/null)
        if [ "$status_code" == "200" ]; then
            echo -e "  ${GREEN}✓ 可连接${NC} ($api_controller)"
        else
            echo -e "  ${RED}✗ 无法连接${NC} ($api_controller)"
        fi
        
    else
        echo -e "${RED}✗ Clash 未在运行！${NC}"
        echo -e "${YELLOW}提示：使用 '$SCRIPT_NAME start' 启动 Clash，或运行 'activate-clash'。${NC}"
    fi
    
    echo ""
}

# 启动Clash服务
function start_clash() {
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
    
    if is_clash_running; then
        echo -e "${YELLOW}提示：Clash 已经在运行！${NC}"
        echo -e "${YELLOW}使用 '$SCRIPT_NAME restart' 重启，或 '$SCRIPT_NAME stop' 停止。${NC}"
        exit 0
    fi
    
    echo -e "${BLUE}正在启动 Clash...${NC}"
    
    # 检查配置文件是否存在
    if [ ! -f "$config_file" ]; then
        echo -e "${RED}错误：配置文件 '$config_file' 不存在！${NC}"
        echo -e "${BLUE}配置文件目录：${CONFIG_DIR}${NC}"
        exit 1
    fi
    
    # 自动创建日志目录
    mkdir -p "$LOG_DIR"

    local mihomo_dir="$HOME/.config/mihomo"
    local clash_dir="$HOME/.config/clash"
    echo -e "${BLUE}正在检查 Country.mmdb 和 GeoSite.dat...${NC}"
    if ! ensure_clash_geodata "$mihomo_dir" "$clash_dir"; then
        echo -e "${RED}错误：地理数据库准备失败，已取消启动。${NC}"
        exit 1
    fi
    
    # 直接使用clash命令启动，确保日志文件正确命名
    local config_name=$(basename "$config_file" .yaml)
    local log_file="${LOG_DIR}/clash_${config_name}.log"
    
    nohup "$CLASH_BIN" -f "$config_file" > "$log_file" 2>&1 &
    CLASH_PID=$!
    
    # 等待 API 真正就绪，并捕获初始化期间发生的崩溃。
    echo -e "${BLUE}正在检查启动状态...${NC}"
    local controller=$(get_api_address "$config_file")
    local secret=$(get_clash_config_value "$config_file" "secret")
    wait_for_clash_api "$CLASH_PID" "$controller" "$secret" 60
    local start_result=$?
    if [ "$start_result" -eq 0 ]; then
        echo -e "${GREEN}✓ Clash 启动成功！${NC}"
        echo -e "${BLUE}日志文件：${NC}$log_file"
        echo -e "${BLUE}进程 ID：${NC}$CLASH_PID"
        
        # 设置代理环境变量
        local port=$(grep -oP 'mixed-port:\s*\K\d+' "$config_file" 2>/dev/null)
        if [ -z "$port" ]; then
            port=$(grep -oP 'port:\s*\K\d+' "$config_file" 2>/dev/null || echo 7890)
        fi
        
        # 自动设置环境变量
        export http_proxy=http://127.0.0.1:$port
        export https_proxy=http://127.0.0.1:$port
        export ALL_PROXY=socks5://127.0.0.1:$port
        export all_proxy=socks5://127.0.0.1:$port
        
        echo -e "${GREEN}✓ 代理环境变量已自动设置：${NC}"
        echo -e "  http_proxy=${http_proxy}"
        echo -e "  https_proxy=${https_proxy}"
        echo -e "  ALL_PROXY=${ALL_PROXY}"
    else
        echo -e "${RED}✗ Clash 启动失败！${NC}"
        if [ "$start_result" -eq 2 ]; then
            echo -e "${YELLOW}等待 API 就绪超时，Clash 进程可能仍在初始化。${NC}"
        fi
        echo -e "${YELLOW}最近的启动日志：${NC}"
        tail -n 20 "$log_file" 2>/dev/null
        exit 1
    fi
    
    echo ""
}

# 停止Clash服务
function stop_clash() {
    if ! is_clash_running; then
        echo -e "${YELLOW}提示：Clash 未在运行！${NC}"
        exit 0
    fi
    
    local pid=$(get_clash_pid)
    echo -e "${BLUE}正在停止 Clash (PID: $pid)...${NC}"
    
    # 停止进程
    kill "$pid"
    
    # 等待进程退出
    local timeout=5
    for ((i=0; i<timeout; i++)); do
        if ! is_clash_running; then
            break
        fi
        sleep 1
    done
    
    if is_clash_running; then
        # 强制杀死进程
        echo -e "${YELLOW}警告：进程未正常退出，正在强制杀死...${NC}"
        kill -9 "$pid"
        sleep 1
    fi
    
    if is_clash_running; then
        echo -e "${RED}✗ Clash 停止失败！${NC}"
        exit 1
    else
        echo -e "${GREEN}✓ Clash 已成功停止！${NC}"
        
        # 清除环境变量（如果需要）
        echo -e "${BLUE}提示：可以运行 'unset http_proxy https_proxy ALL_PROXY all_proxy' 清除代理环境变量。${NC}"
    fi
    
    echo ""
}

# 重启Clash服务
function restart_clash() {
    local config_file="${1:-$DEFAULT_CONFIG}"
    
    echo -e "${CYAN}=== 重启 Clash 服务 ===${NC}"
    echo ""
    
    stop_clash
    start_clash "$config_file"
    
    echo -e "${GREEN}✓ Clash 重启完成！${NC}"
    echo ""
}

# 查看Clash日志
function view_logs() {
    local follow="false"
    local log_file="$DEFAULT_LOG"
    
    # 解析选项
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--follow)
                follow="true"
                shift
                ;;
            -l|--log-file)
                # 处理日志文件路径
                if [[ "$2" != /* ]]; then
                    # 相对路径，加上日志目录前缀
                    log_file="${LOG_DIR}/$2"
                else
                    log_file="$2"
                fi
                shift 2
                ;;
            *)
                echo -e "${RED}错误：无效的选项 '$1'${NC}"
                echo -e "${YELLOW}使用 '$SCRIPT_NAME help' 查看帮助信息。${NC}"
                exit 1
                ;;
        esac
    done
    
    # 检查日志文件是否存在
    if [ ! -f "$log_file" ]; then
        echo -e "${RED}错误：日志文件 '$log_file' 不存在！${NC}"
        
        # 列出可用的日志文件
        local log_files=($(ls -1 "${LOG_DIR}/clash_*.log" 2>/dev/null))
        if [ ${#log_files[@]} -gt 0 ]; then
            echo -e "${YELLOW}可用的日志文件：${NC}"
            for log in "${log_files[@]}"; do
                echo "  $(basename "$log")"
            done
            echo -e "${BLUE}日志文件目录：${LOG_DIR}${NC}"
        fi
        
        exit 1
    fi
    
    echo -e "${CYAN}=== Clash 日志 (${log_file}) ===${NC}"
    echo -e "${BLUE}按 Ctrl+C 退出查看${NC}"
    echo ""
    
    if [ "$follow" == "true" ]; then
        tail -f "$log_file"
    else
        tail -n 50 "$log_file"
        echo -e "\n${BLUE}提示：使用 '$SCRIPT_NAME logs -f' 实时查看日志。${NC}"
    fi
    
    echo ""
}

# 显示代理环境变量
function show_env() {
    echo -e "${CYAN}=== 代理环境变量 ===${NC}"
    echo ""
    
    local env_vars=(
        "http_proxy"
        "https_proxy"
        "HTTP_PROXY"
        "HTTPS_PROXY"
        "ALL_PROXY"
        "all_proxy"
        "NO_PROXY"
        "no_proxy"
    )
    
    for var in "${env_vars[@]}"; do
        if [ -n "${!var}" ]; then
            echo -e "${GREEN}${var}${NC} = ${!var}"
        else
            echo -e "${RED}${var}${NC} = ${NC}<未设置>"
        fi
    done
    
    echo ""
    echo -e "${BLUE}设置环境变量示例：${NC}"
    echo -e "  export http_proxy=http://127.0.0.1:7890"
    echo -e "  export https_proxy=http://127.0.0.1:7890"
    echo ""
    echo -e "${BLUE}清除环境变量示例：${NC}"
    echo -e "  unset http_proxy https_proxy ALL_PROXY all_proxy"
    echo ""
}

# 测试代理连接
function test_proxy() {
    echo -e "${CYAN}=== 代理连接测试 ===${NC}"
    echo ""
    
    # 测试网站列表
    local test_sites=(
        "http://www.google.com"
        "http://www.baidu.com"
        "http://www.github.com"
        "http://www.youtube.com"
    )
    
    echo -e "${BLUE}测试网站连接...${NC}"
    echo -e "${BLUE}----------------${NC}"
    
    for site in "${test_sites[@]}"; do
        echo -n "${site}: "
        
        # 使用curl测试连接，设置超时3秒
        local result=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 "$site")
        
        if [ "$result" == "200" ] || [ "$result" == "301" ] || [ "$result" == "302" ]; then
            echo -e "${GREEN}✓ 成功 (${result})${NC}"
        else
            echo -e "${RED}✗ 失败 (${result})${NC}"
        fi
    done
    
    echo -e "${BLUE}----------------${NC}"
    
    # 测试出口IP
    echo -e "${BLUE}测试出口IP...${NC}"
    local exit_ip=$(curl -s ifconfig.me 2>/dev/null)
    if [ -n "$exit_ip" ]; then
        echo -e "${GREEN}✓ 出口IP：${exit_ip}${NC}"
    else
        echo -e "${RED}✗ 无法获取出口IP${NC}"
    fi
    
    echo ""
}

# 主程序
function main() {
    if [ $# -eq 0 ]; then
        show_status
        exit 0
    fi
    
    local command="$1"
    shift
    
    case "$command" in
        "status")
            show_status
            ;;
            
        "start")
            # 支持配置文件参数
            local config_file="${1:-$DEFAULT_CONFIG}"
            start_clash "$config_file"
            ;;
            
        "stop")
            stop_clash
            ;;
            
        "restart")
            # 支持配置文件参数
            local config_file="${1:-$DEFAULT_CONFIG}"
            restart_clash "$config_file"
            ;;
            
        "logs")
            view_logs "$@"
            ;;
            
        "env")
            show_env
            ;;
            
        "test")
            test_proxy
            ;;
            
        "help")
            show_help
            ;;
            
        *)
            echo -e "${RED}错误：无效的命令 '$command'${NC}"
            echo -e "${YELLOW}使用 '$SCRIPT_NAME help' 查看帮助信息。${NC}"
            exit 1
            ;;
    esac
}

# 执行主程序
main "$@"

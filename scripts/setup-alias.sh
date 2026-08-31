#!/bin/bash

# 彩色输出定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 获取脚本所在的绝对路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 脚本名称
SCRIPT_NAME="$(basename "$0")"

# 要添加的alias命令
ALIAS1="alias activate-clash='source $SCRIPT_DIR/activate'"
ALIAS2="alias select-node='$SCRIPT_DIR/select-node.sh'"
ALIAS3="alias deactivate-clash='source $SCRIPT_DIR/deactivate'"
ALIAS4="alias clash-status='bash $SCRIPT_DIR/clash-status.sh'"

# 显示帮助信息
function show_help() {
    echo -e "${CYAN}=== Clash 别名配置脚本 ===${NC}"
    echo ""
    echo -e "${BLUE}功能：${NC}"
    echo -e "  自动配置 Clash 相关命令的别名到 shell 配置文件"
    echo -e "  自动安装 proxy_on / proxy_off 代理快捷函数"
    echo -e "  支持 bash 和 zsh 环境"
    echo -e "  支持卸载功能"
    echo ""
    echo -e "${BLUE}用法：${NC}"
    echo -e "  $SCRIPT_NAME [选项]"
    echo ""
    echo -e "${BLUE}选项：${NC}"
    echo -e "  ${BLUE}-h, --help${NC}    显示帮助信息"
    echo -e "  ${BLUE}-u, --uninstall${NC}  卸载已配置的别名"
    echo -e "  ${BLUE}-s, --shell <shell>${NC}  指定 shell 类型 (bash/zsh)，默认自动检测"
    echo ""
    echo -e "${BLUE}示例：${NC}"
    echo -e "  $SCRIPT_NAME          # 自动检测 shell 并配置别名"
    echo -e "  $SCRIPT_NAME --uninstall  # 卸载别名"
    echo -e "  $SCRIPT_NAME --shell zsh  # 为 zsh 配置别名"
    echo ""
    exit 0
}

# 检测当前shell
function detect_shell() {
    local current_shell=$(basename "$SHELL")
    if [ "$current_shell" == "bash" ] || [ "$current_shell" == "zsh" ]; then
        echo "$current_shell"
    else
        echo "bash"  # 默认使用 bash
    fi
}

# 获取shell配置文件路径
function get_shell_config() {
    local shell_type=$1
    case "$shell_type" in
        "bash")
            echo "$HOME/.bashrc"
            ;;
        "zsh")
            echo "$HOME/.zshrc"
            ;;
        *)
            echo "$HOME/.bashrc"
            ;;
    esac
}

# 安装别名
function install_aliases() {
    local shell_type=$1
    local config_file=$(get_shell_config "$shell_type")
    
    # 检查配置文件是否存在
    if [ ! -f "$config_file" ]; then
        echo -e "${YELLOW}警告：${config_file} 文件不存在，将创建该文件。${NC}"
        touch "$config_file"
    fi
    
    echo -e "${CYAN}=== 正在配置别名到 ${shell_type} ===${NC}"
    echo -e "${BLUE}配置文件：${NC}$config_file"
    echo ""
    
    # 检查第一个alias是否已存在
    if grep -q "alias activate-clash='source " "$config_file"; then
        echo -e "${GREEN}✓ alias activate-clash 已存在于 ${shell_type} 配置中${NC}"
    else
        # 添加第一个alias
        echo "$ALIAS1" >> "$config_file"
        echo -e "${GREEN}✓ alias activate-clash 已添加到 ${shell_type} 配置中${NC}"
    fi
    
    # 检查第二个alias是否已存在
    if grep -q "alias select-node='" "$config_file"; then
        echo -e "${GREEN}✓ alias select-node 已存在于 ${shell_type} 配置中${NC}"
    else
        # 添加第二个alias
        echo "$ALIAS2" >> "$config_file"
        echo -e "${GREEN}✓ alias select-node 已添加到 ${shell_type} 配置中${NC}"
    fi

    # 检查第三个alias是否已存在
    if grep -q "alias deactivate-clash='" "$config_file"; then
        echo -e "${GREEN}✓ alias deactivate-clash 已存在于 ${shell_type} 配置中${NC}"
    else
        # 添加第三个alias
        echo "$ALIAS3" >> "$config_file"
        echo -e "${GREEN}✓ alias deactivate-clash 已添加到 ${shell_type} 配置中${NC}"
    fi

    # 检查第四个alias是否已存在
    if grep -q "alias clash-status='" "$config_file"; then
        echo -e "${GREEN}✓ alias clash-status 已存在于 ${shell_type} 配置中${NC}"
    else
        # 添加第四个alias
        echo "$ALIAS4" >> "$config_file"
        echo -e "${GREEN}✓ alias clash-status 已添加到 ${shell_type} 配置中${NC}"
    fi

    # 检查 proxy_on/proxy_off 函数是否已配置
    if grep -q "proxy-functions.sh" "$config_file"; then
        echo -e "${GREEN}✓ proxy_on/proxy_off 已存在于 ${shell_type} 配置中${NC}"
    else
        # 追加 source 行
        echo "" >> "$config_file"
        echo "# proxy_on / proxy_off 代理快捷函数" >> "$config_file"
        echo "source $SCRIPT_DIR/proxy-functions.sh" >> "$config_file"
        echo -e "${GREEN}✓ proxy_on/proxy_off 已添加到 ${shell_type} 配置中${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}✨ 配置已完成!${NC}"
    echo -e "${BLUE}请执行以下命令刷新配置:${NC}"
    echo -e "  ${BLUE}source $config_file${NC}"
    echo -e "${BLUE}或重新打开终端窗口以应用新的alias命令。${NC}"
    echo ""
    echo -e "${BLUE}使用方法:${NC}"
    echo -e "  ${BLUE}activate-clash${NC}   # 启动clash代理"
    echo -e "  ${BLUE}select-node${NC}      # 选择代理节点"
    echo -e "  ${BLUE}deactivate-clash${NC} # 关闭代理"
    echo -e "  ${BLUE}clash-status${NC}     # 查看状态"
    echo -e "  ${BLUE}proxy_on${NC}         # 当前终端开启代理环境变量"
    echo -e "  ${BLUE}proxy_off${NC}        # 当前终端清除代理环境变量"
}

# 卸载别名
function uninstall_aliases() {
    local shell_type=$1
    local config_file=$(get_shell_config "$shell_type")
    
    echo -e "${CYAN}=== 正在卸载别名 ===${NC}"
    echo -e "${BLUE}配置文件：${NC}$config_file"
    echo ""
    
    # 检查配置文件是否存在
    if [ ! -f "$config_file" ]; then
        echo -e "${RED}错误：$config_file 文件不存在!${NC}"
        exit 1
    fi
    
    # 卸载第一个alias
    if grep -q "alias activate-clash='source " "$config_file"; then
        # 删除包含activate-clash的行
        sed -i '/alias activate-clash=\x27source /d' "$config_file"
        echo -e "${GREEN}✓ alias activate-clash 已从 ${shell_type} 配置中移除${NC}"
    else
        echo -e "${YELLOW}✗ alias activate-clash 不存在于 ${shell_type} 配置中${NC}"
    fi
    
    # 卸载第二个alias
    if grep -q "alias select-node='" "$config_file"; then
        # 删除包含select-node的行
        sed -i '/alias select-node=\x27/d' "$config_file"
        echo -e "${GREEN}✓ alias select-node 已从 ${shell_type} 配置中移除${NC}"
    else
        echo -e "${YELLOW}✗ alias select-node 不存在于 ${shell_type} 配置中${NC}"
    fi

    # 卸载第三个alias
    if grep -q "alias deactivate-clash='" "$config_file"; then
        # 删除包含deactivate-clash的行
        sed -i '/alias deactivate-clash=\x27/d' "$config_file"
        echo -e "${GREEN}✓ alias deactivate-clash 已从 ${shell_type} 配置中移除${NC}"
    else
        echo -e "${YELLOW}✗ alias deactivate-clash 不存在于 ${shell_type} 配置中${NC}"
    fi

    # 卸载第四个alias
    if grep -q "alias clash-status='" "$config_file"; then
        # 删除包含clash-status的行
        sed -i '/alias clash-status=\x27/d' "$config_file"
        echo -e "${GREEN}✓ alias clash-status 已从 ${shell_type} 配置中移除${NC}"
    else
        echo -e "${YELLOW}✗ alias clash-status 不存在于 ${shell_type} 配置中${NC}"
    fi

    # 卸载 proxy 函数
    if grep -q "proxy-functions.sh" "$config_file"; then
        sed -i '/proxy-functions.sh/d' "$config_file"
        sed -i '/# proxy_on \/ proxy_off 代理快捷函数/d' "$config_file"
        echo -e "${GREEN}✓ proxy_on/proxy_off 已从 ${shell_type} 配置中移除${NC}"
    else
        echo -e "${YELLOW}✗ proxy_on/proxy_off 不存在于 ${shell_type} 配置中${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}✨ 卸载已完成!${NC}"
    echo -e "${BLUE}请执行以下命令刷新配置:${NC}"
    echo -e "  ${BLUE}source $config_file${NC}"
    echo -e "${BLUE}或重新打开终端窗口以应用更改。${NC}"
}

# 主程序
function main() {
    local shell_type=$(detect_shell)
    local action="install"
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                ;;
            -u|--uninstall)
                action="uninstall"
                shift
                ;;
            -s|--shell)
                if [[ $2 =~ ^(bash|zsh)$ ]]; then
                    shell_type=$2
                    shift 2
                else
                    echo -e "${RED}错误：无效的 shell 类型 '$2'，仅支持 bash 和 zsh。${NC}"
                    exit 1
                fi
                ;;
            *)
                echo -e "${RED}错误：无效的参数 '$1'${NC}"
                echo -e "${YELLOW}使用 '$SCRIPT_NAME --help' 查看帮助信息。${NC}"
                exit 1
                ;;
        esac
    done
    
    # 执行操作
    if [ "$action" == "install" ]; then
        install_aliases "$shell_type"
    else
        uninstall_aliases "$shell_type"
    fi
}

# 执行主程序
main "$@"

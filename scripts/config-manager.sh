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

# 配置文件存储目录
CONFIG_DIR="${BASE_DIR}/configs"

# 默认配置文件 - 直接使用文件，不使用符号链接
DEFAULT_CONFIG="${CONFIG_DIR}/config.yaml"

# 配置文件备份目录
BACKUP_DIR="${BASE_DIR}/backups"

# 创建备份目录
mkdir -p "$BACKUP_DIR"

# 显示帮助信息
function show_help() {
    echo -e "${CYAN}=== Clash 配置文件管理器 ===${NC}"
    echo ""
    echo -e "${BLUE}功能：${NC}"
    echo -e "  管理 Clash 配置文件，支持订阅更新、多配置管理、备份恢复等"
    echo ""
    echo -e "${BLUE}用法：${NC}"
    echo -e "  $SCRIPT_NAME [命令] [选项]"
    echo ""
    echo -e "${BLUE}命令：${NC}"
    echo -e "  ${BLUE}update${NC}          从订阅链接更新配置文件"
    echo -e "  ${BLUE}list${NC}            列出所有配置文件"
    echo -e "  ${BLUE}set-default${NC}     设置默认配置文件 (--no-backup 跳过备份)"
    echo -e "  ${BLUE}switch${NC}          直接切换配置文件（同 set-default） (--no-backup 跳过备份)"
    echo -e "  ${BLUE}backup${NC}          备份配置文件"
    echo -e "  ${BLUE}restore${NC}         恢复配置文件"
    echo -e "  ${BLUE}delete${NC}          删除配置文件"
    echo -e "  ${BLUE}help${NC}            显示帮助信息"
    echo ""
    echo -e "${BLUE}示例：${NC}"
    echo -e "  $SCRIPT_NAME update -u <订阅链接>  # 从订阅链接更新配置"
    echo -e "  $SCRIPT_NAME list                  # 列出所有配置文件"
    echo -e "  $SCRIPT_NAME switch config_1.yaml  # 直接切换配置文件"
    echo -e "  $SCRIPT_NAME backup                # 备份当前配置"
    echo ""
    exit 0
}

# 检查curl是否安装
function check_curl() {
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}错误：curl 未安装！${NC}"
        echo -e "${YELLOW}提示：请使用 'apt-get install curl' 或 'yum install curl' 安装。${NC}"
        exit 1
    fi
}

# 从订阅链接更新配置文件
function update_config() {
    local url="$1"
    local output_file="${2:-$DEFAULT_CONFIG}"
    
    check_curl
    
    echo -e "${BLUE}正在从订阅链接更新配置文件...${NC}"
    echo -e "${BLUE}订阅链接：${NC}$url"
    echo -e "${BLUE}输出文件：${NC}$output_file"
    echo ""
    
    # 备份当前配置文件
    if [ -f "$output_file" ]; then
        local backup_file="$BACKUP_DIR/${output_file%.yaml}_$(date +%Y%m%d_%H%M%S).yaml"
        cp "$output_file" "$backup_file"
        echo -e "${GREEN}✓ 当前配置已备份到：${NC}$backup_file"
    fi
    
    # 从订阅链接下载配置
    if curl -s -o "$output_file" "$url"; then
        echo -e "${GREEN}✓ 配置文件更新成功！${NC}"
        echo -e "${BLUE}文件大小：${NC}$(du -h "$output_file" | cut -f1)"
        echo -e "${BLUE}修改时间：${NC}$(date -r "$output_file")"
        
        # 验证配置文件格式
        if grep -q "proxies:" "$output_file"; then
            echo -e "${GREEN}✓ 配置文件格式验证通过。${NC}"
        else
            echo -e "${YELLOW}警告：配置文件可能不完整，建议检查内容。${NC}"
        fi
    else
        echo -e "${RED}✗ 配置文件更新失败！${NC}"
        echo -e "${RED}请检查订阅链接是否正确，或网络连接是否正常。${NC}"
        exit 1
    fi
}

# 列出所有配置文件
function list_configs() {
    echo -e "${CYAN}=== 配置文件列表 ===${NC}"
    echo ""
    
    local config_files=($(find "$CONFIG_DIR" -name "*.yaml" -not -path "$BACKUP_DIR/*" | sort))
    
    if [ ${#config_files[@]} -eq 0 ]; then
        echo -e "${YELLOW}没有找到配置文件。${NC}"
        echo -e "${YELLOW}使用 '$SCRIPT_NAME update -u <订阅链接>' 添加配置文件。${NC}"
        exit 0
    fi
    
    echo -e "${BLUE}序号  文件名                大小    修改时间    状态${NC}"
    echo -e "${BLUE}--------------------------------------------------${NC}"
    
    local i=1
    for file in "${config_files[@]}"; do
        local filename=$(basename "$file")
        local size=$(du -h "$file" | cut -f1)
        local mtime=$(date -r "$file" +"%Y-%m-%d %H:%M")
        
        # 检查是否是当前默认配置
        if [ "$file" == "$DEFAULT_CONFIG" ]; then
            echo -e "${i}    ${filename}  ${size}  ${mtime}  ${GREEN}[默认]${NC}"
        else
            echo -e "${i}    ${filename}  ${size}  ${mtime}"
        fi
        i=$((i+1))
    done
    
    echo -e "${BLUE}--------------------------------------------------${NC}"
    echo -e "${BLUE}总计：${NC}${#config_files[@]} 个配置文件"
    echo ""
    echo -e "${YELLOW}提示：当前默认配置文件：${NC}${GREEN}$DEFAULT_CONFIG${NC}"
    echo -e "${YELLOW}使用 './config-manager.sh set-default <文件名>' 切换默认配置。${NC}"
}

# 设置默认配置文件 - 直接使用文件复制，不使用符号链接
function set_default() {
    local config_file="$1"
    local no_backup=false
    
    # 解析选项
    while [[ $# -gt 1 ]]; do
        case $2 in
            --no-backup)
                no_backup=true
                shift
                ;;
            *)
                echo -e "${RED}错误：无效的选项 '$2'${NC}"
                exit 1
                ;;
        esac
    done
    
    if [ ! -f "$config_file" ]; then
        echo -e "${RED}错误：配置文件 '$config_file' 不存在！${NC}"
        exit 1
    fi
    
    # 检查是否尝试设置默认配置为自身
    if [ "$config_file" == "$DEFAULT_CONFIG" ]; then
        echo -e "${YELLOW}提示：$config_file 已经是默认配置文件！${NC}"
        exit 0
    fi
    
    # 检查是否已经是默认配置（通过内容比较）
    if [ -f "$DEFAULT_CONFIG" ]; then
        # 使用diff简化比较
        if diff -q "$config_file" "$DEFAULT_CONFIG" >/dev/null 2>&1; then
            echo -e "${YELLOW}提示：$config_file 与当前默认配置内容相同，无需切换！${NC}"
            exit 0
        fi
    fi
    
    # 备份当前默认配置（如果存在且未使用 --no-backup 选项）
    if [ -f "$DEFAULT_CONFIG" ] && [ "$no_backup" == false ]; then
        local backup_file="$BACKUP_DIR/${DEFAULT_CONFIG%.yaml}_$(date +%Y%m%d_%H%M%S).yaml"
        cp "$DEFAULT_CONFIG" "$backup_file"
        echo -e "${GREEN}✓ 当前默认配置已备份到：${NC}$backup_file"
    fi
    
    # 删除旧的默认配置（如果存在）
    rm -f "$DEFAULT_CONFIG"
    
    # 直接复制文件
    cp "$config_file" "$DEFAULT_CONFIG"
    
    echo -e "${GREEN}✓ 默认配置文件已成功切换到：${NC}$config_file"
    echo -e "${YELLOW}提示：运行 './clash-status.sh restart' 可立即应用新配置。${NC}"
}

# 备份配置文件
function backup_config() {
    local config_file="${1:-$DEFAULT_CONFIG}"
    
    if [ ! -f "$config_file" ]; then
        echo -e "${RED}错误：配置文件 '$config_file' 不存在！${NC}"
        exit 1
    fi
    
    local backup_name="${config_file%.yaml}_$(date +%Y%m%d_%H%M%S).yaml"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    cp "$config_file" "$backup_path"
    
    echo -e "${GREEN}✓ 配置文件备份成功！${NC}"
    echo -e "${BLUE}原文件：${NC}$config_file"
    echo -e "${BLUE}备份文件：${NC}$backup_path"
    echo -e "${BLUE}文件大小：${NC}$(du -h "$backup_path" | cut -f1)"
}

# 恢复配置文件
function restore_config() {
    echo -e "${CYAN}=== 恢复配置文件 ===${NC}"
    echo ""
    
    local backups=($(find "$BACKUP_DIR" -name "*.yaml" | sort -r))
    
    if [ ${#backups[@]} -eq 0 ]; then
        echo -e "${YELLOW}没有找到备份文件。${NC}"
        exit 0
    fi
    
    echo -e "${BLUE}可用备份文件：${NC}"
    echo -e "${BLUE}序号  备份文件名               修改时间${NC}"
    echo -e "${BLUE}---------------------------------------${NC}"
    
    local i=1
    for backup in "${backups[@]}"; do
        local filename=$(basename "$backup")
        local mtime=$(date -r "$backup" +"%Y-%m-%d %H:%M")
        echo "${i}    ${filename}  ${mtime}"
        i=$((i+1))
    done
    
    echo -e "${BLUE}---------------------------------------${NC}"
    
    # 选择备份文件
    while true; do
        echo -n "${YELLOW}请选择要恢复的备份序号 (1-${#backups[@]})：${NC}"
        read -r choice
        
        if [[ $choice =~ ^[0-9]+$ ]] && [ $choice -ge 1 ] && [ $choice -le ${#backups[@]} ]; then
            break
        else
            echo -e "${RED}错误：无效的选择！${NC}"
        fi
    done
    
    local selected_backup="${backups[$((choice-1))]}"
    local restore_name=$(basename "$selected_backup" | sed 's/\(.*\)_\([0-9]\{8\}_[0-9]\{6\}\)\.yaml/\1.yaml/')
    
    echo ""
    echo -e "${BLUE}正在恢复配置文件...${NC}"
    echo -e "${BLUE}备份文件：${NC}$selected_backup"
    echo -e "${BLUE}恢复为：${NC}$restore_name"
    
    # 备份当前配置
    if [ -f "$restore_name" ]; then
        local current_backup="$BACKUP_DIR/${restore_name%.yaml}_current_$(date +%Y%m%d_%H%M%S).yaml"
        cp "$restore_name" "$current_backup"
        echo -e "${GREEN}✓ 当前配置已备份到：${NC}$current_backup"
    fi
    
    # 恢复配置
    cp "$selected_backup" "$restore_name"
    
    echo -e "${GREEN}✓ 配置文件恢复成功！${NC}"
    echo -e "${BLUE}恢复文件：${NC}$restore_name"
    echo -e "${BLUE}文件大小：${NC}$(du -h "$restore_name" | cut -f1)"
}

# 删除配置文件
function delete_config() {
    echo -e "${CYAN}=== 删除配置文件 ===${NC}"
    echo ""
    
    local config_files=($(find "$CONFIG_DIR" -name "*.yaml" -not -path "$BACKUP_DIR/*" -not -name "$DEFAULT_CONFIG" | sort))
    
    if [ ${#config_files[@]} -eq 0 ]; then
        echo -e "${YELLOW}没有可删除的配置文件。${NC}"
        echo -e "${YELLOW}默认配置文件 '$DEFAULT_CONFIG' 不能直接删除。${NC}"
        exit 0
    fi
    
    echo -e "${BLUE}可删除的配置文件：${NC}"
    echo -e "${BLUE}序号  文件名                大小    修改时间${NC}"
    echo -e "${BLUE}-------------------------------------------${NC}"
    
    local i=1
    for file in "${config_files[@]}"; do
        local filename=$(basename "$file")
        local size=$(du -h "$file" | cut -f1)
        local mtime=$(date -r "$file" +"%Y-%m-%d %H:%M")
        echo "${i}    ${filename}  ${size}  ${mtime}"
        i=$((i+1))
    done
    
    echo -e "${BLUE}-------------------------------------------${NC}"
    echo -e "${RED}注意：删除操作不可恢复，请谨慎操作！${NC}"
    
    # 选择要删除的文件
    while true; do
        echo -n "${YELLOW}请选择要删除的配置序号 (1-${#config_files[@]}, 0 取消)：${NC}"
        read -r choice
        
        if [ "$choice" == "0" ]; then
            echo -e "${YELLOW}操作已取消。${NC}"
            exit 0
        fi
        
        if [[ $choice =~ ^[0-9]+$ ]] && [ $choice -ge 1 ] && [ $choice -le ${#config_files[@]} ]; then
            break
        else
            echo -e "${RED}错误：无效的选择！${NC}"
        fi
    done
    
    local selected_file="${config_files[$((choice-1))]}"
    local filename=$(basename "$selected_file")
    
    echo ""
    echo -e "${RED}确定要删除配置文件 '$filename' 吗？(y/N)${NC}"
    read -r confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        rm "$selected_file"
        echo -e "${GREEN}✓ 配置文件 '$filename' 已删除！${NC}"
    else
        echo -e "${YELLOW}操作已取消。${NC}"
    fi
}

# 主程序
function main() {
    if [ $# -eq 0 ]; then
        show_help
    fi
    
    local command="$1"
    shift
    
    case "$command" in
        "update")
            local url=""
            local output=""
            
            # 解析选项
            while [[ $# -gt 0 ]]; do
                case $1 in
                    -u|--url)
                        url="$2"
                        shift 2
                        ;;
                    -o|--output)
                        output="$2"
                        shift 2
                        ;;
                    *)
                        echo -e "${RED}错误：无效的选项 '$1'${NC}"
                        echo -e "${YELLOW}使用 '$SCRIPT_NAME help' 查看帮助信息。${NC}"
                        exit 1
                        ;;
                esac
            done
            
            if [ -z "$url" ]; then
                echo -e "${RED}错误：请提供订阅链接！${NC}"
                echo -e "${YELLOW}用法：$SCRIPT_NAME update -u <订阅链接> [-o <输出文件>]${NC}"
                exit 1
            fi
            
            update_config "$url" "$output"
            ;;
            
        "list")
            list_configs
            ;;
            
        "set-default")
            if [ $# -ne 1 ]; then
                echo -e "${RED}错误：请指定要设置为默认的配置文件名！${NC}"
                echo -e "${YELLOW}用法：$SCRIPT_NAME set-default <配置文件名>${NC}"
                exit 1
            fi
            set_default "$1"
            ;;
            
        "switch")
            if [ $# -ne 1 ]; then
                echo -e "${RED}错误：请指定要切换的配置文件名！${NC}"
                echo -e "${YELLOW}用法：$SCRIPT_NAME switch <配置文件名>${NC}"
                exit 1
            fi
            # 直接调用 set_default 函数，使用相同的逻辑
            set_default "$1"
            ;;
            
        "backup")
            local config_file="${1:-}"
            backup_config "$config_file"
            ;;
            
        "restore")
            restore_config
            ;;
            
        "delete")
            delete_config
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
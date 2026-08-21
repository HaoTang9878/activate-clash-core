#!/bin/bash

# 读取 Clash YAML 中常见的单行标量。该函数只读取配置，不会修改订阅文件。
# 支持未加引号、单引号及双引号的值；调用方负责提供默认值。
get_clash_config_value() {
    local config_file="$1"
    local key="$2"
    local value

    [ -f "$config_file" ] || return 1

    value=$(sed -n -E "s/^[[:space:]]*${key}:[[:space:]]*//p" "$config_file" | head -n 1)
    [ -n "$value" ] || return 1

    # 去除首尾空白。
    value=$(printf '%s' "$value" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

    # YAML 引号是语法的一部分，不能被带入 API 地址或认证头。
    if [[ "$value" == \"* ]]; then
        value="${value#\"}"
        value="${value%%\"*}"
    elif [[ "$value" == \'* ]]; then
        value="${value#\'}"
        value="${value%%\'*}"
    else
        # 无引号标量中，空白后的 # 表示 YAML 行内注释。
        value=$(printf '%s' "$value" | sed 's/[[:space:]]#.*$//; s/[[:space:]]*$//')
    fi

    printf '%s\n' "$value"
}

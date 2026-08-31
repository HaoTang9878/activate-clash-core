# proxy_on / proxy_off —— 当前终端代理开关
#
# 特性：
#   * proxy_on : clash 已在后台运行 -> 仅给当前 shell 设置代理环境变量（秒开）
#                clash 未运行      -> 自动调用 activate 启动并设置变量
#   * proxy_off: 清除当前 shell 的代理环境变量
#
# 安装：由 setup-alias.sh 自动 source 到 ~/.bashrc / ~/.zshrc；
#       也可以手动执行:  source scripts/proxy-functions.sh
#
# 注意：代理环境变量按终端隔离，新建终端需重新执行 proxy_on。

proxy_on() {
    local PORT
    local DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local CFG="$DIR/../configs/config.yaml"
    if pgrep -x clash > /dev/null; then
        PORT=$(grep -oP 'mixed-port:\s*\K\d+' "$CFG" 2>/dev/null)
        [ -z "$PORT" ] && PORT=7890
        export http_proxy="http://127.0.0.1:$PORT"
        export https_proxy="http://127.0.0.1:$PORT"
        export ALL_PROXY="socks5://127.0.0.1:$PORT"
        export all_proxy="socks5://127.0.0.1:$PORT"
        echo "✓ Clash 已在运行（端口 $PORT），代理环境变量已设置："
        echo "  http_proxy=$http_proxy"
        echo "  https_proxy=$https_proxy"
        echo "  ALL_PROXY=$ALL_PROXY"
    else
        source "$DIR/activate"
    fi
    # 本地地址不走代理（避免 select-node / API 调用被代理劫持）
    export no_proxy="localhost,127.0.0.1"
    export NO_PROXY="localhost,127.0.0.1"
}

proxy_off() {
    unset http_proxy https_proxy ALL_PROXY all_proxy
    echo "✓ 代理环境变量已清除"
}

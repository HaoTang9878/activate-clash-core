#!/bin/bash

# Mihomo 官方文档提供的 Cloudflare-backed jsDelivr 地址，在国内服务器上
# 通常比 GitHub Release 直连稳定。
GEODATA_BASE_URL="https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release"

calculate_sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

ensure_geodata_asset() {
    local local_name="$1"
    local remote_name="$2"
    local mihomo_dir="$3"
    local clash_dir="$4"
    local checksum_file download_file expected_checksum actual_checksum source_file
    local mihomo_file="${mihomo_dir}/${local_name}"
    local clash_file="${clash_dir}/${local_name}"

    checksum_file=$(mktemp)
    download_file=$(mktemp)

    if ! curl --noproxy '*' -fsSL --retry 2 --connect-timeout 10 --max-time 60 \
        "${GEODATA_BASE_URL}/${remote_name}.sha256sum" -o "$checksum_file"; then
        rm -f "$checksum_file" "$download_file"
        echo "无法获取 ${local_name} 校验信息。" >&2
        return 1
    fi

    expected_checksum=$(awk 'NR == 1 {print tolower($1)}' "$checksum_file")
    if ! [[ "$expected_checksum" =~ ^[0-9a-f]{64}$ ]]; then
        rm -f "$checksum_file" "$download_file"
        echo "${local_name} 校验信息格式无效。" >&2
        return 1
    fi

    source_file=""
    for candidate in "$mihomo_file" "$clash_file"; do
        if [ -f "$candidate" ]; then
            actual_checksum=$(calculate_sha256 "$candidate")
            if [ "$actual_checksum" = "$expected_checksum" ]; then
                source_file="$candidate"
                break
            fi
        fi
    done

    if [ -z "$source_file" ]; then
        echo "正在下载并校验 ${local_name}..."
        if ! curl --noproxy '*' -fsSL --retry 2 --connect-timeout 10 --max-time 180 \
            "${GEODATA_BASE_URL}/${remote_name}" -o "$download_file"; then
            rm -f "$checksum_file" "$download_file"
            echo "${local_name} 下载失败。" >&2
            return 1
        fi

        actual_checksum=$(calculate_sha256 "$download_file")
        if [ "$actual_checksum" != "$expected_checksum" ]; then
            rm -f "$checksum_file" "$download_file"
            echo "${local_name} 校验失败，已拒绝使用损坏文件。" >&2
            return 1
        fi
        source_file="$download_file"
    fi

    mkdir -p "$mihomo_dir" "$clash_dir"
    if [ "$source_file" != "$mihomo_file" ]; then
        cp "$source_file" "$mihomo_file"
    fi
    if [ "$source_file" != "$clash_file" ]; then
        cp "$source_file" "$clash_file"
    fi

    rm -f "$checksum_file" "$download_file"
    return 0
}

ensure_clash_geodata() {
    local mihomo_dir="$1"
    local clash_dir="$2"

    ensure_geodata_asset "Country.mmdb" "country.mmdb" "$mihomo_dir" "$clash_dir" || return 1
    ensure_geodata_asset "GeoSite.dat" "geosite.dat" "$mihomo_dir" "$clash_dir" || return 1
}

wait_for_clash_api() {
    local clash_pid="$1"
    local controller="$2"
    local secret="$3"
    local timeout_seconds="${4:-60}"
    local elapsed=0
    local auth_args=()

    if [ -n "$secret" ]; then
        auth_args=(-H "Authorization: Bearer $secret")
    fi

    while [ "$elapsed" -lt "$timeout_seconds" ]; do
        if ! kill -0 "$clash_pid" 2>/dev/null; then
            return 1
        fi
        if curl --noproxy '*' -fsS --connect-timeout 1 --max-time 2 \
            "${auth_args[@]}" "http://${controller}/version" >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done

    return 2
}

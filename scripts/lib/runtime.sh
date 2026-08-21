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

is_plausible_geodata() {
    local local_name="$1"
    local file="$2"
    local file_size

    [ -f "$file" ] || return 1
    file_size=$(wc -c < "$file" | tr -d '[:space:]')
    [ "$file_size" -ge 1048576 ] || return 1

    # MaxMind DB 的元数据区包含固定标识；GeoSite 是无固定魔数的 protobuf，
    # 因此至少要求达到完整数据库的合理体积。
    if [ "$local_name" = "Country.mmdb" ]; then
        LC_ALL=C grep -aFq "MaxMind.com" "$file" || return 1
    fi
    return 0
}

install_verified_geodata() {
    local source_file="$1"
    local checksum="$2"
    local mihomo_file="$3"
    local clash_file="$4"

    if [ "$source_file" != "$mihomo_file" ]; then
        cp "$source_file" "$mihomo_file"
    fi
    if [ "$source_file" != "$clash_file" ]; then
        cp "$source_file" "$clash_file"
    fi
    printf '%s\n' "$checksum" > "${mihomo_file}.sha256"
    printf '%s\n' "$checksum" > "${clash_file}.sha256"
}

ensure_geodata_asset() {
    local local_name="$1"
    local remote_name="$2"
    local mihomo_dir="$3"
    local clash_dir="$4"
    local checksum_file download_file expected_checksum actual_checksum saved_checksum source_file
    local mihomo_file="${mihomo_dir}/${local_name}"
    local clash_file="${clash_dir}/${local_name}"

    mkdir -p "$mihomo_dir" "$clash_dir"

    # 优先验证本地记录。地理数据库是启动依赖，不应在每次启动时被远程滚动
    # 更新和 CDN 缓存时差阻断。
    source_file=""
    for candidate in "$mihomo_file" "$clash_file"; do
        if [ -f "$candidate" ] && [ -f "${candidate}.sha256" ]; then
            saved_checksum=$(sed -n '1p' "${candidate}.sha256")
            actual_checksum=$(calculate_sha256 "$candidate")
            if [[ "$saved_checksum" =~ ^[0-9a-f]{64}$ ]] && [ "$actual_checksum" = "$saved_checksum" ]; then
                source_file="$candidate"
                expected_checksum="$saved_checksum"
                break
            fi
        fi
    done

    if [ -n "$source_file" ]; then
        install_verified_geodata "$source_file" "$expected_checksum" "$mihomo_file" "$clash_file"
        return 0
    fi

    # 兼容升级前已成功使用但尚无本地校验记录的数据库。
    for candidate in "$mihomo_file" "$clash_file"; do
        if is_plausible_geodata "$local_name" "$candidate"; then
            actual_checksum=$(calculate_sha256 "$candidate")
            install_verified_geodata "$candidate" "$actual_checksum" "$mihomo_file" "$clash_file"
            return 0
        fi
    done

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

    install_verified_geodata "$source_file" "$expected_checksum" "$mihomo_file" "$clash_file"

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

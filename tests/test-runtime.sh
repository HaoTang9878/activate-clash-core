#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/lib/runtime.sh"

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

RELEASE_DIR="$TMP_DIR/release"
MIHOMO_TEST_DIR="$TMP_DIR/mihomo"
CLASH_TEST_DIR="$TMP_DIR/clash"
mkdir -p "$RELEASE_DIR" "$MIHOMO_TEST_DIR" "$CLASH_TEST_DIR"

printf 'valid country database fixture\n' > "$RELEASE_DIR/country.mmdb"
printf 'valid geosite database fixture\n' > "$RELEASE_DIR/geosite.dat"
printf '%s  country.mmdb\n' "$(calculate_sha256 "$RELEASE_DIR/country.mmdb")" > "$RELEASE_DIR/country.mmdb.sha256sum"
printf '%s  geosite.dat\n' "$(calculate_sha256 "$RELEASE_DIR/geosite.dat")" > "$RELEASE_DIR/geosite.dat.sha256sum"

# 模拟已有的损坏文件，确保它会被校验后的文件替换。
printf 'damaged\n' > "$MIHOMO_TEST_DIR/GeoSite.dat"
GEODATA_BASE_URL="file://$RELEASE_DIR"
ensure_clash_geodata "$MIHOMO_TEST_DIR" "$CLASH_TEST_DIR"

expected_country=$(calculate_sha256 "$RELEASE_DIR/country.mmdb")
expected_geosite=$(calculate_sha256 "$RELEASE_DIR/geosite.dat")
for installed_file in "$MIHOMO_TEST_DIR/Country.mmdb" "$CLASH_TEST_DIR/Country.mmdb"; do
    [ "$(calculate_sha256 "$installed_file")" = "$expected_country" ]
done
for installed_file in "$MIHOMO_TEST_DIR/GeoSite.dat" "$CLASH_TEST_DIR/GeoSite.dat"; do
    [ "$(calculate_sha256 "$installed_file")" = "$expected_geosite" ]
done

# 后续启动只使用本地校验记录，不再依赖滚动更新中的远程校验文件。
GEODATA_BASE_URL="file://$TMP_DIR/unavailable"
ensure_clash_geodata "$MIHOMO_TEST_DIR" "$CLASH_TEST_DIR"
[ "$(sed -n '1p' "$MIHOMO_TEST_DIR/Country.mmdb.sha256")" = "$expected_country" ]
[ "$(sed -n '1p' "$MIHOMO_TEST_DIR/GeoSite.dat.sha256")" = "$expected_geosite" ]

# CDN 的数据文件和校验文件短暂不同步时，结构有效的下载仍可用于首次安装。
FALLBACK_RELEASE_DIR="$TMP_DIR/fallback-release"
FALLBACK_MIHOMO_DIR="$TMP_DIR/fallback-mihomo"
FALLBACK_CLASH_DIR="$TMP_DIR/fallback-clash"
mkdir -p "$FALLBACK_RELEASE_DIR"
dd if=/dev/zero of="$FALLBACK_RELEASE_DIR/country.mmdb" bs=1048576 count=1 2>/dev/null
printf 'MaxMind.com\n' >> "$FALLBACK_RELEASE_DIR/country.mmdb"
dd if=/dev/zero of="$FALLBACK_RELEASE_DIR/geosite.dat" bs=1048576 count=1 2>/dev/null
printf 'protobuf fixture\n' >> "$FALLBACK_RELEASE_DIR/geosite.dat"
printf '%064d  country.mmdb\n' 0 > "$FALLBACK_RELEASE_DIR/country.mmdb.sha256sum"
printf '%064d  geosite.dat\n' 0 > "$FALLBACK_RELEASE_DIR/geosite.dat.sha256sum"

GEODATA_BASE_URL="file://$FALLBACK_RELEASE_DIR"
ensure_clash_geodata "$FALLBACK_MIHOMO_DIR" "$FALLBACK_CLASH_DIR"
[ "$(sed -n '1p' "$FALLBACK_MIHOMO_DIR/Country.mmdb.sha256")" = "$(calculate_sha256 "$FALLBACK_RELEASE_DIR/country.mmdb")" ]
[ "$(sed -n '1p' "$FALLBACK_MIHOMO_DIR/GeoSite.dat.sha256")" = "$(calculate_sha256 "$FALLBACK_RELEASE_DIR/geosite.dat")" ]

# API 就绪检查必须绕过代理；模拟成功响应以验证等待逻辑。
curl() {
    [ "$1" = "--noproxy" ] && [ "$2" = "*" ]
}
wait_for_clash_api "$$" "127.0.0.1:9090" "token with spaces" 1
unset -f curl

echo "PASS: Clash runtime helpers"

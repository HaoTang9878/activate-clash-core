#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/lib/config.sh"

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

assert_equal() {
    local expected="$1"
    local actual="$2"
    local description="$3"
    if [ "$expected" != "$actual" ]; then
        echo "FAIL: $description (expected: $expected, actual: $actual)" >&2
        exit 1
    fi
}

for quote in single double plain; do
    config_file="$TMP_DIR/$quote.yaml"
    case "$quote" in
        single) printf "external-controller: '127.0.0.1:9090'\n" > "$config_file" ;;
        double) printf 'external-controller: "127.0.0.1:9090"\n' > "$config_file" ;;
        plain) printf 'external-controller: 127.0.0.1:9090\n' > "$config_file" ;;
    esac

    before=$(cksum "$config_file")
    controller=$(get_clash_config_value "$config_file" "external-controller")
    after=$(cksum "$config_file")
    assert_equal "127.0.0.1:9090" "$controller" "$quote controller parsing"
    assert_equal "$before" "$after" "$quote config remains unchanged"
    assert_equal "http://127.0.0.1:9090/proxies" "http://$controller/proxies" "$quote API URL"
done

comment_file="$TMP_DIR/comment.yaml"
printf 'external-controller: 127.0.0.1:9090 # Clash API\n' > "$comment_file"
controller=$(get_clash_config_value "$comment_file" "external-controller")
assert_equal "127.0.0.1:9090" "$controller" "plain controller with inline comment"

missing_file="$TMP_DIR/missing.yaml"
printf 'mixed-port: 7890\n' > "$missing_file"
controller=$(get_clash_config_value "$missing_file" "external-controller" || true)
assert_equal "" "$controller" "missing controller parsing"
assert_equal "127.0.0.1:9090" "${controller:-127.0.0.1:9090}" "default controller fallback"

secret_file="$TMP_DIR/secret.yaml"
printf "secret: 'token with spaces'\n" > "$secret_file"
secret=$(get_clash_config_value "$secret_file" "secret")
assert_equal "token with spaces" "$secret" "quoted secret parsing"
curl_auth_args=(-H "Authorization: Bearer $secret")
assert_equal "Authorization: Bearer token with spaces" "${curl_auth_args[1]}" "authorization header remains one argument"

echo "PASS: Clash configuration parser"

#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
订阅自动更新脚本（适用于 sakura-cat / tube-cat 等机场）

流程：
    下载订阅（clash UA 返回 Clash YAML，普通 UA 返回 base64 trojan 链接）
    -> 解析 trojan 节点 -> 重建 proxies + proxy-groups（include-all 策略组）
    -> 保留原配置头部与 rules -> 备份旧配置 -> 重启 clash

路径自动识别：脚本位于 <仓库>/scripts/ 下，仓库根目录自动推导。
订阅链接：默认读取 <仓库>/sub_url.txt（已被 .gitignore 忽略，不会入库），
          也可通过环境变量 SUB_URL_FILE 指定其它路径。

用法：
    python3 scripts/update-clash-sub.py          # 正常更新
    SUB_DRY_RUN=1 python3 scripts/update-clash-sub.py   # 试运行：只解析不落盘不重启

定时任务示例（crontab -e）：
    0 */6 * * * /usr/bin/python3 /path/to/activate-clash-core/scripts/update-clash-sub.py > /dev/null 2>&1

依赖：python3 + PyYAML（Debian/Ubuntu: apt install python3-yaml；或 pip install pyyaml）
"""
import base64
import os
import re
import subprocess
import sys
import time
import urllib.parse
import urllib.request
from datetime import datetime

# ---- 路径自动推导 ----
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
BASE = os.path.dirname(SCRIPT_DIR)                       # 仓库根目录
CONFIG = os.path.join(BASE, "configs", "config.yaml")
BACKUP_DIR = os.path.join(BASE, "backups")
SUB_URL_FILE = os.environ.get("SUB_URL_FILE") or os.path.join(BASE, "sub_url.txt")
ACTIVATE = os.path.join(SCRIPT_DIR, "activate")
LOG = os.path.join(BASE, "logs", "update-clash-sub.log")
WORKDIR = os.environ.get("SUB_WORKDIR") or os.getcwd()
DRY_RUN = os.environ.get("SUB_DRY_RUN") == "1"
UA = "clash-verge/v1.8.2"


def log(msg):
    line = "[%s] %s" % (datetime.now().strftime("%Y-%m-%d %H:%M:%S"), msg)
    print(line)
    if DRY_RUN:
        return
    try:
        with open(LOG, "a", encoding="utf-8") as f:
            f.write(line + "\n")
    except Exception:
        pass


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read()


def parse_trojan_links(text):
    """解析 trojan:// 链接格式"""
    nodes, seen = [], set()
    for line in text.splitlines():
        line = line.strip()
        if not line or "://" not in line:
            continue
        if not line.lower().startswith("trojan://"):
            log("跳过不支持的协议: %s" % line.split("://", 1)[0])
            continue
        try:
            p = urllib.parse.urlsplit(line)
            if not p.hostname or not p.port:
                continue
            q = urllib.parse.parse_qs(p.query)
            name = urllib.parse.unquote(p.fragment) or "%s:%s" % (p.hostname, p.port)
            if name in seen:
                continue
            seen.add(name)
            nodes.append({
                "name": name,
                "server": p.hostname,
                "port": p.port,
                "password": urllib.parse.unquote(p.username or ""),
                "sni": (q.get("sni") or [""])[0],
                "skip_cert_verify": (q.get("allowInsecure") or ["0"])[0] == "1",
                "udp": True,
            })
        except Exception as e:
            log("解析节点失败 %s...: %s" % (line[:60], e))
    return nodes


def parse_subscription(raw):
    """统一入口：识别并解析订阅内容，返回节点 dict 列表"""
    text = raw.decode("utf-8", errors="replace")

    # 格式一：Clash YAML（含 proxies: 段）
    if "proxies:" in text:
        try:
            import yaml
            doc = yaml.safe_load(text)
            plist = doc.get("proxies") or []
            nodes, seen = [], set()
            for p in plist:
                if not isinstance(p, dict) or p.get("type") != "trojan":
                    continue
                name = str(p.get("name", "") or "")
                if name in seen:
                    continue
                seen.add(name)
                nodes.append({
                    "name": name,
                    "server": str(p.get("server", "") or ""),
                    "port": int(p.get("port") or 0),
                    "password": str(p.get("password", "") or ""),
                    "sni": str(p.get("sni", "") or ""),
                    "skip_cert_verify": bool(p.get("skip-cert-verify", False)),
                    "udp": True,
                })
            if nodes:
                return nodes
        except ImportError:
            log("未安装 PyYAML，无法解析 Clash YAML 订阅，请安装: pip install pyyaml 或 apt install python3-yaml")
        except Exception as e:
            log("YAML 解析失败，尝试链接解析: %s" % e)

    # base64 解码（机场标准链接格式）
    if "trojan://" not in text and re.fullmatch(r"[A-Za-z0-9+/=\s]+", text[:2000] or " "):
        try:
            text = base64.b64decode(text).decode("utf-8", errors="replace")
        except Exception:
            pass

    # 格式二：trojan:// 链接
    return parse_trojan_links(text)


def quote(s):
    return "'" + s.replace("'", "''") + "'"


def build_config(nodes, old_config):
    """保留旧配置的头部(proxies: 之前)与 rules 段，重建 proxies + proxy-groups"""
    lines = old_config.split("\n")

    def find(key):
        for i, l in enumerate(lines):
            if l.strip().startswith(key + ":"):
                return i
        return -1

    pi = find("proxies")
    ri = find("rules")
    if pi < 0 or ri < 0 or ri <= pi:
        raise RuntimeError("旧配置结构异常：找不到 proxies:/rules: 段")
    head = "\n".join(lines[:pi + 1])   # 含 'proxies:' 行
    tail = "\n".join(lines[ri:])       # 含 'rules:' 行

    body = []
    for n in nodes:
        parts = [
            "name: " + quote(n["name"]),
            "type: trojan",
            "server: " + quote(n["server"]),
            "port: %d" % n["port"],
            "password: " + quote(n["password"]),
            "udp: true",
        ]
        if n["sni"]:
            parts.append("sni: " + quote(n["sni"]))
        if n["skip_cert_verify"]:
            parts.append("skip-cert-verify: true")
        body.append("    - { " + ", ".join(parts) + " }")

    groups = [
        "{ name: 节点选择, type: select, proxies: [自动选择], include-all: true }",
        "{ name: 自动选择, type: url-test, include-all: true, url: 'http://cp.cloudflare.com', interval: 7200 }",
        "{ name: 港台番剧, type: select, include-all: true, proxies: [DIRECT] }",
        "{ name: 国际媒体, type: select, include-all: true, proxies: [节点选择] }",
        "{ name: 电报代理, type: select, include-all: true, proxies: [节点选择] }",
        "{ name: 蒸汽平台, type: select, include-all: true, proxies: [DIRECT, 节点选择] }",
    ]
    body.append("proxy-groups:")
    body.extend("    - " + g for g in groups)
    return head + "\n" + "\n".join(body) + "\n" + tail + "\n"


def restart_clash():
    subprocess.run(["pkill", "-x", "clash"], check=False)
    time.sleep(2)
    try:
        r = subprocess.run(
            ["bash", "-c", "cd %s && source %s" % (WORKDIR, ACTIVATE)],
            capture_output=True, text=True, timeout=60,
        )
        time.sleep(2)
        return r.returncode == 0
    except Exception as e:
        log("重启 clash 异常: %s" % e)
        return False


def main():
    if not os.path.exists(SUB_URL_FILE):
        log("错误: 找不到订阅链接文件 %s（请把订阅 URL 写入该文件）" % SUB_URL_FILE)
        return 1
    url = open(SUB_URL_FILE).read().strip()
    if not url:
        log("错误: 订阅链接为空")
        return 1
    log("开始更新订阅...%s" % ("（DRY RUN，不会落盘/重启）" if DRY_RUN else ""))
    try:
        raw = fetch(url)
    except Exception as e:
        log("下载订阅失败: %s（保留旧配置，不重启）" % e)
        return 1
    nodes = parse_subscription(raw)
    if len(nodes) < 5:
        log("解析出的节点过少(%d)，疑似订阅异常，放弃更新" % len(nodes))
        return 1
    log("下载并解析成功：%d 个节点" % len(nodes))
    old = open(CONFIG, encoding="utf-8").read()
    new = build_config(nodes, old)
    if new == old:
        log("配置与上次一致，跳过重启")
        return 0
    if DRY_RUN:
        log("DRY RUN：配置将有变化，跳过写入与重启")
        return 0
    os.makedirs(BACKUP_DIR, exist_ok=True)
    bak = os.path.join(BACKUP_DIR, "config_" + datetime.now().strftime("%Y%m%d_%H%M%S") + ".yaml")
    with open(bak, "w", encoding="utf-8") as f:
        f.write(old)
    with open(CONFIG, "w", encoding="utf-8") as f:
        f.write(new)
    log("配置已更新：%d 个节点，旧配置备份到 %s" % (len(nodes), bak))
    if restart_clash():
        log("Clash 已重启")
        return 0
    log("警告: Clash 重启可能失败，请检查 clash 日志")
    return 1


if __name__ == "__main__":
    sys.exit(main())

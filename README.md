# Activate Clash Core

🚀 **零依赖、一键启动的 Linux 终端代理工具**

专为无图形界面（Headless）服务器环境设计，让你在 Linux 终端也能像在 Windows/Mac 上一样轻松管理 Clash 代理。

---

## ✨ 核心功能

*   **一键起飞**：`activate-clash` 启动代理
*   **节点选择**：`select-node` 可视化切换节点（自动测速、显示IP）
*   **一键关闭**：`deactivate-clash` 停止代理并清理环境
*   **状态监控**：`clash-status` 查看运行状态和日志
*   **自动配置**：自动设置 `http_proxy` 等环境变量，无需手动 export
*   **订阅自动更新**：`update-clash-sub.py` 定时拉取机场订阅、自动重启代理，节点/端口轮换无需手动干预

---

## ⚡️ 30秒极速安装

### 1. 下载项目
```bash
git clone https://github.com/HaoTang9878/activate-clash-core.git
cd activate-clash-core
```

### 2. 赋予权限
```bash
chmod +x scripts/* clash
```

### 3. 创建必要目录
```bash
mkdir -p configs logs backups
```

### 4. 导入订阅 (二选一)

**方式 A：自动导入（推荐）**
```bash
# 替换成你的订阅链接
./scripts/config-manager.sh update -u "https://example.com/subscribe/xxx"
```

**方式 B：手动导入**
将你的 `config.yaml` 文件直接放入 `configs/` 目录。

### 5. 安装命令
```bash
./scripts/setup-alias.sh
source ~/.bashrc  # 让命令立即生效
```

---

## 🚀 快速开始

```bash
activate-clash          # 启动代理（后台运行，自动设置代理环境变量）
select-node             # 选择节点（键盘交互，自动测速）
clash-status            # 查看运行状态和日志
deactivate-clash        # 停止代理并清理环境变量
```

启动后代理监听 `127.0.0.1:7890`（mixed-port，HTTP/SOCKS5 通用），控制 API 位于 `127.0.0.1:9090`。

---

## 🔄 订阅自动更新（强烈推荐）

机场为了反封锁会**定期轮换节点端口**，手动导入的配置很快就会失效。本仓库提供自动化方案：

### 1. 保存订阅链接
```bash
# 把机场后台的订阅 URL 写入文件（文件已被 .gitignore 忽略，不会泄露 token）
echo "https://your-airport.com/subscribe?token=xxx" > sub_url.txt
chmod 600 sub_url.txt
```

### 2. 手动更新一次
```bash
python3 scripts/update-clash-sub.py
```

脚本会：下载订阅 → 解析节点（兼容 Clash YAML / base64 链接两种格式）→ 重建 `proxies` 与策略组（`include-all`，机场新增节点自动进组）→ 保留原配置的端口/DNS/分流规则 → 备份旧配置到 `backups/` → 重启代理。日志写入 `logs/update-clash-sub.log`。

### 3. 配置定时任务（crontab -e）
```bash
# 每 6 小时自动更新一次
0 */6 * * * /usr/bin/python3 /path/to/activate-clash-core/scripts/update-clash-sub.py > /dev/null 2>&1
```

### 试运行模式
```bash
# 只下载解析、不落盘不重启，用于排查订阅问题
SUB_DRY_RUN=1 python3 scripts/update-clash-sub.py
```

> **依赖**：python3 + PyYAML（Debian/Ubuntu: `apt install python3-yaml`；或 `pip install pyyaml`）
>
> **提示**：部分机场每次拉取订阅会轮换约 1/4 的端口，且新端口需要 1-2 分钟才生效。更新完成后如果立刻访问超时，稍等片刻再试即可。

---

## 🎮 常用命令

| 命令 | 说明 |
| :--- | :--- |
| `activate-clash` | **启动代理** (自动后台运行) |
| `select-node` | **切换节点** (支持键盘选择) |
| `clash-status` | **查看状态** (运行状态、日志) |
| `deactivate-clash` | **关闭代理** (停止进程、清理变量) |
| `python3 scripts/update-clash-sub.py` | **手动更新订阅** (自动重启) |

---

## 📂 进阶使用

### 多配置文件切换
如果你有多个机场订阅，可以存为不同文件：
```bash
activate-clash config_game.yaml   # 启动游戏节点配置
activate-clash config_video.yaml  # 启动流媒体配置
```

### 查看实时日志
```bash
clash-status logs -f
```

### 配置文件备份与恢复
```bash
./scripts/config-manager.sh backup     # 备份当前配置
./scripts/config-manager.sh list       # 列出所有配置
./scripts/config-manager.sh switch config_xxx.yaml  # 切换配置
./scripts/config-manager.sh restore    # 从备份恢复
```

---

## 🛠 常见问题

| 问题 | 解决办法 |
| :--- | :--- |
| 代理无法访问外网 | 运行 `select-node` 换一个节点；或 `python3 scripts/update-clash-sub.py` 更新订阅 |
| 更新订阅后立刻超时 | 机场端口轮换有 1-2 分钟生效延迟，稍等重试 |
| `Permission denied (publickey)` | 本机 SSH key 未注册到 GitHub，改用 HTTPS 方式 clone/push |
| 缺少 Country.mmdb | 启动脚本会自动从国内加速源下载 |

---

## 📄 License

MIT

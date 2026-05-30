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
mkdir -p configs logs
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

## 🎮 常用命令

| 命令 | 说明 |
| :--- | :--- |
| `activate-clash` | **启动代理** (自动后台运行) |
| `select-node` | **切换节点** (支持键盘选择) |
| `clash-status` | **查看状态** (运行状态、日志) |
| `deactivate-clash` | **关闭代理** (停止进程、清理变量) |

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

### 更新订阅
```bash
./scripts/config-manager.sh update
```

---

## ❓ 常见问题

**Q: 启动后 `curl google.com` 还是不通？**
A: 请检查：
1. 是否执行了 `activate-clash`？
2. `clash-status` 显示状态是 Running 吗？
3. 尝试 `select-node` 切换一个有效节点。

**Q: 如何卸载？**
A: 运行 `./scripts/setup-alias.sh --uninstall` 即可清理所有系统修改。

**Q: 怎么更新内核？**
A: 这里的 `clash` 文件其实是 [Mihomo (Clash Meta)](https://github.com/MetaCubeX/mihomo) 内核。你可以随时下载最新版 Linux amd64 替换根目录下的 `clash` 文件。

---

## 💖 支持与反馈

如果觉得好用，请给个 Star ⭐️！
有问题欢迎提交 Issue。

# n8n 本地安装脚本

一键式 n8n 原生安装脚本，适用于 Ubuntu 24.04（无需 Docker）。针对国内用户优化，使用镜像源加速安装。

## 功能特性

- **原生安装**: 直接安装，无 Docker 开销
- **镜像源优化**: 使用国内镜像源，下载更快
  - Node.js（npmmirror.com）
  - npm 包（registry.npmmirror.com）
  - Ubuntu APT 源（阿里云镜像）
- **数据库选择**: PostgreSQL（推荐）或 SQLite
- **反向代理**: 可选 Caddy 自动 HTTPS
- **系统服务**: systemd 自动启动
- **防火墙**: 可选 UFW 配置

## 系统要求

- Ubuntu 24.04 LTS（其他版本可能可用但未测试）
- Root 权限（sudo）
- 互联网连接

## 快速开始

1. **下载并运行脚本：**

   ```bash
   wget https://raw.githubusercontent.com/EasyCam/n8n_local_setup/main/setup.sh
   sudo bash setup.sh
   ```
2. **按照交互式提示操作：**

   - 选择部署模式（生产环境带域名 或 本地/内网）
   - 选择数据库类型（PostgreSQL 或 SQLite）
   - 根据需要配置防火墙
3. **访问 n8n：**

   - 本地模式：`http://服务器IP:5678`
   - 生产模式：`https://你的域名.com`

## 部署模式

### 1. 生产模式（带域名）

- 需要有效的域名
- Let's Encrypt 自动 HTTPS
- Caddy 反向代理
- 防火墙配置（端口 80, 443, 22）

### 2. 本地/内网模式

- 通过 5678 端口直接访问
- 无需域名
- 可选防火墙配置（端口 5678, 22）

## 数据库选择

### PostgreSQL（推荐）

- 生产环境性能更好
- 自动创建数据库和用户
- 适合多用户环境

### SQLite

- 轻量级选择
- 适合测试和小型部署
- 单文件数据库

## 安装后操作

### 服务管理

```bash
# 启动 n8n
sudo systemctl start n8n

# 停止 n8n
sudo systemctl stop n8n

# 重启 n8n
sudo systemctl restart n8n

# 查看日志
sudo journalctl -u n8n -f
```

### 升级 n8n

```bash
npm i -g n8n@latest
sudo systemctl restart n8n
```

### 重要路径

- **安装目录**: `/opt/n8n`
- **数据目录**: `/opt/n8n/.n8n`
- **环境变量文件**: `/opt/n8n/.env`
- **服务文件**: `/etc/systemd/system/n8n.service`
- **Caddy 配置**: `/etc/caddy/Caddyfile`（如果使用域名）

## 配置说明

脚本会自动在 `/opt/n8n/.env` 生成优化的环境变量文件。你可以修改此文件来自定义 n8n 行为。

### 主要环境变量

- `N8N_PORT`: 端口号（默认：5678）
- `N8N_HOST`: 主机名或 IP
- `N8N_PROTOCOL`: http 或 https
- `WEBHOOK_URL`: Webhook 基础 URL
- `N8N_ENCRYPTION_KEY`: 数据加密密钥
- `GENERIC_TIMEZONE`: 时区设置

## 故障排除

### 检查服务状态

```bash
sudo systemctl status n8n
```

### 查看详细日志

```bash
sudo journalctl -u n8n --no-pager
```

### 测试数据库连接（PostgreSQL）

```bash
sudo -u postgres psql -c "\l" | grep n8n
```

### 验证防火墙规则

```bash
sudo ufw status verbose
```

## 安全考虑

- 脚本生成安全的随机密码和加密密钥
- 数据库凭据存储在 `/opt/n8n/.env`，具有受限权限
- 可选配置 UFW 防火墙限制访问
- 生产模式自动配置 HTTPS

## 镜像源

本脚本使用以下国内镜像源以加速下载：

- **Node.js**: https://npmmirror.com/mirrors/node/
- **npm 仓库**: https://registry.npmmirror.com
- **Ubuntu 软件包**: https://mirrors.aliyun.com/ubuntu/

## 贡献

欢迎贡献！请随时提交问题和拉取请求。

## 许可证

本项目采用 GPL-3.0 许可证 - 详见 LICENSE 文件。

## 支持

如果遇到任何问题，请：

1. 查看故障排除部分
2. 检查服务日志
3. 提交包含详细错误信息的问题

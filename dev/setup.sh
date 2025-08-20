#!/usr/bin/env bash
set -euo pipefail

# ============================================
# n8n one-click native setup on Ubuntu 24.04 (no Docker)
# 针对本土地区优化，使用镜像源
# - Node.js (淘宝镜像)
# - n8n (淘宝 npm 镜像)
# - Ubuntu APT 源 (阿里云/清华镜像)
# - Optional: PostgreSQL (recommended) or SQLite
# - Optional: Caddy reverse proxy with automatic HTTPS
# - systemd service for auto-start
# - UFW firewall (optional)
# ============================================

APP_NAME="n8n"
APP_USER="n8n"
APP_GROUP="n8n"
INSTALL_DIR="/opt/${APP_NAME}"
ENV_FILE="${INSTALL_DIR}/.env"
DATA_DIR="${INSTALL_DIR}/.n8n"
USE_DOMAIN=false
DOMAIN=""
EMAIL=""
USE_POSTGRES=true
DB_PASSWORD=""
ENCRYPTION_KEY=""
TZ_VALUE="Asia/Shanghai"
OS_OK=false
NEEDS_FIREWALL=false
CADDYFILE="/etc/caddy/Caddyfile"

# 镜像源配置
UBUNTU_MIRROR="https://mirrors.aliyun.com/ubuntu/"
NODEJS_MIRROR="https://npmmirror.com/mirrors/node/"
NPM_REGISTRY="https://registry.npmmirror.com"

log() { echo -e "\033[1;32m[+] $*\033[0m"; }
warn() { echo -e "\033[1;33m[!] $*\033[0m"; }
err() { echo -e "\033[1;31m[-] $*\033[0m" 1>&2; }

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    err "请以 root 身份运行（例如：sudo bash $0）"
    exit 1
  fi
}

check_ubuntu_2404() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    if [[ "${ID:-}" == "ubuntu" && "${VERSION_ID:-}" == "24.04" ]]; then
      OS_OK=true
    fi
  fi
  if ! $OS_OK; then
    warn "检测到系统不是 Ubuntu 24.04（继续执行可能也能工作）。"
    read -r -p "仍要继续吗？(y/N): " cont
    if [[ "${cont,,}" != "y" ]]; then
      exit 1
    fi
  fi
}

detect_timezone() {
  if [[ -f /etc/timezone ]]; then
    TZ_VALUE=$(cat /etc/timezone || echo "Asia/Shanghai")
  else
    TZ_VALUE=$(timedatectl show -p Timezone --value 2>/dev/null || echo "Asia/Shanghai")
  fi
  # 如果检测到的是 UTC，默认设为时区
  if [[ "${TZ_VALUE}" == "UTC" ]]; then
    TZ_VALUE="Asia/Shanghai"
    log "设置时区为标准时间：${TZ_VALUE}"
  else
    log "使用时区：${TZ_VALUE}"
  fi
}

setup_ubuntu_mirrors() {
  log "配置 Ubuntu APT 源为镜像..."
  # 备份原源
  if [[ ! -f /etc/apt/sources.list.backup ]]; then
    cp /etc/apt/sources.list /etc/apt/sources.list.backup
  fi

  # 获取 Ubuntu 版本代号
  local codename
  codename=$(lsb_release -cs 2>/dev/null || echo "noble")

  cat > /etc/apt/sources.list <<EOF
# 阿里云 Ubuntu 24.04 镜像源
deb ${UBUNTU_MIRROR} ${codename} main restricted universe multiverse
deb ${UBUNTU_MIRROR} ${codename}-updates main restricted universe multiverse
deb ${UBUNTU_MIRROR} ${codename}-backports main restricted universe multiverse
deb ${UBUNTU_MIRROR} ${codename}-security main restricted universe multiverse
EOF

  log "APT 源已更新为阿里云镜像"
}

prompt_mode() {
  echo "请选择部署模式："
  echo "1) 生产（带域名 + 可选 Caddy 自动 HTTPS 反代）"
  echo "2) 本地/内网（无域名，直连 5678 端口）"
  read -r -p "输入 1 或 2 [2]: " mode
  mode="${mode:-2}"
  if [[ "$mode" == "1" ]]; then
    USE_DOMAIN=true
    read -r -p "请输入你的域名（例如 n8n.example.com）: " DOMAIN
    if [[ -z "${DOMAIN}" ]]; then
      err "域名不能为空"
      exit 1
    fi
    read -r -p "请输入用于申请证书的邮箱（Let's Encrypt 联系邮箱）: " EMAIL
    if [[ -z "${EMAIL}" ]]; then
      err "邮箱不能为空"
      exit 1
    fi
    echo "提示：请确保该域名的 A 记录已正确指向本服务器的公网 IP。"
    NEEDS_FIREWALL=true
  else
    USE_DOMAIN=false
    warn "你选择了本地/内网模式，将通过 http://<服务器IP>:5678 访问。"
    read -r -p "是否需要开启并配置 UFW 防火墙（允许 22/5678 端口）？(y/N): " ufw_ans
    if [[ "${ufw_ans,,}" == "y" ]]; then
      NEEDS_FIREWALL=true
    fi
  fi
}

prompt_database() {
  echo "请选择数据库类型："
  echo "1) PostgreSQL（推荐，生产环境）"
  echo "2) SQLite（轻量，测试/内网）"
  read -r -p "输入 1 或 2 [1]: " dbmode
  dbmode="${dbmode:-1}"
  if [[ "$dbmode" == "2" ]]; then
    USE_POSTGRES=false
  else
    USE_POSTGRES=true
  fi
}

gen_secret() {
  if ! command -v openssl >/dev/null 2>&1; then
    apt-get update -y
    apt-get install -y --no-install-recommends openssl
  fi
  ENCRYPTION_KEY=$(openssl rand -base64 32 | tr -d '\n')
  DB_PASSWORD=$(openssl rand -base64 24 | tr -d '\n')
}

install_base_deps() {
  log "安装基础依赖..."
  apt-get update -y
  apt-get install -y --no-install-recommends \
    ca-certificates curl gnupg lsb-release ufw \
    build-essential python3-minimal software-properties-common
}

install_nodejs() {
  log "安装 Node.js 20.x..."

  # 优先使用 snap 安装 Node.js（更稳定）
  if command -v snap >/dev/null 2>&1; then
    log "使用 snap 安装 Node.js 20..."
    snap install node --classic --channel=20/stable
  else
    # 备用方案：尝试 Ubuntu 官方仓库的 nodejs
    log "snap 不可用，尝试 Ubuntu 官方仓库..."
    apt-get update -y
    apt-get install -y nodejs npm
    
    # 检查版本，如果版本太低则手动下载安装
    node_version=$(node -v 2>/dev/null | sed 's/v//' | cut -d. -f1)
    if [[ "${node_version:-0}" -lt 18 ]]; then
      warn "系统 Node.js 版本过低，手动安装 Node.js 20..."
      # 手动下载并安装 Node.js 20
      cd /tmp
      wget https://npmmirror.com/mirrors/node/v20.17.0/node-v20.17.0-linux-x64.tar.xz
      tar -xf node-v20.17.0-linux-x64.tar.xz
      cp -r node-v20.17.0-linux-x64/* /usr/local/
      ln -sf /usr/local/bin/node /usr/bin/node
      ln -sf /usr/local/bin/npm /usr/bin/npm
      cd -
    fi
  fi

  # 验证安装
  node -v
  npm -v

  # 配置 npm 使用淘宝镜像
  log "配置 npm 使用淘宝镜像源..."
  npm config set registry ${NPM_REGISTRY}
  
  # 通过环境变量配置所有镜像，避免 npm v10+ 拒绝这些配置选项
  export npm_config_disturl="${NODEJS_MIRROR}"
  export NODEJS_ORG_MIRROR="${NODEJS_MIRROR}"
  export nvm_nodejs_org_mirror="${NODEJS_MIRROR}"
  export SASS_BINARY_SITE="https://npmmirror.com/mirrors/node-sass/"
  export ELECTRON_MIRROR="https://npmmirror.com/mirrors/electron/"
  export PUPPETEER_DOWNLOAD_HOST="https://npmmirror.com/mirrors"
  export CHROMEDRIVER_CDNURL="https://npmmirror.com/mirrors/chromedriver/"
  export OPERADRIVER_CDNURL="https://npmmirror.com/mirrors/operadriver/"
  export PHANTOMJS_CDNURL="https://npmmirror.com/mirrors/phantomjs/"
  export SELENIUM_CDNURL="https://npmmirror.com/mirrors/selenium/"
  export NODE_INSPECTOR_CDNURL="https://npmmirror.com/mirrors/node-inspector/"

  log "npm 镜像配置完成：$(npm config get registry)"
}

install_n8n() {
  log "通过 npm 全局安装 n8n（使用淘宝镜像）..."
  npm install -g n8n@latest
  command -v n8n >/dev/null 2>&1 || { err "未能找到 n8n 命令，请检查 npm 全局安装路径"; exit 1; }
  log "n8n 版本：$(n8n --version)"
}

create_app_user_and_dirs() {
  log "创建系统用户与目录..."
  if ! id -u "${APP_USER}" >/dev/null 2>&1; then
    adduser --system --home "${INSTALL_DIR}" --group "${APP_USER}"
  fi
  mkdir -p "${DATA_DIR}"
  chown -R "${APP_USER}:${APP_GROUP}" "${INSTALL_DIR}"
  chmod 750 "${INSTALL_DIR}"
}

install_postgres_if_needed() {
  if $USE_POSTGRES; then
    log "安装 PostgreSQL..."
    apt-get install -y postgresql
    systemctl enable --now postgresql
    # 创建数据库与用户（幂等）
    log "创建 PostgreSQL 用户和数据库（如果不存在）..."
    sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='${APP_NAME}'" | grep -q 1 || \
      sudo -u postgres psql -c "CREATE ROLE ${APP_NAME} LOGIN PASSWORD '${DB_PASSWORD}';"
    sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${APP_NAME}'" | grep -q 1 || \
      sudo -u postgres createdb -O "${APP_NAME}" "${APP_NAME}"
  fi
}

detect_ip() {
  local ip
  ip=$(hostname -I | awk '{print $1}')
  echo "${ip:-127.0.0.1}"
}

# Edit the write_env_file function around line 250
write_env_file() {
  log "生成 ${ENV_FILE} ..."
  local protocol host webhook
  if $USE_DOMAIN; then
    protocol="https"
    host="${DOMAIN}"
    webhook="https://${DOMAIN}/"
  else
    local ip
    ip=$(detect_ip)
    protocol="http"
    host="${ip}"
    webhook="http://${ip}:5678/"
  fi

  cat > "${ENV_FILE}" <<EOF
# n8n environment
NODE_ENV=production
N8N_PORT=5678
N8N_HOST=${host}
N8N_PROTOCOL=${protocol}
WEBHOOK_URL=${webhook}
N8N_ENCRYPTION_KEY=${ENCRYPTION_KEY}
GENERIC_TIMEZONE=${TZ_VALUE}
# Disable secure cookie for local development (NOT RECOMMENDED for production)
N8N_SECURE_COOKIE=false
# 如果你在反代后端需要设置 Editor Base URL，可启用以下行
# N8N_EDITOR_BASE_URL=${protocol}://${host}/

EOF

# 数据库配置
EOF

  if $USE_POSTGRES; then
    cat >> "${ENV_FILE}" <<EOF
DB_TYPE=postgresdb
DB_POSTGRESDB_HOST=127.0.0.1
DB_POSTGRESDB_PORT=5432
DB_POSTGRESDB_DATABASE=${APP_NAME}
DB_POSTGRESDB_USER=${APP_NAME}
DB_POSTGRESDB_PASSWORD=${DB_PASSWORD}
EOF
  else
    cat >> "${ENV_FILE}" <<'EOF'
DB_TYPE=sqlite
# 可选：自定义 SQLite 路径（默认 ~/.n8n/database.sqlite）
# DB_SQLITE_DATABASE=/opt/n8n/.n8n/database.sqlite
EOF
  fi

  chown "${APP_USER}:${APP_GROUP}" "${ENV_FILE}"
  chmod 640 "${ENV_FILE}"
}

write_systemd_unit() {
  log "创建 systemd 服务..."
  cat > "/etc/systemd/system/${APP_NAME}.service" <<EOF
[Unit]
Description=${APP_NAME} (native)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${APP_USER}
Group=${APP_GROUP}
EnvironmentFile=${ENV_FILE}
WorkingDirectory=${INSTALL_DIR}
ExecStart=/usr/bin/n8n
Restart=always
RestartSec=3
LimitNOFILE=16384

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable "${APP_NAME}.service"
}

install_and_config_caddy() {
  if $USE_DOMAIN; then
    log "安装并配置 Caddy（自动 HTTPS）..."
    # 如果官方源不可用，尝试从 snap 安装
    if ! apt-get install -y caddy 2>/dev/null; then
      warn "从 APT 安装 Caddy 失败，尝试使用 snap..."
      snap install caddy
      # 创建 caddy 用户和组（snap 版本可能需要）
      if ! id -u caddy >/dev/null 2>&1; then
        useradd --system --home /var/lib/caddy --shell /bin/false caddy
      fi
    fi

    mkdir -p /etc/caddy
    cat > "${CADDYFILE}" <<EOF
${DOMAIN} {
  encode gzip
  tls ${EMAIL}
  reverse_proxy 127.0.0.1:5678
}
EOF

    # 根据安装方式启动 caddy
    if command -v snap >/dev/null 2>&1 && snap list caddy >/dev/null 2>&1; then
      # snap 版本的 caddy
      systemctl enable --now snap.caddy.caddy
    else
      # APT 版本的 caddy
      systemctl enable --now caddy
      systemctl restart caddy
    fi
  fi
}

setup_firewall() {
  if $NEEDS_FIREWALL; then
    log "配置 UFW 防火墙..."
    ufw allow OpenSSH || true
    if $USE_DOMAIN; then
      ufw allow 80/tcp || true
      ufw allow 443/tcp || true
    else
      ufw allow 5678/tcp || true
    fi
    ufw --force enable
    ufw status verbose || true
  fi
}

start_services() {
  log "启动 n8n 服务..."
  systemctl start "${APP_NAME}.service"
  sleep 2
  systemctl --no-pager status "${APP_NAME}.service" || true
}

post_checks() {
  echo
  log "验证信息："
  if $USE_DOMAIN; then
    echo "访问地址：https://${DOMAIN}"
    echo "证书申请可能需要等待 DNS 生效，稍后可执行：curl -I https://${DOMAIN}"
  else
    local ip
    ip=$(detect_ip)
    echo "访问地址："
    echo "  - http://${ip}:5678"
  fi

  echo
  log "重要路径与命令："
  echo "1) n8n 数据目录：${DATA_DIR}"
  echo "2) 环境变量文件：${ENV_FILE}"
  echo "3) systemd 服务：${APP_NAME}.service"
  echo "   - 启动：systemctl start ${APP_NAME}"
  echo "   - 停止：systemctl stop ${APP_NAME}"
  echo "   - 查看日志：journalctl -u ${APP_NAME} -f"
  echo "4) 升级 n8n 到最新："
  echo "   - npm i -g n8n@latest && systemctl restart ${APP_NAME}"
  echo "5) npm 镜像源：$(npm config get registry)"
  if $USE_POSTGRES; then
    echo "6) PostgreSQL 数据库：数据库名/用户：${APP_NAME}，密码保存在 ${ENV_FILE}"
  else
    echo "6) SQLite 模式：数据库默认在 ${DATA_DIR}/database.sqlite（如未改）"
  fi
  echo
  log "所有镜像源均已配置完成"
}

main() {
  require_root
  check_ubuntu_2404
  detect_timezone
  setup_ubuntu_mirrors
  prompt_mode
  prompt_database
  gen_secret
  install_base_deps
  install_nodejs
  install_n8n
  create_app_user_and_dirs
  install_postgres_if_needed
  write_env_file
  write_systemd_unit
  install_and_config_caddy
  setup_firewall
  start_services
  post_checks
  log "部署完成！✌️"
}

main "$@"

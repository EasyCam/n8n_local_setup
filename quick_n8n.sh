#!/bin/bash
set -e

echo "快速安装n8n（不使用systemd）"

# 安装Node.js和npm（如果没有）
if ! command -v node &> /dev/null; then
    echo "安装Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash -
    sudo apt install -y nodejs
fi

# 配置npm使用淘宝镜像
echo "配置npm镜像..."
npm config set registry https://registry.npmmirror.com

# 安装n8n
echo "安装n8n..."
npm install -g n8n

# 配置防火墙
echo "开放5678端口..."
sudo ufw allow 5678/tcp
sudo ufw --force enable

# 设置环境变量并启动
echo "启动n8n..."
export N8N_HOST=0.0.0.0
export N8N_PORT=5678
export N8N_SECURE_COOKIE=false
export N8N_PROTOCOL=http
export GENERIC_TIMEZONE=Asia/Shanghai

echo "=================================="
echo "n8n 正在启动..."
echo "访问地址："
hostname -I | tr ' ' '\n' | grep -v '^127\.' | while read ip; do
    echo "  http://$ip:5678"
done
echo "按 Ctrl+C 停止服务"
echo "=================================="

# 直接运行n8n
n8n start
EOF
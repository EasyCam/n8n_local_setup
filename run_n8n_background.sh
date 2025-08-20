#!/bin/bash

# 设置环境变量
export N8N_HOST=0.0.0.0
export N8N_PORT=5678
export N8N_SECURE_COOKIE=false
export N8N_PROTOCOL=http
export GENERIC_TIMEZONE=Asia/Shanghai

# 后台运行
nohup n8n start > n8n.log 2>&1 &
echo "n8n已在后台启动，PID: $!"
echo "日志文件: n8n.log"
echo "停止命令: kill $!"

# 显示访问地址
echo "访问地址："
hostname -I | tr ' ' '\n' | grep -v '^127\.' | while read ip; do
    echo "  http://$ip:5678"
done
EOF
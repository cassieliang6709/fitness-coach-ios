#!/bin/bash
# Vance backend 部署脚本（在 ECS 上执行）
# 用法：cd /opt/vance && ./deploy.sh

set -e

VANCE_DIR="/opt/vance"
ENV_FILE="/opt/prod-config/vance/.env"

echo "==> 1. 拉最新代码"
cd "$VANCE_DIR"
git pull origin main

echo "==> 2. 检查 .env"
if [ ! -f "$ENV_FILE" ]; then
  echo "❌ 缺少 $ENV_FILE"
  echo "   参考 backend/.env.example 创建"
  exit 1
fi

# 链接 .env 到 backend 目录（docker-compose 读取）
ln -sf "$ENV_FILE" "$VANCE_DIR/backend/.env"

echo "==> 3. Build + 启动容器"
cd "$VANCE_DIR/backend"
docker compose build
docker compose up -d

echo "==> 4. 健康检查"
sleep 3
docker compose ps
echo ""
echo "Worker: $(docker inspect vance-worker --format '{{.State.Health.Status}}' 2>/dev/null || echo 'unknown')"
echo "Gateway: $(docker inspect vance-gateway --format '{{.State.Health.Status}}' 2>/dev/null || echo 'unknown')"

echo ""
echo "==> 5. 测试 nginx 反代（需要先在 sourcerlinda nginx 加 server 块）"
curl -s -o /dev/null -w "https://realtime.magicandgrind.com/health → %{http_code}\n" \
  https://realtime.magicandgrind.com/health || echo "nginx 还没配置"

echo ""
echo "✅ 部署完成"
echo ""
echo "查看日志："
echo "  docker logs vance-worker"
echo "  docker logs vance-gateway"

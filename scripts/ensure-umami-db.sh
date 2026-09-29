#!/usr/bin/env bash
# 在服务器上跑：保证 .env 里有 UMAMI_APP_SECRET，且 halodb 里有 umami 库。
# 幂等，重复执行无副作用。部署 workflow 会自动调用；手动部署时自己跑一下。
set -euo pipefail
cd "$(dirname "$0")/.."

if ! grep -q '^UMAMI_APP_SECRET=' .env 2>/dev/null; then
  echo "UMAMI_APP_SECRET=$(openssl rand -hex 32)" >> .env
  echo "已生成 UMAMI_APP_SECRET 写入 .env"
fi

# 等数据库就绪（首次部署时 halodb 可能还在启动）
for _ in $(seq 1 30); do
  docker compose exec -T halodb pg_isready -U halo >/dev/null 2>&1 && break
  sleep 2
done

if ! docker compose exec -T halodb psql -U halo -d postgres -tAc \
     "SELECT 1 FROM pg_database WHERE datname='umami'" | grep -q 1; then
  docker compose exec -T halodb psql -U halo -d postgres -c "CREATE DATABASE umami"
  echo "已创建数据库 umami"
fi

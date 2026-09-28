#!/usr/bin/env bash
# 把本地的配置文件同步到服务器并让改动生效。
# 只同步配置（Caddyfile / docker-compose.yml / setup.sh / static/），
# 不碰服务器上的 .env 和 data/（运行数据）。
#
# 用法：scripts/deploy.sh root@47.107.190.39
set -euo pipefail
TARGET="${1:?用法: scripts/deploy.sh user@host}"
REMOTE_DIR="/opt/kb-deploy"
cd "$(dirname "$0")/.."

rsync -avz --delete \
  --exclude '.env' --exclude 'data/' --exclude '.git/' --exclude '.DS_Store' \
  ./ "${TARGET}:${REMOTE_DIR}/"

ssh "${TARGET}" "cd ${REMOTE_DIR} && docker compose up -d && docker compose restart caddy && docker compose ps"

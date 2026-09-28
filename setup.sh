#!/usr/bin/env bash
# 在全新的 Ubuntu 24.04 服务器上以 root 执行：
#   bash setup.sh cqian.top [公网IP]   （传主域名；IP 不传则自动检测）
# 做的事：加 swap、装 Docker（阿里云镜像源）、生成 .env、启动 Halo + PostgreSQL + Caddy(自动 HTTPS)
set -euo pipefail

SITE_DOMAIN="${1:-}"
if [[ -z "$SITE_DOMAIN" ]]; then
  echo "用法: bash setup.sh <主域名，如 cqian.top>"; exit 1
fi
cd "$(dirname "$0")"

echo "==> [1/5] 2G 内存机器加 2G swap，防止 Halo 启动时 OOM"
if ! swapon --show | grep -q swapfile; then
  fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

echo "==> [2/5] 安装 Docker（阿里云源）"
if ! command -v docker >/dev/null 2>&1; then
  apt-get update -y
  apt-get install -y ca-certificates curl gnupg
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://mirrors.aliyun.com/docker-ce/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
fi

echo "==> [3/5] 配置 Docker Hub 国内镜像加速（拉 postgres / caddy 用）"
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<'EOF'
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://docker.1ms.run",
    "https://dockerproxy.net"
  ],
  "log-driver": "json-file",
  "log-opts": { "max-size": "20m", "max-file": "3" }
}
EOF
systemctl restart docker
systemctl enable docker >/dev/null

echo "==> [4/5] 生成 .env（数据库密码随机生成，保存在 .env 里，别删）"
SERVER_IP="${2:-$(curl -s --max-time 5 https://ipinfo.io/ip || curl -s --max-time 5 http://100.100.100.200/latest/meta-data/eipv4 || true)}"
if [[ ! -f .env ]]; then
  DB_PASSWORD="$(openssl rand -hex 16)"
  cat > .env <<EOF
SITE_DOMAIN=${SITE_DOMAIN}
SERVER_IP=${SERVER_IP}
DB_PASSWORD=${DB_PASSWORD}
EOF
  chmod 600 .env
elif ! grep -q '^SERVER_IP=' .env; then
  echo "SERVER_IP=${SERVER_IP}" >> .env
fi
echo "    公网 IP: ${SERVER_IP:-未检测到，请手动写入 .env 的 SERVER_IP}"
mkdir -p data/halo2 data/db data/caddy static

echo "==> [5/5] 启动服务"
docker compose pull
docker compose up -d

echo
echo "完成。等 1–2 分钟 Halo 初始化后："
echo "  站点首页:   https://kb.${SITE_DOMAIN}/   （cqian.top / www 会自动跳转过来）"
echo "  后台初始化: https://kb.${SITE_DOMAIN}/console   （第一次打开会让你创建管理员账号）"
echo "  这篇资料:   https://kb.${SITE_DOMAIN}/life/how-to-live-better/"
echo "  IP 直连:    http://${SERVER_IP}/   （备案期间临时用）"
echo
echo "查看日志: docker compose logs -f halo"

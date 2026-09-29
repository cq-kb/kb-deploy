# PLATFORM.md — 服务器总地图

一台阿里云服务器上跑的**所有**东西都在这里登记。接手的人/AI 先看这张图，再进对应仓库看细节。
新增或下线任何服务、域名、端口、定时任务，**必须**更新本文件。

最后更新：2026-09-29（加 Umami）

## 服务器

| 项 | 值 |
|---|---|
| 云厂商 / 地域 | 阿里云 ECS（轻量应用服务器），深圳 |
| 规格 | 2 vCPU / 2 GiB + 2 GiB swap / 40 GiB 系统盘 / 固定带宽 |
| 系统 | Ubuntu 24.04，Docker + Docker Compose |
| 登录 | `ssh root@<公网IP>`（IP 在本机 `.env` 的 `SERVER_IP`，也在 GitHub 组织 Secret `DEPLOY_HOST`） |
| 安全组放行 | TCP 22 / 80 / 443（8091 仅在需要 IP 直连考试日历时临时放行） |
| 域名 | `cqian.top`（阿里云注册，ICP 备案已通过：鄂ICP备2026055268号-1） |

## 服务清单

所有服务由 **同一个** `docker compose`（`/opt/kb-deploy/docker-compose.yml`）管理，**同一个** Caddy 做入口。

| 服务 | 容器 | 对外地址 | 内部端口 | 代码 / 配置来源 | 数据目录（服务器） | 部署方式 |
|---|---|---|---|---|---|---|
| 反向代理 + HTTPS | `caddy` | 80 / 443 | — | `kb-deploy/Caddyfile` | `/opt/kb-deploy/data/caddy`（证书） | kb-deploy push → Actions |
| 知识库（Halo CMS） | `halo` | `https://kb.cqian.top` | 8090 | 镜像 `registry.fit2cloud.com/halo/halo:2`；主题来自 `kb-theme` | `/opt/kb-deploy/data/halo2`（附件、主题、插件） | 镜像升级：kb-deploy；主题：kb-theme push → Actions |
| 知识库数据库 | `halodb` | 无 | 5432 | 镜像 `postgres:16-alpine` | `/opt/kb-deploy/data/db` | 随 kb-deploy |
| 访问统计（Umami 3） | `umami` | `https://stats.cqian.top` | 3000 | 镜像 `umamisoftware/umami:3.4.0` | 数据在 `halodb` 的 `umami` 库（`scripts/ensure-umami-db.sh` 自动建） | 随 kb-deploy；`APP_SECRET` 在 `.env` 的 `UMAMI_APP_SECRET` |
| 考试日历（FastAPI + 静态站） | `exam-calendar` | `https://kao.cqian.top`；兜底 `http://<IP>:8091` | 8000 | `~/Personal/exam-calendar`（**尚未入 Git**） | `/opt/exam-calendar/{public,state,data,.env}` | `bash exam-calendar/deploy/deploy.sh root@<IP>`（Mac 直推） |

### 域名 → 服务（Caddyfile）

| 域名 | 去向 |
|---|---|
| `kb.cqian.top` | Halo（`/life/how-to-live-better/*`、`/files/*` 为 Caddy 直出的静态目录 `/opt/kb-deploy/static`） |
| `stats.cqian.top` | Umami（统计后台；站点上引用的脚本是 `https://stats.cqian.top/kb.js`，上报到 `/api/kb`） |
| `kao.cqian.top` | 静态站 `/opt/exam-calendar/public`；`/api/*` → exam-calendar:8000 |
| `cqian.top`、`www.cqian.top` | 301 → `kb.cqian.top`（主域名预留给未来业务） |
| `*.cqian.top`（HTTP） | 301 → `kb.cqian.top` |

### 定时 / 后台任务

| 任务 | 在哪跑 | 频率 | 说明 |
|---|---|---|---|
| 考试官网监控 | `exam-calendar` 容器内调度线程 | 每 6 小时 | 抓官方页比对指纹，变化则标「核对中」并通知 |
| 静态站 / 海报重建 | 同上 | 每天 | 重新生成 `public/` |
| 报名提醒邮件 | 同上 | 每天 `REMIND_HOUR` | 未配 SMTP 时只记日志（当前未配） |
| Halo 备份 | **无** | — | 待补：至少每周 `tar` `/opt/kb-deploy/data` 到 OSS |
| 证书续期 | Caddy 自动 | — | 无需干预 |

## 代码仓库

GitHub 组织 `cq-kb`（免费版：组织级 Secrets 只对公开仓库生效）。本机统一放 `~/Personal/`。

| 仓库 | 可见性 | 用途 | CI/CD |
|---|---|---|---|
| `cq-kb/kb-deploy` | 公开 | **本仓库**：服务器配置总入口（compose、Caddyfile、setup.sh）、本总地图 | push main → rsync 到 `/opt/kb-deploy` + 重启 caddy |
| `cq-kb/kb-theme` | 公开 | Halo 主题（fork theme-earth） | push main → 测试、构建、rsync 到主题目录 + 重启 halo |
| `cq-kb/kb-content` | 私有 | 知识库内容源（Markdown，含 how-to-live-better 39 篇） | 无；用 Halo「站点迁移」插件手动导入 |
| （待建）`exam-calendar` | — | 考试日历 | 目前 Mac 直推，建议入 Git + 接 Actions |

## 密钥与配置在哪

| 东西 | 位置 | 备注 |
|---|---|---|
| 服务器 root 密码 | 密码管理器 | 阿里云控制台可重置 |
| GitHub Actions 部署私钥 | 服务器 `/root/.ssh/github_deploy`；GitHub 组织 Secret `DEPLOY_KEY` | 公钥在 `/root/.ssh/authorized_keys` |
| `SITE_DOMAIN` / `SERVER_IP` / `DB_PASSWORD` / `UMAMI_APP_SECRET` | 服务器 `/opt/kb-deploy/.env` | setup.sh / ensure-umami-db.sh 生成，不进仓库 |
| Umami 管理员 | 首次登录 `admin` / `umami`，**必须立即改密码**，新密码放密码管理器 | 忘记：进 `halodb` 的 `umami` 库改 `user` 表 |
| 考试日历 `ADMIN_TOKEN` / SMTP | 服务器 `/opt/exam-calendar/.env` | deploy.sh 首次生成 |
| Halo 管理员 | 用户名 `chengqian`，密码在密码管理器 | 忘记：改库重置，见 CLAUDE.md |

## 资源占用（2G 内存的分配）

Halo（JVM，限 768m）≈ 800m · PostgreSQL ≈ 100m · Caddy ≈ 30m · Umami（限 350m）≈ 200m · exam-calendar（限 300m）≈ 150m · 系统 ≈ 300m。
已接近 2G 上限，靠 swap 兜底；**下一个服务上来之前先升配到 4G**。
**再加服务前先看 `free -m`**，超了就该升配或把考试日历挪去 Serverless。

## 新增一个服务的标准动作

1. 代码入 `cq-kb/<name>` 仓库，带 Dockerfile
2. `kb-deploy/docker-compose.yml` 加 service（`mem_limit` 必填，不暴露宿主端口除非必要）；镜像用 Docker Hub 或国内源均可，部署时 Actions 会把服务器缺的镜像打包送过去
3. `Caddyfile` 加子域名段，阿里云 DNS 加 A 记录
4. 给该仓库加 Actions（复制 kb-theme 的 workflow 改路径），或先用 Mac 直推
5. **更新本文件**的服务清单、域名表、定时任务表

## 已知待办（平台级）

- [x] 备案通过，Caddyfile 的 IP 直连段已删
- [ ] 删 `static/` 里的 how-to-live-better（内容已是 Halo 文章）
- [ ] 补 Halo 数据备份（cron + OSS）
- [ ] exam-calendar 入 Git，接 Actions，去掉对 Mac 的依赖
- [ ] 8091 端口若已放行，确认不再需要后关掉
- [x] 访问统计（Umami，`stats.cqian.top`）

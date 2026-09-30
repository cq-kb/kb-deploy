# CLAUDE.md — kb-deploy 交接说明

给接手这个项目的人或 AI 会话看的。三份文档分工：
- **PLATFORM.md** — 服务器总地图：这台机器上跑着哪些服务、域名、端口、仓库、密钥在哪。**先看它。**
- README.md — 本仓库怎么部署、怎么改配置
- 本文件 — 当前状态、踩过的坑、约定
状态会变，改完请更新本文件底部的「当前状态」和 PLATFORM.md。

## 一句话

`kb.cqian.top` 是 cheng.qian 的个人知识库（Halo CMS），本仓库是它的服务器配置；主题在 `cq-kb/kb-theme`；
内容（Markdown 源）在 `cq-kb/kb-content`（私有）↔ `~/Personal/kb-content`。

## 一台服务器、多个业务

这台服务器不只跑知识库：`docker-compose.yml` 里还有 **exam-calendar**（考试日历，`kao.cqian.top`，代码在 `~/Personal/exam-calendar`，
用它自己的 `deploy/deploy.sh` 从 Mac 直推）。改 compose / Caddyfile 时别动别人的段落；全貌见 PLATFORM.md。

## 知识库相关的仓库

| 东西 | 位置 | 说明 |
|---|---|---|
| 服务器 | 阿里云 ECS，公网 IP 见 `.env`（服务器上 `/opt/kb-deploy/.env`） | Ubuntu 24.04，2C2G + 2G swap，root 登录 |
| 本仓库 | `github.com/cq-kb/kb-deploy` ↔ `~/Personal/kb-deploy` ↔ 服务器 `/opt/kb-deploy` | Caddy + Halo + PostgreSQL 的 compose 配置 |
| 主题 | `github.com/cq-kb/kb-theme` ↔ `~/Personal/kb-theme` ↔ 服务器 `/opt/kb-deploy/data/halo2/themes/kb-theme` | fork 自 halo-dev/theme-earth |
| 内容 | `github.com/cq-kb/kb-content`（私有）↔ `~/Personal/kb-content/how-to-live-better/`（39 篇 md，带 frontmatter） | 用 Halo「站点迁移」插件导入 |

GitHub 组织 `cq-kb`（免费版）：两个仓库都是 **公开** 的，因为免费版组织级 Secrets 只对公开仓库生效。
组织级 Secrets：`DEPLOY_HOST` / `DEPLOY_USER`(root) / `DEPLOY_KEY`(服务器 `/root/.ssh/github_deploy` 的私钥，完整含 BEGIN/END 行)。

## 部署方式（push 即上线）

- 本仓库 push main → Actions rsync 配置到 `/opt/kb-deploy`（排除 `.env`、`data/`）→ `docker compose up -d` + 重启 caddy
- kb-theme push main → Actions 跑测试、`pnpm build-only`、rsync `theme.yaml/settings.yaml/templates/i18n` 到主题目录 → 重启 halo 容器
- 手动兜底：`scripts/deploy.sh root@<IP>`
- 服务器**不需要**也**不应该**去访问 GitHub（国内到 GitHub 不稳定），一切由 Actions 推过来

## 域名与路由（Caddyfile）

- 正式地址只有 `kb.cqian.top`；`cqian.top`、`www`、`*.cqian.top` 都 301 到它。以后主域名上新业务只改 Caddyfile 的「主域名 / www」段
- 备案已通过（鄂ICP备2026055268号-1，2026-09），Caddyfile 里的 IP 直连段已删；纯 IP 访问现在不通是正常的
- `/life/how-to-live-better/` 和 `/files/*` 是 Caddy 直出的静态目录（`static/`），不经过 Halo，**会员插件管不到**，所以要控制访问的内容必须是 Halo 文章

## Halo

- 版本：`registry.fit2cloud.com/halo/halo:2`，数据在 `data/halo2`（附件、主题、插件）+ `data/db`（PostgreSQL 16）
- 管理员用户名 `chengqian`；密码只有哈希，忘了按 https://www.halo.run/archives/forgot-admin-password 改数据库重置
- 后台 `/console`。已装/待装插件：站点迁移（Markdown 导入）、会员插件（付费，游客/VIP 分级）、文章加密
- 证书由 Caddy 自动管理，存放在 `data/caddy/caddy/certificates/`（注意多一层 caddy）

## 已知的坑（踩过的）

- `setup.sh` 早期版本里 `tr | head` 配合 `pipefail` 会静默退出，已改用 `openssl rand`
- 备案：未通过时阿里云会拦截域名访问，表现为 HTTPS 握手错误、HTTP 出现阿里云提示页（2026-09 已通过：鄂ICP备2026055268号-1）
- 手机/电脑访问结果不一致时先排查 DNS 缓存和代理，再怀疑服务器
- Halo 附件的 URL 在上传时就固定了，改「附件名称」不改 URL；附件是公开直链
- Git 在 Cowork 的隔离环境里推不了 GitHub（无凭据），推送要在 Mac 自己的终端做
- GitHub Actions 的 `DEPLOY_KEY` 必须是私钥**全文**，漏掉 BEGIN/END 行会报 `error in libcrypto`
- Cowork 写不了 `.github/workflows/` 下的文件（受保护路径），要先写到别处再 `mv`
- 服务器直接拉 Docker Hub 镜像会卡死（加速器没缓存的层一直 Downloading）：新镜像由 kb-deploy 的 Actions 在 runner 上拉好、推到阿里云 ACR（深圳个人版，命名空间 cq-kb），服务器走内网从 ACR 拉回并 `docker tag` 成 compose 里的原名；不要在服务器上手动 `docker pull` 国外镜像。曾试过 `docker save | ssh docker load`，受服务器几 Mbps 入网带宽限制 20 分钟都传不完

## 约定

- 密钥、密码、IP 只放 `.env`（服务器）和 GitHub Secrets，永远不进仓库
- 内容以 Halo 文章为主；静态 HTML 只在"别人做好的整站"这种例外场景用
- 个人 Git 身份：`Cq-study` / `Cq-study@users.noreply.github.com`（可换成真实个人邮箱），不要用公司邮箱
- 开发路线：Halo 做底座，只开发差异部分（主题 → 结构化条目插件 → 配套服务），不从零造 CMS
- **当前阶段（2026-09 定）：先做流量，不做会员/付费。** 会员插件、支付都往后放；所有内容对游客开放，优先做内容量、SEO、分享体验和访问统计

## 当前状态（2026-09-29）

- [x] 服务器、Halo、Caddy、HTTPS 全部就绪，域名可访问，备案通过（鄂ICP备2026055268号-1）
- [x] 两个仓库迁入 `cq-kb`，Actions 部署链路跑通
- [x] kb-theme v0.1：条目卡片 / 成本徽章 / 证据等级 / 筛选栏，已部署到服务器
- [ ] 在 Halo 后台启用「KB（知识库）」主题
- [x] 导入 `kb-content/how-to-live-better/` 39 篇文章（站点迁移插件 → Markdown）
- [ ] ~~装会员插件，建 VIP 等级~~ 暂缓（先做流量）
- [x] Umami 已进 compose（`stats.cqian.top`）。**待人工**：首次登录改密码 → 添加网站 kb.cqian.top → 把跟踪脚本贴到 Halo 后台「设置 → 代码注入 → 头部」
- [ ] 站点地图插件（应用市场搜「站点地图」，免费）→ 提交到百度站长 / Bing / Google
- [x] 备案通过，Caddyfile 的 IP 段已删
- [ ] 后台 → 主题 → KB 设置 → 备案，填 ICP 号 `鄂ICP备2026055268号-1`（主题页脚会显示并链到 beian.miit.gov.cn）
- [ ] 删 `static/` 的 how-to-live-better（内容已是文章，确认无外链依赖后删）
- [ ] 主题下一步：首页改分类导航、分类页统计条、VIP 锁标识、页脚备案号

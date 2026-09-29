# kb-deploy — 个人知识库部署配置

`kb.cqian.top` 的服务器端配置：Halo（内容 / 用户 / 会员）+ PostgreSQL + Caddy（自动 HTTPS、域名分流）。
这个仓库只放**配置**，不放内容和运行数据；内容在 Halo 后台管理，数据在服务器的 `data/` 目录。

## 架构

```
浏览器 ──HTTPS──> Caddy
                   ├── kb.cqian.top            -> 知识库（正式地址，canonical）
                   │     ├── /life/how-to-live-better/   静态 HTML 资料
                   │     ├── /files/*                    static/ 下任意目录
                   │     └── 其他                        -> Halo :8090
                   ├── stats.cqian.top          -> Umami 访问统计
                   ├── cqian.top / www          -> 301 跳转到 kb（以后可换成新业务）
                   └── *.cqian.top（HTTP）       -> 301 跳转到 kb
Halo ──> PostgreSQL
```

服务器上的目录结构：

```
/opt/kb-deploy/
├── Caddyfile            路由与域名规划（本仓库）
├── docker-compose.yml   三个容器的定义（本仓库）
├── setup.sh             裸机初始化脚本（本仓库）
├── scripts/deploy.sh    本地 -> 服务器 同步配置（本仓库）
├── static/              静态资料（本仓库）
├── .env                 域名 / IP / 数据库密码（setup.sh 生成，不进仓库）
└── data/                Halo 附件、数据库、证书（运行数据，不进仓库）
```

备份 = 打包服务器上整个 `/opt/kb-deploy`；迁移 = 拷到新机器后 `docker compose up -d`。

## 首次部署

1. 服务器：Ubuntu 24.04，安全组放行 TCP 22 / 80 / 443。
2. 域名解析，四条 A 记录指向服务器公网 IP：`kb`、`@`、`www`、`*`。
3. 上传并执行：

```bash
scp -r kb-deploy root@<服务器IP>:/opt/
ssh root@<服务器IP>
cd /opt/kb-deploy && bash setup.sh cqian.top     # 第二个参数可显式传公网 IP
```

脚本做的事：加 2G swap → 装 Docker（阿里云源 + 镜像加速）→ 生成 `.env` → `docker compose up -d`。
之后打开 `https://kb.cqian.top/console` 创建管理员。

## 自动部署（push 即上线）

两个仓库都配了 GitHub Actions（`.github/workflows/deploy.yml`）：推送到 `main` 后，Actions 通过 SSH
把文件 rsync 到服务器并让改动生效。服务器不需要能访问 GitHub，构建也在 Actions 上完成。

一次性准备（在服务器上生成一对专用密钥）：

```bash
ssh root@<服务器IP>
ssh-keygen -t ed25519 -N "" -C "github-actions-deploy" -f /root/.ssh/github_deploy
cat /root/.ssh/github_deploy.pub >> /root/.ssh/authorized_keys
cat /root/.ssh/github_deploy          # 私钥，整段复制
```

然后在 GitHub 上 **kb-deploy 和 kb-theme 两个仓库**各自的 Settings → Secrets and variables → Actions 里添加：

| Secret | 值 |
|---|---|
| `DEPLOY_HOST` | 服务器公网 IP |
| `DEPLOY_USER` | `root` |
| `DEPLOY_KEY`  | 上面 `cat` 出来的私钥全文（含 BEGIN/END 行） |

之后：改 `kb-deploy` 推送 → 配置同步 + Caddy 重启；改 `kb-theme` 推送 → 测试、构建、主题同步、Halo 重启。
在仓库的 Actions 页面能看到每次部署的日志。手动触发用 Actions 页面的 "Run workflow"。

## 日常改配置（手动方式，备用）

本地改完 `Caddyfile` / `docker-compose.yml` / `static/`，一条命令同步并生效：

```bash
scripts/deploy.sh root@<服务器IP>
```

（rsync 配置到 `/opt/kb-deploy`，排除 `.env` 和 `data/`，然后重启 Caddy。）

## 内容怎么管

- **文章、图片、PDF**：全部在 Halo 后台操作，不碰服务器。需要访问控制（游客 / VIP）的内容必须是 Halo 文章，附件和静态文件是公开直链，会员插件管不到。
- **整本书 / 结构化资料**：转成带 frontmatter 的 Markdown，用 Halo 应用市场的「站点迁移」插件（来源选 Markdown）批量导入，每章一篇文章。
- **别人做好的整站 HTML**（少数例外）：放到 `static/<分类>/<名字>/`，通过 `/files/<分类>/<名字>/` 访问，无需改配置。

## 备案

国内服务器绑定域名需要 ICP 备案，`cqian.top` 已备案（鄂ICP备2026055268号-1）。审核期间若需要 IP 直连，
在 `Caddyfile` 末尾临时加一段 `http://{$SERVER_IP} { import kb_routes }` 即可，通过后删掉。

## 访问统计（Umami）

`stats.<域名>` 是自托管的 Umami，数据存在 halodb 的 `umami` 库里，部署时 `scripts/ensure-umami-db.sh` 会自动建库并生成 `UMAMI_APP_SECRET`。
首次使用：登录 `admin` / `umami` → 立即改密码 → 「网站」添加 `kb.<域名>` → 复制跟踪代码，贴到 Halo 后台「设置 → 代码注入 → 头部」。
脚本地址是 `/kb.js`、上报接口 `/api/kb`（改过名，减少被广告拦截）。

## 以后主域名要上新业务

只改 `Caddyfile` 里「主域名 / www」那一段：把 `redir` 换成新业务的 `reverse_proxy`，`scripts/deploy.sh` 同步即可。
知识库的配置、数据、用户手里的 `kb.` 链接全部不受影响。

## 开发路线（Halo 做底座，只开发差异部分）

1. **主题** `kb-theme`：分类树侧栏、条目折叠、成本标签 / 证据等级色块、VIP 内容锁标识。Fork 现有主题改起。
2. **结构化条目插件** `kb-plugin-*`：把「建议条目」做成自定义模型（成本 / 收益 / 证据等级 / 标签），可筛选、可收藏。
3. **配套服务**：微信登录、知识星球打通、周报推送等，独立容器挂在 Caddy 后面。

主题和插件各自独立仓库，构建产物通过 `scripts/deploy.sh` 或 Actions 推到服务器。

## 本地开发环境（主题 / 插件调试）

```bash
git clone https://github.com/Cq-study/kb-theme.git ~/Personal/kb-theme   # 主题仓库，与本仓库平级
cd ~/Personal/kb-deploy/dev && docker compose up -d                      # 本地 Halo，http://localhost:8090
cd ~/Personal/kb-theme && pnpm install && pnpm dev                       # 监听构建主题
```

本地 Halo 用内置 H2 数据库，数据在 `dev/data/`（已 gitignore），与线上完全隔离。
后台 → 主题 → 启用「KB（知识库）」，改 `kb-theme/src` 后刷新即可看到效果。

## 常用命令（服务器上）

```bash
cd /opt/kb-deploy
docker compose ps                              # 状态
docker compose logs -f halo                    # Halo 日志
docker compose logs --since 10m caddy          # Caddy 日志
docker compose pull && docker compose up -d    # 升级
ls data/caddy/caddy/certificates/*/            # 已签发的证书
tar czf ~/kb-backup-$(date +%F).tgz -C /opt kb-deploy   # 备份
```

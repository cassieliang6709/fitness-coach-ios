# Vance Backend

FitnessCoach iOS App 的后端服务，包含文字对话/计划生成 Worker 和 MiniMax Realtime 语音 Gateway。

## 架构

```
iPhone App
    ↓ HTTPS / WSS
realtime.magicandgrind.com (nginx)
    ├─ /*         → vance-worker:8788  (DeepSeek 文字+计划)
    ├─ /realtime  → vance-gateway:8787 (MiniMax Realtime WS)
    └─ /gateway/* → vance-gateway:8787 (GymVision 等)
```

**部署位置**：阿里云 ECS `47.120.13.248`。Vance 有独立代码、Compose、密钥和
Docker 网络，但目前与 SourcerLinda 共用一个入口 Nginx；这不是对抗已入侵容器的
硬安全边界。完整的生产交接、当前限制与隔离升级路径见
[`docs/VANCE_PRODUCTION_BACKEND_HANDOFF_20260805.md`](../docs/VANCE_PRODUCTION_BACKEND_HANDOFF_20260805.md)。

**隔离原则**：
- 独立 Docker 网络 `vance`
- 独立密钥 `VANCE_*_SECRET`（不复用 sourcerlinda 的 `APP_SHARED_SECRET`）
- 独立目录 `/opt/vance/`（不在 `/opt/sourcerlinda-releases/`）
- 独立 compose 项目 `vance`
- Worker 的本地 D1 状态保存在 Docker named volume `vance_worker_state`，部署时不得用无状态临时目录替代。

## 目录结构

```
backend/
├── worker/           # Cloudflare Worker（Wrangler 本地运行时 + D1）
│   ├── src/          # TypeScript 源码
│   ├── Dockerfile
│   └── wrangler.jsonc
├── gateway/          # MiniMax Realtime Gateway（node:22 容器）
│   ├── server.mjs
│   ├── Dockerfile
│   └── package.json
├── nginx/
│   └── realtime.magicandgrind.com.conf  # nginx server 块（要加到 sourcerlinda nginx）
├── docker-compose.yaml
├── deploy.sh         # ECS 部署脚本
└── .env.example      # 密钥模板
```

## 本地开发

### 前置依赖
- Docker Desktop（或 colima）
- Node 22+（如果只跑单个服务）

### 启动
```bash
cd backend

# 复制密钥模板（找 @cassieliang6709 要 API keys）
cp .env.example .env
# 编辑 .env 填入真实 key

# 起服务
docker compose up

# 或单独起 worker
cd worker && npx wrangler dev

# 或单独起 gateway
cd gateway && node server.mjs
```

Worker 会监听 `127.0.0.1:8788`，Gateway 监听 `127.0.0.1:8787`。

### iOS App 连接
编辑 `Secrets.xcconfig`（不要提交到 Git）：
```
# 模拟器
COACH_API_HOST = 127.0.0.1:8788
REALTIME_GATEWAY_HOST = 127.0.0.1:8787

# 真机（Mac 和 iPhone 同一 WiFi）
COACH_API_HOST = 192.168.1.x:8788
REALTIME_GATEWAY_HOST = 192.168.1.x:8787

# 生产
COACH_API_HOST = realtime.magicandgrind.com
REALTIME_GATEWAY_HOST = realtime.magicandgrind.com

# 密钥从 backend/.env 复制（不要提交 Secrets.xcconfig）
COACH_SHARED_SECRET = <VANCE_WORKER_SECRET>
REALTIME_GATEWAY_SECRET = <VANCE_GATEWAY_SECRET>
```

## 部署到生产

### 已完成的生产入口
- [x] DNS: `realtime.magicandgrind.com` → `47.120.13.248`
- [x] HTTPS 证书
- [x] Nginx Vance virtual host 已合入 SourcerLinda
- [x] Worker 与 Gateway 已作为独立 Compose 服务运行

### 日常部署
```bash
# 仅限已获授权的 Vance 生产操作员。
# 从已验证的 FitnessCoach main SHA / 已验证 bundle 准备干净源码后：
cd /opt/vance/backend
docker compose build worker gateway
docker compose up -d --no-deps --force-recreate worker gateway
```

不要用 `git reset --hard` 覆盖一个不明状态的生产工作树，也不要把 Vance 部署变成
SourcerLinda 整栈重启。若 container recreate 改变了 upstream IP，按
[`docs/VANCE_PRODUCTION_BACKEND_HANDOFF_20260805.md`](../docs/VANCE_PRODUCTION_BACKEND_HANDOFF_20260805.md)
的候选配置校验流程确认后，才 reload 共享 Nginx。

### 查看日志
```bash
docker logs vance-worker -f
docker logs vance-gateway -f
```

### 回滚

使用已记录的上一版 Vance image / 已验证的 release source 重新创建**仅 Vance**的
`worker` 和 `gateway`。保留 `/data` Docker volume、外部生产配置和当前运行镜像；
不要删除 volume、不要覆盖主站 release，也不要把主站 Nginx 当成 Vance 的回滚单位。

## 密钥管理

**生产密钥**在 ECS 的 `/opt/prod-config/vance/.env`，**不在 Git 里**。

修改密钥后必须 force-recreate 受影响的 Vance 服务；`docker compose restart` 不会重读
环境变量。App-facing static secret 的轮换还需要兼容旧 App 的双 token 方案，否则现有
安装包会立刻收到 401。不要把真实密钥交给普通代码贡献者。

新增密钥：
1. 在 `.env.example` 里加占位符
2. 在 ECS 的 `.env` 里加真实值
3. 在 `docker-compose.yaml` 的 `environment` 里映射给容器

## 协作流程

1. **clone 仓库**
   ```bash
   git clone https://github.com/cassieliang6709/fitness-coach-ios.git
   cd fitness-coach-ios/backend
   ```

2. **创建 feature 分支**
   ```bash
   git checkout -b feat/your-feature
   ```

3. **本地开发 + 测试**
   ```bash
   docker compose up
   # 改代码，测试
   ```

4. **提 PR**
   ```bash
   git push origin feat/your-feature
   gh pr create
   ```

5. **review + merge**

6. **部署**（@cassieliang6709 或有部署权限的人）
   ```bash
   ssh sourcerlinda "cd /opt/vance && ./deploy.sh"
   ```

## 故障排查

### 容器起不来
```bash
docker compose ps
docker compose logs worker
docker compose logs gateway
```

### API 返回 502
检查容器是否健康：
```bash
docker inspect vance-worker --format '{{.State.Health.Status}}'
docker inspect vance-gateway --format '{{.State.Health.Status}}'
```

### WebSocket 连不上
1. 确认 nginx 的 `Upgrade` 头配置正确
2. 检查 Gateway 日志是否有 `401 Unauthorized`（密钥不对）
3. 确认 iPhone 的 `REALTIME_GATEWAY_HOST` 是 `realtime.magicandgrind.com`（不带协议）

### DNS 不生效
```bash
dig realtime.magicandgrind.com +short
# 应该返回 47.120.13.248
```

## 监控

**健康检查**：
- https://realtime.magicandgrind.com/health → 应该返回 `ok`
- `/plan`、`/exercises`、`/coach/turn` 均要求 Worker 鉴权
- `/gateway/health` 要求 Gateway 鉴权

**资源占用**：
```bash
docker stats vance-worker vance-gateway
```

**磁盘占用**：
```bash
docker system df
```

## 技术栈

- **Worker**: TypeScript + Cloudflare Worker (workerd) + DeepSeek API
- **Gateway**: Node 22 + 原生 http/ws + MiniMax Realtime API
- **部署**: Docker Compose + nginx 反代
- **密钥**: 环境变量注入，不进 Git

## 与 sourcerlinda 的关系

两个项目的源码、部署物、数据和密钥独立，**但目前共用一台 ECS 和入口 Nginx**：
- 不同 Docker 网络
- 不同密钥
- 不同域名
- 不同代码仓库（sourcerlinda 在 caizhidian-ops/sourcerlinda）

唯一功能性交叉点：Nginx 的 Vance `server` 块要加到 SourcerLinda 主仓库的
`docker/nginx/nginx.conf` 模板里（因为入口 Nginx 属于 SourcerLinda）。该块必须直接
放在 `http {}` 内；同时需要把 Nginx 服务持久加入外部 Docker 网络 `vance`。不要把
`map` 写进 `server {}`，也不要直接编辑某个 ECS release 目录——两者都会让共享 Nginx
无法启动或在下次发布时丢失。

这条网络连接只用于 Nginx → Vance upstream；它不应被误称为安全隔离。Vance 容器不
挂载 Docker socket、主站 release、主站数据库或主站配置，但共享入口仍会形成路由层
耦合。任何要求“被攻破的 Vance 容器绝不能触及主站”的发布，必须先完成独立 ECS/网络
边界迁移，不能只靠同机 Docker 网络命名。

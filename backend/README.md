# Vance Backend

FitnessCoach iOS App 的后端服务，包含文字对话/计划生成 Worker 和 MiniMax Realtime 语音 Gateway。

## 架构

```
iPhone App
    ↓ HTTPS / WSS
realtime.magicandgrind.com (nginx)
    ├─ /api/*     → vance-worker:8788  (DeepSeek 文字+计划)
    ├─ /realtime  → vance-gateway:8787 (MiniMax Realtime WS)
    └─ /gateway/* → vance-gateway:8787 (GymVision 等)
```

**部署位置**：阿里云 ECS `47.120.13.248`（与 sourcerlinda 同机但完全隔离）

**隔离原则**：
- 独立 Docker 网络 `vance`
- 独立密钥 `VANCE_*_SECRET`（不复用 sourcerlinda 的 `APP_SHARED_SECRET`）
- 独立目录 `/opt/vance/`（不在 `/opt/sourcerlinda-releases/`）
- 独立 compose 项目 `vance`

## 目录结构

```
backend/
├── worker/           # Cloudflare Worker（workerd 容器跑）
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

# 密钥从 backend/.env 复制
COACH_SHARED_SECRET = <VANCE_WORKER_SECRET>
```

## 部署到生产

### 第一次部署（已完成）
- [x] DNS: `realtime.magicandgrind.com` → `47.120.13.248`
- [ ] ECS 初始化（见下）
- [ ] nginx server 块加入 sourcerlinda 主仓库
- [ ] HTTPS 证书申请

### 日常部署
```bash
# 1. 提 PR → review → merge 到 main

# 2. SSH 到 ECS
ssh sourcerlinda

# 3. 进入 vance 目录
cd /opt/vance

# 4. 拉代码 + 部署
./deploy.sh
```

### 查看日志
```bash
docker logs vance-worker -f
docker logs vance-gateway -f
```

### 回滚
```bash
cd /opt/vance
git log --oneline -5  # 找到上一个正常 commit
git reset --hard <commit-sha>
./deploy.sh
```

## 密钥管理

**生产密钥**在 ECS 的 `/opt/prod-config/vance/.env`，**不在 Git 里**。

修改密钥：
```bash
ssh sourcerlinda
vim /opt/prod-config/vance/.env
cd /opt/vance/backend && docker compose restart
```

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
- https://realtime.magicandgrind.com/api/health → 应该返回 401（要鉴权）

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

完全独立的两个项目，**只是共用同一台 ECS**：
- 不同 Docker 网络
- 不同密钥
- 不同域名
- 不同代码仓库（sourcerlinda 在 caizhidian-ops/sourcerlinda）

唯一交叉点：nginx server 块要加到 sourcerlinda 主仓库的 `docker/nginx/nginx.conf` 模板里（因为 nginx 容器是 sourcerlinda 的）。

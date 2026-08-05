# Vance 生产后端交接与隔离边界

本文是 2026-08-05 Vance 生产修复后的**无密钥交接说明**，供代码审阅者和有授权的
部署操作员使用。本文不包含真实凭据、生产配置内容、SSH 配置、用户数据或可识别私有
基础设施的路径。

## 一、职责与归属

| 事项 | 归属 | 仓库或边界 |
| --- | --- | --- |
| iOS App、Worker、Gateway、本地 D1 数据卷 | FitnessCoach | `fitness-coach-ios` |
| Vance 运行时配置、供应商凭据 | Vance 生产操作员 | 外置生产配置，永不进入 Git |
| `realtime.magicandgrind.com` TLS 虚拟主机 | SourcerLinda 操作员 | SourcerLinda Nginx 配置 |
| 主站应用、数据与凭据 | SourcerLinda | 不存在于本仓库 |

Vance 的业务后端代码全部位于本仓库 `backend/`。SourcerLinda 只拥有入口 Nginx 的
Vance 虚拟主机及其到 Vance upstream 的转发，不拥有 Vance 的业务逻辑、D1 数据或模型
密钥。

## 二、对外接口合同

生产域名为 `realtime.magicandgrind.com`。

| 对外路径 | 目标 | 用途 |
| --- | --- | --- |
| `/coach/turn`、`/plan`、`/speech`、`/vision/equipment`、`/exercises` | Worker | 文字陪练、计划、语音与动作库 |
| `/realtime` | Gateway | 经鉴权的 MiniMax 实时语音 WebSocket |
| `/gateway/...` | Gateway | 带命名空间的 Gateway HTTP API |
| `/health` | Nginx | 仅供负载均衡探活，不需要 App 密钥 |

Worker 与 Gateway 均不映射主机公网端口；80/443 只由入口 Nginx 对外监听。App 的
文字/计划和实时语音是两条独立链路，任何一条通过都不能替代另一条验收。

## 三、凭据合同（只列名称）

| 运行时变量 | 使用方 | App 对应项 | 规则 |
| --- | --- | --- | --- |
| `VANCE_WORKER_SECRET` | Worker | `COACH_SHARED_SECRET` | 当前为同一环境统一的静态 bearer 凭据 |
| `VANCE_GATEWAY_SECRET` | Gateway | `REALTIME_GATEWAY_SECRET` | 与 Worker 独立的静态 bearer 凭据 |
| `DEEPSEEK_PROXY_SECRET` | Worker ↔ Gateway | 无 | 仅 Docker 内网使用，绝不进入 App |
| `DEEPSEEK_API_KEY`、`MINIMAX_API_KEY`、`KIMI_API_KEY` | 服务端供应商调用 | 无 | 绝不进入 App |

前两项就是 **App-facing secret**。目前同一生产环境的所有 App 构建会使用各自统一的
固定值。它们不是供应商 API Key，也不授予 SSH、Docker 或 SourcerLinda 主站权限；但
App 包可以被逆向，所以它们不适合作为公开大规模发行时的长期授权模型。

在面向广泛用户发布前，应升级为“用户认证后签发的短期 token”。在此之前，不得直接
轮换静态 secret：若没有同时接受旧/新 token 的兼容窗口，已经安装的 App 会立即收到
401。

## 四、本次生产修复内容

1. 共享 Nginx 中曾把 Vance 的 `server {}` 块放入另一个 `server {}` 块，导致 Nginx
   拒绝整份配置，主站入口与 Vance 一起不可用。
2. Vance HTTP/HTTPS 虚拟主机现作为 Nginx `http {}` 的直接子块；`map` 只允许放在
   `http {}` 作用域。
3. Worker 不再以缺少绑定的 bare `workerd` 运行，改由 Wrangler 提供进程密钥与持久化
   本地 D1 绑定。
4. DeepSeek 出网改为经独立鉴权的 Worker → Gateway 私网转发，保留 TLS 校验，而不是
   关闭证书验证。
5. 两个 Vance 容器均禁止提权，并移除全部 Linux capabilities。这能缩小容器攻击面，
   但不能替代独立主机。

## 五、修改与上线流程

### 只改 Vance 业务代码

只构建和重建 Worker 与 Gateway；不要重启、重建或修改主站应用。切换后验证受影响的
鉴权接口和生产域名。

### 修改 Nginx

这是跨仓库改动，必须走更严格的门禁：

1. 在 SourcerLinda Nginx 源码中修改，不能编辑临时 release 目录。
2. Vance HTTP/HTTPS 虚拟主机必须是完整、并列的 `server {}`，直接位于 `http {}` 内；
   不得嵌套 `server`，也不得把 `map` 放入 `server`。
3. 用与生产一致的模板变量渲染候选配置，并在替换运行配置前执行 `nginx -t`。
4. 保留具名备份；reload 后分别验证 `magicandgrind.com` 与
   `realtime.magicandgrind.com`。
5. 修复必须合入拥有入口配置的仓库并回写部署源码；线上手工 patch 不等于发布完成。

## 六、当前隔离的真实边界

当前已具备的保护：

- FitnessCoach 源码、Vance 密钥、Vance 状态卷和 Vance Compose 与主站仓库、主站数据
  分离。
- Vance 容器不以 privileged 运行，不挂载 Docker socket、主机路径、主站 release、
  主站数据库或主站生产配置。
- Vance 容器不发布端口；入口 Nginx 是唯一公网监听点。

但这**不是对抗已被攻破容器的绝对安全边界**：共享 Nginx 为转发 Vance，同时连接主站
网络与 Vance 网络。Vance 容器不能读取 Nginx 挂载文件，但仍可在网络层访问这台共享
代理。单台 ECS 上的 Docker 网络拆分，不能保证攻击者无法借共享代理或主机级漏洞影响
主站。

因此，只要 Vance 与主站共享当前 ECS 和 Nginx 进程，就不得声明“Vance 被攻破也绝无
主站路径”。

## 七、满足严格主站隔离的目标架构

若要求 Vance 无法触及主站，应把 Vance 迁到独立 ECS（或等价的独立网络边界），并把
`realtime.magicandgrind.com` 指向该独立入口。目标环境必须满足：

- 不共享 Docker 主机、Docker 网络、反向代理容器、文件系统挂载、数据库、Docker
  socket 或生产配置；
- 使用独立 Vance 安全组：只允许必要的 HTTPS/WSS 入站，以及受控的供应商出站；
- 使用独立部署凭据、密钥、日志、备份和回滚产物；
- 迁移后证明 Vance 无法路由到主站私网地址/名称，同时公开 Worker 与 Gateway 验收仍
  通过。

这是一项基础设施迁移，需要单独批准和执行；不能由 App 构建或本文档 PR 静默完成。

## 八、给队友的交接清单

- 使用 FitnessCoach `main` 的合并提交 `2649c24` 或之后经审阅的 main 提交。
- 只获得职责所需的凭据**名称**和部署权限；不得获得 `.env`、`Secrets.xcconfig`、
  供应商 Key、Nginx 凭据、主站检出或主站 SSH 权限。
- 把 Worker 文字/计划和 Gateway 实时语音当成独立验收链路。
- 使用脱敏测试数据验证 `/plan`、`/exercises`、`/coach/turn` SSE、`/realtime`
  WebSocket 与 `/health`。
- 在专用 `KIMI_API_KEY` 被生产操作员配置前，器材照片识别应视为不可用。

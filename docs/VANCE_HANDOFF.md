# Vance 模块 handoff

这是在现有 MiniMax 实时语音能力之上新增的 Kimi 模块：拍照识别健身器械，并把高置信结果更新到本地训练记忆（SwiftData）。本 handoff 不要求重接或改造既有 MiniMax 链路；没有新的 iOS 三方包，也不需要 CloudKit 或数据库后端。

## 1. 接入方式

1. 保留既有 MiniMax 实时语音和 `CoachAPI` / Cloudflare SSE 文本路径；本次不改它们。
2. 在现有 `vance-gateway/` 部署中启用 Kimi 识别路由，并通过 HTTPS 暴露给 App；无需改动既有 MiniMax WebSocket 路由。
3. 在 App 的未提交 `Secrets.xcconfig` 填入 Gateway 主机和 App→Gateway Bearer Token：

   ```xcconfig
   VANCE_GATEWAY_HOST = gateway.example.com
   VANCE_GATEWAY_SHARED_SECRET = replace-at-build-time
   ```

4. `WorkoutSession` 已将 `GymVisionAPI` 和本地 `WorkoutStore` 接到 `CoachThread`；Home 对话页已提供拍照入口，无需再交付单独 UI。
5. 相机照片会与定位/地点反查并行：对话先回显已确认器械，随后显示 `地点：<名称>`；同地点器械会在“AI 记住的事”中合并为一条 `地点 · 器械A、器械B`。

## 2. 依赖与配置

| 位置 | 依赖 | 说明 |
| --- | --- | --- |
| iOS | `AVFoundation`、`AudioToolbox`、`CoreLocation`、`SwiftData`、`UIKit` | 系统框架；无需 SPM/CocoaPods |
| Gateway | Node.js >= 22.5 | 原生 `fetch`、WebSocket 代理；`npm test` |
| 本次新增 Secret | `KIMI_API_KEY`、`VANCE_GATEWAY_SHARED_SECRET` | Kimi 识别需要；仅部署环境，绝不进 iOS 包或 Git |
| 既有 Gateway Secret | `MINIMAX_API_KEY` | 当前合并 Gateway 仍会读取它以保留既有实时路由；本次不修改其用法 |
| iOS 权限 | 麦克风、语音识别、相机、使用期间定位 | 现有 `Info.plist` 已有说明 |

Gateway 路由：

- `POST /api/gym-vision`：Kimi K2.6 器械识别；只返回 high 置信器械。
- `GET /health`：配置探针，不返回任何密钥。

## 模块边界

- 视觉模块只识别器械，不生成训练计划；下一轮语音教练使用器械上下文继续。
- 经纬度和识别耗时仅保存在本机 SwiftData；不会发送给 Kimi。地点名来自系统反查，若系统没有场馆 POI，可能只返回街道/区域名。
- 每次识别的图片大小、端到端、Gateway→Kimi、定位耗时会写入本地 `GymVisionTimingRecord`，**不会出现在用户对话中**。
- Gateway 不持久化图片、音频、对话或坐标。

## 验证

```bash
cd vance-gateway
npm test
curl -H "Authorization: Bearer <shared-secret>" https://<gateway>/health
```

真机验收：拍摄器械后只出现 high 设备、地点与合并后的本地记忆；下一轮既有语音教练能使用这些器械上下文。若需要排查时延，可读取本机 `GymVisionTimingRecord`，无需向用户展示诊断数字。

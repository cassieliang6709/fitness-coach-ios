# 在 iOS 上跑通 MiniMax 实时语音

`SWIFTUI_HANDOFF.md` 描述的是协议；这份是把它真正跑起来的步骤。iOS 侧的实现在
`FitnessCoach/Realtime/`，入口是首页右上角的波形按钮（路由 `/workout/realtime`）。

## 0. 先确认上游还活着

这一步失败的话，后面全部无意义。交接文档把网关硬编码的
`api.minimax.chat/ws/v1/realtime?model=abab6.5s-chat` 标注为旧版接口，所以先探一次：

```bash
cd Vance_Coach_Gateway_Handoff_20260802 && cp .env.example .env
```

把 `.env` 里的 `MINIMAX_API_KEY` 换成真实 key，然后：

```bash
nvm use 24 && node Vance_Coach_Gateway_Handoff_20260802/scripts/probe-minimax.mjs
```

拿到 `realtime upstream is alive.` 才继续。

**已用假 key 验证过：这个端点是活的。** 它对 upgrade 请求不返回 4xx，而是返回
`HTTP/1.1 200 OK` 加一段 JSON 错误体：

```
body: {"base_resp":{"status_code":2049,"status_msg":"invalid api key"}}
```

也就是说 200 + `invalid api key` 说明路由存在、只是 key 没通过；真正的 404 / 路由消失
会是另一种响应。`api.minimax.io` 行为相同。若真实 key 仍被拒，换端点不用改代码：

```bash
MINIMAX_HOST=api.minimax.io node Vance_Coach_Gateway_Handoff_20260802/scripts/probe-minimax.mjs
```

哪个通，就把 `MINIMAX_HOST` / `MINIMAX_PATH` 写进 `.env`，网关会读同一组变量。

## 1. 起网关

`store.mjs` 用 `node:sqlite`，**Node 22.5 以下直接 import 失败**，必须 Node 24：

```bash
nvm use 24 && node Vance_Coach_Gateway_Handoff_20260802/server.mjs
```

`curl http://127.0.0.1:8787/health` 应返回 `{"ok":true,...}`。

## 2. 跑 App

模拟器直接可用（`Secrets.xcconfig` 里默认 `REALTIME_GATEWAY_HOST = 127.0.0.1:8787`，
loopback 不受 ATS 限制）：

```bash
xcodegen generate && open FitnessCoach.xcodeproj
```

真机需要两处改动：网关用 `HOST=0.0.0.0 node server.mjs` 监听局域网，
`REALTIME_GATEWAY_HOST` 改成 Mac 的局域网 IP。Info.plist 里的
`NSAllowsLocalNetworking` 和 `NSLocalNetworkUsageDescription` 已经配好。

## 端上目前的取舍

- **按住说话，不是自动 VAD。** 交接文档的 VAD 参数（基线 +18 dB、260 ms 起、850 ms 止、
  <550 ms 丢弃）是浏览器实测值，需要用真实健身房录音重新校准后才能当默认值。
  按键把这个变量从首次联调里拿掉了。松手时长不足 550 ms 的按压会本地丢弃。
- **回声消除靠 `setVoiceProcessingEnabled`。** 采集和播放共用一个 `AVAudioEngine`，
  否则外放的教练声会被麦克风收回去、被转写成用户说话，模型会自己打断自己。
  模拟器上这条链路不稳定，回声问题以真机为准。
- **空 commit 端上先拦一道。** 网关对 `audioChunks === 0` 的 commit 报错，而报错后的
  上游会话不能继续 append，所以客户端不发空 commit；真收到 `input_audio` 相关错误时
  会整条重连（同一个 `conversationId`）。
- **Prompt 还在客户端之外但也不在服务端。** 网关目前透传 `session.update`，Vance
  Prompt v1 的原文随 `public/` 一起没有交接过来，只剩 `SWIFTUI_HANDOFF.md` 里的约束
  条目。合并前应按文档收敛成 `vance.session.configure`，由网关注入。

## 生产前必须补的

网关现在没有鉴权、没有限流、明文 ws、单进程手写 WebSocket 代理。
只适合黑客松和联调，不能对外。

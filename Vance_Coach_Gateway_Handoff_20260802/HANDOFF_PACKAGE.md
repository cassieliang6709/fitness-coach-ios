# Vance Coach Gateway 交接包说明

此压缩包只包含可合并的后端模块、接口契约、环境变量模板、测试与产品案例材料。

包含：

- `server.mjs`：MiniMax Realtime Gateway 与 Kimi API 路由
- `gym-vision.mjs`：Kimi 器械识别与置信度过滤
- `store.mjs`：开发期会话与评估存储参考实现
- `exercise-catalog.mjs`：尚未接入的动作资料库能力
- `SWIFTUI_HANDOFF.md`：SwiftUI 接入、部署和密钥交接规范
- `CAPABILITIES.md`：当前三个核心能力
- `健身案例.md`：产品案例、Vance 人格与提示词材料
- `.env.example`：仅 Secret 名称与占位符
- `scripts/`：数据导入与模块测试

刻意不包含：Web UI、真实 `.env`、真实 API Key、SQLite、日志、原始照片、录音或用户数据。

真实 Key 的接收方应在部署系统的 Secret Manager 中配置 `MINIMAX_API_KEY` 和 `KIMI_API_KEY`，而不是放入 iOS App、CloudKit、Git 或压缩包。

# Vance realtime + DeepSeek development handoff — 2026-08-05

## Delivery state

- Authoritative checkout: `ios/fitness-coach-ios-main-test`
- Branch: `agent/integrated-realtime-deepseek`
- Draft PR: `https://github.com/cassieliang6709/fitness-coach-ios/pull/5`
- Base: current `origin/main`
- This handoff covers code and local/physical test work. It does not claim a production deployment.

## Product behavior delivered

1. MiniMax realtime voice is embedded directly in the strength and cardio coaching pages. The standalone waveform destination, route and home entry are removed.
2. Exercise, set, prescription, venue and memory context are sent to the Gateway and refreshed when workout context changes.
3. The same page shows connection state, transcript, typed context, push-to-talk and end-training actions.
4. Debug builds include three Mandarin M4A fixtures: back, tired and give-up. They decode to 24 kHz mono PCM16 and travel through the real authenticated Gateway and MiniMax response path.
5. The Worker uses DeepSeek's OpenAI-compatible chat API for text coaching and plan generation. Tool-use history is converted explicitly, `generate_plan.title` is required, and a server fallback prevents an empty title from invalidating an otherwise usable plan.

## Runtime architecture

- Text conversation and plan generation: iOS → authenticated Cloudflare Worker-compatible service → DeepSeek → D1 exercise/plan validation.
- Realtime voice: iOS → authenticated Node Gateway → MiniMax legacy Realtime WebSocket.
- Local ports: Worker `8788`, Gateway `8787`.
- `COACH_API_HOST` and `REALTIME_GATEWAY_HOST` are independent. Both must be reachable from a physical phone.
- Provider keys remain server-side. `Secrets.xcconfig`, Worker `.dev.vars`, Gateway `.env`, personal signing and temporary tunnel hosts are not committed.

## Important fixes and diagnostics

- The app no longer reports a WebSocket ready immediately after `resume()`. It waits for a non-error server event and uses an eight-second connection watchdog with bounded reconnects.
- The Gateway reassembles RFC 6455 continuation frames, including control frames interleaved between fragments. This fixed physical-device audio commits being lost after reverse-proxy fragmentation.
- A delayed previous-turn `response.done` no longer replaces a new `.listening` state and drops the remaining audio chunks.
- Speech-recognition permission is optional. MiniMax remains the authoritative transcript; missing local Speech permission cannot disable the realtime socket or typed turns.
- Gateway bearer authentication fails closed when its shared secret is absent.
- Local HTTP/WS is selected only for loopback/private hosts; deployed hosts use HTTPS/WSS.

## Validation evidence

- iOS Simulator build: passed.
- Simulator live MiniMax tests: three independent fixtures plus all three turns on one socket, 4/4 passed.
- Existing mock workout adjustment regression: 1/1 passed.
- Gateway contract tests: 6/6 passed.
- Worker TypeScript typecheck: passed.
- Authenticated local Worker + DeepSeek plan requests: 3/3 passed, with non-empty titles and five to seven items.
- Physical-device Worker + DeepSeek plan generation: automated live UI acceptance passed with a unique user ID, so neither an existing plan nor MockData could satisfy the assertion.
- Physical device before final consolidation: back and tired fixtures returned real MiniMax audio. The give-up fixture was not rerun after the delayed-response race fix; that race is covered by the passing three-turn Simulator test.
- Final physical-device manual acceptance: the user confirmed that plan generation and realtime conversation both work after the iPhone-side LAN path was corrected. This is recorded as manual evidence, not as a passing realtime XCTest.

## Physical-device state and the current failure

The phone contains two app identities with the same display name: current `com.cassie.fitnesscoach` and older `com.zhitian.fitnesscoach`, both version 1.0 build 1. Preserve the older app unless its data can be deleted.

The failing current-app binary embedded a Worker address on the Mac's iPhone-hotspot subnet and a temporary Quick Tunnel for Gateway. An iPhone acting as hotspot host cannot reliably call back to the Mac hotspot client, and Quick Tunnel URLs have no uptime guarantee. Later testing also confirmed that an iPhone VPN/proxy can capture LAN traffic until “bypass LAN” (or an equivalent rule) and Local Network permission are correct. Therefore “conversation service unavailable” and failure to generate today's plan were endpoint-reachability failures, not Apple-account, certificate or microphone-permission failures.

The final manual pass came from fixing both layers, not from one magic switch:

1. Code: the workout page now uses the real realtime client; the Gateway handles fragmented WebSocket messages; audio/session races are bounded; and the Worker produces validated DeepSeek plans.
2. Runtime: the installed app contains two separately reachable hosts, and the iPhone network no longer diverts/block LAN traffic needed to reach them.

See `docs/iphone-mac-connection-troubleshooting.md` for the reusable decision tree.

## Physical acceptance procedure

1. Start Worker and Gateway locally and verify authenticated `/health` on each origin.
2. Provide separate phone-reachable HTTPS/WSS hosts. Quick Tunnels are acceptable only for an immediate test; repeatable acceptance requires stable deployed or named-tunnel hosts.
3. Put host names only in the ignored `Secrets.xcconfig`; never include `https://` because `//` starts an xcconfig comment.
4. Build the app with the local personal Team override without modifying the committed project team.
5. Run `testLiveWorkerGeneratesTodayPlan` with `VANCE_RUN_LIVE_PLAN=1`; it uses a unique user ID so a cache cannot fake success.
6. Run the realtime live-fixture test on the physical device and inspect Gateway telemetry for open, first append, commit and first audio.

## Remaining release gate

PR #5 is code-complete for the integrated flow, but a permanently usable phone build still requires stable hosts for both Worker and Gateway. Do not merge “temporary tunnel currently works” into the claim “physical service is deployed and reliable.”

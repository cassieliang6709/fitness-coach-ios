# iOS signing and physical-device testing

## Keep the signing identities distinct

- The Apple Account is the login in Xcode. Being logged in lets Xcode request and refresh development assets, but it does not itself sign an app.
- The development certificate plus its private key is this Mac's signing identity. The suffix shown beside a certificate is not the Team ID.
- The Team ID is the developer-team namespace used by App IDs and entitlements. A personal team selected for local device tests is local configuration and must not be committed over the repository's team setting.
- A provisioning profile is an Apple-signed binding of Team, App ID/bundle ID, allowed development certificates, registered devices and capabilities. A matching certificate alone is not enough.

The suffix shown in a certificate name identifies that certificate; it is not the Team ID. The verified profile for the current app uses bundle ID `com.cassie.fitnesscoach`. Exact personal account, certificate, profile UUID and Team values stay in local operator notes rather than this repository.

## Why two FitnessCoach icons can appear

iOS identifies apps by bundle ID, not display name. The current test build is `com.cassie.fitnesscoach`; an older installed build is `com.zhitian.fitnesscoach`. They can coexist as two icons named FitnessCoach and keep separate data. Do not uninstall the older app without an explicit data-deletion decision.

## Repository and branch boundary

The integrated work is developed from `origin/main` on `agent/integrated-realtime-deepseek` in `ios/fitness-coach-ios-main-test`. The separate `ios/fitness-coach-ios` and `worktrees/fitness-coach-ios-vance-realtime-dev` directories are other clones/worktrees and are not the authority for this PR.

## Network boundary: Simulator is not a phone

- Simulator can use `127.0.0.1:8788` for Worker and `127.0.0.1:8787` for Gateway.
- A phone on the same normal router can use a reachable Mac LAN address while both services bind to a non-loopback interface.
- When the iPhone is itself the Mac's hotspot, the phone cannot reliably call back to the Mac hotspot client. A `172.20.10.x` Mac address is therefore not a valid physical-test assumption.
- For repeatable physical tests, use stable deployed HTTPS/WSS hosts. A Cloudflare Quick Tunnel is temporary test infrastructure; its URL expires and repeated WebSocket handshakes can be intermittent.
- `COACH_API_HOST` and `REALTIME_GATEWAY_HOST` are separate services. Making only the Gateway reachable still leaves plan/text conversation unavailable.

`Secrets.xcconfig`, Gateway `.env`, provider keys, personal Team settings and temporary tunnel hosts stay local and out of Git.

## Acceptance evidence to collect separately

1. Gateway contract tests cover authentication-facing behavior and fragmented WebSocket messages.
2. Worker typecheck and authenticated live plan turns prove DeepSeek plan generation and required titles.
3. Simulator live-fixture tests prove all three bundled audio clips produce real MiniMax replies, including three turns on one socket.
4. Physical-device testing separately proves code signing, installation, reachable Worker/Gateway endpoints, microphone capture and playback. Simulator success must never be reported as physical-device success.

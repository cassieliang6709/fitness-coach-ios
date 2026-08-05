# iPhone ↔ Mac development troubleshooting

This playbook is for FitnessCoach Simulator and physical-device testing. It
keeps signing, installation identity, Worker reachability and Gateway realtime
reachability separate so one passing boundary is not mistaken for another.

## 1. Signing terms are not interchangeable

| Term | Meaning | Where to verify |
| --- | --- | --- |
| Apple Account | The Apple ID logged into Xcode | Xcode → Settings → Accounts |
| Signing certificate | A development certificate plus its private key on this Mac | Keychain / `security find-identity -v -p codesigning` |
| Team ID | The developer-team namespace used by `DEVELOPMENT_TEAM` | Certificate OU or Apple developer membership |
| Provisioning profile | Authorization tying together team, bundle ID, certificate, device and capabilities | Xcode managed profiles / embedded profile |
| Bundle ID | The installed app's identity | Target build settings and built `Info.plist` |

The suffix displayed in a certificate's friendly name is not necessarily the
Team ID. Read the certificate's Organizational Unit (`OU`) when the real Team
ID must be established. A signing failure also does not imply that the Apple
Account is logged out.

Personal Team IDs, profile UUIDs, certificate names and account addresses are
local machine state. Do not commit them. For a physical build, override the
team locally or select it in Xcode while keeping the repository configuration
unchanged.

## 2. Two same-name apps can be different apps

iOS identifies apps by Bundle ID, not display name. During this development
cycle the current app (`com.cassie.fitnesscoach`) and an older build with a
different Bundle ID could both remain installed. They have independent data
containers and can show different behavior despite identical icons and names.

Before diagnosing a device report, identify the Bundle ID that was launched.
Do not remove an older app until its data is known to be disposable.

## 3. Worker and Gateway are independent boundaries

| User behavior | Service | Local port | App setting |
| --- | --- | --- | --- |
| Text coaching and today's plan | Worker + DeepSeek | `8788` | `COACH_API_HOST` |
| Realtime voice | Gateway + MiniMax | `8787` | `REALTIME_GATEWAY_HOST` |

A healthy Gateway does not make plan generation work, and a healthy Worker
does not make realtime voice work. Check, expose and authenticate both hosts.

## 4. Choose a valid network topology

### Simulator

Use `127.0.0.1:8788` and `127.0.0.1:8787`. The Simulator shares the Mac's
network stack. Explicitly bypass the system proxy for local health checks.

### Physical phone and Mac on the same router

Use the Mac's LAN address. Both services must listen on `0.0.0.0`, the Mac
firewall must allow them, and the router must not isolate clients.

An iPhone VPN or proxy can still capture RFC1918 traffic. Enable “bypass LAN”
or equivalent, temporarily disable the VPN, and confirm FitnessCoach has Local
Network permission. In the final physical test, correcting this iPhone-side
network path was required before both service hosts were reachable.

### iPhone provides the Mac's personal hotspot

Do not assume the hotspot host can call back to its Mac client at a
`172.20.10.x` address. That topology did not provide a repeatable realtime
path in this test cycle.

### Temporary reverse tunnels

Quick Tunnels can unblock a one-off HTTPS/WSS test, but their host names expire
and WebSocket handshakes can be intermittent. Never commit temporary hosts.
Long-lived physical testing requires stable HTTPS/WSS endpoints.

### Xcode's USB/CoreDevice tunnel

The development tunnel is for Xcode device protocols; it is not a general
reverse port forward for the app's arbitrary Worker or Gateway traffic.

## 5. Inspect what was actually built

Changing `Secrets.xcconfig` does not change an app that is already installed.
After each host change, rebuild and inspect the product rather than the source
file:

```bash
plutil -p <DerivedData>/Build/Products/Debug-iphoneos/FitnessCoach.app/Info.plist \
  | rg 'COACH_API_HOST|REALTIME_GATEWAY_HOST'
```

`Secrets.xcconfig`, provider keys, shared secrets, personal signing values and
temporary tunnel hosts must stay ignored.

## 6. Realtime-specific failures

- Simulator error “microphone input format unavailable” can mean the Simulator
  exposes a `0 Hz` input format. That is a missing virtual audio device, not a
  microphone-permission diagnosis. Use the bundled DEBUG fixtures or a phone.
- A proxy may fragment RFC 6455 messages. The Gateway must reassemble
  continuation frames and allow interleaved control frames before parsing the
  JSON payload. This is covered by Gateway contract tests.
- Do not report the socket ready immediately after `URLSessionWebSocketTask`
  resumes. Wait for a valid server event and keep a bounded watchdog/retry
  budget.
- Delayed completion from the previous assistant turn must not replace a new
  listening state and discard the new audio chunks.

## 7. XCTest on a physical phone

Keep the phone unlocked and awake. `xcodebuild` can wait indefinitely with
“Unlock iPhone … to Continue”.

The live plan test uses a unique install-user ID, so an existing plan cache
cannot fake success. The live audio fixtures decode the bundled Mandarin M4A
to 24 kHz PCM16 and travel through VAD, authenticated WebSocket, Gateway and
MiniMax; they are not scripted assistant responses.

## 8. Triage order

1. Identify the Bundle ID, screen and service boundary.
2. Confirm the service process is listening on the intended interface.
3. Check authenticated health on the origin.
4. Inspect the built app's two embedded hosts.
5. Confirm phone and Mac topology; bypass iPhone VPN for LAN traffic and grant
   Local Network permission.
6. Treat HTTP and WSS as separate probes.
7. For realtime, inspect Gateway telemetry for connection open, first audio
   append, commit and first assistant audio.
8. Only after reachability is proven should provider, audio or model code be
   changed.

## 9. Test discipline

- Simulator, physical signing/install, Worker plan generation and Gateway
  microphone/playback are four separate acceptance gates.
- A manual device pass and an automated XCTest pass must be reported as
  different evidence.
- Do not use “the tunnel currently responds” to claim a stable deployment.
- Never commit personal signing, secrets, `.env`, `.dev.vars`,
  `Secrets.xcconfig` or temporary host names.

## 10. Production ingress incident and isolation boundary (2026-08-05)

A Vance `server {}` block was accidentally nested inside an existing main-site
Nginx `server {}` block. Nginx rejected the entire shared configuration, so
both the Vance hostname and the main site were affected. A dedicated hostname
does not contain an invalid shared Nginx configuration.

For any Vance ingress edit, keep each Vance HTTP/HTTPS `server` as a direct
child of `http {}` and keep `map` directives at `http {}` scope. Render the
candidate with the production template variables and pass `nginx -t` before a
reload or restart. Reconcile the validated source PR immediately; never leave
an ECS-release-only hotfix.

FitnessCoach source/build access does not include the main-site source, its
credentials or a Docker socket, and Vance containers do not mount main-site
paths. That is useful source and data separation. It is not a hostile-container
security guarantee: the shared Nginx currently participates in both Docker
networks to proxy Vance. Strictly preventing a compromised Vance runtime from
reaching the main site requires a separate ECS/network/reverse-proxy boundary,
not merely separate Docker network names.

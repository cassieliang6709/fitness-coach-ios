# Vance Realtime Gateway

Node 22+ service for the iOS app's Vance mode. It exposes no UI and keeps the
MiniMax / Kimi provider keys on the server.

## Local run

```bash
cd vance-gateway
cp .env.example .env
# Add MINIMAX_API_KEY. Add KIMI_API_KEY only when testing photo recognition.
node server.mjs
```

Health check:

```bash
curl http://127.0.0.1:8899/health
```

When `VANCE_GATEWAY_SHARED_SECRET` is set, include:

```bash
curl -H "Authorization: Bearer <secret>" http://127.0.0.1:8899/health
```

Run contract tests:

```bash
node --test test/*.test.mjs
```

## iOS development settings

Copy `Secrets.xcconfig.example` to the untracked `Secrets.xcconfig`, then add:

```xcconfig
VANCE_GATEWAY_HOST = 127.0.0.1:8899
VANCE_GATEWAY_SHARED_SECRET = local-development-secret
```

The gateway uses `ws` / `http` only for `localhost` and `127.0.0.1` (Simulator
development). Any physical iPhone must use an HTTPS/WSS tunnel or deployed
hostname; the client deliberately does not downgrade LAN hosts to cleartext.
Never add `MINIMAX_API_KEY` or `KIMI_API_KEY` to the Xcode configuration.

## Routes

| Route | Use |
| --- | --- |
| `GET /health` | Configuration and prompt-version probe; never returns keys |
| `GET /realtime` (WebSocket upgrade) | 24kHz PCM16 realtime voice events |
| `POST /api/gym-vision` | Kimi K2.6 high-confidence equipment recognition |

The WebSocket accepts a `vance.session.configure` event. The service converts
it to MiniMax's session configuration and injects the server-owned Vance Prompt.

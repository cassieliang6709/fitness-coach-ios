# Vance production backend handoff and isolation boundary

This document is the non-secret handoff for the Vance production repair on
2026-08-05. It is for reviewers and deploy operators. It deliberately omits
credentials, production paths that identify private data, SSH configuration,
and account material.

## Scope and ownership

| Concern | Owner | Repository / boundary |
| --- | --- | --- |
| iOS application, Worker, Gateway, local D1 volume | FitnessCoach | `fitness-coach-ios` |
| Vance runtime configuration and provider credentials | Vance operator | external production configuration only |
| `realtime.magicandgrind.com` TLS virtual host | SourcerLinda operator | SourcerLinda Nginx configuration |
| Main-site application, data and credentials | SourcerLinda | not present in this repository |

The Vance business backend is entirely under `backend/` in this repository.
The only source change made to SourcerLinda was the dedicated Nginx virtual
host and its one-way upstream reachability. No Vance application code belongs
in the main-site backend.

## Public contract

The public hostname is `realtime.magicandgrind.com`.

| Public path | Target | Purpose |
| --- | --- | --- |
| `/coach/turn`, `/plan`, `/speech`, `/vision/equipment`, `/exercises` | Worker | text coaching, plans, speech and catalogue |
| `/realtime` | Gateway | authenticated MiniMax realtime WebSocket |
| `/gateway/...` | Gateway | namespaced Gateway HTTP APIs |
| `/health` | Nginx | unauthenticated load-balancer probe only |

Worker and Gateway have no published host ports. Only the shared edge Nginx
publishes 80/443. The App has two independent service paths and must never use
one as a substitute for the other.

## Credential contract — names only

| Runtime variable | Consumer | App-facing mapping | Rule |
| --- | --- | --- | --- |
| `VANCE_WORKER_SECRET` | Worker | `COACH_SHARED_SECRET` | static, environment-wide bearer credential today |
| `VANCE_GATEWAY_SECRET` | Gateway | `REALTIME_GATEWAY_SECRET` | separate static bearer credential today |
| `DEEPSEEK_PROXY_SECRET` | Worker ↔ Gateway | none | Docker-network-only; never enters an App build |
| `DEEPSEEK_API_KEY`, `MINIMAX_API_KEY`, `KIMI_API_KEY` | server-side providers | none | never enters an App build |

The first two values are the **App-facing secrets**. Each is currently one
static value shared by every build of the same environment. They are not
provider API keys and do not grant SSH, Docker, or SourcerLinda access, but a
released IPA can be reverse-engineered and therefore they are not suitable as
the long-term authorization model for a public app. Before broad public
distribution, replace them with per-user, short-lived tokens issued after
authentication. Do not rotate either static value without a compatible
dual-token rollout, or existing installed builds will receive 401 responses.

## What the 2026-08-05 repair changed

1. The shared Nginx outage was caused by a Vance `server {}` block placed
   inside another `server {}` block. Nginx then rejected the entire file, so
   the main-site entrypoint restarted instead of serving either host.
2. The canonical Vance virtual hosts now live directly under Nginx `http {}`.
   `map` directives remain at `http {}` scope only.
3. The Worker no longer runs bare `workerd` without bindings. Wrangler now
   supplies process secrets and persistent local D1 state.
4. DeepSeek egress uses an authenticated private Worker-to-Gateway endpoint,
   preserving TLS verification rather than disabling certificate checks.
5. The two Vance containers now drop all Linux capabilities and disallow
   privilege escalation. This reduces container attack surface; it is not a
   replacement for host isolation.

## Required change procedure

### Vance application change only

Build and recreate only the Worker and/or Gateway. Do not restart, rebuild or
modify the main-site application. Verify the affected authenticated endpoint
and the public hostname after cutover.

### Nginx change

This is a cross-repository change and has a stricter gate:

1. Make the edit in the SourcerLinda Nginx source, not an ephemeral release
   directory.
2. Keep the Vance host in a complete, sibling `server {}` block directly under
   `http {}`. Never nest `server`, `map`, or other `http` directives.
3. Render the candidate using the same environment contract as production and
   run `nginx -t` before replacing a running configuration.
4. Preserve a named backup and verify both `magicandgrind.com` and
   `realtime.magicandgrind.com` after reload.
5. Merge the source PR and reconcile the deployed source immediately; a
   production-only fix is not a release.

## Current isolation: truthful statement

The following protections exist today:

- FitnessCoach source, Vance secrets, Vance state volume and Vance Compose are
  separate from the main-site repository and state.
- Vance containers are not privileged and do not mount the Docker socket, host
  paths, main-site release files, database files or production configuration.
- Vance ports are not published; the edge is the only public listener.

However, this is **not an absolute hostile-container boundary**. The shared
Nginx is connected to both the main-site network and the Vance network so it
can proxy to Vance. A compromised Vance container cannot read Nginx mounts,
but it can still reach that shared proxy at the network layer. Docker network
separation on one host does not guarantee that an adversary cannot use a shared
proxy or exploit a host-level vulnerability.

Therefore, do not claim that a Vance Docker compromise is incapable of
affecting the main site while they share this ECS host and Nginx process.

## Required target for strict main-site isolation

For the owner's requirement that Vance have no path into the main site, move
Vance to a separate ECS instance (or an equivalent separately administered
network boundary) and point `realtime.magicandgrind.com` to that edge. The
target must have:

- no shared Docker host, Docker network, reverse-proxy container, filesystem
  mounts, database, Docker socket or production configuration;
- a dedicated Vance security group permitting only required public HTTPS/WSS
  ingress and controlled provider egress;
- separate deploy credentials, secrets, logs, backups and rollback artifacts;
- post-migration proof that Vance cannot route to private main-site addresses
  or names, while public Vance Worker and Gateway tests still pass.

This is an infrastructure migration and must be separately approved and
executed; it is not silently performed by an application build or by this
documentation PR.

## Handoff checklist for a teammate

- Use FitnessCoach `main` at merge commit `2649c24` or a later reviewed main
  commit.
- Receive only secret *names* and deployment access appropriate to the
  operator role; never receive an `.env`, `Secrets.xcconfig`, provider key,
  Nginx credential, main-site checkout, or main-site SSH access.
- Treat Worker text/plan and Gateway realtime as independent acceptance paths.
- Confirm `/plan`, `/exercises`, `/coach/turn` SSE, `/realtime` WebSocket,
  and `/health` using redacted test data.
- Treat gym-photo recognition as unavailable until an operator supplies a
  dedicated `KIMI_API_KEY`.

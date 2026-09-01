# Vance - 健身搭子

基于你的倾向和健身环境，陪你健身并适时引导。

SwiftUI iOS app with an AI coach, training plan, exercise library, and a
seven-day interactive gym-learning course:

```
/welcome → /home → /plans → /plans/leg-day
                 → /exercises
                 → /workout/strength → /workout/cardio → /workout/review
                 → /lab/1 … /lab/6 → /lab/final → /lab/license
```

## Vance v2 direction

Vance v2 narrows the product around one execution loop:
`prepare → execute → adapt → review → improve`. The current typed coaching
actions will become a thin, replayable Agent Harness, followed by a simulated
workout benchmark and offline Agentic RL experiments. Safety rules, state
transitions, authorization, and persistence remain deterministic.

- Product, harness, reward, evaluation, and rollout spec:
  [`docs/vance-v2-agent-harness-rl-spec.md`](docs/vance-v2-agent-harness-rl-spec.md)

The harness is deliberately domain-specific; this project is not trying to
become a general-purpose agent framework.

`/welcome` runs once, for a user with no stored profile. Its four questions
(目标 / 场地 / 身体状况 / AI 风格) are written straight into the memory table, so
the coach's first line already reflects them.

`/home` is the root afterwards — one page, four capsule tabs:

| Tab | Contents |
| --- | --- |
| 对话 | The daily coach thread, suggestion chips, compact text + mic bar |
| 我的计划 | Today's plan, this week's stripe, streak / totals, memory chips, recent sessions, tone picker |
| 动作库 | Searchable, safety-filtered exercise catalogue |
| 实验室 | Seven short lessons that turn gym knowledge into a personal first workout |

The four areas share the floating tab capsule. `我的计划` is the default tab;
the Lab uses its own science-notebook header and persistent lesson progress.

## Vance Lab

Vance Lab starts with the learner's goal and real weekly availability, then
moves through gym orientation, Push / Pull, Knee / Hip, training dose, and the
relationship between strength and cardio. Day 7 asks the learner to diagnose
Alex's week before building a full week, a busy-week fallback, and Workout A.

- Approved course manuscript: `docs/vance-lab-course-v2.md`
- Earlier manuscript retained for comparison: `docs/vance-lab-course-v1.md`
- Reusable build workflow: `docs/product-build-workflow.md`
- Selected visual direction: `docs/references/vance-lab-selected.png`
- Lab progress is stored locally in `UserDefaults` and survives relaunches.

## Run

```bash
xcodegen generate && open FitnessCoach.xcodeproj
```

`FitnessCoach.xcodeproj` is generated from `project.yml` — edit the yml, not the
project file. Adding a source file needs no project change; just re-run
`xcodegen generate`.

## Checks

```bash
xcodebuild -project FitnessCoach.xcodeproj -scheme FitnessCoach -destination 'platform=iOS Simulator,name=iPhone 17' build
```

```bash
swift format lint --recursive --strict FitnessCoach FitnessCoachUITests
```

```bash
xcodebuild -project FitnessCoach.xcodeproj -scheme FitnessCoach -destination 'platform=iOS Simulator,name=iPhone 17' test
```

## Deep-linking (DEBUG only)

Jump straight to a screen without walking the flow:

```bash
xcrun simctl launch booted com.cassie.fitnesscoach -route /workout/strength
```

Lab routes use `/lab/1` through `/lab/6`, `/lab/final`, and `/lab/license`.
During DEBUG runs, `-home-tab lab -lab-day 2` opens the Lab and seeds Day 2 as
the current unlocked lesson.

`-route` implies an existing user, so it seeds a demo profile and skips the
welcome flow. To skip it without deep-linking, pass `-onboarded`; to see the
welcome flow itself, launch with neither.

## Web demo (`web/`)

Live: **https://fitness-coach-demo.pages.dev**

For people who can't run an iOS build. All seven routes, same design tokens,
same `MockData` copy and numbers, same phase machine and scripted coach — no
build step, no dependencies, no backend.

```bash
open web/index.html
```

Redeploy after a change — three static files, nothing to build:

```bash
cd backend/worker && npx wrangler pages deploy ../../web --project-name=fitness-coach-demo --branch=main
```

On a desktop it renders inside a phone frame; below 460 px it goes full-bleed.
Routes are mirrored onto the hash, so
`fitness-coach-demo.pages.dev/#/workout/strength` deep-links the same way the
app's `-route` flag does. Clearing site data replays the welcome flow.

The port is deliberate about what it does *not* do: it never calls the Worker,
so nothing here needs a key. `localStorage` stands in for SwiftData — it holds
the profile (no profile means `/welcome` is the root), the memory chips, and the
finished sessions the plan tab counts, so the streak and totals survive a reload
and stay zero until real work is logged.

Speech is the one thing the web build doesn't attempt: the mic replays the next
scripted turn instead of opening a real recogniser.

## Backend (`backend/`)

The Worker handles text coaching and plan generation; the Node Gateway handles
MiniMax Realtime voice. Keys never ship inside the app binary. Training records
stay local in SwiftData, while the exercise catalogue and generated plans live
in D1.

```bash
cd backend
cp .env.example .env
docker compose up
```

For a local Worker-only loop, use `cd backend/worker && npm install && npx
wrangler dev`. The full service layout, local app configuration and production
operational instructions are in [`backend/README.md`](backend/README.md).

The development/production configuration needs `DEEPSEEK_API_KEY`,
`MINIMAX_API_KEY`, `KIMI_API_KEY`, `VANCE_WORKER_SECRET`,
`VANCE_GATEWAY_SECRET`, and `DEEPSEEK_PROXY_SECRET`; copy only the relevant
two public-path secrets into the untracked iOS `Secrets.xcconfig` as described
in the backend guide.

| Route | Auth | Purpose |
| --- | --- | --- |
| `GET /health` | Bearer | Reports whether the DeepSeek and MiniMax keys are configured (never their values) |
| `POST /coach/turn` | Bearer | Streams a coaching turn as SSE |
| `GET /plan?user=…` | Bearer | Returns that install's active generated plan |
| `POST /plan?user=…` | Bearer | Validates and stores a catalogue-backed plan |
| `POST /speech` | Bearer | Voices the coach's final text with MiniMax T2A |

`/coach/turn` request body: `{ style, state, memories, messages }`. It streams
back `text` (token deltas), `action` (tool calls the app applies to local
state), `plan` / `plan_error`, `refusal`, `done`, and `error` events.

The app executes `adjust_weight`, `swap_exercise`, and `remember` locally.
`generate_plan` runs on the Worker because both validation and the catalogue
live there; accepted plans are cached by the app for offline launches.

## Realtime Gateway (`backend/gateway/`)

The workout screen opens an authenticated WebSocket through this small Node
Gateway. It owns the Vance prompt and provider credentials, reassembles RFC 6455
continuation frames, and then proxies MiniMax text/audio events. The old
standalone waveform route is intentionally gone: status, transcript, typed
context and push-to-talk all live in the strength/cardio coaching screen. The
Gateway refuses to start without `VANCE_GATEWAY_SHARED_SECRET`; its value is
configured separately from `COACH_SHARED_SECRET` as `REALTIME_GATEWAY_SECRET`
in the app.

```bash
cd backend/gateway
cp .env.example .env
npm test
BIND_HOST=127.0.0.1 PORT=8787 npm start
```

Debug builds bundle three Mandarin speech fixtures. The `背` / `累` / `弃`
buttons decode them to 24 kHz PCM16 and pace them through the same authenticated
WebSocket, commit and MiniMax response path as microphone audio. They are a
repeatable live integration harness, not scripted coach replies.

For signing, bundle-ID, and physical-network boundaries, see
[`docs/ios-signing-and-device-testing.md`](docs/ios-signing-and-device-testing.md).

## Mascot artwork

`Mascot(pose:size:)` loads `mascot-<pose>` from `Resources/Assets.xcassets` and
falls back to a shape-drawn stand-in when an image set is empty. The ten real
PNG poses now live in the matching image sets and are used throughout the app:

| Pose sheet | Image set | Used in |
| --- | --- | --- |
| 01 idle standing | `mascot-idle` | — |
| 02 waving hello | `mascot-wave` | — |
| 03 pointing forward | `mascot-point` | AI 记忆更新卡 |
| 04 thumbs up | `mascot-thumbs-up` | 有氧完成 |
| 05 drinking water | `mascot-drink` | 组间休息 |
| 06 light jogging | `mascot-jogging` | 有氧陪练卡 |
| 07 warm-up stretch | `mascot-stretch` | — |
| 08 holding dumbbell | `mascot-dumbbell` | 力量陪练卡 |
| 09 listening / coach | `mascot-listening` | 对话头像 |
| 10 celebration | `mascot-celebration` | 复盘标题 |

Unused poses are wired up and ready for the remaining ~15 screens.

## Exercise library

`/exercises` contains 50 structured movement definitions. Each entry includes
its Chinese and English name, level, target muscles, equipment, default volume,
three coaching cues, contraindicated body conditions and a mascot pose.

Safety filtering runs before search and UI filtering. A saved knee, lower-back,
shoulder or wrist condition therefore removes conflicting movements from the
available source rather than merely hiding a warning on their cards. Venue
support is applied in the same pass, so home and outdoor users do not see
gym-only machines.

These rules are conservative product guardrails, not a diagnosis or a clinical
exercise prescription. The full movement-to-condition matrix should be
reviewed by a qualified trainer or physical therapist before release.

Each exercise also reserves an `exercise-<id>` animation asset name. Until a
biomechanically reviewed Lottie or Rive animation exists, the app shows the
honest still mascot fallback instead of treating decorative motion as form
instruction.

## Structure

- `Models/` — `Types.swift` (domain types), `Profile.swift` (welcome answers →
  memories), `TrainingStats.swift` (streak / week / totals, derived from
  storage), `MockData.swift` (all copy & numbers)
- `State/` — `WorkoutSession` (phase machine, sets, timers, memory outcomes),
  `CoachThread` (one conversation; strength and cardio each own one)
- `DesignSystem/Theme.swift` — colors, metrics, type, card modifier
- `Components/` — shared UI, no screen-specific logic
- `Screens/` — one file per route
- `web/` — the browser port of the same module (`index.html`, `styles.css`, `app.js`)

Copy and numbers live in `MockData`, so changing the plan never means touching a
view.

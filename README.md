# AI 健身教练 — 陪练模块

SwiftUI iOS app. One complete module of the product, not the whole app:

```
/plans → /plans/leg-day → /workout/strength → /workout/cardio → /workout/review
```

Mock data only, no backend.

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

## Mascot artwork

`Mascot(pose:size:)` loads `mascot-<pose>` from `Resources/Assets.xcassets` and
falls back to a shape-drawn stand-in when the image set is empty — which is the
current state. To ship the real IP, drop the exported PNGs (or PDFs) into the
matching image sets; no code changes needed:

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

## Structure

- `Models/` — `Types.swift` (domain types), `MockData.swift` (all copy & numbers)
- `State/` — `WorkoutSession` (phase machine, sets, timers, memory outcomes),
  `CoachThread` (one conversation; strength and cardio each own one)
- `DesignSystem/Theme.swift` — colors, metrics, type, card modifier
- `Components/` — shared UI, no screen-specific logic
- `Screens/` — one file per route

Copy and numbers live in `MockData`, so changing the plan never means touching a
view.

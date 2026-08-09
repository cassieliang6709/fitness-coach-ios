# Cassie Product Build Workflow

> Purpose: turn an early product idea into verified code without losing the
> original product identity, inventing UI too early, or delegating away the
> decisions that need one owner.

## 1. Start with the outcome

Before touching code, write down:

- Product surface: app, web, extension, landing page, or backend.
- User outcome: the concrete thing the user can do after the change.
- Existing identity to preserve: name, mascot, colors, typography, tone,
  navigation, assets, and interaction patterns.
- Scope boundary: what is intentionally not part of this iteration.
- Verification: the build, test, browser, simulator, or device evidence that
  will count as done.

If the target or outcome is unclear, ask one focused question. Do not start
building from a mood alone.

## 2. Inspect before designing

Read the actual repository and find:

- current routes and state flow;
- design tokens and shared components;
- product copy and domain models;
- existing image and motion assets;
- persistence and API boundaries;
- dirty worktree state and the active Git root.

Reuse existing product primitives before adding new ones. Record contradictions
between the brief and the shipped product rather than silently choosing one.

## 3. Lock content before UI when content drives the product

Use this gate for courses, onboarding, interview practice, guided workflows,
questionnaires, and AI conversations.

Write the content manuscript first:

- learning or task objective;
- exact user-facing copy;
- decisions and answer choices;
- branch-specific feedback;
- completion evidence;
- safety and refusal boundaries;
- progress and resume behavior.

Do not generate UI until the content has enough structure to populate real
screens. UI should reveal the product logic, not hide missing logic.

## 4. Decide whether image generation is needed

### Generate visual directions first when

- the feature introduces a new screen or interaction model;
- no selected screenshot, Figma frame, or existing screen establishes the
  hierarchy;
- visual identity is part of the product decision;
- two plausible layouts would create meaningfully different experiences.

Generate exactly three independent directions. Vary hierarchy and interaction
before varying brand style. Show them and wait for selection.

### Skip visual ideation when

- the request is a small edit inside an established component;
- an exact visual target has already been selected;
- the change is backend-only or invisible;
- the existing design system has one obvious pattern for the task.

### Generate individual assets during implementation when

- the selected design contains a required illustration, photo, texture, or
  custom raster asset that the repository does not already have.

Do not generate standard icons when the platform icon library has the right
symbol. Do not fake illustrations with code-drawn placeholders.

## 5. Use subagents only for bounded, independent work

The main agent always owns:

- product interpretation and scope;
- final content and safety decisions;
- architecture and file boundaries;
- integration;
- final verification and handoff.

Good subagent tasks:

- independently audit a finished diff;
- check a bounded set of facts or current documentation;
- generate one isolated raster asset with an exact brief and output path;
- run a non-mutating test matrix;
- review accessibility or copy consistency without editing overlapping files.

Do not use subagents when:

- the product direction is still moving;
- two tasks would edit the same files;
- the task is small enough that coordination costs more than the work;
- the subagent would need to infer product strategy;
- the requested model is unavailable and silently substituting would violate
  the user's delegation preference.

Before delegation, define one deliverable, one file or evidence boundary, and a
clear stop condition. The main agent must inspect the result before using it.

## 6. Build the smallest complete vertical slice

Implement in this order:

1. Domain model and realistic data.
2. Navigation entry and state ownership.
3. Primary screen hierarchy.
4. Main interaction from start to completion.
5. Persistence or resume behavior.
6. Empty, blocked, safety, and completion states.
7. Supporting polish and animation.

Prefer one real end-to-end path over many static screens. Reuse the existing
runtime, components, and assets. Avoid speculative frameworks.

## 7. Verify in layers

### Code gate

- formatter/linter for changed files;
- compilation;
- targeted tests for state transitions and persistence;
- diff check and secrets scan.

### Product gate

- primary task works from entry to completion;
- copy matches the approved manuscript;
- state survives navigation or relaunch where promised;
- existing adjacent flows still work.

### Visual gate

- capture the same viewport and state as the selected target;
- inspect the saved screenshot;
- compare target and implementation together;
- fix layout, spacing, typography, asset, and interaction mismatches;
- record the result in design-qa.md.

A build or HTTP 200 is not visual verification.

## 8. Commit and hand off truthfully

Before committing:

- separate unrelated work into logical commits;
- leave user-owned unrelated changes untouched;
- report any checks blocked by dependencies, login, device state, or network;
- do not call a prototype shipped, published, or device-tested without that
  evidence.

Handoff should contain:

- outcome;
- important files;
- verification performed;
- known limits;
- at most three useful next actions.

## Applied decision for Vance Lab

- Content manuscript comes before implementation.
- The selected visual target is the combined science-notebook and Build a
  Human direction.
- No subagent owns product or course decisions.
- Vance's existing mascot, orange palette, cards, exercise catalogue, coaching
  voice, plan engine, and local persistence are reused.
- The first slice includes a seven-day course, interactive lesson steps,
  progress persistence, and a Final Lab plan builder.
- The existing training and chat flows remain intact.

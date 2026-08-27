-- Source of truth for both the iOS app and the web client.
-- Everything the coach needs to know about a user lives here; the clients hold
-- caches, not originals.

-- One row per person. `id` is supplied by the client (a device-scoped UUID for
-- now) so there's no account system to build yet.
CREATE TABLE IF NOT EXISTS users (
    id          TEXT PRIMARY KEY,
    goal        TEXT,
    venue       TEXT,
    ai_style    TEXT NOT NULL DEFAULT 'practical',
    weekly_target INTEGER NOT NULL DEFAULT 4,
    created_at  TEXT NOT NULL,
    updated_at  TEXT NOT NULL
);

-- What the coach remembers: injuries, venue, equipment, preferences.
-- `category = 'equipment'` is what gym-photo recognition writes into.
CREATE TABLE IF NOT EXISTS memories (
    id          TEXT PRIMARY KEY,
    user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category    TEXT NOT NULL CHECK (category IN ('injury','preference','venue','equipment')),
    text        TEXT NOT NULL,
    active      INTEGER NOT NULL DEFAULT 1,
    source      TEXT,                    -- 'onboarding' | 'coach' | 'vision'
    created_at  TEXT NOT NULL,
    updated_at  TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS memories_by_user ON memories(user_id, active);

-- The movement catalogue. Read-only reference data, seeded from the public
-- dataset. The coach may only compose plans out of these ids.
CREATE TABLE IF NOT EXISTS exercises (
    id          TEXT PRIMARY KEY,
    name        TEXT NOT NULL,
    name_zh     TEXT,                    -- filled in by a translation pass
    body_part   TEXT NOT NULL,
    equipment   TEXT NOT NULL,
    target      TEXT NOT NULL,
    secondary   TEXT,                    -- JSON array
    steps_zh    TEXT                     -- JSON array
);
CREATE INDEX IF NOT EXISTS exercises_by_equipment ON exercises(equipment);
CREATE INDEX IF NOT EXISTS exercises_by_body_part ON exercises(body_part);

-- A plan the coach generated. `title` and the section split are the coach's;
-- every movement inside is a reference to `exercises`.
CREATE TABLE IF NOT EXISTS plans (
    id          TEXT PRIMARY KEY,
    user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title       TEXT NOT NULL,
    summary     TEXT,
    created_at  TEXT NOT NULL,
    -- Set when the coach replaces it, so history stays inspectable.
    archived_at TEXT
);
CREATE INDEX IF NOT EXISTS plans_by_user ON plans(user_id, archived_at);

CREATE TABLE IF NOT EXISTS plan_items (
    id           TEXT PRIMARY KEY,
    plan_id      TEXT NOT NULL REFERENCES plans(id) ON DELETE CASCADE,
    exercise_id  TEXT NOT NULL REFERENCES exercises(id),
    section      TEXT NOT NULL CHECK (section IN ('warmup','strength','cardio')),
    position     INTEGER NOT NULL,
    sets         INTEGER NOT NULL,
    reps         TEXT NOT NULL,
    weight_kg    REAL,
    side_based   INTEGER NOT NULL DEFAULT 0,
    note         TEXT
);
CREATE INDEX IF NOT EXISTS plan_items_by_plan ON plan_items(plan_id, section, position);

-- One training session, and the sets actually completed in it.
CREATE TABLE IF NOT EXISTS sessions (
    id                TEXT PRIMARY KEY,
    user_id           TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    plan_id           TEXT REFERENCES plans(id),
    started_at        TEXT NOT NULL,
    ended_at          TEXT,
    planned_set_count INTEGER NOT NULL DEFAULT 0,
    adjustment_count  INTEGER NOT NULL DEFAULT 0,
    cardio_seconds    INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS sessions_by_user ON sessions(user_id, started_at DESC);

CREATE TABLE IF NOT EXISTS set_logs (
    id           TEXT PRIMARY KEY,
    session_id   TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    exercise_id  TEXT NOT NULL,
    set_number   INTEGER NOT NULL,
    reps         TEXT,
    weight_kg    REAL,
    completed_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS set_logs_by_session ON set_logs(session_id);

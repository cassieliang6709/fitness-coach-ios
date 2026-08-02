/**
 * Plan generation.
 *
 * The coach never invents movements. It gets a shortlist of real rows from the
 * `exercises` table, and every id it returns is checked against that table
 * before a plan is written — an unknown id is rejected, not silently rendered.
 */

export interface Env {
    DB: D1Database;
}

export interface ExerciseRow {
    id: string;
    name: string;
    name_zh: string | null;
    body_part: string;
    equipment: string;
    target: string;
}

/** Chinese gym vocabulary → the dataset's English `equipment` values. */
const EQUIPMENT_ALIASES: Record<string, string> = {
    哑铃: "dumbbell",
    杠铃: "barbell",
    绳索: "cable",
    拉力器: "cable",
    龙门架: "cable",
    史密斯机: "smith machine",
    壶铃: "kettlebell",
    弹力带: "band",
    阻力带: "band",
    健身球: "stability ball",
    药球: "medicine ball",
    椭圆机: "elliptical machine",
    动感单车: "stationary bike",
    健身车: "stationary bike",
    跑步机: "body weight",
    器械: "leverage machine",
    固定器械: "leverage machine",
    自重: "body weight",
    徒手: "body weight",
};

/**
 * What the gym actually has. Derived from `equipment` memories; an empty list
 * means we only know bodyweight is possible, which is the safe assumption.
 */
export function equipmentFromMemories(memories: string[]): string[] {
    const found = new Set<string>(["body weight"]);
    for (const memory of memories) {
        for (const [zh, en] of Object.entries(EQUIPMENT_ALIASES)) {
            if (memory.includes(zh)) found.add(en);
        }
    }
    return [...found];
}

/**
 * Candidate movements for the model to choose from. Capped hard — a thousand
 * rows in the prompt would cost more than the reply and bury the good ones.
 */
export async function shortlist(
    env: Env,
    options: { equipment: string[]; bodyParts: string[]; perBucket?: number }
): Promise<ExerciseRow[]> {
    const perBucket = options.perBucket ?? 8;
    const equipment = options.equipment.length ? options.equipment : ["body weight"];
    const bodyParts = options.bodyParts.length
        ? options.bodyParts
        : ["upper legs", "chest", "back", "waist"];

    const rows: ExerciseRow[] = [];
    for (const part of bodyParts) {
        const placeholders = equipment.map(() => "?").join(",");
        const statement = env.DB.prepare(
            `SELECT id, name, name_zh, body_part, equipment, target
             FROM exercises
             WHERE body_part = ? AND equipment IN (${placeholders})
             ORDER BY id
             LIMIT ?`
        ).bind(part, ...equipment, perBucket);
        const result = await statement.all<ExerciseRow>();
        rows.push(...(result.results ?? []));
    }
    return rows;
}

/** Compact form for the prompt — one line per movement, ids first. */
export function renderShortlist(rows: ExerciseRow[]): string {
    return rows
        .map((r) => `${r.id} | ${r.name_zh ?? r.name} | ${r.body_part} | ${r.equipment}`)
        .join("\n");
}

// MARK: - Validation

export interface PlanItemInput {
    exercise_id: string;
    section: "warmup" | "strength" | "cardio";
    sets: number;
    reps: string;
    weight_kg?: number;
    note?: string;
}

export interface PlanInput {
    title: string;
    summary?: string;
    items: PlanItemInput[];
}

export interface ValidatedPlan extends PlanInput {
    items: (PlanItemInput & { name: string })[];
}

/**
 * Rejects the whole plan if any id is unknown. Partial acceptance would render
 * a plan with a hole in it, which is worse than a clear failure the coach can
 * retry from.
 */
export async function validatePlan(
    env: Env,
    plan: PlanInput
): Promise<{ ok: true; plan: ValidatedPlan } | { ok: false; reason: string }> {
    if (!plan?.title?.trim()) return { ok: false, reason: "计划缺少标题" };
    if (!Array.isArray(plan.items) || plan.items.length === 0) {
        return { ok: false, reason: "计划里没有动作" };
    }
    if (plan.items.length > 20) return { ok: false, reason: "动作太多，最多 20 个" };

    const ids = [...new Set(plan.items.map((i) => i.exercise_id))];
    const placeholders = ids.map(() => "?").join(",");
    const found = await env.DB.prepare(
        `SELECT id, name, name_zh FROM exercises WHERE id IN (${placeholders})`
    )
        .bind(...ids)
        .all<{ id: string; name: string; name_zh: string | null }>();

    const byID = new Map((found.results ?? []).map((r) => [r.id, r.name_zh ?? r.name]));
    const unknown = ids.filter((id) => !byID.has(id));
    if (unknown.length) {
        return { ok: false, reason: `这些动作 id 不在动作库里：${unknown.join(", ")}` };
    }

    for (const item of plan.items) {
        if (!Number.isFinite(item.sets) || item.sets < 1 || item.sets > 10) {
            return { ok: false, reason: `${byID.get(item.exercise_id)} 的组数不合理` };
        }
    }

    return {
        ok: true,
        plan: {
            ...plan,
            items: plan.items.map((i) => ({ ...i, name: byID.get(i.exercise_id)! })),
        },
    };
}

// MARK: - Persistence

export async function savePlan(
    env: Env,
    userID: string,
    plan: ValidatedPlan
): Promise<string> {
    const planID = crypto.randomUUID();
    const now = new Date().toISOString();

    const statements = [
        // One active plan at a time; the previous one stays for history.
        env.DB.prepare(
            `UPDATE plans SET archived_at = ? WHERE user_id = ? AND archived_at IS NULL`
        ).bind(now, userID),
        env.DB.prepare(
            `INSERT INTO plans (id, user_id, title, summary, created_at) VALUES (?, ?, ?, ?, ?)`
        ).bind(planID, userID, plan.title, plan.summary ?? null, now),
        ...plan.items.map((item, index) =>
            env.DB.prepare(
                `INSERT INTO plan_items
                 (id, plan_id, exercise_id, section, position, sets, reps, weight_kg, note)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`
            ).bind(
                crypto.randomUUID(),
                planID,
                item.exercise_id,
                item.section,
                index,
                item.sets,
                item.reps,
                item.weight_kg ?? null,
                item.note ?? null
            )
        ),
    ];

    await env.DB.batch(statements);
    return planID;
}

/** The active plan, shaped the way both clients render it. */
export async function activePlan(env: Env, userID: string) {
    const plan = await env.DB.prepare(
        `SELECT id, title, summary, created_at FROM plans
         WHERE user_id = ? AND archived_at IS NULL
         ORDER BY created_at DESC LIMIT 1`
    )
        .bind(userID)
        .first<{ id: string; title: string; summary: string | null; created_at: string }>();

    if (!plan) return null;

    const items = await env.DB.prepare(
        `SELECT pi.section, pi.position, pi.sets, pi.reps, pi.weight_kg, pi.note,
                e.id AS exercise_id, e.name, e.name_zh, e.body_part, e.equipment, e.steps_zh
         FROM plan_items pi
         JOIN exercises e ON e.id = pi.exercise_id
         WHERE pi.plan_id = ?
         -- Alphabetical would put cardio first; training order is fixed.
         ORDER BY CASE pi.section
                    WHEN 'warmup' THEN 0 WHEN 'strength' THEN 1 ELSE 2
                  END, pi.position`
    )
        .bind(plan.id)
        .all();

    return {
        id: plan.id,
        title: plan.title,
        summary: plan.summary,
        createdAt: plan.created_at,
        items: (items.results ?? []).map((row) => {
            const r = row as Record<string, unknown>;
            return {
                exerciseID: r.exercise_id as string,
                name: (r.name_zh as string) ?? (r.name as string),
                section: r.section as string,
                sets: r.sets as number,
                reps: r.reps as string,
                weightKg: r.weight_kg as number | null,
                bodyPart: r.body_part as string,
                equipment: r.equipment as string,
                note: r.note as string | null,
                steps: safeParse(r.steps_zh as string | null),
            };
        }),
    };
}

function safeParse(value: string | null): string[] {
    if (!value) return [];
    try {
        const parsed = JSON.parse(value);
        return Array.isArray(parsed) ? parsed : [];
    } catch {
        return [];
    }
}

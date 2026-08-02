/**
 * Fitness coach API — Cloudflare Worker.
 *
 * Exists so the Anthropic key never ships inside the iOS app. Anything in an
 * App Store binary can be extracted; a Worker secret cannot.
 *
 * Step 1 (this file): auth + health check only. Deploy it, confirm both
 * secrets are wired, then the Claude endpoint gets added on top.
 */

import { streamCoachTurn, type AIStyle, type CoachRequest } from "./coach";
import { openRealtime } from "./realtime";
import { synthesizeSpeech } from "./speech";
import { recognizeEquipment, validateImage } from "./vision";
import {
    activePlan,
    equipmentFromMemories,
    exerciseCatalogPage,
    savePlan,
    shortlist,
    validatePlan,
    type PlanInput,
} from "./plan";

export interface Env {
    /** D1: the shared source of truth for both clients. */
    DB: D1Database;
    /** Shared secret the iOS app sends. Set via: wrangler secret put APP_SHARED_SECRET */
    APP_SHARED_SECRET: string;
    /** Kimi key — coaching turns and vision. Set via: wrangler secret put KIMI_API_KEY */
    KIMI_API_KEY: string;
    /** MiniMax speech key. Set via: wrangler secret put MINIMAX_API_KEY */
    MINIMAX_API_KEY: string;
}

function json(data: unknown, status = 200): Response {
    return new Response(JSON.stringify(data), {
        status,
        headers: { "content-type": "application/json; charset=utf-8" },
    });
}

/**
 * Length-independent comparison. A plain `===` short-circuits on the first
 * differing byte, which leaks the secret one character at a time to anyone
 * measuring response times.
 */
function secretsMatch(candidate: string, expected: string): boolean {
    if (candidate.length !== expected.length) return false;
    let diff = 0;
    for (let i = 0; i < candidate.length; i++) {
        diff |= candidate.charCodeAt(i) ^ expected.charCodeAt(i);
    }
    return diff === 0;
}

/**
 * Without this, the Worker is a free public Claude proxy — it will get found
 * by scanners and run up the bill.
 */
function isAuthorized(request: Request, env: Env): boolean {
    if (!env.APP_SHARED_SECRET) return false;
    const header = request.headers.get("authorization") ?? "";
    if (!header.startsWith("Bearer ")) return false;
    return secretsMatch(header.slice(7), env.APP_SHARED_SECRET);
}

const STYLES: AIStyle[] = ["gentle", "encouraging", "practical"];

/** Rows are keyed by a client-supplied id; no account system yet. */
async function ensureUser(env: Env, userID: string): Promise<void> {
    const now = new Date().toISOString();
    await env.DB.prepare(
        `INSERT INTO users (id, created_at, updated_at) VALUES (?, ?, ?)
         ON CONFLICT(id) DO NOTHING`
    )
        .bind(userID, now, now)
        .run();
}

function normalizeEquipment(value: unknown): string[] | null {
    if (!Array.isArray(value) || value.length > 16) return null;
    const names = value.map((item) =>
        typeof item === "string" ? item.replace(/\s+/g, " ").trim().slice(0, 160) : ""
    );
    if (names.some((name) => !name)) return null;
    return [...new Set(names)];
}

async function saveEquipmentMemories(env: Env, userID: string, names: string[]): Promise<void> {
    if (!names.length) return;
    await ensureUser(env, userID);
    const now = new Date().toISOString();
    await env.DB.batch(
        names.map((name) =>
            env.DB.prepare(
                `INSERT INTO memories (id, user_id, category, text, active, source, created_at, updated_at)
                 VALUES (?, ?, 'equipment', ?, 1, 'vision', ?, ?)
                 ON CONFLICT(id) DO UPDATE SET text = excluded.text, updated_at = excluded.updated_at, active = 1`
            ).bind(`equip-${userID}-${name}`, userID, name, now, now)
        )
    );
}

/** Cheap shape check so malformed clients get a 400, not an upstream 400. */
function validate(payload: CoachRequest): string | null {
    if (!payload || typeof payload !== "object") return "body must be an object";
    if (!STYLES.includes(payload.style)) return "style must be gentle|encouraging|practical";
    if (!payload.state || typeof payload.state.exercise !== "string") {
        return "state.exercise is required";
    }
    if (!Array.isArray(payload.messages) || payload.messages.length === 0) {
        return "messages must be a non-empty array";
    }
    if (payload.messages.length > 200) return "messages too long";
    if (payload.memories && !Array.isArray(payload.memories)) {
        return "memories must be an array";
    }
    if (payload.history && !Array.isArray(payload.history)) {
        return "history must be an array";
    }
    if (payload.history && payload.history.length > 10) return "history too long";
    return null;
}

export default {
    async fetch(request: Request, env: Env): Promise<Response> {
        const url = new URL(request.url);

        if (url.pathname === "/health") {
            if (!isAuthorized(request, env)) {
                return json({ error: "unauthorized" }, 401);
            }
            return json({
                ok: true,
                // Presence only. The key itself is never returned, logged, or echoed.
                kimiKeyConfigured: Boolean(env.KIMI_API_KEY),
                minimaxKeyConfigured: Boolean(env.MINIMAX_API_KEY),
                time: new Date().toISOString(),
            });
        }

        if (url.pathname === "/coach/turn") {
            if (request.method !== "POST") {
                return json({ error: "method_not_allowed" }, 405);
            }
            if (!isAuthorized(request, env)) {
                return json({ error: "unauthorized" }, 401);
            }

            let payload: CoachRequest;
            try {
                payload = (await request.json()) as CoachRequest;
            } catch {
                return json({ error: "invalid_json" }, 400);
            }

            const invalid = validate(payload);
            if (invalid) return json({ error: "invalid_request", detail: invalid }, 400);

            const userID = url.searchParams.get("user") ?? "demo";
            await ensureUser(env, userID);

            // Give the model real movements to pick from, filtered by what the
            // gym actually has according to the user's equipment memories.
            payload.shortlist = await shortlist(env, {
                equipment: equipmentFromMemories(payload.memories ?? []),
                bodyParts: ["upper legs", "chest", "back", "shoulders", "waist", "cardio"],
                perBucket: 6,
            });

            return streamCoachTurn(payload, env.KIMI_API_KEY, {
                onPlan: async (plan) => {
                    const checked = await validatePlan(env, plan);
                    if (!checked.ok) return { ok: false, reason: checked.reason };
                    await savePlan(env, userID, checked.plan);
                    return { ok: true, plan: checked.plan };
                },
            });
        }

        // The text coach has already decided what to say. MiniMax only voices
        // that exact final reply; it does not run a second conversational turn.
        if (url.pathname === "/speech") {
            if (request.method !== "POST") {
                return json({ error: "method_not_allowed" }, 405);
            }
            if (!isAuthorized(request, env)) {
                return json({ error: "unauthorized" }, 401);
            }
            if (!env.MINIMAX_API_KEY) return json({ error: "voice_not_configured" }, 503);

            let body: { text?: string };
            try {
                body = (await request.json()) as typeof body;
            } catch {
                return json({ error: "invalid_json" }, 400);
            }

            const text = body.text?.trim() ?? "";
            if (!text || text.length >= 10_000) {
                return json({ error: "invalid_text" }, 400);
            }

            try {
                const audio = await synthesizeSpeech(text, env.MINIMAX_API_KEY);
                return new Response(audio, {
                    headers: {
                        "content-type": "audio/mpeg",
                        "cache-control": "no-store",
                    },
                });
            } catch (error) {
                // Do not echo the upstream body: it may contain provider or
                // account details. The trace belongs in Worker logs only.
                console.error(
                    "speech synthesis failed",
                    error instanceof Error ? error.message : "unknown"
                );
                return json({ error: "voice_upstream_failed" }, 502);
            }
        }

        // Realtime voice. The device upgrades to a WebSocket here; the key is
        // attached on the upstream leg only.
        if (url.pathname === "/realtime") {
            if (!isAuthorized(request, env)) return json({ error: "unauthorized" }, 401);
            if (!env.MINIMAX_API_KEY) return json({ error: "voice_not_configured" }, 503);

            const userID = url.searchParams.get("user") ?? "demo";
            await ensureUser(env, userID);
            const memories = await env.DB.prepare(
                `SELECT text FROM memories WHERE user_id = ? AND active = 1 ORDER BY created_at`
            )
                .bind(userID)
                .all<{ text: string }>();

            return openRealtime(
                request,
                env,
                userID,
                (memories.results ?? []).map((r) => r.text)
            );
        }

        // Gym photo → equipment. Confirmed items are written straight to
        // memories, which is what the plan shortlist filters on.
        if (url.pathname === "/vision/equipment") {
            if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);
            if (!isAuthorized(request, env)) return json({ error: "unauthorized" }, 401);

            let body: { imageData?: string; goal?: string; save?: boolean };
            try {
                body = (await request.json()) as typeof body;
            } catch {
                return json({ error: "invalid_json" }, 400);
            }

            // Validate the request before the server's own config — a client with a
            // bad image should hear about the image, not about our secrets.
            const check = validateImage(body.imageData);
            if (!check.ok) return json({ error: "invalid_image", detail: check.reason }, 400);
            if (!env.KIMI_API_KEY) return json({ error: "vision_not_configured" }, 503);

            let result;
            try {
                result = await recognizeEquipment(body.imageData!, env.KIMI_API_KEY, body.goal ?? "");
            } catch (error) {
                const reason = error instanceof Error ? error.message : "kimi_unavailable";
                return json({ error: reason }, reason === "kimi_rate_limited" ? 429 : 502);
            }

            // Only the confirmed ones become memories, and only when asked —
            // the client may want the user to review first.
            const userID = url.searchParams.get("user");
            if (userID && body.save !== false && result.equipment.length) {
                await saveEquipmentMemories(
                    env,
                    userID,
                    result.equipment.map((item) => item.name)
                );
            }

            return json(result);
        }

        // The photo is analysed with save=false first. After the user reviews
        // ambiguous sightings, the app commits exactly the accepted names here.
        if (url.pathname === "/vision/equipment/confirm") {
            if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);
            if (!isAuthorized(request, env)) return json({ error: "unauthorized" }, 401);
            const userID = url.searchParams.get("user");
            if (!userID) return json({ error: "missing_user" }, 400);

            let body: { equipment?: unknown };
            try {
                body = (await request.json()) as typeof body;
            } catch {
                return json({ error: "invalid_json" }, 400);
            }
            const equipment = normalizeEquipment(body.equipment);
            if (!equipment) return json({ error: "invalid_equipment" }, 400);

            await saveEquipmentMemories(env, userID, equipment);
            return json({ saved: equipment.length });
        }

        if (url.pathname === "/exercises") {
            if (request.method !== "GET") return json({ error: "method_not_allowed" }, 405);
            if (!isAuthorized(request, env)) return json({ error: "unauthorized" }, 401);

            const rawLimit = url.searchParams.get("limit") ?? "500";
            const rawOffset = url.searchParams.get("offset") ?? "0";
            if (!/^\d+$/.test(rawLimit) || !/^\d+$/.test(rawOffset)) {
                return json({ error: "invalid_pagination" }, 400);
            }
            const limit = Number(rawLimit);
            const offset = Number(rawOffset);
            if (limit < 1 || limit > 500 || offset < 0 || offset > 100_000) {
                return json({ error: "invalid_pagination" }, 400);
            }

            return json(await exerciseCatalogPage(env, limit, offset));
        }

        // The catalogue-backed plan endpoints. All of them need a user id so
        // two clients can look at the same person's data.
        if (url.pathname === "/plan") {
            if (!isAuthorized(request, env)) return json({ error: "unauthorized" }, 401);
            const userID = url.searchParams.get("user");
            if (!userID) return json({ error: "missing_user" }, 400);

            if (request.method === "GET") {
                return json({ plan: await activePlan(env, userID) });
            }

            if (request.method === "POST") {
                // Direct save — used by clients that generated a plan elsewhere.
                let body: { plan?: PlanInput };
                try {
                    body = (await request.json()) as { plan?: PlanInput };
                } catch {
                    return json({ error: "invalid_json" }, 400);
                }
                if (!body.plan) return json({ error: "missing_plan" }, 400);

                const checked = await validatePlan(env, body.plan);
                if (!checked.ok) return json({ error: "invalid_plan", detail: checked.reason }, 400);

                await ensureUser(env, userID);
                const id = await savePlan(env, userID, checked.plan);
                return json({ id, plan: await activePlan(env, userID) });
            }

            return json({ error: "method_not_allowed" }, 405);
        }

        return json({ error: "not_found" }, 404);
    },
};

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

export interface Env {
    /** Anthropic API key. Set via: wrangler secret put ANTHROPIC_API_KEY */
    ANTHROPIC_API_KEY: string;
    /** Shared secret the iOS app sends. Set via: wrangler secret put APP_SHARED_SECRET */
    APP_SHARED_SECRET: string;
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
                anthropicKeyConfigured: Boolean(env.ANTHROPIC_API_KEY),
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

            return streamCoachTurn(payload, env.ANTHROPIC_API_KEY);
        }

        return json({ error: "not_found" }, 404);
    },
};

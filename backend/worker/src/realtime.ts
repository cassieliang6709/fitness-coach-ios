/**
 * MiniMax realtime voice, proxied.
 *
 * The client never talks to MiniMax directly — it opens a WebSocket to this
 * Worker, which opens its own upstream connection and adds the API key there.
 * A key in an App Store binary can be extracted; a Worker secret cannot.
 *
 * MiniMax speaks the OpenAI Realtime event vocabulary, so the shapes below
 * (`session.update`, `input_audio_buffer.append`, `response.audio.delta`, …)
 * are that protocol rather than anything MiniMax-specific.
 *
 * `generate_plan` is executed here rather than on the device: the catalogue
 * and the database both live on this side, and a plan must be validated
 * against real exercise ids before anyone sees it.
 */

import { activePlan, equipmentFromMemories, savePlan, shortlist, validatePlan } from "./plan";
import type { Env as PlanEnv, PlanInput } from "./plan";

// A Worker opens an outbound WebSocket with an HTTPS fetch plus Upgrade.
// `wss://` is valid for a WebSocket client URL, but not for the Fetch API and
// throws before Cloudflare can return a controlled gateway error.
const UPSTREAM = "https://api.minimax.chat/ws/v1/realtime?model=abab6.5s-chat";

export interface RealtimeEnv extends PlanEnv {
    MINIMAX_API_KEY: string;
}

const COACH_INSTRUCTIONS = `你是一个健身陪练 Agent，正在和用户语音对话。

说话规则：
- 这是语音，不是文字。每次只说一到两句话，说人话，不要念稿。
- 不要用 Markdown、列表、编号。
- 直接说下一步做什么，不要复述用户刚说的话。
- 不要提心率、卡路里、补水这些和当前动作无关的东西。

安全规则：
- 用户报告疼痛或不适时，先降负荷或换动作，再继续。
- 涉及疼痛、受伤、用药、疾病时，说明你不是医疗人员，建议就医，不要诊断。
- 记忆里的伤病信息优先于计划。

计划规则：
- 用户问今天练什么、要计划、想换计划时，立刻调用 generate_plan。
  不要先反问"练多久"——先给一版完整的，用户不满意会说要改。
- exercise_id 只能从工具描述里那份清单里复制，绝不自己编动作。`;

/** Tool schema in the realtime API's function-calling shape. */
function planFunction(catalogue: string) {
    return {
        type: "function",
        name: "generate_plan",
        description:
            `根据用户的目标、器械和伤病编排训练计划。exercise_id 必须来自下面这份清单，` +
            `一个字都不能改、不能自己发明动作。\n\n可用动作（id | 名称 | 部位 | 器械）：\n${catalogue}`,
        parameters: {
            type: "object",
            properties: {
                title: { type: "string" },
                summary: { type: "string" },
                items: {
                    type: "array",
                    items: {
                        type: "object",
                        properties: {
                            exercise_id: { type: "string" },
                            section: { type: "string", enum: ["warmup", "strength", "cardio"] },
                            sets: { type: "number" },
                            reps: { type: "string" },
                            weight_kg: { type: "number" },
                            note: { type: "string" },
                        },
                        required: ["exercise_id", "section", "sets", "reps"],
                    },
                },
            },
            required: ["title", "items"],
        },
    };
}

export async function openRealtime(
    request: Request,
    env: RealtimeEnv,
    userID: string,
    memories: string[]
): Promise<Response> {
    if (request.headers.get("Upgrade") !== "websocket") {
        return new Response("expected websocket", { status: 426 });
    }

    // Build the catalogue slice before connecting — it goes into session.update.
    const rows = await shortlist(env, {
        equipment: equipmentFromMemories(memories),
        bodyParts: ["upper legs", "chest", "back", "shoulders", "waist", "cardio"],
        perBucket: 6,
    });
    const catalogue = rows
        .map((r) => `${r.id} | ${r.name_zh ?? r.name} | ${r.body_part} | ${r.equipment}`)
        .join("\n");

    let upstreamResponse: Response;
    try {
        upstreamResponse = await fetch(UPSTREAM, {
            headers: {
                Upgrade: "websocket",
                Authorization: `Bearer ${env.MINIMAX_API_KEY}`,
            },
        });
    } catch (error) {
        console.error(
            "minimax realtime connection failed",
            error instanceof Error ? error.message : "unknown"
        );
        return new Response("upstream connection failed", { status: 502 });
    }
    const upstream = upstreamResponse.webSocket;
    if (!upstream) {
        console.error("minimax realtime upgrade refused", upstreamResponse.status);
        return new Response("upstream refused websocket", { status: 502 });
    }
    upstream.accept();

    const pair = new WebSocketPair();
    const client = pair[0];
    const server = pair[1];
    server.accept();

    const send = (socket: WebSocket, payload: unknown) => {
        try {
            socket.send(JSON.stringify(payload));
        } catch {
            /* socket already closing */
        }
    };

    // Configure the session the moment we're connected. The device never sets
    // instructions or tools, so a compromised client can't rewrite the coach.
    send(upstream, {
        type: "session.update",
        session: {
            modalities: ["text", "audio"],
            instructions:
                `${COACH_INSTRUCTIONS}\n\n` +
                (memories.length
                    ? `关于这个用户你已经记住的：\n${memories.map((m) => `- ${m}`).join("\n")}`
                    : "关于这个用户暂无长期记忆。"),
            input_audio_format: "pcm16",
            output_audio_format: "pcm16",
            input_audio_transcription: { model: "asr-01" },
            tools: [planFunction(catalogue)],
            tool_choice: "auto",
        },
    });

    // Device → MiniMax. Audio frames dominate, so this stays a plain relay.
    server.addEventListener("message", (event) => {
        try {
            upstream.send(event.data as string | ArrayBuffer);
        } catch {
            /* upstream gone; the close handler will tear the pair down */
        }
    });

    // MiniMax → device, with generate_plan intercepted on the way through.
    upstream.addEventListener("message", async (event) => {
        const raw = event.data;
        if (typeof raw !== "string") {
            server.send(raw);
            return;
        }

        server.send(raw);

        let parsed: { type?: string; name?: string; call_id?: string; arguments?: string };
        try {
            parsed = JSON.parse(raw);
        } catch {
            return;
        }

        if (
            parsed.type === "response.function_call_arguments.done" &&
            parsed.name === "generate_plan" &&
            parsed.call_id
        ) {
            await handlePlanCall(env, userID, parsed.call_id, parsed.arguments, upstream, server, send);
        }
    });

    const shutdown = (socket: WebSocket) => () => {
        try {
            socket.close();
        } catch {
            /* already closed */
        }
    };
    server.addEventListener("close", shutdown(upstream));
    server.addEventListener("error", shutdown(upstream));
    upstream.addEventListener("close", shutdown(server));
    upstream.addEventListener("error", shutdown(server));

    return new Response(null, { status: 101, webSocket: client });
}

/**
 * Validate, store, tell the model what happened, and let it speak the result.
 * A rejected plan comes back as a normal function output so the coach can
 * explain itself rather than going silent.
 */
async function handlePlanCall(
    env: RealtimeEnv,
    userID: string,
    callID: string,
    rawArguments: string | undefined,
    upstream: WebSocket,
    server: WebSocket,
    send: (socket: WebSocket, payload: unknown) => void
): Promise<void> {
    let output: string;

    try {
        const parsed = JSON.parse(rawArguments ?? "{}") as PlanInput;
        const checked = await validatePlan(env, parsed);
        if (checked.ok) {
            await savePlan(env, userID, checked.plan);
            const stored = await activePlan(env, userID);
            // The device renders the plan card from this, not from the audio.
            send(server, { type: "app.plan", plan: stored });
            output = `已生成并保存计划「${checked.plan.title}」，共 ${checked.plan.items.length} 个动作。`;
        } else {
            output = `计划未通过校验：${checked.reason}。请只用清单里的 exercise_id 重新编排。`;
        }
    } catch {
        output = "计划参数无法解析，请重新调用 generate_plan。";
    }

    send(upstream, {
        type: "conversation.item.create",
        item: {
            type: "function_call_output",
            call_id: callID,
            output,
        },
    });
    send(upstream, { type: "response.create" });
}

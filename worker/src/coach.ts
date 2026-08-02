import { renderShortlist, type ExerciseRow, type PlanInput, type ValidatedPlan } from "./plan";

/**
 * The coach turn: builds the prompt, calls Kimi, streams the reply back as
 * SSE, and surfaces tool calls to the app as `action` events.
 *
 * The app owns conversation state and executes the tools (they mutate local
 * SwiftData), so this Worker stays stateless — it never stores a session.
 *
 * The app sends Anthropic-shaped blocks (`tool_use` / `tool_result`) because
 * that is the history format its own state machine keeps. Converting to the
 * OpenAI shape happens here rather than in the app, so the SSE contract the
 * app consumes — `text` / `action` / `plan` / `plan_error` / `refusal` /
 * `done` — is unchanged by the provider swap.
 */

const ENDPOINT = "https://api.moonshot.cn/v1/chat/completions";

/** Same family as the vision path, which already runs on this key. */
const MODEL = "kimi-k2.6";

export type AIStyle = "gentle" | "encouraging" | "practical";

export interface CoachState {
    /** `planning` is the home tab — the user hasn't started training yet. */
    phase: "planning" | "strength" | "cardio";
    /** The current movement, or the day's plan title while planning. */
    exercise: string;
    /** e.g. "12 kg · 12 次" */
    prescription: string;
    setNumber?: number;
    totalSets?: number;
    venue?: string;
    /** Minutes elapsed / target, cardio only. */
    elapsedMinutes?: number;
    targetMinutes?: number;
}

/** One block of the app's history. Mirrors `WireBlock` in CoachWire.swift. */
export interface WireBlock {
    type: "text" | "tool_use" | "tool_result";
    text?: string;
    id?: string;
    name?: string;
    input?: unknown;
    tool_use_id?: string;
    content?: string;
}

export interface WireMessage {
    role: "user" | "assistant";
    content: WireBlock[];
}

export interface CoachRequest {
    style: AIStyle;
    /** Absent when the user is just chatting rather than mid-set. */
    state?: CoachState;
    memories: string[];
    /** Finished sessions supplied by the app, newest first. */
    history?: string[];
    messages: WireMessage[];
    /** Real rows from the exercise table; the only movements it may use. */
    shortlist?: ExerciseRow[];
}

// MARK: - Prompt

/**
 * Stable across every request, so it goes in the first system message.
 * Anything that changes mid-session (current set, weight, memories) follows in
 * a second one — Kimi caches matching prefixes automatically, so the split is
 * what keeps the persona cacheable.
 */
const BASE_SYSTEM = `你是一个健身陪练 Agent，在用户训练过程中实时指导。

沟通规则：
- 每次只说一到两句话。用户正在训练，没有时间读长段文字。
- 直接说下一步做什么，不要复述用户刚说的话。
- 不要输出心率、卡路里、补水提醒等与当前动作无关的内容。
- 不要用 Markdown 标题、列表或加粗。就是口语。

安全规则：
- 用户报告任何疼痛或不适时，先降低负荷或替换动作，再继续。
- 涉及疼痛、受伤、用药或疾病时，明确说明你不是医疗人员，建议就医。不要诊断，不要给用药建议。
- 记忆里的伤病信息优先于计划。计划要求做的动作如果和伤病冲突，替换它。
- 与训练无关的请求（医疗诊断、心理危机、其他领域的问题），用一句话说明这不在你的范围内，
  建议找对应的专业人士，然后把话题带回训练。不要尝试回答。

计划规则（重要）：
- 用户要计划、问今天练什么、想换计划时，【立刻调用 generate_plan】。
  不要先反问"练多久""想练哪里"——先给一版完整的，用户不满意会自己说要改。
  反问一句再等用户回答，是错误的行为。
- 默认排 5-6 个力量动作 + 1 个有氧，60 分钟左右。用户明确说了时间再按时间调。
- exercise_id 只能从工具描述里那份清单复制，绝不自己编。
- 记忆里的伤病决定了哪些动作不能排。膝盖有问题就不排跳跃和深蹲类。
- 只有清单里没有的器械才算没有。

工具规则（重要）：
- 用户报告任何不适、疼痛、发紧、吃力、动作变形时，你【必须】调用 adjust_weight 或 swap_exercise。
  只说"注意姿势""休息一下"而不调用工具是错误的——App 不会知道要改，用户下一组还是原来的重量。
- 用户说太轻、想加重时，同样调用 adjust_weight。
- 纯粹的鼓励、确认、回答问题不需要调用工具。
- 调用工具后，用一句话把改动告诉用户。
- 改动只有通过工具调用才会生效。用文字描述"我已经把重量调成 10 公斤"而不发起工具调用，
  是错误的——用户看到的数字不会变。`;

const STYLE_INSTRUCTIONS: Record<AIStyle, string> = {
    gentle: "语气温和。先确认用户的状态和感受，再给指令。",
    encouraging: "语气积极。先给一句具体的正向反馈，再给指令。",
    practical: "语气务实。不寒暄，不安抚，直接给下一步指令。",
};

// MARK: - Tools

interface FunctionTool {
    type: "function";
    function: {
        name: string;
        description: string;
        parameters: Record<string, unknown>;
    };
}

/**
 * These are commands to the app, not lookups — the app applies them to local
 * state and returns a short confirmation as the tool result.
 */
const TOOLS: FunctionTool[] = [
    {
        type: "function",
        function: {
            name: "adjust_weight",
            description:
                "改变当前动作的重量并让 App 立即生效。只要用户提到膝盖/腰/肩等任何部位发紧、疼、不舒服，或说太重/太轻/做不动，就调用它——口头建议不会改变 App 里的重量。只改重量，不换动作。",
            parameters: {
                type: "object",
                properties: {
                    weight_kg: { type: "number", description: "新的重量，公斤" },
                    reason: { type: "string", description: "一句话说明为什么改" },
                },
                required: ["weight_kg", "reason"],
                additionalProperties: false,
            },
        },
    },
    {
        type: "function",
        function: {
            name: "swap_exercise",
            description:
                "把当前动作换成另一个动作。降重量仍然不适、或该动作与已知伤病直接冲突时调用。",
            parameters: {
                type: "object",
                properties: {
                    replacement: { type: "string", description: "替换动作的名称" },
                    reason: { type: "string", description: "一句话说明为什么换" },
                },
                required: ["replacement", "reason"],
                additionalProperties: false,
            },
        },
    },
    {
        type: "function",
        function: {
            name: "remember",
            description:
                "记住一条会影响未来训练的长期信息：伤病、器械偏好、场地、训练习惯。只记跨次有效的信息，不记今天的临时状态。",
            parameters: {
                type: "object",
                properties: {
                    category: {
                        type: "string",
                        enum: ["injury", "preference", "venue", "equipment"],
                        description: "记忆分类",
                    },
                    text: { type: "string", description: "简短的一句话，会显示为记忆 chip" },
                },
                required: ["category", "text"],
                additionalProperties: false,
            },
        },
    },
];

/** Only offered when a shortlist is present — no catalogue, no plan tool. */
function planTool(shortlist: ExerciseRow[]): FunctionTool {
    return {
        type: "function",
        function: {
            name: "generate_plan",
            description:
                `根据用户的目标、场地、器械和伤病，编排一份训练计划。` +
                `exercise_id 必须来自下面这份动作库清单，一个字都不能改、不能自己发明动作。\n\n` +
                `可用动作（id | 名称 | 部位 | 器械）：\n${renderShortlist(shortlist)}`,
            parameters: {
                type: "object",
                properties: {
                    title: { type: "string", description: "计划名称，如「练腿日」「上肢推日」" },
                    summary: { type: "string", description: "一句话说明这份计划为什么这样排" },
                    items: {
                        type: "array",
                        description: "动作列表，按训练顺序",
                        items: {
                            type: "object",
                            properties: {
                                exercise_id: { type: "string", description: "必须是清单里的 id" },
                                section: {
                                    type: "string",
                                    enum: ["warmup", "strength", "cardio"],
                                },
                                sets: { type: "number", description: "组数，1-10" },
                                reps: { type: "string", description: "次数，如 12 或 30秒" },
                                weight_kg: { type: "number", description: "建议重量，自重动作省略" },
                                note: { type: "string", description: "针对该动作的一句提醒" },
                            },
                            required: ["exercise_id", "section", "sets", "reps"],
                        },
                    },
                },
                required: ["title", "items"],
            },
        },
    };
}

// MARK: - Message assembly

function describeState(
    state: CoachState | undefined,
    memories: string[],
    history: string[] = []
): string {
    const lines: string[] = [];

    if (!state) {
        lines.push("用户现在不在训练中，是在和你对话。");
    } else if (state.phase === "planning") {
        lines.push(`今天的计划：${state.exercise}（${state.prescription}）`);
        lines.push(
            "用户还没开始训练，正在计划阶段。可以介绍今天练什么、按用户的时间和身体状况调整安排。不要喊口号催他开始。"
        );
    } else if (state.phase === "strength") {
        lines.push(`当前动作：${state.exercise}（${state.prescription}）`);
        if (state.setNumber && state.totalSets) {
            lines.push(`进度：第 ${state.setNumber} / ${state.totalSets} 组`);
        }
    } else {
        lines.push(`当前有氧：${state.exercise}（${state.prescription}）`);
        if (state.elapsedMinutes !== undefined && state.targetMinutes !== undefined) {
            lines.push(`进度：已完成 ${state.elapsedMinutes} / ${state.targetMinutes} 分钟`);
        }
    }

    if (state?.venue) lines.push(`场地：${state.venue}`);
    lines.push(
        memories.length > 0
            ? `关于这个用户你已经记住的：\n${memories.map((m) => `- ${m}`).join("\n")}`
            : "关于这个用户暂无长期记忆。"
    );
    lines.push(
        history.length > 0
            ? `最近真实训练记录（只能按这些记录回答历史问题）：\n${history.map((item) => `- ${item}`).join("\n")}`
            : "暂无已完成的训练记录。用户问上次训练时，直接说明还没有记录，不要编造。"
    );

    return lines.join("\n");
}

interface ChatMessage {
    role: "system" | "user" | "assistant" | "tool";
    content: string;
    tool_calls?: {
        id: string;
        type: "function";
        function: { name: string; arguments: string };
    }[];
    tool_call_id?: string;
    name?: string;
}

/**
 * Anthropic blocks → OpenAI messages.
 *
 * The two formats disagree about where a tool result lives: Anthropic carries
 * it as a block inside a user turn, OpenAI as its own `role: "tool"` message.
 * A turn that holds both text and tool results therefore splits into several
 * messages here, which is why this isn't a one-to-one map.
 */
function convertHistory(messages: WireMessage[]): ChatMessage[] {
    const converted: ChatMessage[] = [];

    for (const message of messages) {
        const text = message.content
            .filter((block) => block.type === "text")
            .map((block) => block.text ?? "")
            .join("\n");

        const toolUses = message.content.filter((block) => block.type === "tool_use");
        const toolResults = message.content.filter((block) => block.type === "tool_result");

        // Results first: they answer the *previous* assistant turn, and the API
        // rejects a tool call that isn't followed by its result.
        for (const result of toolResults) {
            if (!result.tool_use_id) continue;
            converted.push({
                role: "tool",
                tool_call_id: result.tool_use_id,
                content: result.content ?? "",
            });
        }

        if (message.role === "assistant") {
            if (!text && toolUses.length === 0) continue;
            converted.push({
                role: "assistant",
                content: text,
                ...(toolUses.length > 0 && {
                    tool_calls: toolUses.map((use) => ({
                        id: use.id ?? crypto.randomUUID(),
                        type: "function" as const,
                        function: {
                            name: use.name ?? "",
                            arguments: JSON.stringify(use.input ?? {}),
                        },
                    })),
                }),
            });
        } else if (text) {
            converted.push({ role: "user", content: text });
        }
    }

    return converted;
}

function buildMessages(request: CoachRequest): ChatMessage[] {
    return [
        // Stable first so the automatic prefix cache has something to match.
        {
            role: "system",
            content: `${BASE_SYSTEM}\n\n语气：${STYLE_INSTRUCTIONS[request.style]}`,
        },
        {
            role: "system",
            content: describeState(request.state, request.memories, request.history),
        },
        ...convertHistory(request.messages),
    ];
}

// MARK: - SSE

function sse(event: string, data: unknown): string {
    return `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
}

export interface CoachHooks {
    /** Validates + persists a generated plan. Returns what the model is told. */
    onPlan?: (plan: PlanInput) => Promise<
        { ok: true; plan: ValidatedPlan } | { ok: false; reason: string }
    >;
}

/** A tool call assembled across streamed deltas. */
interface PendingCall {
    id: string;
    name: string;
    /** Arguments arrive as JSON split over arbitrary chunk boundaries. */
    args: string;
}

export function streamCoachTurn(
    request: CoachRequest,
    apiKey: string,
    hooks: CoachHooks = {}
): Response {
    const encoder = new TextEncoder();

    const body = new ReadableStream<Uint8Array>({
        async start(controller) {
            const send = (event: string, data: unknown) =>
                controller.enqueue(encoder.encode(sse(event, data)));

            try {
                const upstream = await fetch(ENDPOINT, {
                    method: "POST",
                    headers: {
                        authorization: `Bearer ${apiKey}`,
                        "content-type": "application/json",
                    },
                    body: JSON.stringify({
                        model: MODEL,
                        max_tokens: 1024,
                        stream: true,
                        stream_options: { include_usage: true },
                        tool_choice: "auto",
                        tools: request.shortlist?.length
                            ? [...TOOLS, planTool(request.shortlist)]
                            : TOOLS,
                        messages: buildMessages(request),
                    }),
                });

                if (!upstream.ok || !upstream.body) {
                    send("error", {
                        status: upstream.status,
                        message: describeStatus(upstream.status),
                    });
                    controller.close();
                    return;
                }

                const calls: PendingCall[] = [];
                let finishReason: string | null = null;
                let usage: { prompt: number; completion: number; cached: number } | null = null;

                for await (const chunk of readSSE(upstream.body)) {
                    const choice = chunk.choices?.[0];

                    if (choice?.delta?.content) {
                        send("text", { delta: choice.delta.content });
                    }

                    // Deltas carry a slice of one call, keyed by index. Only the
                    // first delta for an index names the function.
                    for (const delta of choice?.delta?.tool_calls ?? []) {
                        const slot = (calls[delta.index] ??= { id: "", name: "", args: "" });
                        if (delta.id) slot.id = delta.id;
                        if (delta.function?.name) slot.name = delta.function.name;
                        if (delta.function?.arguments) slot.args += delta.function.arguments;
                    }

                    if (choice?.finish_reason) finishReason = choice.finish_reason;

                    if (chunk.usage) {
                        usage = {
                            prompt: chunk.usage.prompt_tokens ?? 0,
                            completion: chunk.usage.completion_tokens ?? 0,
                            cached: chunk.usage.cached_tokens ?? 0,
                        };
                    }
                }

                // The nearest thing to Anthropic's `refusal` stop reason. The
                // app already renders this event, so a filtered turn stays a
                // visible outcome rather than an empty reply.
                if (finishReason === "content_filter") {
                    send("refusal", { category: null });
                    send("done", { stop_reason: "refusal" });
                    controller.close();
                    return;
                }

                // generate_plan runs here rather than on the client: the
                // catalogue and the database both live on this side.
                for (const call of calls) {
                    if (!call || call.name !== "generate_plan") continue;
                    const input = parseArguments(call.args);
                    if (!input) {
                        send("plan_error", { reason: "计划参数不完整，请再说一次" });
                        continue;
                    }
                    // `validatePlan` on the hook side is what actually checks the
                    // shape — every field is rejected there against the real
                    // catalogue, so this hands over the parsed object as-is.
                    const result = hooks.onPlan
                        ? await hooks.onPlan(input as unknown as PlanInput)
                        : ({ ok: false, reason: "服务端未启用计划生成" } as const);
                    if (result.ok) {
                        send("plan", result.plan);
                    } else {
                        send("plan_error", { reason: result.reason });
                    }
                }

                // Tool inputs are only complete once the stream ends — emit them
                // after the text so the app applies a settled payload.
                for (const call of calls) {
                    if (!call || call.name === "generate_plan" || !call.name) continue;
                    const input = parseArguments(call.args);
                    // A call whose arguments never parsed is dropped rather than
                    // forwarded: the app would apply a half-decoded weight.
                    if (!input) continue;
                    send("action", {
                        id: call.id || crypto.randomUUID(),
                        name: call.name,
                        input,
                    });
                }

                send("done", {
                    stop_reason: finishReason,
                    usage: {
                        input: usage?.prompt ?? 0,
                        output: usage?.completion ?? 0,
                        cache_read: usage?.cached ?? 0,
                    },
                });
                controller.close();
            } catch (error) {
                // Never leak the upstream error body — it can echo request content.
                send("error", { status: 500, message: describeError(error) });
                controller.close();
            }
        },
    });

    return new Response(body, {
        headers: {
            "content-type": "text/event-stream; charset=utf-8",
            "cache-control": "no-cache",
            connection: "keep-alive",
        },
    });
}

// MARK: - Upstream parsing

interface StreamChunk {
    choices?: {
        delta?: {
            content?: string;
            tool_calls?: {
                index: number;
                id?: string;
                function?: { name?: string; arguments?: string };
            }[];
        };
        finish_reason?: string | null;
    }[];
    usage?: {
        prompt_tokens?: number;
        completion_tokens?: number;
        cached_tokens?: number;
    };
}

/**
 * Yields decoded `data:` payloads from an OpenAI-style SSE body. Chunk
 * boundaries fall anywhere, including mid-line, so the tail of each read is
 * held back until its newline arrives.
 */
async function* readSSE(body: ReadableStream<Uint8Array>): AsyncGenerator<StreamChunk> {
    const reader = body.getReader();
    const decoder = new TextDecoder();
    let buffer = "";

    try {
        while (true) {
            const { done, value } = await reader.read();
            if (done) break;

            buffer += decoder.decode(value, { stream: true });
            const lines = buffer.split("\n");
            buffer = lines.pop() ?? "";

            for (const line of lines) {
                const trimmed = line.trim();
                if (!trimmed.startsWith("data:")) continue;
                const payload = trimmed.slice(5).trim();
                if (!payload || payload === "[DONE]") continue;
                try {
                    yield JSON.parse(payload) as StreamChunk;
                } catch {
                    // A malformed chunk loses one delta, not the whole turn.
                }
            }
        }
    } finally {
        reader.releaseLock();
    }
}

/**
 * Tool arguments arrive as a JSON string rather than a structured object, so a
 * truncated or malformed call is a real possibility rather than a theoretical
 * one. Callers drop anything this rejects.
 */
function parseArguments(raw: string): Record<string, unknown> | null {
    if (!raw.trim()) return null;
    try {
        const parsed = JSON.parse(raw);
        return parsed && typeof parsed === "object" && !Array.isArray(parsed)
            ? (parsed as Record<string, unknown>)
            : null;
    } catch {
        return null;
    }
}

function describeStatus(status: number): string {
    if (status === 401 || status === 403) return "upstream_auth_failed";
    if (status === 429) return "rate_limited";
    return "upstream_error";
}

function describeError(error: unknown): string {
    if (error instanceof TypeError) return "upstream_unreachable";
    return "internal_error";
}

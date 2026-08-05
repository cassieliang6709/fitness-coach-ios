import type { Anthropic } from "@anthropic-ai/sdk";
import { renderShortlist, type ExerciseRow, type PlanInput, type ValidatedPlan } from "./plan";

// DeepSeek OpenAI-compatible API
const DEEPSEEK_BASE = "https://api.deepseek.com/v1";
const DEEPSEEK_MODEL = "deepseek-v4-flash";

/**
 * The coach turn: builds the prompt, calls DeepSeek, streams the reply back as
 * SSE, and surfaces tool calls to the app as `action` events.
 *
 * The app owns conversation state and executes the tools (they mutate local
 * SwiftData), so this Worker stays stateless — it never stores a session.
 */

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

export interface CoachRequest {
    style: AIStyle;
    /** Absent when the user is just chatting rather than mid-set. */
    state?: CoachState;
    memories: string[];
    /** Finished sessions supplied by the app, newest first. */
    history?: string[];
    messages: Anthropic.MessageParam[];
    /** Real rows from the exercise table; the only movements it may use. */
    shortlist?: ExerciseRow[];
}

// MARK: - Prompt

/**
 * Stable across every request, so it sits first in `system`. Anything that
 * changes mid-session (current set, weight, memories) is appended as a second
 * block — see buildSystem.
 */
const BASE_SYSTEM = `你是一个健身陪练 Agent，在用户训练过程中实时指导。

沟通规则：
- 每次只说一到两句话。用户正在训练，没有时间读长段文字。
- 直接说下一步做什么，不要复述用户刚说的话。
- 不要输出心率、卡路里、补水提醒等与当前动作无关的内容。
- 不要用 Markdown 标题、列表或加粗。就是口语。

安全规则：
- 用户报告任何疼痛或不适时，先降低负荷或替换动作，再继续。
- 涉及疼痛、受伤、用药或疾病时，明确说明你不是医疗人员，建议就医。不要诊断。
- 记忆里的伤病信息优先于计划。计划要求做的动作如果和伤病冲突，替换它。

计划规则（重要）：
- 用户要计划、问今天练什么、想换计划时，【立刻调用 generate_plan】。
  不要先反问"练多久""想练哪里"——先给一版完整的，用户不满意会自己说要改。
  反问一句再等用户回答，是错误的行为。
- 【必须】在 generate_plan 的 title 字段填入计划名称，如「练腿日」「上肢推日」「全身力量」。这个字段不能为空。
- 默认排 5-6 个力量动作 + 1 个有氧，60 分钟左右。用户明确说了时间再按时间调。
- exercise_id 只能从工具描述里那份清单复制，绝不自己编。
- 记忆里的伤病决定了哪些动作不能排。膝盖有问题就不排跳跃和深蹲类。
- 只有清单里没有的器械才算没有。

工具规则（重要）：
- 用户报告任何不适、疼痛、发紧、吃力、动作变形时，你【必须】调用 adjust_weight 或 swap_exercise。
  只说"注意姿势""休息一下"而不调用工具是错误的——App 不会知道要改，用户下一组还是原来的重量。
- 用户说太轻、想加重时，同样调用 adjust_weight。
- 纯粹的鼓励、确认、回答问题不需要调用工具。
- 调用工具后，用一句话把改动告诉用户。`;

const STYLE_INSTRUCTIONS: Record<AIStyle, string> = {
    gentle: "语气温和。先确认用户的状态和感受，再给指令。",
    encouraging: "语气积极。先给一句具体的正向反馈，再给指令。",
    practical: "语气务实。不寒暄，不安抚，直接给下一步指令。",
};

// MARK: - Tools

/**
 * These are commands to the app, not lookups — the app applies them to local
 * state and returns a short confirmation as the tool result.
 */
const TOOLS: Anthropic.ToolUnion[] = [
    {
        name: "adjust_weight",
        description:
            "改变当前动作的重量并让 App 立即生效。只要用户提到膝盖/腰/肩等任何部位发紧、疼、不舒服，或说太重/太轻/做不动，就调用它——口头建议不会改变 App 里的重量。只改重量，不换动作。",
        strict: true,
        input_schema: {
            type: "object",
            properties: {
                weight_kg: { type: "number", description: "新的重量，公斤" },
                reason: { type: "string", description: "一句话说明为什么改" },
            },
            required: ["weight_kg", "reason"],
            additionalProperties: false,
        },
    },
    {
        name: "swap_exercise",
        description:
            "把当前动作换成另一个动作。降重量仍然不适、或该动作与已知伤病直接冲突时调用。",
        strict: true,
        input_schema: {
            type: "object",
            properties: {
                replacement: { type: "string", description: "替换动作的名称" },
                reason: { type: "string", description: "一句话说明为什么换" },
            },
            required: ["replacement", "reason"],
            additionalProperties: false,
        },
    },
    {
        name: "remember",
        description:
            "记住一条会影响未来训练的长期信息：伤病、器械偏好、场地、训练习惯。只记跨次有效的信息，不记今天的临时状态。",
        strict: true,
        input_schema: {
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
];

/** Only offered when a shortlist is present — no catalogue, no plan tool. */
function planTool(shortlist: ExerciseRow[]): Anthropic.ToolUnion {
    return {
        name: "generate_plan",
        description:
            `根据用户的目标、场地、器械和伤病，编排一份训练计划。` +
            `exercise_id 必须来自下面这份动作库清单，一个字都不能改、不能自己发明动作。\n\n` +
            `可用动作（id | 名称 | 部位 | 器械）：\n${renderShortlist(shortlist)}`,
        input_schema: {
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
                            section: { type: "string", enum: ["warmup", "strength", "cardio"] },
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

/**
 * Two system blocks: the stable persona (cacheable) then the live state.
 *
 * On Opus 5 the live state would ride as a mid-conversation system message to
 * keep the cached prefix byte-identical — but that feature is Opus-5/4.8 only
 * and returns 400 on Haiku, so it goes in `system` here instead.
 */
function buildSystem(request: CoachRequest): Anthropic.TextBlockParam[] {
    return [
        {
            type: "text",
            text: `${BASE_SYSTEM}\n\n语气：${STYLE_INSTRUCTIONS[request.style]}`,
            // Haiku 4.5 needs a 4096-token prefix before anything caches, and
            // this prompt is far shorter — so this is currently a no-op kept
            // for when the prompt grows or the model changes.
            cache_control: { type: "ephemeral" },
        },
        {
            type: "text",
            text: describeState(request.state, request.memories, request.history),
        },
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
                // Build system prompt
                const systemText = buildSystemText(request);

                // Build messages in OpenAI format. The iOS client keeps
                // Anthropic-shaped tool_use/tool_result blocks because that was
                // the original wire contract, so convert both halves explicitly.
                // Dropping tool_result here makes DeepSeek forget what the App
                // just changed and contradict the updated weight/exercise.
                const messages: OpenAIMessage[] = [
                    { role: "system", content: systemText },
                    ...openAIMessages(request.messages),
                ];

                // Build tools in OpenAI format
                const tools = request.shortlist?.length
                    ? [...openAITools(), openAIPlanTool(request.shortlist)]
                    : openAITools();

                const response = await fetch(`${DEEPSEEK_BASE}/chat/completions`, {
                    method: "POST",
                    headers: {
                        "Content-Type": "application/json",
                        "Authorization": `Bearer ${apiKey}`,
                    },
                    body: JSON.stringify({
                        model: DEEPSEEK_MODEL,
                        messages,
                        tools,
                        max_tokens: 1024,
                        stream: false,
                    }),
                });

                if (!response.ok) {
                    const errText = await response.text();
                    send("error", { status: response.status, message: "upstream_error" });
                    controller.close();
                    return;
                }

                const result = await response.json() as any;
                const choice = result.choices?.[0];
                const replyText = choice?.message?.content ?? "";

                // Stream the text in chunks
                if (replyText) {
                    const chunkSize = 4;
                    for (let i = 0; i < replyText.length; i += chunkSize) {
                        send("text", { delta: replyText.slice(i, i + chunkSize) });
                    }
                }

                // Handle tool calls
                const toolCalls = choice?.message?.tool_calls ?? [];
                for (const tc of toolCalls) {
                    const name = tc.function?.name;
                    let input: any = {};
                    try { input = JSON.parse(tc.function?.arguments ?? "{}"); } catch {}

                    if (name === "generate_plan") {
                        // Ensure title exists — DeepSeek sometimes omits it
                        if (!input.title && input.items?.length) {
                            input.title = "今日训练";
                        }
                        const planResult = hooks.onPlan
                            ? await hooks.onPlan(input as PlanInput)
                            : ({ ok: false, reason: "服务端未启用计划生成" } as const);
                        if (planResult.ok) {
                            send("plan", planResult.plan);
                        } else {
                            send("plan_error", { reason: planResult.reason });
                        }
                    } else if (name) {
                        send("action", {
                            id: tc.id,
                            name,
                            input,
                        });
                    }
                }

                send("done", {
                    stop_reason: choice?.finish_reason ?? "stop",
                    usage: {
                        input: result.usage?.prompt_tokens ?? 0,
                        output: result.usage?.completion_tokens ?? 0,
                        cache_read: 0,
                    },
                });
                controller.close();
            } catch (error) {
                send("error", { status: 500, message: "internal_error" });
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

function buildSystemText(request: CoachRequest): string {
    return `${BASE_SYSTEM}\n\n语气：${STYLE_INSTRUCTIONS[request.style]}\n\n${describeState(request.state, request.memories, request.history)}`;
}

type OpenAIMessage =
    | { role: "system" | "user"; content: string }
    | {
        role: "assistant";
        content: string | null;
        tool_calls?: Array<{
            id: string;
            type: "function";
            function: { name: string; arguments: string };
        }>;
    }
    | { role: "tool"; tool_call_id: string; content: string };

/** Preserve text and the complete tool loop when crossing wire formats. */
function openAIMessages(messages: Anthropic.MessageParam[]): OpenAIMessage[] {
    const converted: OpenAIMessage[] = [];

    for (const message of messages) {
        if (typeof message.content === "string") {
            converted.push({ role: message.role, content: message.content });
            continue;
        }

        const blocks = message.content as any[];
        const text = blocks
            .filter((block) => block.type === "text" && typeof block.text === "string")
            .map((block) => block.text)
            .join("");

        if (message.role === "assistant") {
            const toolCalls = blocks
                .filter((block) => block.type === "tool_use")
                .map((block) => ({
                    id: String(block.id),
                    type: "function" as const,
                    function: {
                        name: String(block.name),
                        arguments: JSON.stringify(block.input ?? {}),
                    },
                }));
            if (text || toolCalls.length) {
                converted.push({
                    role: "assistant",
                    content: text || null,
                    ...(toolCalls.length ? { tool_calls: toolCalls } : {}),
                });
            }
            continue;
        }

        // OpenAI requires tool results immediately after the assistant's tool
        // call. Any user text from the same Anthropic message follows them.
        for (const block of blocks.filter((item) => item.type === "tool_result")) {
            const content =
                typeof block.content === "string"
                    ? block.content
                    : JSON.stringify(block.content ?? "");
            converted.push({
                role: "tool",
                tool_call_id: String(block.tool_use_id),
                content,
            });
        }
        if (text) converted.push({ role: "user", content: text });
    }

    return converted;
}

function openAITools() {
    return TOOLS.map((t: any) => ({
        type: "function",
        function: {
            name: t.name,
            description: t.description,
            parameters: t.input_schema,
        },
    }));
}

function openAIPlanTool(shortlist: ExerciseRow[]) {
    const pt = planTool(shortlist) as any;
    return {
        type: "function",
        function: {
            name: pt.name,
            description: pt.description,
            parameters: pt.input_schema,
        },
    };
}

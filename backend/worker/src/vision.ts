/**
 * Gym photo → equipment list.
 *
 * Ported from the Vance handoff's gym-vision module. The discipline worth
 * keeping: this only reports what it can see. It never proposes exercises,
 * sets or weights — planning happens later, from the memories this writes.
 *
 * Confidence is load-bearing. Naming a machine that isn't there produces a
 * plan the user can't perform, so only `high` becomes an equipment memory;
 * `medium` is handed back for the user to confirm and `low` is dropped.
 */

const MAX_IMAGE_BYTES = 8 * 1024 * 1024;
const SUPPORTED_TYPES = new Set(["image/jpeg", "image/png", "image/webp"]);

export interface VisionEquipment {
    name: string;
    confidence: "high" | "medium" | "low";
    visibleEvidence: string;
}

export interface VisionResult {
    sceneSummary: string;
    /** Confirmed — safe to write straight into memories. */
    equipment: VisionEquipment[];
    /** Ambiguous — ask the user before trusting these. */
    needsConfirmation: string[];
}

const SYSTEM_PROMPT = `你是"健身房环境识别"助手。你的职责仅是识别照片中清晰可见的器械，绝不编排训练计划、动作、组数、重量、时长或替代方案。不要杜撰器械、重量、人体姿势或可用性。

置信度标准必须严格执行：
- high：至少有两个可辨认的结构特征，或有清晰可读的器械标识；器械类别没有合理替代解释。只有 high 可以出现在 equipment。
- medium：可见一个关键特征，但角度、遮挡或相似器械导致存在合理歧义；只能写入 needsConfirmation，供用户确认。
- low：只有模糊轮廓、远景、反光或猜测；不要出现在 equipment、needsConfirmation 或 sceneSummary 中。

必须只返回合法 JSON，不能使用 Markdown 或代码围栏，结构严格为：
{
  "sceneSummary": "一句话环境概述，仅描述已确认的 high 器械；若无 high 则写无法确认",
  "equipment": [{"name":"仅 high 的器械名称","confidence":"high","visibleEvidence":"至少两个图中可见线索"}],
  "needsConfirmation": ["仅 medium 器械，说明为什么需要确认"]
}

器械名称用中文，使用中国健身房的通行叫法（哑铃、杠铃、史密斯机、龙门架、腿举机、跑步机、椭圆机、划船机、卧推架、深蹲架等）。

禁止输出任何训练建议、动作名称、组数、次数、时长或安全提醒。`;

export function validateImage(imageData: unknown): { ok: true } | { ok: false; reason: string } {
    if (typeof imageData !== "string") return { ok: false, reason: "请先拍摄或选择一张健身房照片" };
    const match = imageData.match(/^data:([^;,]+);base64,([A-Za-z0-9+/]+={0,2})$/);
    if (!match || !SUPPORTED_TYPES.has(match[1])) {
        return { ok: false, reason: "仅支持 JPEG、PNG 或 WebP 图片" };
    }
    // base64 inflates by 4/3; estimate rather than decoding the whole thing.
    if ((match[2].length * 3) / 4 > MAX_IMAGE_BYTES) {
        return { ok: false, reason: "图片过大，请选择小于 8MB 的照片" };
    }
    return { ok: true };
}

export async function recognizeEquipment(
    imageData: string,
    apiKey: string,
    goal: string
): Promise<VisionResult> {
    const response = await fetch("https://api.moonshot.cn/v1/chat/completions", {
        method: "POST",
        headers: {
            "content-type": "application/json",
            authorization: `Bearer ${apiKey}`,
        },
        body: JSON.stringify({
            model: "kimi-k2.6",
            thinking: { type: "disabled" },
            max_tokens: 1200,
            messages: [
                { role: "system", content: SYSTEM_PROMPT },
                {
                    role: "user",
                    content: [
                        { type: "image_url", image_url: { url: imageData } },
                        {
                            type: "text",
                            text:
                                `用户目标：${goal || "减脂与基础体能"}\n\n` +
                                `请只识别这张健身房照片中可确认的器械；训练方案由后续教练负责。`,
                        },
                    ],
                },
            ],
        }),
    });

    if (!response.ok) {
        if (response.status === 401) throw new Error("kimi_auth_failed");
        if (response.status === 429) throw new Error("kimi_rate_limited");
        throw new Error("kimi_unavailable");
    }

    const payload = (await response.json()) as {
        choices?: { message?: { content?: string } }[];
    };
    return parseResult(payload.choices?.[0]?.message?.content);
}

/** The model is told not to fence its JSON, but strip fences anyway. */
export function parseResult(content: string | undefined): VisionResult {
    if (!content?.trim()) throw new Error("kimi_empty_response");
    const json = content
        .trim()
        .replace(/^```json\s*/i, "")
        .replace(/^```\s*/i, "")
        .replace(/\s*```$/, "");

    let parsed: Record<string, unknown>;
    try {
        parsed = JSON.parse(json);
    } catch {
        throw new Error("kimi_bad_json");
    }
    if (!Array.isArray(parsed.equipment)) throw new Error("kimi_bad_shape");

    const normalized: VisionEquipment[] = (parsed.equipment as unknown[])
        .slice(0, 8)
        .map((raw) => {
            const item = (raw ?? {}) as Record<string, unknown>;
            const confidence = item.confidence;
            return {
                name: clean(item.name, 40) || "未命名器械",
                confidence:
                    confidence === "high" || confidence === "medium" ? confidence : "low",
                visibleEvidence: clean(item.visibleEvidence, 160) || "请用户确认",
            };
        });

    const medium = normalized.filter((item) => item.confidence === "medium");
    const confirmation = [
        ...(Array.isArray(parsed.needsConfirmation)
            ? (parsed.needsConfirmation as unknown[]).slice(0, 5).map((i) => clean(i, 160))
            : []),
        ...medium.map((item) => `疑似${item.name}：${item.visibleEvidence}`),
    ].filter(Boolean);

    return {
        sceneSummary: clean(parsed.sceneSummary, 240) || "已完成健身房环境识别。",
        equipment: normalized.filter((item) => item.confidence === "high"),
        needsConfirmation: [...new Set(confirmation)].slice(0, 5),
    };
}

function clean(value: unknown, maxLength: number): string {
    return typeof value === "string" ? value.replace(/\s+/g, " ").trim().slice(0, maxLength) : "";
}

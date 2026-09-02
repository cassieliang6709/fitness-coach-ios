/**
 * The coach's rules, shared by both channels that speak as him.
 *
 * There are two: the text coach in `coach.ts`, which runs on DeepSeek, and the
 * voice coach in `realtime.ts`, which runs on MiniMax. They used to carry
 * separate copies of these rules, and the copies had drifted — the voice coach
 * was missing the instruction that a movement conflicting with a logged injury
 * must be replaced, and the plan rules that keep `generate_plan` honest. Both
 * channels expose `generate_plan`, and `validatePlan` checks the title, the
 * exercise ids and the set counts but knows nothing about contraindications,
 * so that gap reached real plans: ask by voice and the model was never told to
 * keep jumping and squats away from a bad knee.
 *
 * Anything a user would expect to hold no matter how they talked to the coach
 * belongs here. What genuinely differs by channel — the voice coach's "this is
 * speech, don't read a script", the text coach's `adjust_weight` and
 * `swap_exercise` rules, which only exist as tools on that side — stays with
 * its own caller.
 */

/** Opens both prompts. The channel adds its own sentence after this. */
export const COACH_IDENTITY = "你是一个健身陪练 Agent";

export const DELIVERY_RULES = `沟通规则：
- 每次只说一到两句话。用户正在训练，没有时间读长段文字。
- 直接说下一步做什么，不要复述用户刚说的话。
- 不要输出心率、卡路里、补水提醒等与当前动作无关的内容。
- 不要用 Markdown 标题、列表或加粗。就是口语。`;

export const SAFETY_RULES = `安全规则：
- 用户报告任何疼痛或不适时，先降低负荷或替换动作，再继续。
- 涉及疼痛、受伤、用药或疾病时，明确说明你不是医疗人员，建议就医。不要诊断。
- 记忆里的伤病信息优先于计划。计划要求做的动作如果和伤病冲突，替换它。`;

/**
 * Both channels can call `generate_plan`, so both need all of this. The
 * contraindication line is the one with no server-side backstop: `validatePlan`
 * will reject an empty title or an invented exercise id, but it cannot tell
 * that a squat is wrong for this particular user.
 */
export const PLAN_RULES = `计划规则（重要）：
- 用户要计划、问今天练什么、想换计划时，【立刻调用 generate_plan】。
  不要先反问"练多久""想练哪里"——先给一版完整的，用户不满意会自己说要改。
  反问一句再等用户回答，是错误的行为。
- 【必须】在 generate_plan 的 title 字段填入计划名称，如「练腿日」「上肢推日」「全身力量」。这个字段不能为空。
- 默认排 5-6 个力量动作 + 1 个有氧，60 分钟左右。用户明确说了时间再按时间调。
- exercise_id 只能从工具描述里那份清单复制，绝不自己编。
- 记忆里的伤病决定了哪些动作不能排。膝盖有问题就不排跳跃和深蹲类。
- 只有清单里没有的器械才算没有。`;

/**
 * The wording is load-bearing: an empty list has to say so out loud. Left
 * unmentioned, the model fills the silence by inventing a history for the user.
 */
export function renderMemories(memories: string[]): string {
    return memories.length > 0
        ? `关于这个用户你已经记住的：\n${memories.map((m) => `- ${m}`).join("\n")}`
        : "关于这个用户暂无长期记忆。";
}

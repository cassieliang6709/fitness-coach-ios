import Foundation

enum LabStepKind: String, Hashable {
    case learn
    case predict
    case tryIt
    case observe
    case explain
    case apply

    var label: String {
        switch self {
        case .learn: return "LEARN · 理解"
        case .predict: return "PREDICT · 先猜"
        case .tryIt: return "TRY · 去试"
        case .observe: return "OBSERVE · 感受"
        case .explain: return "EXPLAIN · 理解"
        case .apply: return "APPLY · 独立完成"
        }
    }
}

struct LabChoice: Identifiable, Hashable {
    let id: String
    let title: String
    var feedback: String?

    init(_ title: String, feedback: String? = nil) {
        self.id = title
        self.title = title
        self.feedback = feedback
    }
}

struct LabStep: Identifiable, Hashable {
    let id: String
    let kind: LabStepKind
    let title: String
    let body: String
    var bullets: [String] = []
    var choices: [LabChoice] = []
    var exerciseID: String?
    var note: String?

    var needsChoice: Bool { !choices.isEmpty }
}

struct LabLesson: Identifiable, Hashable {
    var id: Int { day }
    let day: Int
    let code: String
    let title: String
    let subtitle: String
    let unlock: String
    let symbol: String
    var steps: [LabStep]
}

enum LabCourse {
    static let lessons: [LabLesson] = [
        LabLesson(
            day: 1,
            code: "LAB 01",
            title: "先看懂健身房",
            subtitle: "找到座椅、起始位置和配重插销",
            unlock: "Machine Setup",
            symbol: "slider.horizontal.3",
            steps: [
                LabStep(
                    id: "controls",
                    kind: .learn,
                    title: "陌生器械只问三个问题",
                    body: "坐多高？从哪里开始？要多重？",
                    bullets: [
                        "座椅 / 靠背：让器械对准你的身体",
                        "起始位置：决定动作从哪里开始",
                        "配重插销：决定你移动的重量",
                    ],
                    exerciseID: "machine-chest-press"
                ),
                LabStep(
                    id: "pin",
                    kind: .predict,
                    title: "插销应该停在哪里？",
                    body: "调整配重时，插销应该停在两块配重之间，还是完整插进一块配重？",
                    choices: [
                        LabChoice("停在中间", feedback: "再看一次：插销必须完整插入，不能悬在两块配重之间。"),
                        LabChoice("完整插进去", feedback: "对。开始前轻拉一下，确认它已经卡紧。"),
                    ]
                ),
                LabStep(
                    id: "find",
                    kind: .tryIt,
                    title: "找到三个控制点",
                    body: "找一台暂时没有人使用的固定器械。先不训练，只观察和设置。",
                    bullets: [
                        "找到座椅或靠背调节",
                        "找到起始位置调节",
                        "找到配重插销并确认卡紧",
                    ]
                ),
                LabStep(
                    id: "units",
                    kind: .explain,
                    title: "kg 和 lb 不是一回事",
                    body: "先看清器械使用哪一种单位，不要把相同数字当成相同重量。",
                    choices: [
                        LabChoice("20 lb 和 20 kg 一样重", feedback: "不一样。它们使用不同的重量单位。"),
                        LabChoice("20 lb 和 20 kg 不一样重", feedback: "正确。今天不需要心算换算，先认清单位。"),
                    ]
                ),
                LabStep(
                    id: "master",
                    kind: .apply,
                    title: "你学会了读懂陌生器械",
                    body: "不看提示，再指出座椅、起始位置和配重插销。",
                    note: "完成后解锁 Machine Setup。"
                ),
            ]
        ),
        LabLesson(
            day: 2,
            code: "BUILD A HUMAN · LAB 02",
            title: "今天：找到你的胸",
            subtitle: "用坐姿推胸研究 Push",
            unlock: "胸 · Push",
            symbol: "figure.strengthtraining.traditional",
            steps: [
                LabStep(
                    id: "human",
                    kind: .learn,
                    title: "Build a Human",
                    body: "胸部参与把上臂带向身体前方。坐姿推胸是一个容易观察的 Push。",
                    note: "想象你正在把一扇很重的门推开。"
                ),
                LabStep(
                    id: "setup",
                    kind: .learn,
                    title: "设置坐姿推胸",
                    body: "先把器械对准身体，再选择重量。",
                    bullets: [
                        "把手大致与胸口齐平",
                        "肩胛和背部贴住靠背",
                        "选择能轻松完成 12 次以上的重量",
                        "推到手臂接近伸直，不锁死手肘",
                    ],
                    exerciseID: "machine-chest-press"
                ),
                LabStep(
                    id: "hypothesis",
                    kind: .predict,
                    title: "今天的假设",
                    body: "把手与胸口大致对齐后，肩膀会不会更容易放松？",
                    choices: [
                        LabChoice("会", feedback: "去试试看。身体反馈比猜测更重要。"),
                        LabChoice("不会", feedback: "记录你的预测，然后用轻重量验证。"),
                        LabChoice("不确定", feedback: "这也是有效答案。实验就是用来帮助你判断。"),
                    ]
                ),
                LabStep(
                    id: "five-reps",
                    kind: .tryIt,
                    title: "慢慢推 5 次",
                    body: "不追求累，只观察。",
                    bullets: ["推出 1 秒", "回来 2 秒", "全程保持背部贴住靠背"],
                    exerciseID: "machine-chest-press"
                ),
                LabStep(
                    id: "observe",
                    kind: .observe,
                    title: "哪里最明显？",
                    body: "没有标准感受。选择最接近的一项。",
                    choices: [
                        LabChoice("胸部发力", feedback: "你已经找到这个动作的主要目标。"),
                        LabChoice("手臂更累", feedback: "手臂会帮忙，这不代表做错。可以轻一档再观察。"),
                        LabChoice("肩膀不舒服", feedback: "先停止。不要用疼痛验证假设，可以减重或跳过。"),
                        LabChoice("说不清", feedback: "很正常。感受是练出来的观察力，不是考试。"),
                    ]
                ),
                LabStep(
                    id: "apply",
                    kind: .apply,
                    title: "独立完成 8 次",
                    body: "不看提示，重新检查座椅、重量和靠背，然后完成一小组。",
                    note: "保持同样节奏，你大概还能做 3 次吗？"
                ),
            ]
        ),
        LabLesson(
            day: 3,
            code: "BUILD A HUMAN · LAB 03",
            title: "今天：找到你的背",
            subtitle: "选择一台拉类器械",
            unlock: "背 · Pull",
            symbol: "figure.strengthtraining.functional",
            steps: [
                LabStep(
                    id: "pull",
                    kind: .learn,
                    title: "手肘带动 Pull",
                    body: "背部参与把上臂拉近身体，也帮助肩胛在动作中保持稳定。",
                    note: "今天只需掌握高位下拉或坐姿绳索划船中的一台。"
                ),
                LabStep(
                    id: "pull-setup",
                    kind: .learn,
                    title: "先让身体稳定",
                    body: "高位下拉用大腿压垫固定身体；坐姿划船保持胸口打开。",
                    bullets: [
                        "不要向后大幅倒",
                        "不要前后大幅摇摆",
                        "回放时保持控制，不让配重撞回去",
                    ],
                    exerciseID: "lat-pulldown"
                ),
                LabStep(
                    id: "pull-predict",
                    kind: .predict,
                    title: "今天的假设",
                    body: "让肩膀远离耳朵并保持身体稳定，会让拉动更容易控制吗？",
                    choices: [
                        LabChoice("会", feedback: "用轻重量验证它。"),
                        LabChoice("不会", feedback: "保留这个预测，观察实际感受。"),
                        LabChoice("不确定", feedback: "很好。先试再说。"),
                    ]
                ),
                LabStep(
                    id: "pull-observe",
                    kind: .observe,
                    title: "哪里最明显？",
                    body: "手臂参与拉动很正常。目标不是只有背发力。",
                    choices: [
                        LabChoice("背部", feedback: "继续保持身体稳定和受控回放。"),
                        LabChoice("手臂", feedback: "正常。试着让手肘带动，而不是用手握得更紧。"),
                        LabChoice("颈肩紧张", feedback: "先减轻重量，避免耸肩；持续不适就停止。"),
                        LabChoice("说不清", feedback: "记录下来，下一次会更容易比较。"),
                    ]
                ),
                LabStep(
                    id: "pull-apply",
                    kind: .apply,
                    title: "独立完成 8 次",
                    body: "检查器械设置，保持身体稳定，并控制每一次回放。",
                    note: "完成后解锁 Back · Pull。"
                ),
            ]
        ),
        LabLesson(
            day: 4,
            code: "MOVEMENT LAB · 04",
            title: "膝盖在弯，还是髋在往后？",
            subtitle: "比较 Knee 与 Hip",
            unlock: "Knee · Hip",
            symbol: "figure.squat",
            steps: [
                LabStep(
                    id: "knee-hip",
                    kind: .predict,
                    title: "坐下再站起时",
                    body: "膝盖和髋都会动。大腿前侧和臀部会不会一起工作？",
                    choices: [
                        LabChoice("会", feedback: "对，它们会一起工作，只是任务重点不同。"),
                        LabChoice("不会", feedback: "接下来做两个安全对比，看看感觉是否改变。"),
                        LabChoice("不确定", feedback: "先做对比，再形成自己的答案。"),
                    ]
                ),
                LabStep(
                    id: "sit-stand",
                    kind: .tryIt,
                    title: "安全对比 A",
                    body: "徒手坐到稳定凳子再站起 5 次。",
                    bullets: ["膝盖和髋一起弯曲", "脚掌保持完整着地", "观察大腿前侧或臀部"]
                ),
                LabStep(
                    id: "hinge",
                    kind: .tryIt,
                    title: "安全对比 B",
                    body: "徒手早安式 5 次，只在舒适范围内活动。",
                    bullets: ["膝盖微屈", "髋部向后推", "背部保持自然", "观察大腿后侧"],
                    exerciseID: "bodyweight-good-morning"
                ),
                LabStep(
                    id: "leg-press",
                    kind: .learn,
                    title: "在腿推里看见 Knee",
                    body: "腰背贴住靠垫，双脚大致与髋同宽，膝盖朝脚尖方向移动。",
                    bullets: ["膝盖不锁死", "只下降到腰背仍能贴住的深度", "不测试极端脚位"],
                    exerciseID: "leg-press"
                ),
                LabStep(
                    id: "movement-apply",
                    kind: .apply,
                    title: "说出任务重点",
                    body: "坐下站起更接近 Knee；徒手早安式更接近 Hip。两者都会使用多个肌群。",
                    note: "稳定完成比复制唯一姿势更重要。"
                ),
            ]
        ),
        LabLesson(
            day: 5,
            code: "PROGRAMMING LAB · 05",
            title: "3 × 10 到底是什么？",
            subtitle: "学习组、次、休息和 RIR",
            unlock: "Sets · Reps · Rest · RIR",
            symbol: "number",
            steps: [
                LabStep(
                    id: "decode",
                    kind: .learn,
                    title: "把 3 × 10 拆开",
                    body: "3 是组数，10 是每组次数，两组之间需要休息。",
                    choices: [
                        LabChoice("连续做 30 次", feedback: "不是。完成 10 次后休息，再重复，共 3 组。"),
                        LabChoice("10 次一组，共做 3 组", feedback: "正确。组间休息也是计划的一部分。"),
                    ]
                ),
                LabStep(
                    id: "rir",
                    kind: .learn,
                    title: "还剩几次？",
                    body: "做完一组时，问自己：保持同样节奏和控制，我大概还能做几次？",
                    bullets: [
                        "5 次以上：可能偏轻",
                        "2–3 次：适合初学者练习",
                        "0–1 次：今天先减轻",
                        "已经失去控制：结束这一组",
                    ]
                ),
                LabStep(
                    id: "weight-finder",
                    kind: .tryIt,
                    title: "Weight Finder",
                    body: "在已经掌握的一台器械上，用轻重量做 8 次。",
                    choices: [
                        LabChoice("还能 5 次以上", feedback: "可加最小一档，也可以保持不变继续练节奏。"),
                        LabChoice("还能 2–3 次", feedback: "找到了。今天保持这个重量。"),
                        LabChoice("只能 0–1 次", feedback: "减轻一档。起始重量不需要证明什么。"),
                        LabChoice("无法判断", feedback: "保持当前重量，多记录两组再判断。"),
                    ]
                ),
                LabStep(
                    id: "rest",
                    kind: .tryIt,
                    title: "休息实验",
                    body: "完成 8 次，休息 60–90 秒，再用相同重量完成 8 次。",
                    choices: [
                        LabChoice("第二组更稳定", feedback: "休息帮助你恢复了输出和控制。"),
                        LabChoice("差不多", feedback: "记录下来。不同动作需要的休息可能不同。"),
                        LabChoice("第二组更吃力", feedback: "疲劳仍在累积。可以延长休息或降低重量。"),
                    ]
                ),
                LabStep(
                    id: "weight-apply",
                    kind: .apply,
                    title: "没有完美重量",
                    body: "你学会的是每天重新判断重量，而不是记住一个永远不变的数字。",
                    note: "完成后解锁 Sets · Reps · Rest · RIR。"
                ),
            ]
        ),
        LabLesson(
            day: 6,
            code: "FEEDBACK LAB · 06",
            title: "会调整，比会硬撑更重要",
            subtitle: "练习 Continue、Regress、Stop",
            unlock: "Adjust",
            symbol: "arrow.triangle.2.circlepath",
            steps: [
                LabStep(
                    id: "three-actions",
                    kind: .learn,
                    title: "你永远有三个动作",
                    body: "好的计划会根据你今天的反馈改变。",
                    bullets: [
                        "继续：费力，但动作仍受控，没有不适警讯",
                        "降级：节奏失控、幅度被迫改变或状态明显变差",
                        "停止：尖锐痛、麻木、明显头晕、异常呼吸或失去控制",
                    ]
                ),
                LabStep(
                    id: "scenario-a",
                    kind: .predict,
                    title: "情境 A",
                    body: "推胸第 8 次很累，但动作稳定，估计还能做 2 次。",
                    choices: [
                        LabChoice("继续", feedback: "正确。这是可控制的训练费力感。"),
                        LabChoice("降级", feedback: "可以更保守，但当前信息仍允许继续。"),
                        LabChoice("停止", feedback: "当前没有停止警讯。"),
                    ]
                ),
                LabStep(
                    id: "scenario-b",
                    kind: .predict,
                    title: "情境 B",
                    body: "第二组开始靠快速弹回才能完成，已经无法控制回放。",
                    choices: [
                        LabChoice("继续", feedback: "先不要硬撑。失去控制时应该调整。"),
                        LabChoice("降级", feedback: "正确。减轻一档或减少次数。"),
                        LabChoice("停止", feedback: "可以停止，但先降级也可能解决。"),
                    ]
                ),
                LabStep(
                    id: "scenario-c",
                    kind: .predict,
                    title: "情境 C",
                    body: "腿推时膝盖出现突然的尖锐疼痛。",
                    choices: [
                        LabChoice("继续", feedback: "不要继续用疼痛验证动作。"),
                        LabChoice("降级", feedback: "尖锐疼痛不是仅靠减重继续的信号。"),
                        LabChoice("停止", feedback: "正确。停止动作；持续或加重时咨询专业人士。"),
                    ]
                ),
                LabStep(
                    id: "say-it",
                    kind: .apply,
                    title: "把反馈说出来",
                    body: "告诉 Vance：重量失控、今天想少做一组，或某个部位不舒服。",
                    bullets: [
                        "这个重量让我无法保持节奏",
                        "今天我想减少一组",
                        "这个部位不舒服，我要停止",
                    ],
                    note: "你的反馈不是对计划的破坏。它就是计划的一部分。"
                ),
            ]
        ),
        LabLesson(
            day: 7,
            code: "FINAL LAB · 07",
            title: "Build Your First Workout",
            subtitle: "这次，Vance 不先给答案",
            unlock: "Gym License · Level 1",
            symbol: "checkmark.seal.fill",
            steps: []
        ),
    ]

    static func lesson(day: Int) -> LabLesson {
        lessons.first { $0.day == day } ?? lessons[0]
    }
}

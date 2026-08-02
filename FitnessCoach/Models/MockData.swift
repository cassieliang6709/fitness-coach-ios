import Foundation

/// All copy and numbers live here so screens stay data-driven.
enum MockData {

    // MARK: - Welcome

    static let welcomeHighlights: [WelcomeHighlight] = [
        WelcomeHighlight(
            id: "coach",
            symbol: "bubble.left.and.bubble.right.fill",
            title: "训练时能说话",
            body: "哪里不舒服、太重了、想换动作，说一句就改。"
        ),
        WelcomeHighlight(
            id: "memory",
            symbol: "brain.head.profile",
            title: "记得住你",
            body: "伤病、场地、习惯只说一次，下次自动生效。"
        ),
        WelcomeHighlight(
            id: "honest",
            symbol: "checkmark.seal.fill",
            title: "只记你真做过的",
            body: "复盘按实际完成的组数统计，不替你打勾。"
        ),
    ]

    /// Title / subtitle for each question in the welcome flow.
    static let welcomeSteps: [(title: String, subtitle: String)] = [
        ("先认识一下", "我是你的 AI 陪练。训练时你说话，我改计划。"),
        ("你想练成什么样？", "决定动作的重量、次数和有氧比例。"),
        ("平时在哪训练？", "决定我给你安排哪些器械。"),
        ("身体有需要避开的地方吗？", "可多选。这条会一直生效，优先级高于计划。"),
        ("希望我用什么语气？", "随时可以在「我的计划」里改。"),
    ]

    static let styleSampleLines: [AIStyle: String] = [
        .gentle: "慢一点，膝盖朝脚尖方向，髋部向后坐。",
        .encouraging: "这个动作你上次做得很稳，髋部向后坐。",
        .practical: "膝盖朝脚尖方向，髋部向后坐。",
    ]

    // MARK: - Memories

    static let memories: [WorkoutMemory] = [
        WorkoutMemory(id: "mem-knee", category: .injury, text: "右膝不适，避免跳跃"),
        WorkoutMemory(id: "mem-venue", category: .venue, text: "乐刻健身房"),
    ]

    // MARK: - Leg day

    static let legDayExercises: [Exercise] = [
        Exercise(
            id: "goblet-squat", name: "高脚杯深蹲", sets: 4, reps: "12", weight: 12, alternative: "箱式深蹲"),
        Exercise(id: "glute-bridge", name: "臀桥", sets: 4, reps: "15"),
        Exercise(id: "step-up", name: "台阶上步", sets: 3, reps: "10", sideBased: true),
        Exercise(id: "leg-press", name: "坐姿腿推", sets: 3, reps: "12"),
        Exercise(id: "leg-curl", name: "坐姿腿弯举", sets: 3, reps: "12"),
        Exercise(id: "calf-raise", name: "小腿提踵", sets: 3, reps: "15"),
    ]

    static let legDayPlan = WorkoutPlan(
        id: "leg-day",
        title: "练腿日计划",
        tags: ["力量 60 分钟", "有氧 20–30 分钟"],
        symbol: "figure.strengthtraining.traditional",
        sections: [
            PlanSection(id: "warmup", kind: .warmup, duration: "8 分钟", subtitle: "动态拉伸 + 臀腿激活"),
            PlanSection(
                id: "strength", kind: .strength, duration: "60 分钟", exercises: legDayExercises),
            PlanSection(id: "cardio", kind: .cardio, duration: "20–30 分钟", subtitle: "跑步机快走"),
        ],
        memoryNote: MemoryNote(
            title: "膝盖记忆",
            body: "避免跳跃。深蹲不适时降低重量，或替换为箱式深蹲。"
        )
    )

    /// Secondary cards in the library — preview only, this module ships leg day.
    static let otherPlans: [WorkoutPlan] = [
        WorkoutPlan(
            id: "chest-shoulder",
            title: "胸肩 + 有氧",
            tags: ["力量 45 分钟", "有氧 20 分钟"],
            symbol: "figure.strengthtraining.functional"
        ),
        WorkoutPlan(
            id: "back",
            title: "背部 + 有氧",
            tags: ["力量 50 分钟", "有氧 20 分钟"],
            symbol: "figure.rower"
        ),
        WorkoutPlan(
            id: "recovery",
            title: "低冲击恢复日",
            tags: ["拉伸", "核心", "低强度有氧"],
            symbol: "figure.cooldown"
        ),
    ]

    // MARK: - Coached exercise (page 3 focuses on the first strength move)

    static let strengthVenue = "乐刻健身房 · 哑铃区"
    static let restDuration = 45

    // MARK: - Cardio task (page 4)

    static let cardioName = "跑步机快走"
    static let cardioPrescription = "6.0 km/h · 20 分钟"
    static let cardioStartMinutes = 12
    static let cardioTargetMinutes = 30

    // MARK: - Home conversation (page 1, before training starts)

    static let homeOpening: [CoachLine] = [
        CoachLine(
            core: "今天安排的是练腿日：力量 60 分钟，有氧 20–30 分钟。",
            gentleLead: "不着急，",
            encouragingLead: "上次练得不错，"
        )
    ]

    /// Suggestion chips above the input bar. Each one matches a scripted turn,
    /// so tapping a chip gets the reply it promises rather than the next line.
    static let homeSuggestions = ["今天练什么？", "膝盖有点不舒服", "今天时间不多", "上次练得怎么样？"]

    static let homeScript: [ScriptedTurn] = [
        ScriptedTurn(
            id: "home-what",
            userText: "今天练什么？",
            replies: [
                CoachLine(
                    core: "高脚杯深蹲、臀桥、台阶上步等 6 个动作，最后跑步机快走 20 分钟。",
                    gentleLead: "先看一眼，",
                    encouragingLead: "都是你练过的动作，"
                )
            ]
        ),
        ScriptedTurn(
            id: "home-knee",
            userText: "膝盖有点不舒服",
            replies: [
                CoachLine(
                    core: "那深蹲今天从 10 kg 起，台阶上步先做 2 组。疼就立刻说。",
                    gentleLead: "先别硬撑，",
                    encouragingLead: "提前说出来最好，"
                )
            ]
        ),
        ScriptedTurn(
            id: "home-short",
            userText: "今天时间不多",
            replies: [
                CoachLine(
                    core: "那就只做深蹲、臀桥、腿推，有氧压到 15 分钟，40 分钟能结束。",
                    gentleLead: "少练也是练，",
                    encouragingLead: "能来就已经赢了一半，"
                )
            ]
        ),
        ScriptedTurn(
            id: "home-last",
            userText: "上次练得怎么样？",
            replies: [
                CoachLine(
                    core: "上次全部完成，深蹲停在 12 kg。今天可以试试 14 kg。",
                    gentleLead: "按感觉来，",
                    encouragingLead: "上次很稳，"
                )
            ]
        ),
    ]

    // MARK: - Scripts

    static let strengthOpening: [CoachLine] = [
        CoachLine(core: "准备好了吗？", gentleLead: "不着急，", encouragingLead: "状态看起来不错，")
    ]

    static let strengthScript: [ScriptedTurn] = [
        ScriptedTurn(
            id: "start",
            userText: "开始",
            replies: [
                CoachLine(
                    core: "膝盖朝脚尖方向，髋部向后坐。",
                    gentleLead: "慢一点，",
                    encouragingLead: "这个动作你上次做得很稳，"
                )
            ]
        ),
        ScriptedTurn(
            id: "knee",
            userText: "膝盖有点紧。",
            replies: [
                CoachLine(
                    core: "下一组降到 10 kg。仍然不适就改箱式深蹲。",
                    gentleLead: "收到，",
                    encouragingLead: "反馈得很及时，"
                )
            ],
            effect: .reduceWeight(10)
        ),
        ScriptedTurn(
            id: "set3",
            userText: "这组还行。",
            replies: [
                CoachLine(core: "保持这个重量，下放数 2 秒。", encouragingLead: "很好，")
            ]
        ),
        ScriptedTurn(
            id: "set4",
            userText: "最后一组开始。",
            replies: [
                CoachLine(core: "最后一组，站起时呼气。", gentleLead: "稳住就好，")
            ]
        ),
    ]

    static let cardioOpening: [CoachLine] = [
        CoachLine(core: "现在进入有氧阶段。"),
        CoachLine(
            core: "保持 6.0 km/h，能说话但略微喘。",
            gentleLead: "按自己的节奏来，",
            encouragingLead: "力量部分完成得不错，"
        ),
    ]

    static let cardioScript: [ScriptedTurn] = [
        ScriptedTurn(
            id: "cardio-knee",
            userText: "膝盖有点不舒服。",
            replies: [
                CoachLine(
                    core: "把坡度调到 0。如果仍然不适，就改为椭圆机。",
                    gentleLead: "先别硬撑，",
                    encouragingLead: "说出来就对了，"
                )
            ],
            effect: .flattenIncline
        ),
        ScriptedTurn(
            id: "cardio-pace",
            userText: "现在好一些了。",
            replies: [
                CoachLine(core: "保持到 30 分钟，最后 3 分钟降到 4.5 km/h。")
            ]
        ),
    ]

    // MARK: - Review

    static let reviewDurationMinutes = 90
    static let reviewCompletion = 100

    static let kneeMemoryUpdate =
        "右膝今天轻微紧张。下次台阶上步先调整为 2 组，并在深蹲前增加膝关节热身。"
    static let neutralMemoryUpdate =
        "今天全程无不适反馈。下次高脚杯深蹲可以尝试加到 14 kg。"
}

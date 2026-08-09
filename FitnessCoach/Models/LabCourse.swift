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
        case .predict: return "CHOOSE · 做决定"
        case .tryIt: return "TRY · 去试"
        case .observe: return "OBSERVE · 记录"
        case .explain: return "EXPLAIN · 拆开看"
        case .apply: return "APPLY · 放进计划"
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
            code: "DAY 01 · GOAL LAB",
            title: "先决定你在练什么",
            subtitle: "把目标和真实生活放进同一张计划",
            unlock: "Goal Brief",
            symbol: "scope",
            steps: [
                LabStep(
                    id: "maya",
                    kind: .predict,
                    title: "Maya 只需要去跑步吗？",
                    body: "Maya 想减脂，也想让爬楼轻松一点。她每周能去三次健身房，但不想每次待两个小时。",
                    choices: [
                        LabChoice(
                            "对，减脂就应该只做有氧",
                            feedback: "跑步可以增加有氧活动，但它没有包办 Maya 的全部目标。力量训练、其他有氧活动、日常活动和饮食都会影响结果。"
                        ),
                        LabChoice(
                            "不一定，她可能需要不止一种训练",
                            feedback: "对。我们还不能立刻替她排计划，但已经知道不该把“减脂”翻译成一张只有跑步的课表。"
                        ),
                        LabChoice(
                            "我不知道",
                            feedback: "只看“减脂”两个字得不出完整答案。还要问她最想先改善什么，以及愿意长期做什么。"
                        ),
                    ],
                    note: "一个目标可能需要几种训练，也会受到时间、恢复和喜好的影响。"
                ),
                LabStep(
                    id: "goal-map",
                    kind: .learn,
                    title: "同一句“我想健身”，可能指向不同结果",
                    body: "力量、肌肉、心肺、体重管理和日常状态会互相帮助，但训练重点并不完全相同。先选一个四周内最想观察的变化。",
                    bullets: [
                        "力量：相同动作更稳，或逐渐能使用更大负荷",
                        "肌肉：给相关肌群足够、可恢复的练习量",
                        "心肺：同样的走、跑或骑行逐渐没有以前吃力",
                        "减脂：保留力量训练，增加可持续活动；饮食与睡眠也会参与结果",
                        "健康和习惯：从很少活动，变成能够规律出现",
                    ]
                ),
                LabStep(
                    id: "lead-goal",
                    kind: .predict,
                    title: "未来四周，你最想先看到什么变化？",
                    body: "这次选择只服务于第一版计划，以后随时可以改。",
                    choices: [
                        LabChoice("变得更有力量", feedback: "计划会优先保留稳定的力量练习和渐进记录。"),
                        LabChoice("增加肌肉", feedback: "计划会关注主要动作的每周练习量和恢复。"),
                        LabChoice("减脂或管理体重", feedback: "计划会同时保留力量、有氧和日常活动，不用惩罚式训练。"),
                        LabChoice("让心肺和体力更好", feedback: "计划会给持续有氧活动一个明确位置。"),
                        LabChoice("改善日常状态", feedback: "计划会从能稳定完成的小剂量开始。"),
                        LabChoice("重新建立运动习惯", feedback: "计划会优先降低开始的阻力，而不是填满七天。"),
                    ]
                ),
                LabStep(
                    id: "support-goal",
                    kind: .predict,
                    title: "还有哪个方向，你不想完全放掉？",
                    body: "它会成为次要目标。第一版计划会照顾它，但不会让它抢走所有时间。",
                    choices: [
                        LabChoice("力量或肌肉"),
                        LabChoice("心肺和体力"),
                        LabChoice("减脂或体重管理"),
                        LabChoice("日常状态和运动习惯"),
                        LabChoice("暂时没有次要目标"),
                    ]
                ),
                LabStep(
                    id: "availability",
                    kind: .predict,
                    title: "接下来一个月，哪种安排更像真实生活？",
                    body: "先按现在的生活来排，不按理想中的生活。",
                    choices: [
                        LabChoice("每周 2 次，每次约 30 分钟"),
                        LabChoice("每周 2–3 次，每次约 45 分钟"),
                        LabChoice("每周 3–4 次，每次约 60 分钟"),
                        LabChoice("时间经常变化，需要完整周和忙碌周"),
                        LabChoice("还不知道，先从最小版本开始"),
                    ]
                ),
                LabStep(
                    id: "evidence",
                    kind: .predict,
                    title: "四周以后，什么会让你觉得计划有用？",
                    body: "体重和外观可以记录，但训练完成度、能力和身体感受，通常会更早给出反馈。",
                    choices: [
                        LabChoice("我能完成每周计划的大部分内容"),
                        LabChoice("同样的快走或爬楼更轻松"),
                        LabChoice("我能稳定完成一次全身训练"),
                        LabChoice("两个主要动作增加了重量或次数"),
                        LabChoice("我的精力、睡眠或日常状态有改善"),
                    ]
                ),
                LabStep(
                    id: "goal-brief",
                    kind: .apply,
                    title: "这是第一版训练 brief",
                    body:
                        "接下来四周，你最想改善的是「{leadGoal}」，同时保留「{supportGoal}」。你现实中有「{availability}」，会用「{evidence}」判断计划是否值得继续。",
                    note: "明天去看场地和器械。之后每个选择都会回到这份 brief。"
                ),
            ]
        ),
        LabLesson(
            day: 2,
            code: "DAY 02 · GYM MAP",
            title: "第一次看懂健身房",
            subtitle: "认出区域，读懂一台陌生器械",
            unlock: "Machine Setup",
            symbol: "map.fill",
            steps: [
                LabStep(
                    id: "zones",
                    kind: .learn,
                    title: "先走一圈，不急着训练",
                    body: "找到有氧区、固定器械区、自由重量区和开放训练区，再记住出口、饮水处和工作人员在哪里。区域名称不代表难度。",
                    bullets: [
                        "有氧区：跑步机、单车、椭圆机或划船机",
                        "固定器械区：轨迹大多由机器引导",
                        "自由重量区：哑铃、杠铃、训练凳和深蹲架",
                        "开放训练区：垫子、弹力带、壶铃或自重空间",
                    ]
                ),
                LabStep(
                    id: "machine-read",
                    kind: .learn,
                    title: "坐上去以前，先看看它能调什么",
                    body: "找找座椅下面或侧面的拉杆，看看靠背能不能移动，再找到配重旁边的插销。不同机器的调节方式会变，但所有部件都应该在开始前卡紧。",
                    bullets: [
                        "座椅或靠背：改变身体相对把手和转轴的位置",
                        "起始位置：避免一开始就被迫进入过深范围",
                        "配重插销：完整插入一块配重，再轻拉确认",
                        "说明牌：查看动作名称、调节提示和重量单位",
                    ],
                    exerciseID: "machine-chest-press"
                ),
                LabStep(
                    id: "pin",
                    kind: .predict,
                    title: "调整配重时，插销应该停在哪里？",
                    body: "观察配重片上的孔位，再做选择。",
                    choices: [
                        LabChoice("停在两块配重之间", feedback: "插销悬在中间可能无法固定配重。把它完整插入一个孔位。"),
                        LabChoice("完整插进一块配重", feedback: "对。开始前轻拉一下，确认它已经卡紧。"),
                    ]
                ),
                LabStep(
                    id: "units",
                    kind: .explain,
                    title: "相同数字，不一定是相同重量",
                    body: "配重可能使用 kg 或 lb。换了机器以后，滑轮和结构也可能改变体感。把每台机器的重量当成自己的记录。",
                    choices: [
                        LabChoice("看到 20，就沿用上一台机器的 20", feedback: "机器、单位和动作都可能不同。先从容易控制的重量开始。"),
                        LabChoice("先看单位，再做一组轻的", feedback: "对。先观察这一台机器上的表现，再决定是否调整。"),
                    ]
                ),
                LabStep(
                    id: "discover",
                    kind: .tryIt,
                    title: "发现一台器械",
                    body: "找一台暂时没有人使用的固定器械。今天不需要正式训练，只完成一次安全设置。",
                    bullets: [
                        "找到座椅或靠背调节",
                        "看清重量单位",
                        "把插销完整插入",
                        "用最轻重量轻推或轻拉，确认没有松动",
                    ],
                    note: "不确定某个部件时，请工作人员示范。旁边有人使用时不要调节器械。"
                ),
                LabStep(
                    id: "etiquette",
                    kind: .explain,
                    title: "不知道时，可以直接问",
                    body: "有人坐在器械上休息，可以问“你好，你还剩几组？” 做完后带走个人物品，并按场馆规则擦拭接触面。",
                    bullets: [
                        "不要替下一位用户预设重量",
                        "不要在配重悬空时移动插销",
                        "不会解除安全装置时，先找工作人员",
                    ]
                ),
                LabStep(
                    id: "machine-note",
                    kind: .apply,
                    title: "保存第一台器械",
                    body: "记下器械名称、单位，以及下次使用前还要确认的设置。机器之间的数字不用互相比较。",
                    note: "Machine Collection 已开启。"
                ),
            ]
        ),
        LabLesson(
            day: 3,
            code: "DAY 03 · BUILD A HUMAN",
            title: "推和拉：认识上半身动作",
            subtitle: "用一台推和一台拉理解动作方向",
            unlock: "Push + Pull",
            symbol: "figure.strengthtraining.traditional",
            steps: [
                LabStep(
                    id: "push-human",
                    kind: .learn,
                    title: "像把一扇重门推开",
                    body: "胸大肌帮助上臂向身体前方移动，肱三头肌帮助伸直手肘，肩部也会参与。坐姿推胸本来就是多个关节和肌群一起完成的动作。",
                    note: "Body Map 会同时点亮胸部、肩前侧和肱三头肌。"
                ),
                LabStep(
                    id: "push-setup",
                    kind: .learn,
                    title: "设置坐姿推胸",
                    body: "坐下后看看把手在哪里。把手明显高过肩膀或低到腹部时，先调座椅，让它来到胸口附近。背部靠住靠垫，脚踩稳，再选择很轻的重量。",
                    bullets: [
                        "动作开始时不用追求很深的拉伸",
                        "推出时给手肘保留自然空间",
                        "回程慢一点，不让配重片撞回去",
                    ],
                    exerciseID: "machine-chest-press"
                ),
                LabStep(
                    id: "push-try",
                    kind: .observe,
                    title: "轻轻推 5 次，刚才最明显的是什么？",
                    body: "重量只用于观察，不追求疲劳。",
                    choices: [
                        LabChoice("胸和手臂一起用力", feedback: "这是常见的推。先记录，不需要追求某一块肌肉完全孤立。"),
                        LabChoice("主要是手臂累", feedback: "下一次先确认座椅和节奏，不要立刻用更大重量寻找胸感。"),
                        LabChoice("肩部不舒服", feedback: "停下来重新调节；仍不舒服就换动作。"),
                        LabChoice("整体很轻，还不太确定", feedback: "第一组能稳定完成已经足够，之后再比较。"),
                    ]
                ),
                LabStep(
                    id: "pull-human",
                    kind: .learn,
                    title: "拉的时候，让手肘靠近身体",
                    body: "背阔肌和上背部会参与把上臂拉向身体，肱二头肌帮助弯曲手肘。肩胛骨会移动，但不用在每一次拉动前把它们用力夹死。",
                    note: "Body Map 会点亮背阔肌、上背部和肱二头肌。"
                ),
                LabStep(
                    id: "pull-machine",
                    kind: .predict,
                    title: "今天哪台拉类器械有空？",
                    body: "掌握其中一台就可以。器械被占用时，换另一台不影响今天的学习。",
                    choices: [
                        LabChoice("高位下拉", feedback: "调好大腿挡板，把横杆拉向上胸附近，不拉到颈后。"),
                        LabChoice("坐姿划船", feedback: "脚踩稳，把手拉向腹部附近，避免身体前后摆动。"),
                        LabChoice("两台都没有空", feedback: "先完成原理部分，把实操留到下一次到健身房。"),
                    ]
                ),
                LabStep(
                    id: "pull-try",
                    kind: .observe,
                    title: "用轻重量拉 5 次",
                    body: "手臂参与并不代表动作失败。观察身体能否安静地完成拉动和回放。",
                    choices: [
                        LabChoice("可以平稳拉动和放回", feedback: "保留这个设置，下一次再比较重量。"),
                        LabChoice("手臂参与很多", feedback: "很常见。让手肘带动，不用把握把越捏越紧。"),
                        LabChoice("会耸肩或摆动", feedback: "减轻重量，再看看身体能否安静下来。"),
                        LabChoice("有不舒服或疼痛", feedback: "停止这台器械，不继续用负重比较。"),
                    ]
                ),
                LabStep(
                    id: "push-pull",
                    kind: .explain,
                    title: "先看重量相对身体往哪里走",
                    body: "推会把重量从身体移开；拉会让手肘和重量靠近身体。这个分类不完美，但足够用来检查基础计划有没有长期只练一个方向。",
                    choices: [
                        LabChoice("坐姿推胸属于 Push", feedback: "对。胸、肩和肱三头肌会协同完成。"),
                        LabChoice("坐姿推胸属于 Pull", feedback: "观察把手：它正在被推离身体，所以属于 Push。"),
                    ]
                ),
                LabStep(
                    id: "upper-note",
                    kind: .apply,
                    title: "保存你的 Push 和 Pull",
                    body: "把今天试过的推和拉加入动作库。下次先复用相同设置，再比较重量或次数。",
                    note: "Body Map added: Push + Pull。"
                ),
            ]
        ),
        LabLesson(
            day: 4,
            code: "DAY 04 · MOVEMENT LAB",
            title: "膝和髋：认识下半身动作",
            subtitle: "比较坐下站起和髋部后移",
            unlock: "Knee + Hip",
            symbol: "figure.squat",
            steps: [
                LabStep(
                    id: "lower-human",
                    kind: .learn,
                    title: "下半身会用不同方式解决任务",
                    body: "从站立到坐下，膝盖和髋部都会弯曲。髋部更多地向后移动时，大腿后侧和臀部会承担不同的工作。",
                    note: "膝盖可以自然弯曲，背部也不用刻意压成僵硬的直线。"
                ),
                LabStep(
                    id: "sit-stand",
                    kind: .tryIt,
                    title: "从稳定的椅子上站起 5 次",
                    body: "脚掌留在地面，使用自然站距。需要时可以用手扶住固定支撑。",
                    bullets: [
                        "观察大腿前侧、臀部或两者是否一起用力",
                        "膝盖和脚尖大致朝相近方向移动",
                        "不舒服时停止，不继续测试",
                    ]
                ),
                LabStep(
                    id: "hinge",
                    kind: .tryIt,
                    title: "用臀部关上身后的抽屉",
                    body: "双脚站稳，膝盖稍微放松。髋部向后时，上半身会自然前倾。只做到仍然舒服、能够控制的位置，重复 5 次。",
                    bullets: [
                        "观察大腿后侧是否有拉长或用力感",
                        "髋部向后时保持平衡",
                        "有不舒服时停止",
                    ],
                    exerciseID: "bodyweight-good-morning"
                ),
                LabStep(
                    id: "stance",
                    kind: .observe,
                    title: "哪个站距更稳定？",
                    body: "用自然站距做 3 次坐站，再把脚稍微放宽、脚尖自然向外，做 3 次。",
                    choices: [
                        LabChoice("自然站距更舒服", feedback: "保留自然站距。身体比例会影响你的选择。"),
                        LabChoice("稍宽一点更舒服", feedback: "保留稍宽版本，不需要继续测试极端宽度。"),
                        LabChoice("两种差不多", feedback: "选择更容易重复、也更适合场地的一种。"),
                        LabChoice("两种都不舒服", feedback: "停止比较，不继续改变站距测试极限。"),
                    ]
                ),
                LabStep(
                    id: "leg-press",
                    kind: .learn,
                    title: "把 Knee 任务放进腿举",
                    body: "先把座椅调到不拥挤的位置，双脚踩稳，腰背得到靠垫支撑。解除安全装置前，确认自己知道怎样重新锁回去。",
                    bullets: [
                        "膝盖和髋部一起弯曲",
                        "只下降到腰背仍然稳定的位置",
                        "推回时不猛地锁死膝盖",
                        "不确定安全装置时请工作人员示范",
                    ],
                    exerciseID: "leg-press"
                ),
                LabStep(
                    id: "leg-press-try",
                    kind: .observe,
                    title: "用容易控制的重量做 5 次",
                    body: "观察设置，而不是测试极限幅度。",
                    choices: [
                        LabChoice("设置顺利，动作可控", feedback: "记下座椅位置，下次从同一设置开始。"),
                        LabChoice("座椅太近，感觉很挤", feedback: "先把座椅向后调，再用轻重量测试。"),
                        LabChoice("座椅太远，动作范围很小", feedback: "向前调整一档，再确认腰背仍有支撑。"),
                        LabChoice("膝盖或腰背不舒服", feedback: "停止腿举，不继续增加幅度或重量。"),
                    ]
                ),
                LabStep(
                    id: "core",
                    kind: .explain,
                    title: "核心不会只在卷腹时工作",
                    body: "躯干在推、拉、下蹲和搬东西时都要传递力量、保持位置。腿举时稳定腰背，核心也在参与，即使腹部没有强烈酸胀。"
                ),
                LabStep(
                    id: "lower-note",
                    kind: .apply,
                    title: "保存 Knee 和 Hip",
                    body: "记录你的腿举或坐站，以及徒手髋铰链。以后换动作时，先判断它们在解决哪种任务。",
                    note: "Movement Map added: Knee + Hip。"
                ),
            ]
        ),
        LabLesson(
            day: 5,
            code: "DAY 05 · TRAINING DOSE",
            title: "重量、组数和进步",
            subtitle: "读懂一行计划，再找起始重量",
            unlock: "Sets · Reps · Rest · RIR",
            symbol: "chart.line.uptrend.xyaxis",
            steps: [
                LabStep(
                    id: "decode",
                    kind: .explain,
                    title: "Chest Press · 3 × 10 · rest 90 sec",
                    body: "先做 10 次，休息，再开始下一组，总共完成 3 组。休息会影响下一组能否继续保持重量、节奏和动作质量。",
                    choices: [
                        LabChoice("连续完成 30 次", feedback: "计划写了组间休息，所以不需要连续做 30 次。"),
                        LabChoice("10 次一组，共做 3 组", feedback: "对。组间休息也是计划的一部分。"),
                    ]
                ),
                LabStep(
                    id: "rep-range",
                    kind: .predict,
                    title: "计划写 8–12 次，第 9 次开始需要摆动",
                    body: "你会怎样记录这一组？",
                    choices: [
                        LabChoice("继续摆到 12 次", feedback: "摆动已经改变了动作。停在失控前，记录真实次数。"),
                        LabChoice("结束这一组，记录 9 次", feedback: "对。真实完成的次数比强行碰到计划数字更有用。"),
                        LabChoice("立刻加重量", feedback: "当前重量已经难以控制，下一组应该保持或减轻。"),
                    ]
                ),
                LabStep(
                    id: "rir",
                    kind: .learn,
                    title: "做完以后，估计还剩几次",
                    body: "如果保持刚才的动作范围和节奏，你大概还能做几次？这叫 RIR。它不是精确测量，刚开始估得不准很正常。",
                    bullets: [
                        "5 次以上：这是很轻的练习组",
                        "大约 2–4 次：多数初学练习可以从这里开始",
                        "只剩 0–1 次：今天先减轻",
                        "动作已经失控：结束这一组",
                    ]
                ),
                LabStep(
                    id: "weight-finder",
                    kind: .observe,
                    title: "用熟悉的器械做 8 次",
                    body: "选择一个容易控制的重量，再估计 RIR。",
                    choices: [
                        LabChoice("还能做 5 次以上", feedback: "可以把它当练习组。下一组增加最小一档，或继续练节奏。"),
                        LabChoice("大约还能做 2–4 次", feedback: "这是可用的起点。先看下一组能否保持。"),
                        LabChoice("可能只剩 0–1 次", feedback: "减轻一档。第一版计划不需要频繁逼近极限。"),
                        LabChoice("动作已经失控", feedback: "结束这一组，减轻重量或减少次数。"),
                        LabChoice("说不清", feedback: "保持重量，多做一组并记录。RIR 是在比较中学会的。"),
                    ]
                ),
                LabStep(
                    id: "rest",
                    kind: .tryIt,
                    title: "休息会改变下一组",
                    body: "完成 8 次，休息 60–90 秒，再用相同重量完成 8 次。比较两组最后两次的速度和控制。",
                    choices: [
                        LabChoice("和第一组接近", feedback: "这个休息长度暂时够用。"),
                        LabChoice("明显更吃力，但仍能控制", feedback: "疲劳在累积。可以保持，也可以延长休息。"),
                        LabChoice("动作质量下降很多", feedback: "下组多休息一会儿，或降低重量和次数。"),
                        LabChoice("休息后还没准备好", feedback: "可以继续休息。秒数不用强迫你提前开始。"),
                    ]
                ),
                LabStep(
                    id: "progression",
                    kind: .explain,
                    title: "进步不只发生在重量上",
                    body: "同一个重量从 8 次做到 12 次，动作变得更稳定，或相同训练没有以前吃力，都可以成为进步的证据。",
                    choices: [
                        LabChoice("只有每周加重量才算进步", feedback: "次数、控制和相同负荷下的体感也会变化。"),
                        LabChoice("先增加可控次数，再考虑最小加重", feedback: "这是适合第一版计划的渐进方式。"),
                    ]
                ),
                LabStep(
                    id: "dose-note",
                    kind: .apply,
                    title: "保存你的起始剂量",
                    body: "当你能完成所有计划组数和次数，动作仍然稳定，并留下大约 2–4 次余量，下次可以增加最小重量，或先保持一次。",
                    note: "睡眠差、压力大或身体状态不同的时候，保持或降低也属于正常记录。"
                ),
            ]
        ),
        LabLesson(
            day: 6,
            code: "DAY 06 · WEEK BUILDER",
            title: "力量和有氧怎么一起练",
            subtitle: "根据目标安排强度、顺序和忙碌周",
            unlock: "Weekly Map",
            symbol: "calendar.badge.plus",
            steps: [
                LabStep(
                    id: "cardio",
                    kind: .learn,
                    title: "有氧不只发生在跑步机上",
                    body: "快走、骑车、游泳、跑步、舞蹈和许多球类都可以让心率和呼吸持续上升。器械屏幕上的卡路里不决定这次活动有没有价值。",
                    note: "活动名称、持续时间和当时强度会一起决定它对心肺的要求。"
                ),
                LabStep(
                    id: "talk-test",
                    kind: .explain,
                    title: "用说话判断当下强度",
                    body: "中等强度时呼吸明显加快，但还能说出完整句子。较高强度时往往只能说几个词就需要换气。",
                    bullets: [
                        "轻强度：可以自然交谈，适合热身或恢复",
                        "中等强度：能说完整句子，但呼吸明显加快",
                        "较高强度：只能说几个词，不需要填满每次有氧",
                    ]
                ),
                LabStep(
                    id: "talk-try",
                    kind: .observe,
                    title: "活动 5 分钟，再说一句完整的话",
                    body: "可以快走、骑车、使用椭圆机或原地走动。第三分钟时判断一次。",
                    choices: [
                        LabChoice("几乎不喘，可以自然说完", feedback: "这是轻强度，可以作为热身、恢复或增加日常活动。"),
                        LabChoice("能说完，但呼吸明显加快", feedback: "这是容易持续积累的中等强度。"),
                        LabChoice("只能说几个词", feedback: "这是较高强度。新手不用拿它完成全部有氧时间。"),
                        LabChoice("有胸痛、头晕或异常呼吸困难", feedback: "立即停止，不继续强度实验。"),
                        LabChoice("今天只学习，不实操", feedback: "可以。把这一步保留到下次活动时。"),
                    ]
                ),
                LabStep(
                    id: "weekly-direction",
                    kind: .learn,
                    title: "长期方向，第一周不用立刻交满",
                    body:
                        "成年人的长期健康方向包括每周累计 150–300 分钟中等强度有氧，或 75–150 分钟高强度有氧，并在至少两天练习主要肌群。很久没有运动时可以从少量开始。",
                    note: "第一版计划首先要能完成，再逐步接近长期方向。"
                ),
                LabStep(
                    id: "weekly-template",
                    kind: .predict,
                    title: "哪种开局最接近你的现实？",
                    body: "你在 Day 1 记录了「{availability}」。现在给第一周选择一个起点。",
                    choices: [
                        LabChoice("2 次全身力量 + 2–4 个短有氧块", feedback: "适合从很少活动开始。短有氧可以从 10–20 分钟起。"),
                        LabChoice(
                            "2–3 次力量 + 每周约 90–150 分钟有氧", feedback: "适合已经有一些活动习惯的人，再根据恢复逐步增加。"),
                        LabChoice("2 次短力量 + 3 个可移动有氧块", feedback: "这是时间变化较大时的 A / B 版本。"),
                    ]
                ),
                LabStep(
                    id: "order",
                    kind: .predict,
                    title: "同一天既练力量又骑车，先做哪个？",
                    body: "先看今天最重要的目标。需要最高技术、力量或专注度的内容，放在精力更完整的时候。",
                    choices: [
                        LabChoice("力量是重点，先力量再做轻到中等有氧", feedback: "这是常见安排。较长或很累的有氧可以放到另一日。"),
                        LabChoice("正在准备跑步或骑行目标，先完成关键有氧", feedback: "可以。力量训练也可以移到另一日，或在有氧后缩短。"),
                        LabChoice("顺序必须永远固定", feedback: "顺序服务于当日重点。对初学者，先把两种活动稳定做进一周更重要。"),
                    ]
                ),
                LabStep(
                    id: "goal-match",
                    kind: .explain,
                    title: "让主要目标拿到最好的位置",
                    body: "你的主要目标是「{leadGoal}」。先保护和它最相关的训练，再让次要目标得到一个能够长期保留的位置。减脂也不需要每天做惩罚式有氧。",
                    bullets: [
                        "力量或肌肉：保护力量训练的质量和恢复",
                        "心肺：把关键有氧安排在精力较完整的时段",
                        "一般健康：同时保留全身力量和持续有氧",
                        "减脂：保留力量，选择能重复的有氧，并增加日常活动",
                    ]
                ),
                LabStep(
                    id: "busy-week",
                    kind: .apply,
                    title: "提前写好忙碌周",
                    body: "时间突然少一半时，不把所有漏掉的训练塞进同一天。保留和主要目标最相关的内容，短有氧可以在几天之间移动。",
                    choices: [
                        LabChoice("保留 2 次短力量，有氧缩成 10–20 分钟块", feedback: "这是可靠的忙碌周。时间恢复后直接回到完整版本。"),
                        LabChoice("把一周训练全部补到周末", feedback: "这会突然增加单日负担。选择最重要的内容，不用补交运动。"),
                        LabChoice("整周取消，下周重新开始", feedback: "如果还能活动，保留一个最小版本通常更容易延续习惯。"),
                    ],
                    note: "明天会把完整周和忙碌周一起保存。"
                ),
            ]
        ),
        LabLesson(
            day: 7,
            code: "FINAL LAB · 07",
            title: "排出你的第一周",
            subtitle: "先为 Alex 做选择，再完成自己的计划",
            unlock: "Gym License · Level 1",
            symbol: "checkmark.seal.fill",
            steps: []
        ),
    ]

    static func lesson(day: Int) -> LabLesson {
        lessons.first { $0.day == day } ?? lessons[0]
    }
}

import Foundation

// MARK: - Exercise library taxonomy

enum ExerciseLevel: String, CaseIterable, Identifiable, Hashable {
    case beginner
    case intermediate
    case advanced

    var id: String { rawValue }

    var label: String {
        switch self {
        case .beginner: return "入门"
        case .intermediate: return "进阶"
        case .advanced: return "挑战"
        }
    }
}

enum ExerciseCategory: String, CaseIterable, Identifiable, Hashable {
    case mobility
    case strength
    case core
    case cardio

    var id: String { rawValue }

    var label: String {
        switch self {
        case .mobility: return "热身与灵活性"
        case .strength: return "力量"
        case .core: return "核心"
        case .cardio: return "有氧"
        }
    }
}

enum MuscleGroup: String, CaseIterable, Identifiable, Hashable {
    case fullBody
    case chest
    case back
    case shoulders
    case arms
    case core
    case glutes
    case quadriceps
    case hamstrings
    case calves
    case cardio
    case mobility

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fullBody: return "全身"
        case .chest: return "胸"
        case .back: return "背"
        case .shoulders: return "肩"
        case .arms: return "手臂"
        case .core: return "核心"
        case .glutes: return "臀"
        case .quadriceps: return "大腿前侧"
        case .hamstrings: return "大腿后侧"
        case .calves: return "小腿"
        case .cardio: return "心肺"
        case .mobility: return "灵活性"
        }
    }

    static let libraryFilters: [MuscleGroup] = [
        .fullBody, .chest, .back, .shoulders, .arms, .core, .glutes, .quadriceps,
        .hamstrings, .cardio, .mobility,
    ]
}

enum ExerciseEquipment: String, CaseIterable, Identifiable, Hashable {
    case bodyweight
    case mat
    case dumbbell
    case kettlebell
    case resistanceBand
    case bench
    case barbell
    case machine
    case cable
    case pullUpBar
    case cardioMachine
    case step
    case battleRope

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bodyweight: return "自重"
        case .mat: return "瑜伽垫"
        case .dumbbell: return "哑铃"
        case .kettlebell: return "壶铃"
        case .resistanceBand: return "弹力带"
        case .bench: return "训练凳"
        case .barbell: return "杠铃"
        case .machine: return "固定器械"
        case .cable: return "龙门架"
        case .pullUpBar: return "单杠"
        case .cardioMachine: return "有氧器械"
        case .step: return "台阶"
        case .battleRope: return "战绳"
        }
    }
}

/// One reusable movement definition. A workout prescription (sets, reps and
/// weight) remains in `Exercise`; this type owns stable coaching and safety
/// knowledge shared by the library and future plan generation.
struct ExerciseDefinition: Identifiable, Hashable {
    let id: String
    let name: String
    let englishName: String
    let level: ExerciseLevel
    let category: ExerciseCategory
    let primaryMuscles: [MuscleGroup]
    var secondaryMuscles: [MuscleGroup] = []
    let equipment: Set<ExerciseEquipment>
    let supportedVenues: Set<TrainingVenue>
    let prescription: String
    let coachingTips: [String]
    let contraindications: Set<BodyCondition>
    let mascotPose: MascotPose

    /// Reserved for a future Rive/Lottie asset. The still mascot remains the
    /// honest fallback until a biomechanically reviewed animation exists.
    var animationAssetName: String { "exercise-\(id)" }

    var muscleLabel: String {
        primaryMuscles.map(\.label).joined(separator: " · ")
    }

    var equipmentLabel: String {
        equipment.map(\.label).sorted().joined(separator: " · ")
    }

    func isAvailable(for profile: UserProfile) -> Bool {
        supportedVenues.contains(profile.venue)
            && contraindications.isDisjoint(with: Set(profile.conditions))
    }
}

// MARK: - Catalog

enum ExerciseCatalog {
    static let all: [ExerciseDefinition] = [
        item(
            "cat-cow", "猫牛式", "Cat-Cow", .beginner, .mobility, [.mobility, .core],
            equipment: [.bodyweight, .mat], prescription: "6–10 次慢速循环",
            tips: ["双手放在肩膀正下方", "呼气拱背，吸气打开胸口", "只在舒适范围内活动脊柱"],
            avoid: [.wrist], pose: .stretch
        ),
        item(
            "bird-dog", "鸟狗式", "Bird Dog", .beginner, .core, [.core, .glutes],
            equipment: [.bodyweight, .mat], prescription: "3 × 8 / 侧",
            tips: ["先收紧腹部再抬手抬腿", "骨盆始终朝向地面", "手脚向远处延伸，不要追求高度"],
            avoid: [.wrist, .shoulder], pose: .point
        ),
        item(
            "dead-bug", "死虫式", "Dead Bug", .beginner, .core, [.core],
            equipment: [.bodyweight, .mat], prescription: "3 × 8 / 侧",
            tips: ["下背部轻贴地面", "对侧手脚缓慢伸直", "腰一旦拱起就缩小动作幅度"],
            avoid: [.lowBack], pose: .stretch
        ),
        item(
            "hip-flexor-stretch", "跪姿髋屈肌拉伸", "Kneeling Hip Flexor Stretch", .beginner,
            .mobility, [.mobility, .glutes], equipment: [.bodyweight, .mat],
            prescription: "30 秒 × 2 / 侧",
            tips: ["后侧膝盖垫软垫", "骨盆轻轻后卷", "身体直立向前移动，不要塌腰"],
            avoid: [.knee, .lowBack], pose: .stretch
        ),
        item(
            "wall-slide", "靠墙肩胛上滑", "Wall Slide", .beginner, .mobility,
            [.shoulders, .mobility], equipment: [.bodyweight], prescription: "2 × 10",
            tips: ["后脑和上背轻贴墙面", "肋骨保持下沉", "手臂只抬到肩部舒适的位置"],
            avoid: [.shoulder], pose: .wave
        ),
        item(
            "open-book", "侧卧开书式", "Open Book Rotation", .beginner, .mobility,
            [.mobility, .back], equipment: [.bodyweight, .mat], prescription: "2 × 8 / 侧",
            tips: ["双膝叠放固定骨盆", "上侧手臂随胸椎打开", "动作缓慢，视线跟随手指"],
            avoid: [.shoulder, .lowBack], pose: .stretch
        ),
        item(
            "bodyweight-good-morning", "徒手早安式", "Bodyweight Good Morning", .beginner,
            .mobility, [.hamstrings, .glutes], secondary: [.back], equipment: [.bodyweight],
            prescription: "2 × 12",
            tips: ["膝盖微屈，髋部向后推", "脊柱保持自然中立", "感到大腿后侧拉伸后站起"],
            avoid: [.lowBack], pose: .stretch
        ),
        item(
            "clamshell", "蚌式开合", "Clamshell", .beginner, .mobility, [.glutes],
            equipment: [.bodyweight, .mat], prescription: "3 × 15 / 侧",
            tips: ["侧卧时骨盆上下叠放", "脚跟相贴，只打开上侧膝盖", "不要为了抬高而向后翻身"],
            pose: .thumbsUp
        ),
        item(
            "goblet-squat", "高脚杯深蹲", "Goblet Squat", .beginner, .strength,
            [.quadriceps, .glutes], secondary: [.core], equipment: [.dumbbell, .kettlebell],
            prescription: "3–4 × 8–12",
            tips: ["重量贴近胸口", "膝盖朝脚尖方向移动", "髋膝同时弯曲，脚掌保持完整着地"],
            avoid: [.knee, .lowBack], pose: .dumbbell
        ),
        item(
            "box-squat", "箱式深蹲", "Box Squat", .beginner, .strength,
            [.quadriceps, .glutes], equipment: [.bodyweight, .bench], prescription: "3 × 10",
            tips: ["训练凳放在身后作为深度参照", "臀部轻触凳面，不要完全坐下放松", "站起时脚掌均匀发力"],
            avoid: [.knee, .lowBack], venues: [.gym, .home], pose: .thumbsUp
        ),
        item(
            "reverse-lunge", "后撤弓步", "Reverse Lunge", .intermediate, .strength,
            [.quadriceps, .glutes], equipment: [.bodyweight, .dumbbell], prescription: "3 × 8 / 侧",
            tips: ["向后迈步后垂直下沉", "前脚脚掌始终踩实", "前膝保持朝向第二脚趾"],
            avoid: [.knee], pose: .jogging
        ),
        item(
            "step-up", "台阶上步", "Step-Up", .intermediate, .strength,
            [.quadriceps, .glutes], equipment: [.step, .dumbbell], prescription: "3 × 10 / 侧",
            tips: ["整只脚踩稳台阶", "主要用上方腿发力站起", "下降时保持控制，不要直接落下"],
            avoid: [.knee], venues: [.gym, .outdoor], pose: .jogging
        ),
        item(
            "glute-bridge", "臀桥", "Glute Bridge", .beginner, .strength, [.glutes],
            secondary: [.hamstrings, .core], equipment: [.bodyweight, .mat],
            prescription: "4 × 12–15",
            tips: ["脚跟靠近臀部并踩稳", "先收紧腹部再抬起骨盆", "顶端夹紧臀部，不要用腰过度后仰"],
            pose: .thumbsUp
        ),
        item(
            "hip-thrust", "臀推", "Hip Thrust", .intermediate, .strength, [.glutes],
            secondary: [.hamstrings], equipment: [.bench, .barbell], prescription: "4 × 8–12",
            tips: ["肩胛下缘靠在凳边", "下巴微收，肋骨不要外翻", "顶端小腿接近垂直并夹紧臀部"],
            avoid: [.lowBack], venues: [.gym], pose: .dumbbell
        ),
        item(
            "romanian-deadlift", "罗马尼亚硬拉", "Romanian Deadlift", .intermediate,
            .strength, [.hamstrings, .glutes], secondary: [.back],
            equipment: [.dumbbell, .barbell],
            prescription: "3–4 × 8–12",
            tips: ["膝盖保持微屈", "髋部向后推，重量贴近腿部", "背部保持中立，感到腿后侧拉伸后站起"],
            avoid: [.lowBack], venues: [.gym, .home], pose: .dumbbell
        ),
        item(
            "conventional-deadlift", "传统硬拉", "Conventional Deadlift", .advanced,
            .strength, [.glutes, .hamstrings, .back], secondary: [.core], equipment: [.barbell],
            prescription: "3–5 × 3–6",
            tips: ["杠铃位于脚掌中部上方", "起拉前夹紧背部并建立腹压", "髋膝一起伸展，杠铃始终贴近身体"],
            avoid: [.lowBack, .knee], venues: [.gym], pose: .dumbbell
        ),
        item(
            "leg-press", "坐姿腿推", "Leg Press", .beginner, .strength,
            [.quadriceps, .glutes], equipment: [.machine], prescription: "3 × 10–15",
            tips: ["腰背完整贴住靠垫", "双脚与髋同宽放在踏板上", "膝盖不要锁死，也不要内扣"],
            avoid: [.knee, .lowBack], venues: [.gym], pose: .dumbbell
        ),
        item(
            "leg-curl", "坐姿腿弯举", "Seated Leg Curl", .beginner, .strength,
            [.hamstrings], equipment: [.machine], prescription: "3 × 10–15",
            tips: ["机器转轴对准膝关节", "大腿压垫固定后再发力", "弯曲和还原都保持控制"],
            avoid: [.knee], venues: [.gym], pose: .dumbbell
        ),
        item(
            "calf-raise", "站姿提踵", "Standing Calf Raise", .beginner, .strength,
            [.calves], equipment: [.bodyweight, .dumbbell], prescription: "3 × 12–20",
            tips: ["脚掌朝正前方", "抬到最高点停一秒", "下降到脚跟获得完整伸展"],
            pose: .thumbsUp
        ),
        item(
            "band-lateral-walk", "弹力带侧向走", "Band Lateral Walk", .beginner, .strength,
            [.glutes], equipment: [.resistanceBand], prescription: "3 × 10 步 / 侧",
            tips: ["弹力带保持持续张力", "髋部向后，身体微微下沉", "膝盖和脚尖始终朝向一致"],
            avoid: [.knee], pose: .jogging
        ),
        item(
            "wall-push-up", "墙壁俯卧撑", "Wall Push-Up", .beginner, .strength,
            [.chest, .arms], secondary: [.shoulders, .core], equipment: [.bodyweight],
            prescription: "3 × 10–15",
            tips: ["双手略宽于肩", "身体从头到脚保持一条直线", "胸口靠近墙面后推回"],
            avoid: [.shoulder, .wrist], pose: .point
        ),
        item(
            "incline-push-up", "上斜俯卧撑", "Incline Push-Up", .beginner, .strength,
            [.chest, .arms], secondary: [.shoulders, .core], equipment: [.bodyweight, .bench],
            prescription: "3 × 8–12",
            tips: ["双手撑在稳定的高台上", "腹部收紧，身体保持直线", "肘部与身体约成 45 度"],
            avoid: [.shoulder, .wrist], venues: [.gym, .home], pose: .point
        ),
        item(
            "push-up", "标准俯卧撑", "Push-Up", .intermediate, .strength,
            [.chest, .arms], secondary: [.shoulders, .core], equipment: [.bodyweight],
            prescription: "3 × 6–15",
            tips: ["手掌在肩部下方略宽位置", "臀部和肋骨保持收紧", "胸口接近地面后完整推起"],
            avoid: [.shoulder, .wrist, .lowBack], pose: .point
        ),
        item(
            "dumbbell-bench-press", "哑铃卧推", "Dumbbell Bench Press", .intermediate,
            .strength, [.chest], secondary: [.arms, .shoulders], equipment: [.dumbbell, .bench],
            prescription: "3–4 × 8–12",
            tips: ["肩胛向后下方收紧", "哑铃下降到胸部两侧", "手腕保持在肘部正上方"],
            avoid: [.shoulder, .wrist], venues: [.gym, .home], pose: .dumbbell
        ),
        item(
            "machine-chest-press", "坐姿推胸", "Machine Chest Press", .beginner, .strength,
            [.chest], secondary: [.arms, .shoulders], equipment: [.machine],
            prescription: "3 × 10–15",
            tips: ["座椅调到把手与胸口齐平", "肩胛贴住靠背", "推到手臂接近伸直，不要锁肘"],
            avoid: [.shoulder, .wrist], venues: [.gym], pose: .dumbbell
        ),
        item(
            "dumbbell-shoulder-press", "哑铃肩上推举", "Dumbbell Shoulder Press", .intermediate,
            .strength, [.shoulders], secondary: [.arms, .core], equipment: [.dumbbell],
            prescription: "3 × 8–12",
            tips: ["肋骨下沉，腹部收紧", "前臂保持接近垂直", "哑铃向上移动时不要耸肩"],
            avoid: [.shoulder, .wrist, .lowBack], venues: [.gym, .home], pose: .dumbbell
        ),
        item(
            "lateral-raise", "哑铃侧平举", "Dumbbell Lateral Raise", .beginner, .strength,
            [.shoulders], equipment: [.dumbbell], prescription: "3 × 12–15",
            tips: ["肘部保持轻微弯曲", "手臂向两侧抬到肩高即可", "使用轻重量，避免耸肩借力"],
            avoid: [.shoulder], venues: [.gym, .home], pose: .dumbbell
        ),
        item(
            "triceps-pressdown", "绳索下压", "Triceps Pressdown", .beginner, .strength,
            [.arms], equipment: [.cable], prescription: "3 × 10–15",
            tips: ["肘部固定在身体两侧", "只让前臂移动", "底端伸直手臂但不要锁死关节"],
            avoid: [.wrist], venues: [.gym], pose: .dumbbell
        ),
        item(
            "band-row", "弹力带划船", "Resistance Band Row", .beginner, .strength,
            [.back], secondary: [.arms, .shoulders], equipment: [.resistanceBand],
            prescription: "3 × 12–15",
            tips: ["弹力带固定点必须牢靠", "先向后下方收肩胛，再拉动手臂", "拉到肋骨两侧时不要耸肩"],
            avoid: [.shoulder], pose: .point
        ),
        item(
            "seated-cable-row", "坐姿绳索划船", "Seated Cable Row", .beginner, .strength,
            [.back], secondary: [.arms], equipment: [.cable], prescription: "3 × 10–15",
            tips: ["坐稳后保持胸口打开", "把手拉向肚脐附近", "身体不要前后大幅摇摆"],
            avoid: [.shoulder, .lowBack], venues: [.gym], pose: .dumbbell
        ),
        item(
            "lat-pulldown", "高位下拉", "Lat Pulldown", .beginner, .strength,
            [.back], secondary: [.arms], equipment: [.cable], prescription: "3 × 10–15",
            tips: ["大腿压垫固定身体", "胸口微微抬起", "将握把拉向锁骨，不要拉到颈后"],
            avoid: [.shoulder, .wrist], venues: [.gym], pose: .dumbbell
        ),
        item(
            "assisted-pull-up", "辅助引体向上", "Assisted Pull-Up", .intermediate, .strength,
            [.back], secondary: [.arms], equipment: [.machine, .pullUpBar],
            prescription: "3 × 6–10",
            tips: ["起始时先让肩胛下沉", "胸口朝向把手拉起", "缓慢下降到手臂接近伸直"],
            avoid: [.shoulder, .wrist], venues: [.gym], pose: .dumbbell
        ),
        item(
            "one-arm-dumbbell-row", "单臂哑铃划船", "One-Arm Dumbbell Row", .intermediate,
            .strength, [.back], secondary: [.arms], equipment: [.dumbbell, .bench],
            prescription: "3 × 8–12 / 侧",
            tips: ["支撑手和膝盖稳定在训练凳上", "背部保持平直", "肘部贴近身体拉向髋部"],
            avoid: [.shoulder, .wrist, .lowBack], venues: [.gym, .home], pose: .dumbbell
        ),
        item(
            "face-pull", "绳索面拉", "Face Pull", .intermediate, .strength,
            [.shoulders, .back], equipment: [.cable], prescription: "3 × 12–15",
            tips: ["绳索设置在脸部高度", "拉向眉毛两侧并打开双手", "保持肋骨下沉，不要后仰借力"],
            avoid: [.shoulder, .wrist], venues: [.gym], pose: .point
        ),
        item(
            "dumbbell-curl", "哑铃弯举", "Dumbbell Curl", .beginner, .strength,
            [.arms], equipment: [.dumbbell], prescription: "3 × 10–15",
            tips: ["肘部固定在身体两侧", "肩膀保持放松", "缓慢放下哑铃，不要甩动身体"],
            avoid: [.wrist], venues: [.gym, .home], pose: .dumbbell
        ),
        item(
            "hammer-curl", "锤式弯举", "Hammer Curl", .beginner, .strength,
            [.arms], equipment: [.dumbbell], prescription: "3 × 10–15",
            tips: ["掌心始终相对", "上臂贴近身体", "顶端停顿后控制下降"],
            avoid: [.wrist], venues: [.gym, .home], pose: .dumbbell
        ),
        item(
            "high-plank", "直臂平板支撑", "High Plank", .intermediate, .core,
            [.core], secondary: [.shoulders, .fullBody], equipment: [.bodyweight, .mat],
            prescription: "3 × 20–45 秒",
            tips: ["手掌在肩膀正下方", "从头到脚保持直线", "收紧腹部和臀部，不要塌腰"],
            avoid: [.wrist, .shoulder, .lowBack], pose: .point
        ),
        item(
            "forearm-plank", "前臂平板支撑", "Forearm Plank", .beginner, .core,
            [.core], secondary: [.shoulders], equipment: [.bodyweight, .mat],
            prescription: "3 × 20–45 秒",
            tips: ["肘部放在肩膀正下方", "脚跟向后推，头顶向前延伸", "保持正常呼吸，不要憋气"],
            avoid: [.shoulder, .lowBack], pose: .point
        ),
        item(
            "side-plank", "侧平板支撑", "Side Plank", .intermediate, .core,
            [.core], secondary: [.shoulders, .glutes], equipment: [.bodyweight, .mat],
            prescription: "3 × 20–30 秒 / 侧",
            tips: ["肘部位于肩膀正下方", "髋部向上抬起形成直线", "保持骨盆上下叠放，不要向前翻"],
            avoid: [.shoulder, .lowBack], pose: .point
        ),
        item(
            "pallof-press", "帕洛夫抗旋推", "Pallof Press", .beginner, .core,
            [.core], equipment: [.resistanceBand, .cable], prescription: "3 × 10 / 侧",
            tips: ["侧对固定点站立", "手柄从胸前水平推出", "抵抗旋转，肩膀和骨盆始终朝前"],
            avoid: [.shoulder], venues: [.gym, .home], pose: .point
        ),
        item(
            "russian-twist", "俄罗斯转体", "Russian Twist", .intermediate, .core,
            [.core], equipment: [.bodyweight, .mat], prescription: "3 × 12 / 侧",
            tips: ["坐稳后保持脊柱延展", "转动胸廓而不是只摆动双手", "动作幅度以腰部没有压力为准"],
            avoid: [.lowBack], pose: .stretch
        ),
        item(
            "mountain-climber", "登山跑", "Mountain Climber", .advanced, .core,
            [.core, .cardio], secondary: [.fullBody], equipment: [.bodyweight, .mat],
            prescription: "4 × 20–30 秒",
            tips: ["手掌在肩膀正下方", "保持骨盆稳定，膝盖向胸口交替移动", "先保证躯干稳定，再逐渐加速"],
            avoid: [.knee, .wrist, .shoulder, .lowBack], pose: .jogging
        ),
        item(
            "treadmill-walk", "跑步机快走", "Treadmill Walk", .beginner, .cardio,
            [.cardio, .fullBody], equipment: [.cardioMachine], prescription: "15–30 分钟",
            tips: ["从舒适速度开始逐步加速", "目视前方，避免长期扶住把手", "保持能说短句但略微喘的强度"],
            avoid: [.knee], venues: [.gym], pose: .jogging
        ),
        item(
            "stationary-bike", "固定单车", "Stationary Bike", .beginner, .cardio,
            [.cardio, .quadriceps], equipment: [.cardioMachine], prescription: "15–30 分钟",
            tips: ["座椅高度让膝盖在最低点仍微屈", "脚掌稳定踩住踏板", "先维持均匀转速，再增加阻力"],
            avoid: [.knee, .lowBack], venues: [.gym], pose: .jogging
        ),
        item(
            "elliptical", "椭圆机", "Elliptical Trainer", .beginner, .cardio,
            [.cardio, .fullBody], equipment: [.cardioMachine], prescription: "15–30 分钟",
            tips: ["双脚完整贴住踏板", "躯干保持直立，不要依靠把手", "保持平稳节奏，避免突然提高阻力"],
            avoid: [.knee], venues: [.gym], pose: .jogging
        ),
        item(
            "rowing-machine", "划船机", "Rowing Machine", .intermediate, .cardio,
            [.cardio, .back, .fullBody], equipment: [.cardioMachine], prescription: "10–20 分钟",
            tips: ["先蹬腿，再后倾，最后拉手柄", "回程顺序相反：手、身体、腿", "全程保持背部中立，不要含胸猛拉"],
            avoid: [.knee, .lowBack, .shoulder], venues: [.gym], pose: .jogging
        ),
        item(
            "jumping-jack", "开合跳", "Jumping Jack", .intermediate, .cardio,
            [.cardio, .fullBody], equipment: [.bodyweight], prescription: "4 × 30 秒",
            tips: ["前脚掌轻柔落地", "膝盖保持朝向脚尖", "双臂只抬到肩部舒适的位置"],
            avoid: [.knee, .shoulder, .lowBack], pose: .jogging
        ),
        item(
            "high-knees", "高抬腿跑", "High Knees", .advanced, .cardio,
            [.cardio, .quadriceps, .core], equipment: [.bodyweight], prescription: "4 × 20–30 秒",
            tips: ["躯干保持直立", "用前脚掌快速轻柔落地", "先控制节奏，再逐渐提高抬腿高度"],
            avoid: [.knee, .lowBack], pose: .jogging
        ),
        item(
            "battle-rope", "战绳交替波浪", "Battle Rope Alternating Waves", .advanced,
            .cardio, [.cardio, .fullBody], secondary: [.shoulders, .arms, .core],
            equipment: [.battleRope], prescription: "6 × 20 秒",
            tips: ["双脚站稳并保持膝盖微屈", "用手臂快速交替制造均匀波浪", "腹部收紧，避免身体前后摇晃"],
            avoid: [.shoulder, .wrist, .lowBack], venues: [.gym], pose: .dumbbell
        ),
        item(
            "farmers-carry", "农夫行走", "Farmer's Carry", .intermediate, .strength,
            [.fullBody, .core], secondary: [.arms, .shoulders],
            equipment: [.dumbbell, .kettlebell],
            prescription: "3 × 30–45 秒",
            tips: ["两侧重量保持一致", "站高并让肩胛稳定下沉", "小步直线行走，身体不要左右倾斜"],
            avoid: [.wrist, .shoulder, .lowBack], venues: [.gym, .home], pose: .dumbbell
        ),
    ]

    static func available(for profile: UserProfile) -> [ExerciseDefinition] {
        all.filter { $0.isAvailable(for: profile) }
    }

    static func exercise(id: String) -> ExerciseDefinition? {
        all.first { $0.id == id }
    }

    private static func item(
        _ id: String,
        _ name: String,
        _ englishName: String,
        _ level: ExerciseLevel,
        _ category: ExerciseCategory,
        _ muscles: [MuscleGroup],
        secondary: [MuscleGroup] = [],
        equipment: Set<ExerciseEquipment>,
        prescription: String,
        tips: [String],
        avoid: Set<BodyCondition> = [],
        venues: Set<TrainingVenue> = Set(TrainingVenue.allCases),
        pose: MascotPose
    ) -> ExerciseDefinition {
        ExerciseDefinition(
            id: id,
            name: name,
            englishName: englishName,
            level: level,
            category: category,
            primaryMuscles: muscles,
            secondaryMuscles: secondary,
            equipment: equipment,
            supportedVenues: venues,
            prescription: prescription,
            coachingTips: tips,
            contraindications: avoid,
            mascotPose: pose
        )
    }
}

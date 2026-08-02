import Foundation

// MARK: - AI style

/// Tone the coach uses. Mirrors the web spec's `type AIStyle`.
enum AIStyle: String, CaseIterable, Identifiable, Hashable {
    case gentle
    case encouraging
    case practical

    var id: String { rawValue }

    var label: String {
        switch self {
        case .gentle: return "温和"
        case .encouraging: return "鼓励"
        case .practical: return "务实"
        }
    }

    /// Shown only on tap, never persistently.
    var tooltip: String {
        switch self {
        case .gentle: return "更多安抚和状态确认"
        case .encouraging: return "更多正向反馈"
        case .practical: return "直接告诉你下一步怎么做"
        }
    }
}

// MARK: - Plan

struct Exercise: Identifiable, Hashable {
    let id: String
    let name: String
    let sets: Int
    let reps: String
    var weight: Double?
    var sideBased: Bool = false
    var alternative: String?
    /// Metadata returned by the server-backed exercise catalogue. The curated
    /// local catalogue remains the first choice; these fields keep generated
    /// plans connected when the server uses a broader movement set.
    var bodyPart: String?
    var equipment: String?
    var coachingTips: [String] = []

    /// "4 × 12" or "3 × 10 / 侧"
    var volumeLabel: String {
        sideBased ? "\(sets) × \(reps) / 侧" : "\(sets) × \(reps)"
    }

    var weightLabel: String? {
        guard let weight else { return nil }
        return "建议重量 \(Format.kg(weight))"
    }

    var libraryMuscleLabel: String? {
        if let local = ExerciseCatalog.exercise(id: id) { return local.muscleLabel }
        guard let bodyPart else { return nil }
        return Self.bodyPartLabels[bodyPart] ?? bodyPart
    }

    var libraryEquipmentLabel: String? {
        if let local = ExerciseCatalog.exercise(id: id) { return local.equipmentLabel }
        guard let equipment else { return nil }
        return Self.equipmentLabels[equipment] ?? equipment
    }

    var libraryCoachingTips: [String] {
        ExerciseCatalog.exercise(id: id)?.coachingTips ?? coachingTips
    }

    private static let bodyPartLabels: [String: String] = [
        "upper legs": "臀腿",
        "lower legs": "小腿",
        "waist": "核心",
        "chest": "胸",
        "back": "背",
        "shoulders": "肩",
        "upper arms": "手臂",
        "lower arms": "前臂",
        "cardio": "心肺",
        "neck": "颈部",
    ]

    private static let equipmentLabels: [String: String] = [
        "body weight": "自重",
        "dumbbell": "哑铃",
        "barbell": "杠铃",
        "cable": "龙门架",
        "band": "弹力带",
        "kettlebell": "壶铃",
        "leverage machine": "固定器械",
        "smith machine": "史密斯机",
        "stability ball": "健身球",
        "medicine ball": "药球",
        "elliptical machine": "椭圆机",
        "stationary bike": "固定单车",
        "assisted": "辅助器械",
    ]
}

enum SectionKind: String, Hashable {
    case warmup
    case strength
    case cardio

    var title: String {
        switch self {
        case .warmup: return "热身"
        case .strength: return "力量"
        case .cardio: return "有氧"
        }
    }

    var symbol: String {
        switch self {
        case .warmup: return "flame.fill"
        case .strength: return "dumbbell.fill"
        case .cardio: return "figure.run"
        }
    }
}

struct PlanSection: Identifiable, Hashable {
    let id: String
    let kind: SectionKind
    let duration: String
    var subtitle: String?
    var exercises: [Exercise] = []
}

struct MemoryNote: Hashable {
    let title: String
    let body: String
}

struct WorkoutPlan: Identifiable, Hashable {
    let id: String
    let title: String
    /// Short lines used on the compact cards in the library, e.g. "力量 45 分钟".
    var tags: [String] = []
    var symbol: String = "figure.strengthtraining.traditional"
    var sections: [PlanSection] = []
    var memoryNote: MemoryNote?

    var strengthExercises: [Exercise] {
        sections.first { $0.kind == .strength }?.exercises ?? []
    }
}

// MARK: - Memory

enum MemoryCategory: String, Hashable {
    case injury
    case preference
    case venue
    case equipment

    var symbol: String {
        switch self {
        case .injury: return "figure.walk.motion"
        case .preference: return "slider.horizontal.3"
        case .venue: return "mappin.and.ellipse"
        case .equipment: return "dumbbell"
        }
    }
}

struct WorkoutMemory: Identifiable, Hashable {
    let id: String
    let category: MemoryCategory
    let text: String
    var active: Bool = true
}

// MARK: - Chat

enum ChatRole: Hashable {
    case user
    case assistant
}

enum ChatMessageKind: Hashable {
    case text
    case generatedPlan
}

struct ChatMessage: Identifiable, Hashable {
    let id: String
    let role: ChatRole
    let kind: ChatMessageKind
    /// Mutable: streamed replies grow a single bubble instead of appending many.
    var content: String
    let timestamp: Date

    init(
        id: String = UUID().uuidString,
        role: ChatRole,
        kind: ChatMessageKind = .text,
        content: String,
        timestamp: Date = .now
    ) {
        self.id = id
        self.role = role
        self.kind = kind
        self.content = content
        self.timestamp = timestamp
    }
}

/// One coach line, with optional short style-specific lead-ins so the tone
/// selector actually changes what the coach says without duplicating scripts.
struct CoachLine: Hashable {
    let core: String
    var gentleLead: String?
    var encouragingLead: String?

    func rendered(for style: AIStyle) -> String {
        switch style {
        case .practical:
            return core
        case .gentle:
            return gentleLead.map { "\($0)\(core)" } ?? core
        case .encouraging:
            return encouragingLead.map { "\($0)\(core)" } ?? core
        }
    }
}

/// Side effect a scripted user turn has on the session.
enum TurnEffect: Hashable {
    /// The coach rewrites the prescription (counts as a plan adjustment).
    case reduceWeight(Double)
    /// Machine setting tweak — flags the knee, but is not a plan rewrite.
    case flattenIncline
}

struct ScriptedTurn: Identifiable, Hashable {
    let id: String
    let userText: String
    let replies: [CoachLine]
    var effect: TurnEffect?
}

// MARK: - Session state

/// The workout state machine from the spec.
enum WorkoutPhase: Hashable {
    case planning
    case strengthActive
    case strengthRest
    case strengthComplete
    case cardioActive
    case cardioComplete
    case review
}

enum InputMode: Hashable {
    case voice
    case text
}

enum VoiceState: Hashable {
    case idle
    case listening
    case processing
    case speaking

    var label: String? {
        switch self {
        case .idle: return nil
        case .listening: return "在听"
        case .processing: return "处理中"
        case .speaking: return "回应中"
        }
    }
}

// MARK: - Formatting

enum Format {
    /// 12 -> "12 kg", 12.5 -> "12.5 kg"
    static func kg(_ value: Double) -> String {
        let rounded = value.rounded()
        let number =
            abs(value - rounded) < 0.05
            ? String(Int(rounded))
            : String(format: "%.1f", value)
        return "\(number) kg"
    }

    /// 45 -> "00:45"
    static func clock(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

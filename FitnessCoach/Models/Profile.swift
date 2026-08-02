import Foundation

/// What the user tells us during the welcome flow.
///
/// Every answer becomes an AI memory, so the coach's very first session already
/// knows the goal, the venue and the bad knee — the onboarding is not a survey
/// that gets filed away, it is where the memory table starts.

// MARK: - Goal

enum TrainingGoal: String, CaseIterable, Identifiable, Hashable {
    case fatLoss
    case muscle
    case shape
    case endurance

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fatLoss: return "减脂"
        case .muscle: return "增肌"
        case .shape: return "塑形"
        case .endurance: return "体能"
        }
    }

    var detail: String {
        switch self {
        case .fatLoss: return "力量打底，配稳定有氧"
        case .muscle: return "大重量，组间休息更长"
        case .shape: return "中等重量，多次数"
        case .endurance: return "循环训练，心肺为主"
        }
    }

    var symbol: String {
        switch self {
        case .fatLoss: return "flame.fill"
        case .muscle: return "dumbbell.fill"
        case .shape: return "figure.strengthtraining.functional"
        case .endurance: return "figure.run"
        }
    }

    /// Sessions per week the plan tab measures against.
    var weeklyTarget: Int {
        switch self {
        case .fatLoss: return 5
        case .muscle, .shape: return 4
        case .endurance: return 3
        }
    }

    var memoryText: String { "训练目标：\(label)" }
}

// MARK: - Venue

enum TrainingVenue: String, CaseIterable, Identifiable, Hashable {
    case gym
    case home
    case outdoor

    var id: String { rawValue }

    var label: String {
        switch self {
        case .gym: return "健身房"
        case .home: return "家里"
        case .outdoor: return "户外"
        }
    }

    var detail: String {
        switch self {
        case .gym: return "器械齐全，动作不设限"
        case .home: return "哑铃、弹力带、自重"
        case .outdoor: return "跑步、爬坡、自重"
        }
    }

    var symbol: String {
        switch self {
        case .gym: return "mappin.and.ellipse"
        case .home: return "house.fill"
        case .outdoor: return "tree.fill"
        }
    }

    var memoryText: String { "常在\(label)训练" }
}

// MARK: - Body conditions

enum BodyCondition: String, CaseIterable, Identifiable, Hashable {
    case knee
    case lowBack
    case shoulder
    case wrist

    var id: String { rawValue }

    var label: String {
        switch self {
        case .knee: return "膝盖"
        case .lowBack: return "腰"
        case .shoulder: return "肩"
        case .wrist: return "手腕"
        }
    }

    var detail: String {
        switch self {
        case .knee: return "避免跳跃，深蹲降重量"
        case .lowBack: return "避免硬拉与大重量弯腰"
        case .shoulder: return "避免过顶推举"
        case .wrist: return "改用固定器械或护腕"
        }
    }

    var symbol: String {
        switch self {
        case .knee: return "figure.walk.motion"
        case .lowBack: return "figure.flexibility"
        case .shoulder: return "figure.arms.open"
        case .wrist: return "hand.raised.fill"
        }
    }

    var memoryText: String { "\(label)不适：\(detail)" }
}

// MARK: - Profile

/// The onboarding answers as one value. Views edit a copy; only the last step
/// writes it to storage.
struct UserProfile: Hashable {
    var goal: TrainingGoal = .fatLoss
    var venue: TrainingVenue = .gym
    var conditions: [BodyCondition] = []
    var style: AIStyle = .practical
    var equipment: [String] = []

    var weeklyTarget: Int { goal.weeklyTarget }

    /// One-line summary shown on the plan tab.
    var summary: String {
        let base = "\(goal.label) · \(venue.label)"
        guard !conditions.isEmpty else { return base }
        return "\(base) · 注意\(conditions.map(\.label).joined(separator: "、"))"
    }

    /// The memories the welcome flow seeds. Ids are stable so re-running
    /// onboarding updates the chips instead of duplicating them.
    var seedMemories: [WorkoutMemory] {
        var seeds = [
            WorkoutMemory(id: "mem-goal", category: .preference, text: goal.memoryText),
            WorkoutMemory(id: "mem-venue", category: .venue, text: venue.memoryText),
        ]
        seeds += conditions.map { condition in
            WorkoutMemory(
                id: "mem-\(condition.rawValue)",
                category: .injury,
                text: condition.memoryText
            )
        }
        seeds += equipment.map { name in
            WorkoutMemory(
                id: "mem-equipment-\(name)",
                category: .equipment,
                text: name
            )
        }
        return seeds
    }
}

// MARK: - Welcome copy

struct WelcomeHighlight: Identifiable, Hashable {
    let id: String
    let symbol: String
    let title: String
    let body: String
}

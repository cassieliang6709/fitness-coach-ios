import Foundation

struct ExerciseCatalogPageWire: Decodable {
    let items: [ExerciseCatalogItem]
    let total: Int
    let nextOffset: Int?
}

/// One row from the D1 movement catalogue. Unlike the 50 hand-curated offline
/// movements, this data does not claim a difficulty or medical safety rating.
struct ExerciseCatalogItem: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let nameZh: String?
    let bodyPart: String
    let equipment: String
    let target: String
    let secondary: [String]
    let steps: [String]

    private enum CodingKeys: String, CodingKey {
        case id, name, equipment, target, secondary, steps
        case nameZh = "name_zh"
        case bodyPart = "body_part"
    }

    var displayName: String { nameZh?.nonEmpty ?? name }

    var englishName: String {
        nameZh?.nonEmpty == nil ? "" : name
    }

    var muscleLabel: String {
        let values = [target, bodyPart]
            .map(Self.muscleLabel(for:))
            .reduce(into: [String]()) { labels, value in
                if !labels.contains(value) { labels.append(value) }
            }
        return values.joined(separator: " · ")
    }

    var equipmentLabel: String {
        Self.equipmentLabels[equipment] ?? equipment
    }

    var muscleGroups: Set<MuscleGroup> {
        Set(([target, bodyPart] + secondary).compactMap(Self.muscleGroup(for:)))
    }

    private static func muscleLabel(for value: String) -> String {
        muscleGroup(for: value)?.label ?? bodyPartLabels[value] ?? value
    }

    private static func muscleGroup(for value: String) -> MuscleGroup? {
        switch value.lowercased() {
        case "glutes": return .glutes
        case "quads", "quadriceps", "upper legs": return .quadriceps
        case "hamstrings": return .hamstrings
        case "calves", "lower legs": return .calves
        case "pectorals", "chest": return .chest
        case "lats", "spine", "upper back", "back": return .back
        case "delts", "shoulders": return .shoulders
        case "biceps", "triceps", "upper arms", "lower arms", "forearms": return .arms
        case "abs", "waist": return .core
        case "cardiovascular system", "cardio": return .cardio
        default: return nil
        }
    }

    private static let bodyPartLabels: [String: String] = [
        "upper legs": "臀腿", "lower legs": "小腿", "waist": "核心",
        "chest": "胸", "back": "背", "shoulders": "肩", "upper arms": "手臂",
        "lower arms": "前臂", "cardio": "心肺", "neck": "颈部",
    ]

    private static let equipmentLabels: [String: String] = [
        "body weight": "自重", "dumbbell": "哑铃", "barbell": "杠铃",
        "cable": "龙门架", "band": "弹力带", "kettlebell": "壶铃",
        "leverage machine": "固定器械", "smith machine": "史密斯机",
        "stability ball": "健身球", "medicine ball": "药球",
        "elliptical machine": "椭圆机", "stationary bike": "固定单车",
        "assisted": "辅助器械",
    ]
}

private extension String {
    var nonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

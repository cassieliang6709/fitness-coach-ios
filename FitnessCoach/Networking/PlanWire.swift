import Foundation

/// A plan as the Worker sends it.
///
/// The backend stores a flat, ordered item list; the app renders sections. The
/// translation lives here so neither side has to know the other's shape.
///
/// Two wire dialects land in this type. `GET /plan` returns rows joined against
/// the catalogue (`exerciseID`, `weightKg`), while the `plan` SSE event returns
/// the validated tool input (`exercise_id`, `weight_kg`). Both are decoded by
/// `PlanItemWire` rather than duplicating the mapping.
struct PlanWire: Codable {
    let id: String?
    let title: String
    let summary: String?
    let createdAt: String?
    let items: [PlanItemWire]
}

extension PlanWire {
    /// `GET /plan` includes the server timestamp. Tool-streamed plans do not,
    /// but they were generated in the current turn and are therefore current.
    var wasCreatedToday: Bool {
        guard let createdAt, let date = ISO8601DateFormatter().date(from: createdAt) else {
            return true
        }
        return Calendar.current.isDateInToday(date)
    }
}

struct PlanItemWire: Codable {
    let exerciseID: String
    let name: String
    let section: String
    let sets: Int
    let reps: String
    let weightKg: Double?
    let note: String?
    let bodyPart: String?
    let equipment: String?
    let steps: [String]

    private enum CodingKeys: String, CodingKey {
        case exerciseID, name, section, sets, reps, weightKg, note, bodyPart, equipment, steps
        case exerciseIDSnake = "exercise_id"
        case weightKgSnake = "weight_kg"
        case bodyPartSnake = "body_part"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.section = try container.decode(String.self, forKey: .section)
        self.sets = try container.decode(Int.self, forKey: .sets)
        self.reps = try container.decode(String.self, forKey: .reps)
        self.note = try container.decodeIfPresent(String.self, forKey: .note)
        self.equipment = try container.decodeIfPresent(String.self, forKey: .equipment)
        self.steps = try container.decodeIfPresent([String].self, forKey: .steps) ?? []

        if let camel = try container.decodeIfPresent(String.self, forKey: .bodyPart) {
            self.bodyPart = camel
        } else {
            self.bodyPart = try container.decodeIfPresent(String.self, forKey: .bodyPartSnake)
        }

        if let camel = try container.decodeIfPresent(String.self, forKey: .exerciseID) {
            self.exerciseID = camel
        } else {
            self.exerciseID = try container.decode(String.self, forKey: .exerciseIDSnake)
        }

        if let camel = try container.decodeIfPresent(Double.self, forKey: .weightKg) {
            self.weightKg = camel
        } else {
            self.weightKg = try container.decodeIfPresent(Double.self, forKey: .weightKgSnake)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(exerciseID, forKey: .exerciseID)
        try container.encode(name, forKey: .name)
        try container.encode(section, forKey: .section)
        try container.encode(sets, forKey: .sets)
        try container.encode(reps, forKey: .reps)
        try container.encodeIfPresent(weightKg, forKey: .weightKg)
        try container.encodeIfPresent(note, forKey: .note)
        try container.encodeIfPresent(bodyPart, forKey: .bodyPart)
        try container.encodeIfPresent(equipment, forKey: .equipment)
        if !steps.isEmpty { try container.encode(steps, forKey: .steps) }
    }
}

extension PlanWire {
    private struct Envelope: Decodable { let plan: PlanWire? }

    /// `GET /plan` wraps the plan in `{ "plan": … }`; the SSE `plan` event sends
    /// it bare. Accepting both lets the cache store whichever arrived without
    /// normalising it first.
    static func decode(_ data: Data) -> PlanWire? {
        let decoder = JSONDecoder()
        if let envelope = try? decoder.decode(Envelope.self, from: data) {
            return envelope.plan
        }
        return try? decoder.decode(PlanWire.self, from: data)
    }
}

// MARK: - Wire → domain

extension PlanWire {
    /// Nil when the plan carries no usable strength work. The coaching flow
    /// indexes into `strengthExercises`, so an empty one would be a crash
    /// rather than an empty state — better to keep the previous plan.
    var asPlan: WorkoutPlan? {
        let sections = Self.sectionOrder.compactMap { kind in
            section(kind, from: items.filter { $0.section == kind.rawValue })
        }
        guard sections.contains(where: { $0.kind == .strength && !$0.exercises.isEmpty })
        else { return nil }

        return WorkoutPlan(
            id: id ?? "generated",
            title: title,
            tags: Self.tags(for: sections),
            sections: sections,
            memoryNote: summary.map { MemoryNote(title: "为什么这样排", body: $0) }
        )
    }

    private static let sectionOrder: [SectionKind] = [.warmup, .strength, .cardio]

    private func section(_ kind: SectionKind, from items: [PlanItemWire]) -> PlanSection? {
        guard !items.isEmpty else { return nil }
        return PlanSection(
            id: kind.rawValue,
            kind: kind,
            duration: Self.duration(kind: kind, items: items),
            subtitle: kind == .strength ? nil : items.map(\.name).joined(separator: " · "),
            exercises: items.map(\.asExercise)
        )
    }

    /// Estimated from volume — the backend stores sets and reps, not minutes.
    /// A set plus its rest runs about a minute; warm-up and cardio are paced by
    /// their reps field instead, so they get a flat estimate per movement.
    private static func duration(kind: SectionKind, items: [PlanItemWire]) -> String {
        switch kind {
        case .strength:
            return "\(items.reduce(0) { $0 + $1.sets }) 组"
        case .warmup:
            return "\(max(5, items.count * 3)) 分钟"
        case .cardio:
            let explicitMinutes = items.compactMap { minutes(from: $0.reps) }.reduce(0, +)
            if explicitMinutes > 0 { return "\(explicitMinutes) 分钟" }
            return "\(max(10, items.count * 15)) 分钟"
        }
    }

    private static func minutes(from prescription: String) -> Int? {
        guard prescription.contains("分钟"), !prescription.contains("秒") else { return nil }
        return prescription.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }.first
    }

    private static func tags(for sections: [PlanSection]) -> [String] {
        sections.map { "\($0.kind.title) \($0.duration)" }
    }
}

extension PlanItemWire {
    var asExercise: Exercise {
        Exercise(
            id: exerciseID,
            name: name.isEmpty ? exerciseID : name,
            sets: sets,
            reps: reps,
            weight: weightKg,
            alternative: note,
            bodyPart: bodyPart,
            equipment: equipment,
            coachingTips: steps
        )
    }
}

import Foundation
import SwiftData

/// What the coach remembers about the user between sessions. This is the table
/// that makes "AI 记住你" true rather than a slogan.
@Model
final class MemoryRecord {
    @Attribute(.unique) var id: String
    var categoryRaw: String
    var text: String
    var active: Bool
    var createdAt: Date
    var updatedAt: Date
    /// Which session produced this memory, if it was learned during training.
    var sourceSessionID: String?

    init(
        id: String = UUID().uuidString,
        category: MemoryCategory,
        text: String,
        active: Bool = true,
        createdAt: Date = .now,
        sourceSessionID: String? = nil
    ) {
        self.id = id
        self.categoryRaw = category.rawValue
        self.text = text
        self.active = active
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.sourceSessionID = sourceSessionID
    }

    var category: MemoryCategory {
        get { MemoryCategory(rawValue: categoryRaw) ?? .preference }
        set { categoryRaw = newValue.rawValue }
    }

    var asMemory: WorkoutMemory {
        WorkoutMemory(id: id, category: category, text: text, active: active)
    }
}

/// The welcome flow's answers. Its existence is also the "has this user been
/// onboarded" flag — one row, id `me`.
@Model
final class ProfileRecord {
    @Attribute(.unique) var id: String
    var goalRaw: String
    var venueRaw: String
    var conditionRaws: [String]
    var aiStyleRaw: String
    var weeklyTarget: Int
    var createdAt: Date
    var updatedAt: Date

    static let singletonID = "me"

    init(id: String = ProfileRecord.singletonID, profile: UserProfile, createdAt: Date = .now) {
        self.id = id
        self.goalRaw = profile.goal.rawValue
        self.venueRaw = profile.venue.rawValue
        self.conditionRaws = profile.conditions.map(\.rawValue)
        self.aiStyleRaw = profile.style.rawValue
        self.weeklyTarget = profile.weeklyTarget
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    var asProfile: UserProfile {
        UserProfile(
            goal: TrainingGoal(rawValue: goalRaw) ?? .fatLoss,
            venue: TrainingVenue(rawValue: venueRaw) ?? .gym,
            conditions: conditionRaws.compactMap(BodyCondition.init(rawValue:)),
            style: AIStyle(rawValue: aiStyleRaw) ?? .practical
        )
    }

    func apply(_ profile: UserProfile) {
        goalRaw = profile.goal.rawValue
        venueRaw = profile.venue.rawValue
        conditionRaws = profile.conditions.map(\.rawValue)
        aiStyleRaw = profile.style.rawValue
        weeklyTarget = profile.weeklyTarget
        updatedAt = .now
    }
}

/// One training session. Closed out when the user reaches the review.
@Model
final class SessionRecord {
    @Attribute(.unique) var id: String
    var planID: String
    var planTitle: String
    var startedAt: Date
    var endedAt: Date?
    var aiStyleRaw: String
    var plannedSetCount: Int
    var adjustmentCount: Int
    var cardioSeconds: Int
    var cardioTargetMinutes: Int

    @Relationship(deleteRule: .cascade, inverse: \SetLogRecord.session)
    var setLogs: [SetLogRecord] = []

    init(
        id: String = UUID().uuidString,
        planID: String,
        planTitle: String,
        startedAt: Date = .now,
        aiStyle: AIStyle,
        plannedSetCount: Int,
        cardioTargetMinutes: Int
    ) {
        self.id = id
        self.planID = planID
        self.planTitle = planTitle
        self.startedAt = startedAt
        self.aiStyleRaw = aiStyle.rawValue
        self.plannedSetCount = plannedSetCount
        self.adjustmentCount = 0
        self.cardioSeconds = 0
        self.cardioTargetMinutes = cardioTargetMinutes
    }

    var durationMinutes: Int {
        let end = endedAt ?? .now
        return max(1, Int(end.timeIntervalSince(startedAt) / 60))
    }

    /// Stable id of the bundled walkthrough plan. Records created from it are
    /// useful in explicit demo mode, but must not count as real user history.
    var isSamplePlan: Bool { planID == "leg-day" }

    /// Logged sets over planned sets — the same honest number the review shows.
    var completionPercent: Int {
        guard plannedSetCount > 0 else { return 0 }
        return Int((Double(setLogs.count) / Double(plannedSetCount) * 100).rounded())
    }
}

/// One completed set. The unit of truth for "what did the user actually do".
@Model
final class SetLogRecord {
    var exerciseID: String
    var exerciseName: String
    var setNumber: Int
    var reps: String
    var weight: Double?
    var completedAt: Date
    var session: SessionRecord?

    init(
        exerciseID: String,
        exerciseName: String,
        setNumber: Int,
        reps: String,
        weight: Double?,
        completedAt: Date = .now
    ) {
        self.exerciseID = exerciseID
        self.exerciseName = exerciseName
        self.setNumber = setNumber
        self.reps = reps
        self.weight = weight
        self.completedAt = completedAt
    }
}

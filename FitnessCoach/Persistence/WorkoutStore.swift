import Foundation
import SwiftData

/// Thin facade over SwiftData so views and `WorkoutSession` never touch
/// `ModelContext` directly — and so swapping local storage for a synced
/// backend later is one file, not fifty call sites.
@MainActor
final class WorkoutStore {

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Container

    static let schema = Schema([
        MemoryRecord.self,
        EquipmentRecord.self,
        GymLocationRecord.self,
        GymVisionTimingRecord.self,
        ProfileRecord.self,
        SessionRecord.self,
        SetLogRecord.self,
    ])

    /// In-memory containers keep UI tests isolated from the user's real data.
    static func makeContainer(inMemory: Bool) -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            // Storage is unusable (corrupt store, no disk). Fall back to memory
            // rather than refusing to launch.
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: fallback)
        }
    }

    // MARK: - Profile

    /// A profile row means the welcome flow has been completed. No row means a
    /// brand new user, and the app opens on onboarding.
    var hasProfile: Bool {
        (try? context.fetchCount(FetchDescriptor<ProfileRecord>())) ?? 0 > 0
    }

    func profile() -> UserProfile? {
        let singletonID = ProfileRecord.singletonID
        let descriptor = FetchDescriptor<ProfileRecord>(
            predicate: #Predicate { $0.id == singletonID }
        )
        return (try? context.fetch(descriptor).first)?.asProfile
    }

    var weeklyTarget: Int { profile()?.weeklyTarget ?? 4 }

    /// Closes the welcome flow: stores the answers and turns each one into a
    /// memory chip, so the coach starts already knowing this user.
    func completeOnboarding(_ profile: UserProfile) {
        let singletonID = ProfileRecord.singletonID
        let descriptor = FetchDescriptor<ProfileRecord>(
            predicate: #Predicate { $0.id == singletonID }
        )
        if let existing = try? context.fetch(descriptor).first {
            existing.apply(profile)
        } else {
            context.insert(ProfileRecord(profile: profile))
        }

        for memory in profile.seedMemories {
            upsertMemory(
                id: memory.id,
                category: memory.category,
                text: memory.text,
                sourceSessionID: nil
            )
        }
        save()
    }

    /// Demo / UI-test shortcut: a finished profile plus the baseline memories,
    /// so deep links can skip straight past the welcome flow.
    func seedDemoProfileIfNeeded() {
        guard !hasProfile else { return }
        completeOnboarding(
            UserProfile(goal: .fatLoss, venue: .gym, conditions: [.knee], style: .practical)
        )
        for memory in MockData.memories {
            upsertMemory(
                id: memory.id,
                category: memory.category,
                text: memory.text,
                sourceSessionID: nil
            )
        }
    }

    // MARK: - Memories

    func activeMemories() -> [MemoryRecord] {
        let descriptor = FetchDescriptor<MemoryRecord>(
            predicate: #Predicate { $0.active },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Upserts by id so a repeated observation updates rather than piles up.
    func upsertMemory(
        id: String,
        category: MemoryCategory,
        text: String,
        sourceSessionID: String?
    ) {
        let descriptor = FetchDescriptor<MemoryRecord>(predicate: #Predicate { $0.id == id })
        if let existing = try? context.fetch(descriptor).first {
            existing.text = text
            existing.updatedAt = .now
            existing.active = true
            existing.sourceSessionID = sourceSessionID
        } else {
            context.insert(
                MemoryRecord(
                    id: id,
                    category: category,
                    text: text,
                    sourceSessionID: sourceSessionID
                )
            )
        }
        save()
    }

    func updateMemory(id: String, category: MemoryCategory, text: String) {
        let descriptor = FetchDescriptor<MemoryRecord>(predicate: #Predicate { $0.id == id })
        guard let record = try? context.fetch(descriptor).first else { return }
        record.category = category
        record.text = text
        record.updatedAt = .now
        save()
    }

    func deactivateMemory(id: String) {
        let descriptor = FetchDescriptor<MemoryRecord>(predicate: #Predicate { $0.id == id })
        guard let record = try? context.fetch(descriptor).first else { return }
        record.active = false
        record.updatedAt = .now
        save()
    }

    /// Persists an authorized location as soon as the camera flow captures it,
    /// even if the later network image recognition fails.
    func recordGymLocation(_ snapshot: GymLocationSnapshot) {
        _ = upsertGymLocation(snapshot)
        save()
    }

    func recordGymVisionTiming(_ timing: GymVisionTiming) {
        context.insert(GymVisionTimingRecord(timing: timing))
        save()
    }

    /// Saves the factual photo observation and its user-authorized location.
    /// The paired memory chips are just a compact, editable projection of
    /// these tables for the planning UI and the coach prompt.
    func recordGymObservation(
        equipment: [GymVisionResult.Equipment],
        location: GymLocationSnapshot?
    ) {
        let locationID = location.map { ensureGymLocation($0) }
        for item in equipment {
            let normalizedName = item.name
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .lowercased()
            let id = "equipment-\(normalizedName.replacingOccurrences(of: " ", with: "-"))"
            let descriptor = FetchDescriptor<EquipmentRecord>(predicate: #Predicate { $0.id == id })
            if let existing = try? context.fetch(descriptor).first {
                existing.confidence = item.confidence
                existing.visibleEvidence = item.visibleEvidence
                existing.lastObservedAt = .now
                existing.observationCount += 1
                existing.lastLocationID = locationID
            } else {
                context.insert(EquipmentRecord(
                    id: id,
                    name: item.name,
                    confidence: item.confidence,
                    visibleEvidence: item.visibleEvidence,
                    locationID: locationID
                ))
            }
            // Older builds stored one memory for every device. Once this
            // observation is merged below, hide those legacy fragments.
            deactivateMemory(id: "memory-\(id)")
        }
        if let location, let locationID, let placeName = location.displayName {
            let equipmentNames = equipmentAtLocation(locationID)
            upsertMemory(
                id: "memory-gym-\(locationID)",
                category: .equipment,
                text: "\(placeName) · \(equipmentNames.joined(separator: "、"))",
                sourceSessionID: nil
            )
            deactivateMemory(id: "memory-venue-\(locationID)")
        }
        save()
    }

    // MARK: - Sessions

    func createSession(
        plan: WorkoutPlan,
        aiStyle: AIStyle,
        plannedSetCount: Int,
        cardioTargetMinutes: Int
    ) -> SessionRecord {
        let record = SessionRecord(
            planID: plan.id,
            planTitle: plan.title,
            aiStyle: aiStyle,
            plannedSetCount: plannedSetCount,
            cardioTargetMinutes: cardioTargetMinutes
        )
        context.insert(record)
        save()
        return record
    }

    func log(
        set setNumber: Int,
        of exercise: Exercise,
        weight: Double?,
        to session: SessionRecord
    ) {
        let log = SetLogRecord(
            exerciseID: exercise.id,
            exerciseName: exercise.name,
            setNumber: setNumber,
            reps: exercise.reps,
            weight: weight
        )
        log.session = session
        context.insert(log)
        save()
    }

    func finish(_ session: SessionRecord, adjustments: Int, cardioSeconds: Int) {
        session.endedAt = .now
        session.adjustmentCount = adjustments
        session.cardioSeconds = cardioSeconds
        save()
    }

    func recentSessions(limit: Int = 10) -> [SessionRecord] {
        var descriptor = FetchDescriptor<SessionRecord>(
            predicate: #Predicate { $0.endedAt != nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Deletes everything. Used by UI tests and the debug reset.
    func wipe() {
        try? context.delete(model: EquipmentRecord.self)
        try? context.delete(model: GymLocationRecord.self)
        try? context.delete(model: GymVisionTimingRecord.self)
        try? context.delete(model: SetLogRecord.self)
        try? context.delete(model: SessionRecord.self)
        try? context.delete(model: MemoryRecord.self)
        try? context.delete(model: ProfileRecord.self)
        save()
    }

    // MARK: - Internals

    private func save() {
        guard context.hasChanges else { return }
        try? context.save()
    }

    private func upsertGymLocation(_ snapshot: GymLocationSnapshot) -> String {
        // ~11 m precision keeps repeat visits to one gym together without
        // storing a falsely exact, constantly changing GPS identity.
        let id = gymLocationID(snapshot)
        let descriptor = FetchDescriptor<GymLocationRecord>(predicate: #Predicate { $0.id == id })
        if let existing = try? context.fetch(descriptor).first {
            existing.horizontalAccuracy = snapshot.horizontalAccuracy
            if let placeName = snapshot.displayName { existing.placeName = placeName }
            existing.lastObservedAt = snapshot.capturedAt
            existing.observationCount += 1
        } else {
            context.insert(GymLocationRecord(id: id, snapshot: snapshot))
        }
        return id
    }

    private func equipmentAtLocation(_ locationID: String) -> [String] {
        let records = (try? context.fetch(FetchDescriptor<EquipmentRecord>())) ?? []
        var seen = Set<String>()
        return records
            .filter { $0.lastLocationID == locationID }
            .map(\.name)
            .filter { seen.insert($0).inserted }
    }

    private func ensureGymLocation(_ snapshot: GymLocationSnapshot) -> String {
        let id = gymLocationID(snapshot)
        let descriptor = FetchDescriptor<GymLocationRecord>(predicate: #Predicate { $0.id == id })
        if (try? context.fetch(descriptor).first) == nil {
            context.insert(GymLocationRecord(id: id, snapshot: snapshot))
        }
        return id
    }

    private func gymLocationID(_ snapshot: GymLocationSnapshot) -> String {
        String(format: "gym-%.4f-%.4f", snapshot.latitude, snapshot.longitude)
    }
}

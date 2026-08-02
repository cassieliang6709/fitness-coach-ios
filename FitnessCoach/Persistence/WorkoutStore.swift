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

    // MARK: - Memories

    /// Seeds the baseline profile on first launch only.
    func seedMemoriesIfNeeded() {
        let existing = (try? context.fetchCount(FetchDescriptor<MemoryRecord>())) ?? 0
        guard existing == 0 else { return }
        for memory in MockData.memories {
            context.insert(
                MemoryRecord(id: memory.id, category: memory.category, text: memory.text)
            )
        }
        save()
    }

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
        try? context.delete(model: SetLogRecord.self)
        try? context.delete(model: SessionRecord.self)
        try? context.delete(model: MemoryRecord.self)
        save()
    }

    // MARK: - Internals

    private func save() {
        guard context.hasChanges else { return }
        try? context.save()
    }
}

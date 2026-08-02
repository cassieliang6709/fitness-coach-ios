import Foundation
import Observation

/// Single source of truth for one training session: plan, phase machine, live
/// numbers and the two coaching threads.
///
/// Progress is tracked per exercise *and* per set — the review reports only
/// what was actually logged, never what was merely planned.
@MainActor
@Observable
final class WorkoutSession {

    // MARK: - Plan & preferences

    let plan = MockData.legDayPlan

    var aiStyle: AIStyle = .practical {
        didSet {
            daily.style = aiStyle
            strength.style = aiStyle
            cardio.style = aiStyle
        }
    }

    // MARK: - Phase

    private(set) var phase: WorkoutPhase = .planning

    // MARK: - Strength progress

    var exercises: [Exercise] { plan.strengthExercises }

    private(set) var exerciseIndex = 0
    private(set) var currentSet = 1
    /// Coach-driven weight changes, keyed by exercise id.
    private(set) var weightOverrides: [String: Double] = [:]
    /// Coach-driven exercise substitutions, keyed by the original exercise id.
    private(set) var swappedExercises: [String: String] = [:]
    /// Every set the user actually finished.
    private(set) var completedSets: [CompletedSet] = []
    private(set) var restRemaining = 0
    private(set) var justCompletedSet = false

    var currentExercise: Exercise {
        exercises[min(exerciseIndex, exercises.count - 1)]
    }

    /// What the card shows — the substitution if the coach made one.
    var currentExerciseName: String {
        swappedExercises[currentExercise.id] ?? currentExercise.name
    }

    var currentWeight: Double? {
        weightOverrides[currentExercise.id] ?? currentExercise.weight
    }

    var plannedSetCount: Int {
        exercises.reduce(0) { $0 + $1.sets }
    }

    var completedSetsForCurrentExercise: Int {
        completedSets.filter { $0.exerciseID == currentExercise.id }.count
    }

    // MARK: - Cardio progress

    private(set) var cardioSeconds = 0
    let cardioTarget = MockData.cardioTargetMinutes

    // MARK: - Memory outcomes

    private(set) var kneeReported = false
    private(set) var adjustmentCount = 0

    // MARK: - Threads

    /// The home tab's conversation: planning, questions, "今天时间不多". It is
    /// created once and deliberately survives `reset()` — finishing a workout
    /// shouldn't wipe the chat the user has been having with their coach.
    private(set) var daily: CoachThread!
    private(set) var strength: CoachThread!
    private(set) var cardio: CoachThread!

    // MARK: - Persistence

    private let store: WorkoutStore
    private var record: SessionRecord?
    private(set) var startedAt = Date.now

    private var restTask: Task<Void, Never>?
    private var cardioTask: Task<Void, Never>?

    /// One recognizer for all three threads — only one page listens at a time,
    /// and each instance owns an audio engine.
    private let speech = WorkoutSession.makeSpeech()

    init(store: WorkoutStore) {
        self.store = store
        makeDailyThread()
        makeThreads()
        // After the threads exist: `aiStyle`'s observer fans out to all three.
        aiStyle = store.profile()?.style ?? .practical
    }

    /// Live coach when configured, nil in demo / UI-test mode.
    private static func makeAPI() -> CoachAPI? {
        if ProcessInfo.processInfo.arguments.contains("-uitest") { return nil }
        return CoachAPI.fromBundle()
    }

    /// Realtime is optional so the existing Claude SSE and scripted flows keep
    /// working on simulators, UI tests, and builds without gateway settings.
    private static func makeRealtime() -> RealtimeCoachClient? {
        if ProcessInfo.processInfo.arguments.contains("-uitest") { return nil }
        guard let config = VanceGatewayConfig.fromBundle() else { return nil }
        return RealtimeCoachClient(config: config)
    }

    private static func makeVision() -> GymVisionAPI? {
        if ProcessInfo.processInfo.arguments.contains("-uitest") { return nil }
        guard let config = VanceGatewayConfig.fromBundle() else { return nil }
        return GymVisionAPI(config: config)
    }

    private static func makeMemorySummarizer() -> MemorySummaryAPI? {
        if ProcessInfo.processInfo.arguments.contains("-uitest") { return nil }
        guard let config = VanceGatewayConfig.fromBundle() else { return nil }
        return MemorySummaryAPI(config: config)
    }

    private func makeDailyThread() {
        daily = CoachThread(
            opening: MockData.homeOpening,
            script: MockData.homeScript,
            onEffect: { [weak self] effect in self?.handle(effect) }
        )
        // The home tab is read-and-type, not hands-busy — start on the keyboard.
        daily.inputMode = .text
        configure(daily, phase: "planning")
    }

    /// Nil in UI tests and on the simulator, where there's no usable mic —
    /// the scripted voice turns take over.
    private static func makeSpeech() -> SpeechRecognizer? {
        if ProcessInfo.processInfo.arguments.contains("-uitest") { return nil }
        #if targetEnvironment(simulator)
        return nil
        #else
        return SpeechRecognizer()
        #endif
    }

    private func makeThreads() {
        strength = CoachThread(
            opening: MockData.strengthOpening,
            script: MockData.strengthScript,
            onEffect: { [weak self] effect in self?.handle(effect) }
        )
        cardio = CoachThread(
            opening: MockData.cardioOpening,
            script: MockData.cardioScript,
            onEffect: { [weak self] effect in self?.handle(effect) }
        )
        configure(strength, phase: "strength")
        configure(cardio, phase: "cardio")
    }

    private func configure(_ thread: CoachThread, phase: String) {
        thread.style = aiStyle
        thread.api = Self.makeAPI()
        if let realtime = Self.makeRealtime() {
            thread.configureRealtime(realtime)
        }
        if let vision = Self.makeVision() {
            thread.configureVision(vision)
        }
        if let summarizer = Self.makeMemorySummarizer() {
            thread.configureMemorySummarizer(summarizer)
        }
        thread.speech = speech
        thread.memoryProvider = { [weak self] in
            self?.store.activeMemories().map(\.text) ?? []
        }
        // Location records stay on-device. Kimi does not need them to decide
        // whether a new preference or injury fact duplicates an old memory.
        thread.memorySummaryProvider = { [weak self] in
            self?.store.activeMemories()
                .filter { $0.category != .venue }
                .map(\.text) ?? []
        }
        thread.memoryUpdateHandler = { [weak self] updates in
            guard let self else { return }
            for update in updates {
                switch update.operation {
                case .upsert:
                    self.store.upsertMemory(
                        id: "kimi-\(update.id)",
                        category: update.category,
                        text: update.text,
                        sourceSessionID: self.record?.id
                    )
                }
            }
        }
        thread.gymObservationHandler = { [weak self] result, location in
            self?.store.recordGymObservation(equipment: result.equipment, location: location)
        }
        thread.gymLocationHandler = { [weak self] location in
            self?.store.recordGymLocation(location)
        }
        thread.contextProvider = { [weak self] in
            self?.coachContext(phase: phase)
                ?? CoachContext(phase: phase, exercise: "-", prescription: "-")
        }
        thread.actionHandler = { [weak self] action in
            self?.perform(action) ?? "无法执行。"
        }
    }

    /// Snapshot of what the user is doing right now, sent with every turn.
    private func coachContext(phase: String) -> CoachContext {
        if phase == "planning" {
            return CoachContext(
                phase: "planning",
                exercise: plan.title,
                prescription: plan.tags.joined(separator: " · "),
                venue: MockData.strengthVenue
            )
        }
        if phase == "cardio" {
            return CoachContext(
                phase: "cardio",
                exercise: MockData.cardioName,
                prescription: MockData.cardioPrescription,
                elapsedMinutes: cardioElapsedMinutes,
                targetMinutes: cardioTarget
            )
        }
        return CoachContext(
            phase: "strength",
            exercise: currentExerciseName,
            prescription: strengthMetrics,
            setNumber: currentSet,
            totalSets: currentExercise.sets,
            venue: MockData.strengthVenue
        )
    }

    /// Executes a coach action and returns the tool result the model reads next.
    private func perform(_ action: CoachAction) -> String {
        switch action {
        case .adjustWeight(let kg, _):
            guard kg > 0, kg < 500 else { return "重量不合理，未改动。" }
            weightOverrides[currentExercise.id] = kg
            kneeReported = true
            adjustmentCount += 1
            return "已把\(currentExercise.name)改为 \(Format.kg(kg))，下一组生效。"

        case .swapExercise(let replacement, _):
            swappedExercises[currentExercise.id] = replacement
            adjustmentCount += 1
            return "已把\(currentExercise.name)替换为\(replacement)。"

        case .remember(let category, let text):
            store.upsertMemory(
                id: "mem-\(category.rawValue)-\(abs(text.hashValue))",
                category: category,
                text: text,
                sourceSessionID: record?.id
            )
            if category == .injury { kneeReported = true }
            return "已记住：\(text)"
        }
    }

    // MARK: - Derived labels

    var strengthMetrics: String {
        let load = currentWeight.map(Format.kg) ?? "自重"
        let reps =
            currentExercise.sideBased
            ? "\(currentExercise.reps) 次 / 侧"
            : "\(currentExercise.reps) 次"
        return "\(load) · \(reps)"
    }

    var setProgressLabel: String { "第 \(currentSet) / \(currentExercise.sets) 组" }

    var exerciseProgressLabel: String {
        "动作 \(min(exerciseIndex + 1, exercises.count)) / \(exercises.count)"
    }

    var cardioElapsedMinutes: Int { cardioSeconds / 60 }

    var cardioProgressLabel: String { "已完成 \(cardioElapsedMinutes) / \(cardioTarget) 分钟" }

    var cardioProgress: Double {
        min(1, Double(cardioSeconds) / Double(cardioTarget * 60))
    }

    var isResting: Bool { phase == .strengthRest }

    /// Real elapsed time, not a constant.
    var durationMinutes: Int {
        max(1, Int(Date.now.timeIntervalSince(startedAt) / 60))
    }

    /// Real completion: logged sets over planned sets.
    var completionPercent: Int {
        guard plannedSetCount > 0 else { return 0 }
        return Int((Double(completedSets.count) / Double(plannedSetCount) * 100).rounded())
    }

    var memoryUpdateText: String {
        kneeReported ? MockData.kneeMemoryUpdate : MockData.neutralMemoryUpdate
    }

    var reviewMetrics: [(value: String, label: String)] {
        [
            ("\(durationMinutes) 分钟", "训练时长"),
            ("\(completionPercent)%", "完成度"),
            ("\(adjustmentCount) 次", "计划调整"),
        ]
    }

    /// Per-exercise outcome for the review — reports logged sets, and marks
    /// anything untouched as unfinished instead of quietly ticking it off.
    var strengthOutcomes: [ExerciseOutcome] {
        exercises.map { exercise in
            let logged = completedSets.filter { $0.exerciseID == exercise.id }
            return ExerciseOutcome(
                id: exercise.id,
                name: exercise.name,
                doneSets: logged.count,
                plannedSets: exercise.sets,
                reps: exercise.reps,
                sideBased: exercise.sideBased,
                weight: logged.last?.weight ?? exercise.weight
            )
        }
    }

    var cardioOutcome: ExerciseOutcome {
        ExerciseOutcome(
            id: "cardio",
            name: MockData.cardioName,
            doneSets: cardioElapsedMinutes,
            plannedSets: cardioTarget,
            reps: "",
            sideBased: false,
            weight: nil,
            unit: "分钟"
        )
    }

    // MARK: - Strength flow

    func enterStrength() {
        if phase == .planning {
            phase = .strengthActive
            startedAt = .now
            record = store.createSession(
                plan: plan,
                aiStyle: aiStyle,
                plannedSetCount: plannedSetCount,
                cardioTargetMinutes: cardioTarget
            )
        }
        strength.startIfNeeded()
    }

    func completeCurrentSet() {
        guard phase == .strengthActive else { return }

        let exercise = currentExercise
        let weight = currentWeight
        completedSets.append(
            CompletedSet(
                exerciseID: exercise.id,
                exerciseName: exercise.name,
                setNumber: currentSet,
                weight: weight,
                completedAt: .now
            )
        )
        if let record {
            store.log(set: currentSet, of: exercise, weight: weight, to: record)
        }

        justCompletedSet = true
        Task {
            try? await Task.sleep(for: .seconds(0.9))
            justCompletedSet = false
        }

        let wasLastSet = currentSet >= exercise.sets
        let wasLastExercise = exerciseIndex >= exercises.count - 1

        if wasLastSet && wasLastExercise {
            phase = .strengthComplete
        } else {
            phase = .strengthRest
            startRest()
        }
    }

    private func startRest() {
        restTask?.cancel()
        restRemaining = MockData.restDuration
        restTask = Task {
            while restRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                restRemaining -= 1
            }
            finishRest()
        }
    }

    func skipRest() {
        restTask?.cancel()
        restTask = nil
        finishRest()
    }

    private func finishRest() {
        guard phase == .strengthRest else { return }
        restRemaining = 0

        if currentSet >= currentExercise.sets {
            exerciseIndex += 1
            currentSet = 1
            announceCurrentExercise()
        } else {
            currentSet += 1
        }
        phase = .strengthActive
    }

    /// The coach calls the next movement so the user is never guessing.
    private func announceCurrentExercise() {
        let exercise = currentExercise
        let load = weightOverrides[exercise.id] ?? exercise.weight
        let loadText = load.map { "，\(Format.kg($0))" } ?? ""
        strength.announce(
            CoachLine(
                core: "下一个：\(exercise.name)，\(exercise.volumeLabel)\(loadText)。",
                gentleLead: "慢慢来，",
                encouragingLead: "节奏很好，"
            )
        )
    }

    // MARK: - Cardio flow

    func enterCardio() {
        restTask?.cancel()
        if phase != .cardioComplete {
            phase = .cardioActive
        }
        cardio.startIfNeeded()
        startCardioTicker()
    }

    /// Wall-clock, one second at a time. The "完成有氧" control exists for
    /// demos precisely because this is now real.
    private func startCardioTicker() {
        guard cardioTask == nil else { return }
        cardioTask = Task {
            while cardioSeconds < cardioTarget * 60 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                cardioSeconds += 1
            }
            if phase == .cardioActive {
                phase = .cardioComplete
            }
        }
    }

    func completeCardio() {
        cardioTask?.cancel()
        cardioTask = nil
        cardioSeconds = cardioTarget * 60
        phase = .cardioComplete
    }

    // MARK: - Review

    func enterReview() {
        guard phase != .review else { return }
        cardioTask?.cancel()
        cardioTask = nil
        restTask?.cancel()
        restTask = nil
        phase = .review
        persistOutcome()
    }

    /// Closes the session and writes back what the coach learned.
    private func persistOutcome() {
        guard let record else { return }
        store.finish(record, adjustments: adjustmentCount, cardioSeconds: cardioSeconds)

        if kneeReported {
            store.upsertMemory(
                id: "mem-knee",
                category: .injury,
                text: "右膝不适，避免跳跃",
                sourceSessionID: record.id
            )
            store.upsertMemory(
                id: "mem-knee-followup",
                category: .injury,
                text: "台阶上步先做 2 组",
                sourceSessionID: record.id
            )
        }
    }

    // MARK: - Reset

    func reset() {
        restTask?.cancel()
        cardioTask?.cancel()
        restTask = nil
        cardioTask = nil
        phase = .planning
        exerciseIndex = 0
        currentSet = 1
        weightOverrides = [:]
        swappedExercises = [:]
        completedSets = []
        restRemaining = 0
        cardioSeconds = 0
        kneeReported = false
        adjustmentCount = 0
        record = nil
        startedAt = .now
        makeThreads()
    }

    // MARK: - Effects from the coach

    private func handle(_ effect: TurnEffect) {
        switch effect {
        case .reduceWeight(let value):
            // A rewritten prescription — this is what the review counts.
            weightOverrides[currentExercise.id] = value
            kneeReported = true
            adjustmentCount += 1
        case .flattenIncline:
            // A machine setting, not a plan rewrite.
            kneeReported = true
        }
    }
}

// MARK: - Value types

struct CompletedSet: Identifiable, Hashable {
    let id = UUID()
    let exerciseID: String
    let exerciseName: String
    let setNumber: Int
    let weight: Double?
    let completedAt: Date
}

/// Row model for the review — knows the difference between done and planned.
struct ExerciseOutcome: Identifiable, Hashable {
    let id: String
    let name: String
    let doneSets: Int
    let plannedSets: Int
    let reps: String
    let sideBased: Bool
    let weight: Double?
    var unit = "组"

    var isComplete: Bool { doneSets >= plannedSets }
    var isUntouched: Bool { doneSets == 0 }

    var detail: String {
        if unit == "分钟" {
            return "\(doneSets) / \(plannedSets) 分钟"
        }
        let suffix = sideBased ? " / 侧" : ""
        return "\(doneSets) / \(plannedSets) 组 · \(reps) 次\(suffix)"
    }
}

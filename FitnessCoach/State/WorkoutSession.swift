import Foundation
import Observation

/// Single source of truth for one training session: plan, phase machine,
/// live numbers and the two coaching threads.
@MainActor
@Observable
final class WorkoutSession {

    // MARK: - Plan & preferences

    let plan = MockData.legDayPlan
    let memories = MockData.memories

    var aiStyle: AIStyle = .practical {
        didSet {
            strength.style = aiStyle
            cardio.style = aiStyle
        }
    }

    // MARK: - Phase

    private(set) var phase: WorkoutPhase = .planning

    // MARK: - Strength

    /// Page 3 coaches the first strength movement set by set.
    var coachedExercise: Exercise { plan.strengthExercises[0] }
    var totalSets: Int { coachedExercise.sets }
    private(set) var currentSet = 1
    private(set) var currentWeight: Double = MockData.legDayExercises[0].weight ?? 12
    private(set) var completedSets = 0
    private(set) var restRemaining = 0
    private(set) var justCompletedSet = false

    // MARK: - Cardio

    private(set) var cardioElapsed = MockData.cardioStartMinutes
    let cardioTarget = MockData.cardioTargetMinutes

    // MARK: - Memory outcomes

    private(set) var kneeReported = false
    private(set) var adjustmentCount = 0

    // MARK: - Threads

    private(set) var strength: CoachThread!
    private(set) var cardio: CoachThread!

    private var restTask: Task<Void, Never>?
    private var cardioTask: Task<Void, Never>?

    init() {
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
    }

    // MARK: - Derived labels

    var strengthMetrics: String {
        "\(Format.kg(currentWeight)) · \(coachedExercise.reps) 次"
    }

    var setProgressLabel: String { "第 \(currentSet) / \(totalSets) 组" }

    var cardioProgressLabel: String { "已完成 \(cardioElapsed) / \(cardioTarget) 分钟" }

    var cardioProgress: Double {
        min(1, Double(cardioElapsed) / Double(cardioTarget))
    }

    var isResting: Bool { phase == .strengthRest }

    var memoryUpdateText: String {
        kneeReported ? MockData.kneeMemoryUpdate : MockData.neutralMemoryUpdate
    }

    var reviewMetrics: [(value: String, label: String)] {
        [
            ("\(MockData.reviewDurationMinutes) 分钟", "训练时长"),
            ("\(MockData.reviewCompletion)%", "完成度"),
            ("\(adjustmentCount) 次", "计划调整"),
        ]
    }

    // MARK: - Strength flow

    func enterStrength() {
        if phase == .planning {
            phase = .strengthActive
        }
        strength.startIfNeeded()
    }

    func completeCurrentSet() {
        guard phase == .strengthActive else { return }
        completedSets = currentSet
        justCompletedSet = true

        Task {
            try? await Task.sleep(for: .seconds(0.9))
            justCompletedSet = false
        }

        if currentSet >= totalSets {
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
        currentSet = min(currentSet + 1, totalSets)
        phase = .strengthActive
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

    private func startCardioTicker() {
        guard cardioTask == nil else { return }
        cardioTask = Task {
            while cardioElapsed < cardioTarget {
                try? await Task.sleep(for: .seconds(4))
                if Task.isCancelled { return }
                cardioElapsed += 1
            }
            if phase == .cardioActive {
                phase = .cardioComplete
            }
        }
    }

    func completeCardio() {
        cardioTask?.cancel()
        cardioTask = nil
        cardioElapsed = cardioTarget
        phase = .cardioComplete
    }

    func enterReview() {
        cardioTask?.cancel()
        cardioTask = nil
        phase = .review
    }

    // MARK: - Reset

    func reset() {
        restTask?.cancel()
        cardioTask?.cancel()
        restTask = nil
        cardioTask = nil
        phase = .planning
        currentSet = 1
        completedSets = 0
        restRemaining = 0
        currentWeight = MockData.legDayExercises[0].weight ?? 12
        cardioElapsed = MockData.cardioStartMinutes
        kneeReported = false
        adjustmentCount = 0
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
        strength.style = aiStyle
        cardio.style = aiStyle
    }

    // MARK: - Effects from the coach

    private func handle(_ effect: TurnEffect) {
        switch effect {
        case .reduceWeight(let value):
            // A rewritten prescription — this is what the review counts.
            currentWeight = value
            kneeReported = true
            adjustmentCount += 1
        case .flattenIncline:
            // A machine setting, not a plan rewrite.
            kneeReported = true
        }
    }
}

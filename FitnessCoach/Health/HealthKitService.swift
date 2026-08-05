import Foundation
import HealthKit
import Observation

/// The intentionally small, local-only health snapshot shown in the plan tab.
/// It is not written to SwiftData and never enters a coaching request.
struct HealthSummary: Equatable, Sendable {
    let workoutsInLastSevenDays: Int
    let workoutMinutesInLastSevenDays: Int
    let todaySteps: Int?
    let todayActiveEnergyKilocalories: Int?
    let refreshedAt: Date

    var hasData: Bool {
        workoutsInLastSevenDays > 0
            || todaySteps != nil
            || todayActiveEnergyKilocalories != nil
    }
}

/// This deliberately has no `denied` state. HealthKit makes denied read access
/// indistinguishable from no matching samples, which protects the user's privacy.
enum HealthKitState: Equatable {
    case unavailable
    case notConnected
    case requestingAccess
    case loading
    case ready(HealthSummary)
    case noData
    case failed
}

@MainActor
@Observable
final class HealthKitService {
    private let healthStore = HKHealthStore()
    private let workoutType = HKObjectType.workoutType()
    private let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    private let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!

    private(set) var state: HealthKitState

    init() {
        state = HKHealthStore.isHealthDataAvailable() ? .notConnected : .unavailable
    }

    /// Triggered only by the user's explicit tap. A completed authorization
    /// request does not reveal which individual read types were declined.
    func requestAccessAndRefresh() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            state = .unavailable
            return
        }

        state = .requestingAccess
        do {
            try await requestReadAuthorization()
            await refresh()
        } catch {
            state = .failed
        }
    }

    /// Re-queries only the summary visible in the UI. The service holds no raw
    /// samples after each query completes.
    func refresh() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            state = .unavailable
            return
        }

        state = .loading
        do {
            let now = Date.now
            let calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: now)
            let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now

            async let workouts = workoutSummary(from: sevenDaysAgo, to: now)
            async let steps = cumulativeQuantity(
                type: stepCountType,
                unit: .count(),
                from: todayStart,
                to: now
            )
            async let energy = cumulativeQuantity(
                type: activeEnergyType,
                unit: .kilocalorie(),
                from: todayStart,
                to: now
            )

            let (workout, stepValue, energyValue) = try await (workouts, steps, energy)
            let summary = HealthSummary(
                workoutsInLastSevenDays: workout.count,
                workoutMinutesInLastSevenDays: workout.minutes,
                todaySteps: stepValue.map { Int($0.rounded()) },
                todayActiveEnergyKilocalories: energyValue.map { Int($0.rounded()) },
                refreshedAt: now
            )
            state = summary.hasData ? .ready(summary) : .noData
        } catch {
            state = .failed
        }
    }

    private var readTypes: Set<HKObjectType> {
        [workoutType, stepCountType, activeEnergyType]
    }

    private func requestReadAuthorization() async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: [], read: readTypes) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func workoutSummary(
        from start: Date,
        to end: Date
    ) async throws -> (count: Int, minutes: Int) {
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: .strictStartDate
        )
        let workouts: [HKWorkout] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: samples?.compactMap { $0 as? HKWorkout } ?? [])
            }
            healthStore.execute(query)
        }
        let minutes = workouts.reduce(0.0) { $0 + $1.duration } / 60
        return (workouts.count, Int(minutes.rounded()))
    }

    private func cumulativeQuantity(
        type: HKQuantityType,
        unit: HKUnit,
        from start: Date,
        to end: Date
    ) async throws -> Double? {
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: .strictStartDate
        )
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: statistics?.sumQuantity()?.doubleValue(for: unit))
            }
            healthStore.execute(query)
        }
    }
}

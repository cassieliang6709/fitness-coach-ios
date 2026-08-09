import Foundation
import Observation

@MainActor
@Observable
final class LabProgress {
    private enum Key {
        static let completedDays = "vance.lab.completed-days"
        static let lessonSteps = "vance.lab.lesson-steps"
        static let answers = "vance.lab.answers"
        static let personalPlan = "vance.lab.personal-plan"
    }

    private(set) var completedDays: Set<Int>
    private(set) var lessonSteps: [Int: Int]
    private(set) var answers: [String: String]
    private(set) var personalPlan: [String]

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-uitest") {
            defaults.removeObject(forKey: Key.completedDays)
            defaults.removeObject(forKey: Key.lessonSteps)
            defaults.removeObject(forKey: Key.answers)
            defaults.removeObject(forKey: Key.personalPlan)
        }

        completedDays = Set(defaults.array(forKey: Key.completedDays) as? [Int] ?? [])
        lessonSteps = Self.intDictionary(defaults.dictionary(forKey: Key.lessonSteps))
        answers = defaults.dictionary(forKey: Key.answers) as? [String: String] ?? [:]
        personalPlan = defaults.stringArray(forKey: Key.personalPlan) ?? []

        #if DEBUG
        if let index = arguments.firstIndex(of: "-lab-day"),
            arguments.indices.contains(index + 1),
            let day = Int(arguments[index + 1]),
            (1...7).contains(day)
        {
            completedDays = Set(1..<day)
        }
        #endif
    }

    var currentDay: Int {
        (1...7).first { !completedDays.contains($0) } ?? 7
    }

    var isCourseComplete: Bool {
        completedDays.count == LabCourse.lessons.count
    }

    var masteredCount: Int { completedDays.count }

    func isUnlocked(_ day: Int) -> Bool {
        day <= currentDay || completedDays.contains(day)
    }

    func step(for day: Int) -> Int {
        lessonSteps[day] ?? 0
    }

    func save(step: Int, for day: Int) {
        lessonSteps[day] = step
        persist()
    }

    func save(answer: String, lessonDay: Int, stepID: String) {
        answers["\(lessonDay).\(stepID)"] = answer
        persist()
    }

    func answer(lessonDay: Int, stepID: String) -> String? {
        answers["\(lessonDay).\(stepID)"]
    }

    func complete(day: Int) {
        completedDays.insert(day)
        lessonSteps[day] = 0
        persist()
    }

    func save(personalPlan: [String]) {
        self.personalPlan = personalPlan
        persist()
    }

    private func persist() {
        defaults.set(completedDays.sorted(), forKey: Key.completedDays)
        defaults.set(
            Dictionary(uniqueKeysWithValues: lessonSteps.map { (String($0.key), $0.value) }),
            forKey: Key.lessonSteps
        )
        defaults.set(answers, forKey: Key.answers)
        defaults.set(personalPlan, forKey: Key.personalPlan)
    }

    private static func intDictionary(_ source: [String: Any]?) -> [Int: Int] {
        guard let source else { return [:] }
        var result: [Int: Int] = [:]
        for (key, value) in source {
            guard let intKey = Int(key), let intValue = value as? Int else { continue }
            result[intKey] = intValue
        }
        return result
    }
}

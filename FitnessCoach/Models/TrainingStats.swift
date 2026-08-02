import Foundation

/// Everything the plan tab reports about the user's history, derived from the
/// finished sessions in storage. Nothing here is a mock number — an empty store
/// produces an honest set of zeros.
struct TrainingStats: Hashable {
    let weeklyDone: Int
    let weeklyTarget: Int
    /// Weekday indexes (0 = Monday) that already have a finished session.
    let completedWeekdays: Set<Int>
    let streakDays: Int
    let totalSessions: Int
    let totalMinutes: Int
    let totalSets: Int

    /// Monday-first, matching how the week reads in Chinese.
    static var trainingWeek: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }

    static let weekdayLabels = ["一", "二", "三", "四", "五", "六", "日"]

    init(sessions: [SessionRecord], weeklyTarget: Int, now: Date = .now) {
        let calendar = Self.trainingWeek
        let finished = sessions.filter { $0.endedAt != nil }
        let week = calendar.dateInterval(of: .weekOfYear, for: now)

        let thisWeek = finished.filter { week?.contains($0.startedAt) ?? false }
        self.weeklyDone = thisWeek.count
        self.weeklyTarget = weeklyTarget
        self.completedWeekdays = Set(
            thisWeek.compactMap { Self.weekdayIndex(of: $0.startedAt, calendar: calendar) }
        )

        self.totalSessions = finished.count
        self.totalMinutes = finished.reduce(0) { $0 + $1.durationMinutes }
        self.totalSets = finished.reduce(0) { $0 + $1.setLogs.count }
        self.streakDays = Self.streak(
            days: Set(finished.map { calendar.startOfDay(for: $0.startedAt) }),
            calendar: calendar,
            now: now
        )
    }

    // MARK: - Derived

    var weeklyProgress: Double {
        guard weeklyTarget > 0 else { return 0 }
        return min(1, Double(weeklyDone) / Double(weeklyTarget))
    }

    var remainingThisWeek: Int { max(0, weeklyTarget - weeklyDone) }

    /// Header subtitle — praises a finished week rather than showing "还差 0 次".
    var weeklyHeadline: String {
        remainingThisWeek == 0
            ? "本周目标已经完成了"
            : "本周还差 \(remainingThisWeek) 次训练"
    }

    var tiles: [(value: String, label: String)] {
        [
            ("\(streakDays) 天", "连续打卡"),
            ("\(totalSessions) 次", "累计训练"),
            ("\(totalMinutes) 分钟", "累计时长"),
        ]
    }

    // MARK: - Internals

    /// 0 = Monday … 6 = Sunday, independent of the device's first weekday.
    private static func weekdayIndex(of date: Date, calendar: Calendar) -> Int? {
        let weekday = calendar.component(.weekday, from: date)  // 1 = Sunday
        return (weekday + 5) % 7
    }

    /// Consecutive days ending today. A rest day today does not break the
    /// streak yet — it only breaks once yesterday is also empty.
    private static func streak(days: Set<Date>, calendar: Calendar, now: Date) -> Int {
        var cursor = calendar.startOfDay(for: now)
        if !days.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                return 0
            }
            cursor = yesterday
        }

        var count = 0
        while days.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previous
        }
        return count
    }
}

import Foundation

/// Last known good plan, kept so a cold launch on a bad network shows the
/// user's real plan instead of falling back to the sample one.
///
/// Deliberately not SwiftData: D1 owns the plan, this is only a cache. Keeping
/// the wire model here avoids a second local persistence schema for server data.
enum PlanCache {
    private static let key = "cachedPlanWire"

    private struct Entry: Codable {
        let plan: PlanWire
        let cachedAt: Date
    }

    static func save(_ plan: PlanWire) {
        let entry = Entry(plan: plan, cachedAt: .now)
        guard let data = try? JSONEncoder().encode(entry) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    /// A plan is labelled "today" in the UI, so yesterday's cache is not a
    /// valid fallback. Legacy un-dated cache entries are deliberately ignored.
    static func loadForToday(now: Date = .now) -> PlanWire? {
        guard let data = UserDefaults.standard.data(forKey: key),
            let entry = try? JSONDecoder().decode(Entry.self, from: data),
            Calendar.current.isDate(entry.cachedAt, inSameDayAs: now)
        else { return nil }
        return entry.plan
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

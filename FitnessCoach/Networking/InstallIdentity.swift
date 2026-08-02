import Foundation

/// Who the Worker thinks we are.
///
/// The backend keys plans and memories off a `user` query parameter and has no
/// account system yet, so the client supplies its own id. A UUID generated once
/// per install is enough: it is stable across launches, it is not derived from
/// anything identifying, and it disappears when the app is deleted.
///
/// Deliberately not `identifierForVendor` — that value is shared across every
/// app from the same vendor and resets in ways we don't control.
enum InstallIdentity {
    private static let key = "installUserID"

    /// UI tests and demo mode share one id so the fixtures they rely on don't
    /// have to be re-seeded per run.
    static let demoID = "demo"

    static var current: String {
        if ProcessInfo.processInfo.arguments.contains("-uitest") { return demoID }

        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: key), !existing.isEmpty {
            return existing
        }

        let fresh = UUID().uuidString
        defaults.set(fresh, forKey: key)
        return fresh
    }
}

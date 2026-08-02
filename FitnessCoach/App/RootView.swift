import SwiftUI

/// Routes mirror the spec's URL paths one-to-one.
/// /plans is the stack root; the rest are pushed destinations.
enum Route: Hashable {
    case plans
    case legDay
    case strength
    case cardio
    case review

    var path: String {
        switch self {
        case .plans: return "/plans"
        case .legDay: return "/plans/leg-day"
        case .strength: return "/workout/strength"
        case .cardio: return "/workout/cardio"
        case .review: return "/workout/review"
        }
    }

    init?(path: String) {
        guard let match = Route.all.first(where: { $0.path == path }) else { return nil }
        self = match
    }

    static let all: [Route] = [.plans, .legDay, .strength, .cardio, .review]
}

struct RootView: View {
    @State private var session = WorkoutSession()
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            PlanLibraryView(path: $path)
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .plans:
                        PlanLibraryView(path: $path)
                    case .legDay:
                        LegDayDetailView(path: $path)
                    case .strength:
                        StrengthCoachView(path: $path)
                    case .cardio:
                        CardioCoachView(path: $path)
                    case .review:
                        ReviewView(path: $path)
                    }
                }
        }
        .environment(session)
        .tint(Theme.primary)
        .preferredColorScheme(.light)
        .onAppear(perform: applyLaunchRoute)
    }

    /// Deep-link straight to a route for screenshotting and manual QA:
    /// `xcrun simctl launch booted <id> -route /workout/strength`
    private func applyLaunchRoute() {
        #if DEBUG
        guard path.isEmpty,
            let raw = UserDefaults.standard.string(forKey: "route"),
            let route = Route(path: raw),
            route != .plans
        else { return }
        path = [route]
        #endif
    }
}

// MARK: - Navigation helpers

extension Array where Element == Route {
    /// Replace the coaching page rather than stacking them, so "back" from
    /// cardio never lands on a finished strength session.
    mutating func replaceLast(with route: Route) {
        if isEmpty {
            append(route)
        } else {
            self[count - 1] = route
        }
    }

    mutating func popToRoot() {
        removeAll()
    }
}

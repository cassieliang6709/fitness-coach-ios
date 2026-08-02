import SwiftUI

/// Routes mirror the spec's URL paths one-to-one.
/// /home is the stack root; the rest are pushed destinations.
enum Route: Hashable {
    case home
    case plans
    case legDay
    case strength
    case cardio
    case review

    var path: String {
        switch self {
        case .home: return "/home"
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

    static let all: [Route] = [.home, .plans, .legDay, .strength, .cardio, .review]
}

struct RootView: View {
    let session: WorkoutSession
    let store: WorkoutStore

    @State private var path: [Route] = []
    /// A stored profile means the welcome flow is done. Held in state so
    /// finishing onboarding swaps the root without a relaunch.
    @State private var onboarded: Bool

    init(session: WorkoutSession, store: WorkoutStore) {
        self.session = session
        self.store = store
        _onboarded = State(initialValue: store.hasProfile)
    }

    var body: some View {
        NavigationStack(path: $path) {
            root
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .home:
                        HomeView(path: $path)
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
        .environment(\.workoutStore, store)
        .tint(Theme.primary)
        .preferredColorScheme(.light)
        .onAppear(perform: applyLaunchRoute)
    }

    @ViewBuilder
    private var root: some View {
        if onboarded {
            HomeView(path: $path)
        } else {
            WelcomeView(onFinish: finishOnboarding)
        }
    }

    /// The welcome answers become the profile, the memory chips and the coach's
    /// tone in one step — nothing is left for the user to set up afterwards.
    private func finishOnboarding(_ profile: UserProfile) {
        store.completeOnboarding(profile)
        session.aiStyle = profile.style
        withAnimation(.easeInOut(duration: 0.3)) {
            onboarded = true
        }
    }

    /// Deep-link straight to a route for screenshotting and manual QA:
    /// `xcrun simctl launch booted <id> -route /workout/strength`
    private func applyLaunchRoute() {
        #if DEBUG
        guard path.isEmpty,
            onboarded,
            let raw = UserDefaults.standard.string(forKey: "route"),
            let route = Route(path: raw),
            route != .home
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

// MARK: - Store access

private struct WorkoutStoreKey: EnvironmentKey {
    static let defaultValue: WorkoutStore? = nil
}

extension EnvironmentValues {
    var workoutStore: WorkoutStore? {
        get { self[WorkoutStoreKey.self] }
        set { self[WorkoutStoreKey.self] = newValue }
    }
}

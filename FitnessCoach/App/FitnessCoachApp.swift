import SwiftData
import SwiftUI

@main
@MainActor
struct FitnessCoachApp: App {

    private let container: ModelContainer
    private let store: WorkoutStore
    @State private var session: WorkoutSession

    init() {
        // Demo and UI-test runs get a throwaway store. A debug deep link only
        // chooses a screen; it must not silently turn live coaching into the
        // sample script.
        let arguments = ProcessInfo.processInfo.arguments
        let usesLiveServiceFixture = Self.usesLiveServiceFixture(arguments)
        let usesDemoStore =
            arguments.contains("-uitest") || arguments.contains("-onboarded")
            || arguments.contains("-demo") || usesLiveServiceFixture
        let container = WorkoutStore.makeContainer(inMemory: usesDemoStore)
        let store = WorkoutStore(context: container.mainContext)

        // A genuine first launch goes through the welcome flow, which is what
        // writes the profile and the first memory chips. The test/demo flag
        // skips straight past it; a deep link continues to use the real store.
        if arguments.contains("-onboarded") || arguments.contains("-demo")
            || usesLiveServiceFixture
        {
            store.seedDemoProfileIfNeeded()
        }

        self.container = container
        self.store = store
        _session = State(initialValue: WorkoutSession(store: store))
    }

    /// Debug-only harnesses use an in-memory profile while keeping the real
    /// Worker/Gateway clients. Neither model output nor a generated plan is
    /// seeded by this flag.
    private static func usesLiveServiceFixture(_ arguments: [String]) -> Bool {
        #if DEBUG
        return arguments.contains("-live-audio-fixture")
            || arguments.contains("-live-plan-fixture")
        #else
        return false
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView(session: session, store: store)
        }
        .modelContainer(container)
    }
}

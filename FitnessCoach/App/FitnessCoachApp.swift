import SwiftData
import SwiftUI

@main
@MainActor
struct FitnessCoachApp: App {

    private let container: ModelContainer
    private let store: WorkoutStore
    @State private var session: WorkoutSession

    init() {
        // UI tests get a throwaway store so they never touch real training data.
        let arguments = ProcessInfo.processInfo.arguments
        let isUITest = arguments.contains("-uitest")
        let container = WorkoutStore.makeContainer(inMemory: isUITest)
        let store = WorkoutStore(context: container.mainContext)

        // A genuine first launch goes through the welcome flow, which is what
        // writes the profile and the first memory chips. `-onboarded` and any
        // deep link (which presumes an existing user) skip straight past it.
        if arguments.contains("-onboarded") || arguments.contains("-route") {
            store.seedDemoProfileIfNeeded()
        }

        self.container = container
        self.store = store
        _session = State(initialValue: WorkoutSession(store: store))
    }

    var body: some Scene {
        WindowGroup {
            RootView(session: session, store: store)
        }
        .modelContainer(container)
    }
}

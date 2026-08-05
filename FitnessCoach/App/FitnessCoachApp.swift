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
        let usesLiveAudioFixture = Self.usesLiveAudioFixture(arguments)
        let usesDemoStore =
            arguments.contains("-uitest") || arguments.contains("-onboarded")
            || arguments.contains("-demo") || usesLiveAudioFixture
        let container = WorkoutStore.makeContainer(inMemory: usesDemoStore)
        let store = WorkoutStore(context: container.mainContext)

        // A genuine first launch goes through the welcome flow, which is what
        // writes the profile and the first memory chips. The test/demo flag
        // skips straight past it; a deep link continues to use the real store.
        if arguments.contains("-onboarded") || arguments.contains("-demo")
            || usesLiveAudioFixture
        {
            store.seedDemoProfileIfNeeded()
        }

        self.container = container
        self.store = store
        _session = State(initialValue: WorkoutSession(store: store))
    }

    /// Debug-only harness: a deterministic workout with live network clients,
    /// used by the bundled-audio integration test. Assistant output is never
    /// seeded — it must still arrive from the realtime gateway.
    private static func usesLiveAudioFixture(_ arguments: [String]) -> Bool {
        #if DEBUG
        return arguments.contains("-live-audio-fixture")
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

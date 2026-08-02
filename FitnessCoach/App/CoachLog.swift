import os

/// Signposts for the paths that fail quietly.
///
/// Coach speech is best-effort by design — a text reply must survive a voice
/// outage — which also means a broken voice path leaves no trace in the UI.
/// These channels exist so "I heard nothing" can be traced to a specific step.
///
/// Every line goes to the unified log for Console.app, and in debug builds also
/// to stdout, which is what `devicectl process launch --console` can read off a
/// tethered phone without any extra tooling.
enum CoachLog {

    /// Text-to-speech: request, bytes returned, route, playback outcome.
    static let voice = Channel(category: "voice")

    /// Coach turns: what each thread delivered, and whether it was cancelled.
    static let thread = Channel(category: "thread")

    struct Channel {
        private let logger: Logger
        private let category: String

        init(category: String) {
            self.category = category
            self.logger = Logger(subsystem: "com.cassie.fitnesscoach", category: category)
        }

        func info(_ message: @autoclosure () -> String) {
            emit(message(), isError: false)
        }

        func error(_ message: @autoclosure () -> String) {
            emit(message(), isError: true)
        }

        private func emit(_ message: String, isError: Bool) {
            if isError {
                logger.error("\(message, privacy: .public)")
            } else {
                logger.info("\(message, privacy: .public)")
            }
            #if DEBUG
            print("[\(category)] \(message)")
            #endif
        }
    }
}

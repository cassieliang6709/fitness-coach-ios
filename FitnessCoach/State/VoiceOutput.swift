import Foundation

/// Whether the coach is allowed to make sound.
///
/// Off by default, so opening the app is silent: the coach's opening line lands
/// as text and nothing reaches the speech model until the user asks for it.
/// Launching straight into audio was the complaint — it talks over whatever the
/// user is already listening to, and on the workout pages it also seized the
/// microphone before anyone had agreed to a session.
///
/// Kept in `UserDefaults` rather than passed down the view tree because the two
/// places that need it can't share state any other way: `CoachThread` is a plain
/// observable object with no environment, while the toggle is a view using
/// `@AppStorage(VoiceOutput.key)`. Both read and write the same value.
enum VoiceOutput {
    static let key = "voiceEnabled"

    /// Absent key reads as `false`, which is the intended default — no
    /// registration needed.
    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: key)
    }
}

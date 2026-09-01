import SwiftUI

/// Header speaker toggle. One switch for the whole app: it silences the chat's
/// text-to-speech and keeps the workout pages from opening a realtime session,
/// so a muted app never reaches a speech model at all.
struct VoiceToggleButton: View {
    @AppStorage(VoiceOutput.key) private var voiceEnabled = false

    var body: some View {
        IconButton(
            symbol: voiceEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill",
            tint: voiceEnabled ? Theme.primary : Theme.secondaryText,
            background: voiceEnabled ? Theme.lightOrange : Theme.surface
        ) {
            voiceEnabled.toggle()
        }
        .accessibilityIdentifier("voice-toggle")
        .accessibilityLabel(voiceEnabled ? "关闭语音" : "开启语音")
        .animation(.easeInOut(duration: 0.15), value: voiceEnabled)
    }
}

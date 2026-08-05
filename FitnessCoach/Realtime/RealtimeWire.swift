import Foundation

/// The MiniMax Realtime event names the gateway passes through, as documented
/// in `Vance_Coach_Gateway_Handoff_20260802/SWIFTUI_HANDOFF.md`.
///
/// Only the events this client actually acts on are modelled. The gateway is a
/// transparent proxy today, so anything MiniMax adds arrives here untouched and
/// falls through `RealtimeSession.handle(_:)` unhandled rather than erroring.
enum RealtimeWire {

    /// 24 kHz mono PCM16 — the only format the upstream session is configured
    /// for, so capture, playback and the wire all agree on it.
    static let sampleRate: Double = 24_000

    /// Voices cleared for the MVP by the handoff document.
    static let defaultVoice = "male-qn-jingying"

    // MARK: - Outgoing

    /// Let the gateway own the provider configuration and Vance's instructions.
    /// Sending MiniMax's `session.update` directly would bypass that boundary
    /// and create a generic MiniMax session instead of the Vance coach.
    static func sessionUpdate(
        voice: String,
        style: AIStyle,
        state: CoachContext,
        memories: [String]
    ) -> [String: Any] {
        var statePayload: [String: Any] = [
            "phase": state.phase,
            "exercise": state.exercise,
            "prescription": state.prescription,
        ]
        if let value = state.setNumber { statePayload["setNumber"] = value }
        if let value = state.totalSets { statePayload["totalSets"] = value }
        if let value = state.venue { statePayload["venue"] = value }
        if let value = state.elapsedMinutes { statePayload["elapsedMinutes"] = value }
        if let value = state.targetMinutes { statePayload["targetMinutes"] = value }

        return [
            "type": "vance.session.configure",
            "session": [
                "voiceId": voice,
                "style": style.rawValue,
                "state": statePayload,
                "memories": memories,
            ],
        ]
    }

    static func audioAppend(base64: String) -> [String: Any] {
        ["type": "input_audio_buffer.append", "audio": base64]
    }

    static let audioCommit: [String: Any] = ["type": "input_audio_buffer.commit"]

    static let audioClear: [String: Any] = ["type": "input_audio_buffer.clear"]

    static func userText(_ text: String) -> [String: Any] {
        [
            "type": "conversation.item.create",
            "item": [
                "type": "message",
                "role": "user",
                "status": "completed",
                "content": [["type": "input_text", "text": text]],
            ],
        ]
    }

    static func responseCreate(voice: String) -> [String: Any] {
        [
            "type": "response.create",
            "response": ["modalities": ["audio", "text"], "voice": voice],
        ]
    }

    /// Client-side VAD telemetry. The gateway logs these and does not forward
    /// them upstream, so they are safe to send at any point in a turn.
    static func vad(stage: String, metrics: [String: Any] = [:]) -> [String: Any] {
        ["type": "client.vad", "stage": stage, "metrics": metrics]
    }

    static func encode(_ event: [String: Any]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: event) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }
}

// MARK: - Incoming

/// A server event, decoded loosely: MiniMax reuses `delta` across the text and
/// audio streams, and the transcript of what the user said arrives buried in
/// `conversation.item.created`.
struct RealtimeServerEvent: Decodable {
    let type: String
    let delta: String?
    let item: Item?
    let error: ErrorBody?

    struct Item: Decodable {
        let content: [Content]?
    }

    struct Content: Decodable {
        let type: String?
        let text: String?
        let transcript: String?
    }

    struct ErrorBody: Decodable {
        let code: String?
        let message: String?
    }

    /// What the user was heard saying, when the server echoes the item back.
    var inputTranscript: String? {
        item?.content?.compactMap { $0.transcript ?? $0.text }
            .first { !$0.isEmpty }
    }

    static func decode(_ text: String) -> RealtimeServerEvent? {
        try? JSONDecoder().decode(RealtimeServerEvent.self, from: Data(text.utf8))
    }
}

/// One line in the live transcript.
struct RealtimeMessage: Identifiable, Equatable {
    enum Role { case user, coach }

    let id = UUID()
    let role: Role
    var text: String
    /// Coach lines stream in token by token; the last one stays open until
    /// `response.done` so deltas append instead of creating new bubbles.
    var isComplete: Bool
}

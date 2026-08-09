import AVFoundation
import Foundation

/// Plays one MiniMax-generated coach reply and restores the user's previous
/// audio after it finishes. The player owns no API credentials or text logic.
@MainActor
final class CoachSpeechPlayer {
    enum Failure: LocalizedError {
        case invalidAudio
        case playbackUnavailable

        var errorDescription: String? {
            switch self {
            case .invalidAudio: return "MiniMax 返回的语音无法播放"
            case .playbackUnavailable: return "语音播放无法启动"
            }
        }
    }

    private var player: AVAudioPlayer?

    var isPlaying: Bool { player?.isPlaying == true }

    func play(_ data: Data) async throws {
        stop()

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try session.setActive(true)
        let route = session.currentRoute.outputs.first?.portType.rawValue ?? "none"
        CoachLog.voice.info(
            "session: \(session.category.rawValue) → \(route) @ \(session.outputVolume)")

        let next: AVAudioPlayer
        do {
            next = try AVAudioPlayer(data: data)
        } catch {
            CoachLog.voice.error("decode failed: \(String(describing: error))")
            deactivateSession()
            throw Failure.invalidAudio
        }
        next.prepareToPlay()
        player = next

        guard next.play() else {
            CoachLog.voice.error("play() refused")
            stop()
            throw Failure.playbackUnavailable
        }
        CoachLog.voice.info("playing: \(next.duration)s vol=\(next.volume)")

        do {
            while next.isPlaying {
                try await Task.sleep(for: .milliseconds(100))
            }
            if player === next {
                player = nil
                deactivateSession()
            }
        } catch {
            stop()
            throw error
        }
    }

    func stop() {
        player?.stop()
        player = nil
        deactivateSession()
    }

    private func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(
            false, options: [.notifyOthersOnDeactivation])
    }
}

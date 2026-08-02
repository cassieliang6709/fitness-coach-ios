import AVFoundation
import Foundation
import Observation
import Speech

/// On-device speech recognition for the coaching pages.
///
/// Dictation in a gym is noisy and users stop mid-sentence, so this doesn't
/// wait for `isFinal` — it publishes partial transcripts as they arrive and
/// ends the turn after a short pause. Tapping the mic again ends it early.
@MainActor
@Observable
final class SpeechRecognizer {

    enum Availability: Equatable {
        case unknown
        case ready
        /// Permission denied, restricted, or no recognizer for the locale.
        case unavailable(String)
    }

    private(set) var availability: Availability = .unknown
    private(set) var transcript = ""
    private(set) var isRecording = false

    /// Seconds of no new words before the turn is considered finished.
    private let silenceTimeout: TimeInterval = 1.6

    private let recognizer: SFSpeechRecognizer?
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var silenceTimer: Task<Void, Never>?
    private var onFinish: ((String) -> Void)?

    init(locale: Locale = Locale(identifier: "zh-CN")) {
        recognizer = SFSpeechRecognizer(locale: locale)
    }

    // MARK: - Permissions

    /// Asks for speech + microphone access. Safe to call repeatedly.
    func requestAccess() async {
        guard recognizer?.isAvailable == true else {
            availability = .unavailable("当前语言的语音识别不可用")
            return
        }

        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speech == .authorized else {
            availability = .unavailable("语音识别权限未开启")
            return
        }

        let mic = await AVAudioApplication.requestRecordPermission()
        guard mic else {
            availability = .unavailable("麦克风权限未开启")
            return
        }

        availability = .ready
    }

    // MARK: - Recording

    /// Starts listening. `onFinish` fires once with the final transcript —
    /// empty if the user said nothing.
    func start(onFinish: @escaping (String) -> Void) {
        guard !isRecording, let recognizer, recognizer.isAvailable else { return }

        self.onFinish = onFinish
        transcript = ""

        do {
            try configureSession()
        } catch {
            availability = .unavailable("无法启动录音")
            onFinish("")
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // Keep audio on the device. Slightly lower accuracy than the server
        // path, but no workout audio leaves the phone.
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        self.request = request

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            cleanUp()
            availability = .unavailable("无法启动录音")
            onFinish("")
            return
        }

        isRecording = true
        armSilenceTimer()

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self, self.isRecording else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                    if result.isFinal {
                        self.finish()
                    } else {
                        self.armSilenceTimer()
                    }
                } else if error != nil {
                    self.finish()
                }
            }
        }
    }

    /// Ends the turn now — used when the user taps the mic a second time.
    func stop() {
        guard isRecording else { return }
        finish()
    }

    /// Aborts without delivering a transcript.
    func cancel() {
        guard isRecording else { return }
        onFinish = nil
        cleanUp()
        transcript = ""
    }

    // MARK: - Internals

    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        // .duckOthers so the user's workout music dips instead of stopping.
        try session.setCategory(
            .playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    /// Restarted on every partial result; firing means the user stopped talking.
    private func armSilenceTimer() {
        silenceTimer?.cancel()
        silenceTimer = Task { [silenceTimeout] in
            try? await Task.sleep(for: .seconds(silenceTimeout))
            guard !Task.isCancelled else { return }
            finish()
        }
    }

    private func finish() {
        guard isRecording else { return }
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let callback = onFinish
        onFinish = nil
        cleanUp()
        callback?(text)
    }

    private func cleanUp() {
        silenceTimer?.cancel()
        silenceTimer = nil
        isRecording = false

        engine.inputNode.removeTap(onBus: 0)
        if engine.isRunning { engine.stop() }

        request?.endAudio()
        request = nil
        task?.cancel()
        task = nil

        // Hand audio back so music resumes at full volume.
        try? AVAudioSession.sharedInstance().setActive(
            false, options: .notifyOthersOnDeactivation)
    }
}

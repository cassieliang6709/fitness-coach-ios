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
        /// Only for things a retry cannot fix — everything transient goes to
        /// `lastFailure` instead, or one bad tap would kill dictation for the
        /// rest of the app's life.
        case unavailable(String)
    }

    private(set) var availability: Availability = .unknown
    private(set) var transcript = ""
    private(set) var isRecording = false

    /// Why the last attempt ended without words, when the cause was temporary:
    /// the audio session was busy, the engine wouldn't start, the recognition
    /// service dropped, a call came in. Cleared at the start of every attempt.
    private(set) var lastFailure: String?

    /// Seconds of silence before the turn is considered finished. The lead-in
    /// is longer because it covers the user deciding what to say — partial
    /// results only start once they actually speak, so a 1.6s window here shut
    /// the mic off while people were still thinking.
    private let leadInTimeout: TimeInterval = 5
    private let silenceTimeout: TimeInterval = 1.6

    private let recognizer: SFSpeechRecognizer?
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var silenceTimer: Task<Void, Never>?
    private var onFinish: ((String) -> Void)?
    private let observers = ObserverTokens()

    init(locale: Locale = Locale(identifier: "zh-CN")) {
        recognizer = SFSpeechRecognizer(locale: locale)
        observeAudioDisruptions()
    }

    // MARK: - Permissions

    /// Asks for speech + microphone access. Safe to call repeatedly — the
    /// system only shows a dialog the first time, so callers can re-check after
    /// a denial in case the user changed their mind in Settings.
    func requestAccess() async {
        // Deliberately not checking `isAvailable` here: it flips with system
        // and network conditions, so it belongs in the per-attempt check in
        // `start()`, not in a verdict that sticks.
        guard recognizer != nil else {
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
        // Hand this caller back its turn, but leave the in-flight recording's
        // own callback alone so the turn already running still delivers.
        guard !isRecording else {
            lastFailure = "上一次录音还没结束"
            onFinish("")
            return
        }

        self.onFinish = onFinish
        transcript = ""
        lastFailure = nil

        // Checked per attempt, not once: `isAvailable` goes false while the
        // system is busy or offline and comes back on its own. Returning here
        // without calling back would leave the caller stuck in "listening".
        guard let recognizer, recognizer.isAvailable else {
            fail("语音识别暂时不可用，稍后再试", onFinish: onFinish)
            return
        }

        do {
            try configureSession()
        } catch {
            fail("无法开始录音，可能有其他应用正在占用麦克风", onFinish: onFinish)
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
        // A zero-rate format means the input route isn't up yet — right after a
        // call, or while another engine is tearing down. Installing a tap with
        // it traps inside AVAudioEngine instead of throwing.
        guard format.sampleRate > 0, format.channelCount > 0 else {
            fail("麦克风还没准备好，再试一次", onFinish: onFinish)
            return
        }
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            cleanUp()
            fail("无法开始录音，可能有其他应用正在占用麦克风", onFinish: onFinish)
            return
        }

        isRecording = true
        armSilenceTimer(after: leadInTimeout)

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self, self.isRecording else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                    if result.isFinal {
                        self.finish()
                    } else {
                        self.armSilenceTimer(after: self.silenceTimeout)
                    }
                } else if error != nil {
                    // Mid-sentence drops still deliver what was heard; only a
                    // turn with nothing at all needs explaining to the user.
                    if self.transcript.isEmpty {
                        self.lastFailure = "语音识别中断了，再说一次"
                    }
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

    /// Ends the attempt without a transcript, keeping `availability` intact so
    /// the next tap tries again.
    private func fail(_ reason: String, onFinish: (String) -> Void) {
        lastFailure = reason
        self.onFinish = nil
        onFinish("")
    }

    /// Restarted on every partial result; firing means the user stopped talking.
    private func armSilenceTimer(after seconds: TimeInterval) {
        silenceTimer?.cancel()
        silenceTimer = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.finish()
        }
    }

    /// A call, Siri, or an unplugged headset stops the engine underneath us and
    /// the recognizer never hears another buffer. Without this the turn sits in
    /// "listening" until the user taps again.
    private func observeAudioDisruptions() {
        let center = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()
        let handler: @Sendable (Notification) -> Void = { [weak self] note in
            Task { @MainActor in self?.handleDisruption(note) }
        }
        observers.tokens = [
            center.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: session, queue: nil, using: handler),
            center.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: session, queue: nil, using: handler),
            center.addObserver(
                forName: .AVAudioEngineConfigurationChange,
                object: engine, queue: nil, using: handler),
        ]
    }

    private func handleDisruption(_ note: Notification) {
        guard isRecording else { return }

        switch note.name {
        case AVAudioSession.interruptionNotification:
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            guard raw == AVAudioSession.InterruptionType.began.rawValue else { return }

        case AVAudioSession.routeChangeNotification:
            // Only the reasons that actually invalidate the input tap. Our own
            // `setCategory` fires a `.categoryChange` that must be ignored.
            let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            let reason = raw.flatMap(AVAudioSession.RouteChangeReason.init(rawValue:))
            guard reason == .oldDeviceUnavailable || reason == .newDeviceAvailable else {
                return
            }

        default:
            break
        }

        // Deliver a partial sentence if there is one — it beats losing the turn.
        if transcript.isEmpty { lastFailure = "录音被打断了，再说一次" }
        finish()
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

/// Holds the notification tokens outside the main actor so they are removed
/// when the recognizer goes away — a `deinit` on the recognizer itself can't
/// touch its own isolated state.
private final class ObserverTokens: @unchecked Sendable {
    var tokens: [NSObjectProtocol] = []

    deinit {
        let center = NotificationCenter.default
        for token in tokens { center.removeObserver(token) }
    }
}

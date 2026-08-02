import AVFoundation
import Foundation
import Speech

/// Microphone capture and coach playback for the realtime session.
///
/// Both directions live on one `AVAudioEngine` on purpose: the voice-processing
/// I/O unit needs to see our own playback to cancel it out of the mic feed.
/// Without that, the speaker's audio is transcribed back as user speech and the
/// coach interrupts itself — the failure mode is loud and immediate on a phone
/// held at arm's length in a gym.
///
/// The wire format is 24 kHz mono PCM16. The hardware is usually 48 kHz float,
/// and the engine's processing graph is float throughout, so int16 conversion
/// happens at the two edges only.
final class RealtimeAudioEngine {

    enum Failure: LocalizedError {
        case sessionUnavailable(String)

        var errorDescription: String? {
            switch self {
            case .sessionUnavailable(let detail): return "音频通道无法启动：\(detail)"
            }
        }
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()

    /// What the engine's graph carries: float32, deinterleaved, 24 kHz.
    private let graphFormat = AVAudioFormat(
        standardFormatWithSampleRate: RealtimeWire.sampleRate, channels: 1)!

    /// What the wire carries: int16, interleaved, 24 kHz.
    private let wireFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: RealtimeWire.sampleRate,
        channels: 1,
        interleaved: true)!

    private var converter: AVAudioConverter?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var transcriptionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var transcriptionTask: SFSpeechRecognitionTask?
    private var isRunning = false
    private var isCapturing = false

    /// Frames still queued on the player. Tracked so the UI can tell "the coach
    /// is speaking" from "the coach finished" without polling the node.
    private var scheduledBuffers = 0
    private let bufferLock = NSLock()

    var isPlaying: Bool {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        return scheduledBuffers > 0
    }

    // MARK: - Lifecycle

    /// Configures the audio session and starts the engine with playback live and
    /// the mic idle. Capture is gated separately by `startCapture`.
    func start() throws {
        guard !isRunning else { return }

        let session = AVAudioSession.sharedInstance()
        do {
            // .voiceChat gives us the echo-cancelled input path and routes to
            // the speaker rather than the earpiece.
            try session.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.defaultToSpeaker, .allowBluetooth])
            try session.setPreferredSampleRate(RealtimeWire.sampleRate)
            try session.setActive(true, options: [])
        } catch {
            throw Failure.sessionUnavailable(error.localizedDescription)
        }

        // Must happen before the graph is built: toggling voice processing
        // reconfigures the I/O unit and invalidates existing taps. The
        // simulator's voice-processing I/O can stop its engine after startup;
        // it also cannot validate real echo cancellation, so keep the stable
        // regular I/O path there and reserve voice processing for devices.
        #if !targetEnvironment(simulator)
        try? engine.inputNode.setVoiceProcessingEnabled(true)
        try? engine.outputNode.setVoiceProcessingEnabled(true)
        #endif

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: graphFormat)

        engine.prepare()
        do {
            try engine.start()
        } catch {
            throw Failure.sessionUnavailable(error.localizedDescription)
        }
        player.play()
        isRunning = true
    }

    func stop() {
        stopCapture()
        transcriptionTask?.cancel()
        transcriptionTask = nil
        transcriptionRequest = nil
        stopPlayback()
        player.stop()
        engine.stop()
        if isRunning {
            engine.detach(player)
            try? AVAudioSession.sharedInstance().setActive(
                false, options: [.notifyOthersOnDeactivation])
        }
        isRunning = false
    }

    // MARK: - Capture

    /// Installs one mic tap for both the MiniMax PCM stream and the user-visible
    /// local transcript. This avoids two audio engines competing for the same
    /// simulator/device input route.
    func startCapture(
        onChunk: @escaping (Data) -> Void,
        onTranscript: @escaping (String, Bool) -> Void
    ) throws {
        guard isRunning, !isCapturing else { return }

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        // A zero sample rate means the input hardware never came up (simulator
        // without a mic, or a route change mid-start). Bail rather than install
        // a tap that will trap in AVAudioConverter.
        guard inputFormat.sampleRate > 0 else {
            throw Failure.sessionUnavailable("麦克风输入格式不可用")
        }

        converter = AVAudioConverter(from: inputFormat, to: wireFormat)
        guard let converter else {
            throw Failure.sessionUnavailable("无法创建 24 kHz 音频转换器")
        }

        transcriptionTask?.cancel()
        let transcriptionRequest = SFSpeechAudioBufferRecognitionRequest()
        transcriptionRequest.shouldReportPartialResults = true
        if let speechRecognizer {
            transcriptionRequest.requiresOnDeviceRecognition =
                speechRecognizer.supportsOnDeviceRecognition
        }
        self.transcriptionRequest = transcriptionRequest
        transcriptionTask = speechRecognizer?.recognitionTask(with: transcriptionRequest) {
            result, error in
            if let result {
                onTranscript(result.bestTranscription.formattedString, result.isFinal)
            } else if error != nil {
                onTranscript("", true)
            }
        }

        // 100 ms of input audio per callback. The tap size is a hint — CoreAudio
        // rounds it — which is why the output capacity below is derived from the
        // buffer we actually receive.
        let tapSize = AVAudioFrameCount(inputFormat.sampleRate / 10)
        input.installTap(onBus: 0, bufferSize: tapSize, format: inputFormat) { buffer, _ in
            transcriptionRequest.append(buffer)
            guard let chunk = Self.convert(buffer, with: converter, to: self.wireFormat) else {
                return
            }
            onChunk(chunk)
        }

        // The simulator may stop an otherwise configured engine after an audio
        // route reconfiguration. `isRunning` above tracks our graph lifecycle,
        // while `engine.isRunning` is the source of truth for live I/O.
        if !engine.isRunning {
            engine.prepare()
            do {
                try engine.start()
            } catch {
                input.removeTap(onBus: 0)
                self.converter = nil
                throw Failure.sessionUnavailable(error.localizedDescription)
            }
        }
        if !player.isPlaying {
            player.play()
        }
        isCapturing = true
    }

    func stopCapture() {
        guard isCapturing else { return }
        engine.inputNode.removeTap(onBus: 0)
        transcriptionRequest?.endAudio()
        converter?.reset()
        converter = nil
        isCapturing = false
    }

    /// Resamples one tap buffer to 24 kHz PCM16 and returns its raw bytes.
    private static func convert(
        _ buffer: AVAudioPCMBuffer,
        with converter: AVAudioConverter,
        to format: AVAudioFormat
    ) -> Data? {
        let ratio = format.sampleRate / buffer.format.sampleRate
        // Rounding up plus a frame of slack: the converter keeps a small
        // internal history across calls, so output length is not exactly
        // input × ratio.
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 1
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
            return nil
        }

        var consumed = false
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if consumed {
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return buffer
        }

        guard error == nil, output.frameLength > 0, let samples = output.int16ChannelData else {
            return nil
        }
        return Data(bytes: samples[0], count: Int(output.frameLength) * MemoryLayout<Int16>.size)
    }

    // MARK: - Playback

    /// Queues one `response.audio.delta` payload. Buffers play back to back in
    /// arrival order, which is what keeps the coach's speech intelligible.
    func enqueue(pcm16: Data) {
        guard isRunning, !pcm16.isEmpty else { return }

        let frames = pcm16.count / MemoryLayout<Int16>.size
        guard frames > 0,
            let buffer = AVAudioPCMBuffer(
                pcmFormat: graphFormat, frameCapacity: AVAudioFrameCount(frames))
        else { return }
        buffer.frameLength = AVAudioFrameCount(frames)

        // Copied through an array rather than read in place: `Data` from base64
        // carries no alignment guarantee, and loading Int16 from an odd address
        // is undefined.
        var samples = [Int16](repeating: 0, count: frames)
        _ = samples.withUnsafeMutableBytes { pcm16.copyBytes(to: $0) }

        guard let channel = buffer.floatChannelData else { return }
        for index in 0..<frames {
            channel[0][index] = Float(Int16(littleEndian: samples[index])) / 32_768
        }

        bufferLock.lock()
        scheduledBuffers += 1
        bufferLock.unlock()

        player.scheduleBuffer(buffer) { [weak self] in
            guard let self else { return }
            bufferLock.lock()
            scheduledBuffers -= 1
            bufferLock.unlock()
        }
    }

    /// Drops everything queued. Used for barge-in: the moment the user starts
    /// talking, the coach should stop mid-sentence like a person would.
    func stopPlayback() {
        guard isRunning else { return }
        player.stop()
        bufferLock.lock()
        scheduledBuffers = 0
        bufferLock.unlock()
        if engine.isRunning {
            player.play()
        }
    }
}

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

    /// What the player node carries: int16, deinterleaved, 24 kHz. Coach audio
    /// arrives in exactly this format, so it reaches the mixer without a
    /// conversion step in between that can fail into silence.
    private let playbackFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: RealtimeWire.sampleRate,
        channels: 1,
        interleaved: false)!

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
            // .measurement keeps playback on the media volume and the built-in
            // speaker. .voiceChat put it on the voice-call path instead, where a
            // phone whose media volume is up still plays the coach at almost
            // nothing, and .allowBluetooth handed the route to whatever headset
            // happened to be paired.
            try session.setCategory(
                .playAndRecord,
                mode: .measurement,
                options: [.duckOthers, .defaultToSpeaker])
            try session.setPreferredSampleRate(RealtimeWire.sampleRate)
            try session.setActive(true, options: [])
        } catch {
            throw Failure.sessionUnavailable(error.localizedDescription)
        }

        // No voice processing on either node. Echo cancellation only earns its
        // cost when the mic is open while the coach speaks, and capture here is
        // push-to-talk: `beginSpeaking` stops playback before it installs the
        // tap, so the speaker is never in the mic's way. Enabling it on the
        // output node also reconfigures the I/O unit behind the graph, which is
        // what left devices silent while the simulator stayed fine.

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: playbackFormat)

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

        let bytes = pcm16.count - pcm16.count % MemoryLayout<Int16>.size
        let frames = bytes / MemoryLayout<Int16>.size
        guard frames > 0,
            let buffer = AVAudioPCMBuffer(
                pcmFormat: playbackFormat, frameCapacity: AVAudioFrameCount(frames))
        else { return }
        buffer.frameLength = AVAudioFrameCount(frames)

        // Copied byte-wise rather than as Int16s: `Data` from base64 carries no
        // alignment guarantee, and the wire is already little-endian int16, so
        // the bytes need no reinterpretation on the way in.
        guard let channel = buffer.int16ChannelData else { return }
        channel[0].withMemoryRebound(to: UInt8.self, capacity: bytes) { destination in
            _ = pcm16.copyBytes(
                to: UnsafeMutableBufferPointer(start: destination, count: bytes))
        }

        bufferLock.lock()
        scheduledBuffers += 1
        bufferLock.unlock()

        // The node stops itself when a barge-in drains the queue, and a stopped
        // node accepts buffers without ever sounding them.
        if !player.isPlaying {
            player.play()
        }

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

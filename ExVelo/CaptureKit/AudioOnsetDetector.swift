import AVFAudio
import Accelerate

/// Listens to the microphone for the "crack of the bat" — a sudden spike in
/// amplitude relative to the recent ambient noise floor — so a session can
/// auto-trigger a hit instead of requiring a tap per swing. This is the V1
/// audio-onset approach described in docs/ASSESSMENT.md §2.3, promoted to the
/// primary trigger; the manual "Mark Hit" button remains as a fallback for
/// noisy environments where a swing's crack doesn't clear the threshold.
final class AudioOnsetDetector {
    var onOnsetDetected: (() -> Void)?

    private let audioEngine = AVAudioEngine()
    private var noiseFloor: Float = 0.0005
    private var lastTriggerTime: TimeInterval = -.infinity
    private var isRunning = false

    /// How many times louder than the ambient floor a sound needs to be to count
    /// as a hit, tuned to reject speech/crowd noise while catching a bat crack.
    private let triggerMultiplier: Float = 5.0
    /// A floor below which nothing triggers, even if it's relatively loud versus
    /// near-silence — avoids false positives while setting up in a quiet room.
    private let minimumAbsoluteThreshold: Float = 0.02
    private let noiseFloorDecay: Float = 0.98
    /// Ignores further onsets for this long after a trigger, so one crack (plus
    /// its natural decay/echo) can't fire twice for the same swing.
    private let cooldownSeconds: TimeInterval = 2.0

    func requestAccess() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    func start() throws {
        guard !isRunning else { return }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.mixWithOthers])
        try session.setActive(true)

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.process(buffer: buffer)
        }
        audioEngine.prepare()
        try audioEngine.start()
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        try? AVAudioSession.sharedInstance().setActive(false)
        isRunning = false
    }

    private func process(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameCount = vDSP_Length(buffer.frameLength)
        var rms: Float = 0
        vDSP_rmsqv(channelData[0], 1, &rms, frameCount)

        let now = ProcessInfo.processInfo.systemUptime
        let isOnset = rms > noiseFloor * triggerMultiplier && rms > minimumAbsoluteThreshold
        let cooledDown = now - lastTriggerTime > cooldownSeconds

        if isOnset, cooledDown {
            lastTriggerTime = now
            let callback = onOnsetDetected
            DispatchQueue.main.async { callback?() }
        } else if !isOnset {
            // Only adapt toward quiet stretches, so a loud hit doesn't immediately
            // raise the floor and suppress detection of the very next swing.
            noiseFloor = noiseFloor * noiseFloorDecay + rms * (1 - noiseFloorDecay)
        }
    }
}

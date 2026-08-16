import AVFoundation
import CoreMedia

/// Owns the AVCaptureSession: selects the highest-fps format the device supports,
/// buffers frames continuously, and trims a clip around the moment the user marks
/// contact rather than requiring them to start recording ahead of the swing.
@MainActor
final class CaptureSessionController: NSObject, ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var achievedFrameRate: Double = 0
    @Published private(set) var frameRateWarning: String?
    @Published private(set) var isMarkingHit = false
    @Published private(set) var lastCapturedClipURL: URL?
    @Published private(set) var captureError: String?
    @Published private(set) var activeCameraGeometry: CameraGeometry?

    let session = AVCaptureSession()

    private let sampleBufferQueue = DispatchQueue(label: "com.jonahobitz.exvelo.samplebuffer")
    private let videoOutput = AVCaptureVideoDataOutput()
    // Every buffered frame is an uncompressed image held in memory: even at the
    // efficient NV12 format below, a 720p frame is ~1.4MB, so at up to 240fps a
    // few seconds of buffer is already several hundred MB. 1.5s comfortably covers
    // human reaction time to tap "Mark Hit" after contact without exhausting memory.
    private let rollingBuffer = RollingFrameBuffer(retainedDuration: 1.5)
    private var activeDevice: AVCaptureDevice?

    func requestAccessAndConfigure() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        guard granted else {
            captureError = "Camera access denied. Enable it in Settings to record swings."
            return
        }
        configureSession()
    }

    func start() {
        guard !session.isRunning else { return }
        let session = session
        Task.detached(priority: .userInitiated) {
            session.startRunning()
        }
        isRunning = true
    }

    func stop() {
        guard session.isRunning else { return }
        let session = session
        Task.detached(priority: .userInitiated) {
            session.stopRunning()
        }
        isRunning = false
    }

    func lockExposureAndFocus() {
        guard let device = activeDevice else { return }
        do {
            try device.lockForConfiguration()
            if device.isFocusModeSupported(.locked) { device.focusMode = .locked }
            if device.isExposureModeSupported(.locked) { device.exposureMode = .locked }
            device.unlockForConfiguration()
        } catch {
            captureError = "Failed to lock exposure/focus: \(error.localizedDescription)"
        }
    }

    /// Marks the moment of contact. Waits a short post-roll so the ball's flight is
    /// still in the buffer, then writes the trimmed window to a clip on disk.
    func markHit(postRollDuration: TimeInterval = 1.0) async -> URL? {
        isMarkingHit = true
        defer { isMarkingHit = false }
        try? await Task.sleep(for: .seconds(postRollDuration))
        let buffers = await rollingBuffer.snapshot()
        guard !buffers.isEmpty else {
            captureError = "No frames captured yet."
            return nil
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        do {
            try await ClipWriter.write(buffers: buffers, to: url)
            lastCapturedClipURL = url
            return url
        } catch {
            captureError = "Failed to save clip: \(error.localizedDescription)"
            return nil
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .inputPriority

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            captureError = "No rear camera available."
            return
        }
        activeDevice = device

        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                captureError = "Could not add camera input."
                return
            }
            for existingInput in session.inputs {
                session.removeInput(existingInput)
            }
            session.addInput(input)
        } catch {
            captureError = "Failed to open camera: \(error.localizedDescription)"
            return
        }

        guard let selection = CameraFormatSelector.selectBestFormat(for: device) else {
            captureError = "No usable capture format found."
            return
        }

        do {
            try device.lockForConfiguration()
            device.activeFormat = selection.format
            let duration = CMTime(value: 1, timescale: Int32(selection.maxFrameRate.rounded()))
            device.activeVideoMinFrameDuration = duration
            device.activeVideoMaxFrameDuration = duration
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            device.unlockForConfiguration()
        } catch {
            captureError = "Failed to configure camera format: \(error.localizedDescription)"
            return
        }

        achievedFrameRate = selection.maxFrameRate
        frameRateWarning = selection.maxFrameRate < CameraFormatSelector.minimumAcceptableFrameRate
            ? "This device tops out at \(Int(selection.maxFrameRate)) fps. Fast swings may be hard to track below \(Int(CameraFormatSelector.minimumAcceptableFrameRate)) fps."
            : nil
        activeCameraGeometry = CameraGeometry(
            pixelWidth: Int(selection.dimensions.width),
            pixelHeight: Int(selection.dimensions.height),
            horizontalFieldOfViewDegrees: selection.format.videoFieldOfView
        )

        // Explicit, memory-efficient pixel format (~1.5 bytes/pixel) rather than
        // leaving this to the default, which can be a 4-bytes/pixel format on some
        // devices — a 2.7x memory difference that matters a lot at high frame rates.
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
        ]
        videoOutput.setSampleBufferDelegate(self, queue: sampleBufferQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        guard session.canAddOutput(videoOutput) else {
            captureError = "Could not add video output."
            return
        }
        for existingOutput in session.outputs {
            session.removeOutput(existingOutput)
        }
        session.addOutput(videoOutput)
    }
}

extension CaptureSessionController: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let rollingBuffer = rollingBuffer
        Task { await rollingBuffer.append(sampleBuffer) }
    }
}

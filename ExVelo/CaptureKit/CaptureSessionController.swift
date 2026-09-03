import AVFoundation
import CoreMedia

/// Owns the AVCaptureSession: selects the highest-fps format the device supports
/// and streams live frames out for tracking. Unlike a swing analyzer, a radar gun
/// has nothing to trim around — every frame is forwarded live via `onSampleBuffer`
/// rather than buffered for a later "mark the hit" moment.
@MainActor
final class CaptureSessionController: NSObject, ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var achievedFrameRate: Double = 0
    @Published private(set) var frameRateWarning: String?
    @Published private(set) var captureError: String?
    @Published private(set) var activeCameraGeometry: CameraGeometry?

    let session = AVCaptureSession()

    /// Called on the sample-buffer delegate queue (never the main actor) for every
    /// captured frame. `nonisolated(unsafe)` because it's read from the nonisolated
    /// delegate callback; safe because it's only ever assigned once, before the
    /// session starts producing frames.
    nonisolated(unsafe) var onSampleBuffer: ((CMSampleBuffer) -> Void)?

    private let sampleBufferQueue = DispatchQueue(label: "com.jonahobitz.exvelo.samplebuffer")
    private let videoOutput = AVCaptureVideoDataOutput()
    private var activeDevice: AVCaptureDevice?

    func requestAccessAndConfigure() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        guard granted else {
            captureError = "Camera access denied. Enable it in Settings to use the radar gun."
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
            ? "This device tops out at \(Int(selection.maxFrameRate)) fps. Fast pitches/hits may be hard to track below \(Int(CameraFormatSelector.minimumAcceptableFrameRate)) fps."
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
        onSampleBuffer?(sampleBuffer)
    }
}

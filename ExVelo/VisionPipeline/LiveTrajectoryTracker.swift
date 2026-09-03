import AVFoundation
import Vision

/// Runs VNDetectTrajectoriesRequest continuously over live camera frames, reusing
/// the same request instance across frames so Vision can keep accumulating evidence
/// for a parabolic path instead of re-detecting it from scratch each frame — the
/// same technique docs/ASSESSMENT.md describes for a recorded clip, applied live so
/// a reading is available the moment a ball's path is tracked instead of after the
/// fact. Not thread-safe on its own: every call must come from the same serial
/// queue (the capture session's sample-buffer queue), which is what makes the
/// unsynchronized dictionary access below safe.
final class LiveTrajectoryTracker {
    struct Configuration {
        /// Minimum points needed to fit a parabola. Vision requires at least 5.
        var trajectoryLength: Int = 10
    }

    private let configuration: Configuration
    private var latestByID: [UUID: TrackedTrajectory] = [:]

    private lazy var request: VNDetectTrajectoriesRequest = {
        VNDetectTrajectoriesRequest(frameAnalysisSpacing: .zero, trajectoryLength: configuration.trajectoryLength) { [weak self] request, error in
            guard error == nil, let observations = request.results as? [VNTrajectoryObservation] else { return }
            for observation in observations {
                self?.latestByID[observation.uuid] = TrackedTrajectory(observation: observation)
            }
        }
    }()

    init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    /// Feeds one live frame into the ongoing trajectory request and returns every
    /// trajectory tracked so far. VNDetectTrajectoriesRequest's completion handler
    /// runs synchronously within `perform`, so `latestByID` is already up to date
    /// by the time this returns.
    func process(sampleBuffer: CMSampleBuffer) -> [TrackedTrajectory] {
        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up, options: [:])
        try? handler.perform([request])
        return Array(latestByID.values)
    }

    /// Clears tracked state so the next ball through the frame starts a fresh
    /// trajectory instead of blending with a stale one.
    func reset() {
        latestByID.removeAll()
    }
}
